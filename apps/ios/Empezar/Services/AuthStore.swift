import Foundation
import Combine
import Security

enum Configuration {
    static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return dict
    }()
    static func value(_ name: String) -> String { values[name] ?? "" }
    static var configured: Bool {
        ["API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY"].allSatisfy { !value($0).isEmpty && !value($0).contains("YOUR_") }
    }
    static var purchasesConfigured: Bool { value("REVENUECAT_PUBLIC_KEY").hasPrefix("appl_") && !value("REVENUECAT_PUBLIC_KEY").contains("REPLACE") }
}
enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
}
struct AuthSession: Codable {
    struct User: Codable { let id: String }
    let access_token, refresh_token: String
    let expires_at: Double
    let user: User
}
enum SessionKeychain {
    static let service = "com.empezarainvertir.session"
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "supabase"] }
    static func read() -> Data? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }
    static func write(_ data: Data) throws {
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw AppError.message("No se pudo guardar la sesión de forma segura.") }
        var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw AppError.message("No se pudo guardar la sesión de forma segura.") }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}
@MainActor final class AuthStore: ObservableObject {
    @Published private(set) var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    init() { if let data = SessionKeychain.read() { session = try? JSONDecoder().decode(AuthSession.self, from: data) } }
    func sendCode(email: String) async throws {
        _ = try await call("otp", body: ["email": email, "create_user": true])
    }
    func verify(email: String, code: String) async throws {
        let data = try await call("verify", body: ["email": email, "token": code, "type": "email"])
        try save(JSONDecoder().decode(AuthSession.self, from: data))
    }
    func token() async throws -> String {
        guard let current = session else { throw AppError.message("Inicia sesión para continuar.") }
        if current.expires_at > Date().timeIntervalSince1970 + 90 { return current.access_token }
        if let task = refreshTask { return try await task.value.access_token }
        let task = Task { @MainActor in
            let data = try await self.call("token?grant_type=refresh_token", body: ["refresh_token": current.refresh_token])
            return try JSONDecoder().decode(AuthSession.self, from: data)
        }
        refreshTask = task
        defer { refreshTask = nil }
        let refreshed = try await task.value
        try save(refreshed)
        return refreshed.access_token
    }
    private func save(_ value: AuthSession) throws { try SessionKeychain.write(JSONEncoder().encode(value)); session = value }
    func clear() { refreshTask?.cancel(); refreshTask = nil; session = nil; SessionKeychain.clear() }
    func signOut() async {
        if let token = session?.access_token { _ = try? await call("logout", body: [:], bearer: token) }
        clear()
    }
    private func call(_ path: String, body: [String: Any], bearer: String? = nil) async throws -> Data {
        guard Configuration.configured, let url = URL(string: Configuration.value("SUPABASE_URL") + "/auth/v1/" + path) else { throw AppError.message("Esta versión aún no está conectada. Puedes explorar la interfaz.") }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 20
        r.setValue(Configuration.value("SUPABASE_ANON_KEY"), forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { r.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw AppError.message("No hemos podido verificar la solicitud. Revisa el código o inténtalo dentro de un momento.")
        }
        return data
    }
}
