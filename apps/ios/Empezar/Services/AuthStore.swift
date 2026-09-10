import Foundation
import Combine
import Security
import AuthenticationServices
import CryptoKit
import UIKit

enum Configuration {
    static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return dict
    }()
    static func value(_ name: String) -> String {
        if name == "API_BASE_URL", testPurchases { return values["REVENUECAT_TEST_API_BASE_URL"] ?? "" }
        return values[name] ?? ""
    }
    static var configured: Bool {
        ["API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY"].allSatisfy { !value($0).isEmpty && !value($0).contains("YOUR_") }
    }
    static var testPurchases: Bool {
        #if DEBUG
        return value("REVENUECAT_TEST_MODE") == "true"
        #else
        return false
        #endif
    }
    static var revenueCatKey: String {
        value(testPurchases ? "REVENUECAT_TEST_KEY" : "REVENUECAT_PUBLIC_KEY")
    }
    static var purchasesConfigured: Bool {
        revenueCatKey.hasPrefix(testPurchases ? "test_" : "appl_") && !revenueCatKey.contains("REPLACE")
    }
}
enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
}
struct AuthProviders: Decodable {
    let external: [String: Bool]
    var appleEnabled: Bool { external["apple"] == true }
    var googleEnabled: Bool { external["google"] == true }
}

struct AuthSession: Codable {
    struct User: Codable {
        let id: String
        var email: String? = nil
        var user_metadata: Metadata? = nil
        struct Metadata: Codable {
            var avatar_url: String? = nil
            var picture: String? = nil
            var full_name: String? = nil
            var name: String? = nil
        }
        var displayName: String { user_metadata?.full_name ?? user_metadata?.name ?? email?.components(separatedBy: "@").first ?? "Mi cuenta" }
        var initials: String { displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
        var avatarURL: URL? {
            guard let value = user_metadata?.avatar_url ?? user_metadata?.picture,
                  let url = URL(string: value), url.scheme == "https" else { return nil }
            return url
        }
    }
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
    private var webAuthenticationSession: ASWebAuthenticationSession?
    private let webAuthenticationContext = WebAuthenticationContext()
    private let providerSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration)
    }()
    #if DEBUG && targetEnvironment(simulator)
    private var providerChecks = 0
    #endif
    init() {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled {
            if MaestroEnvironment.scenario == "guest" || MaestroEnvironment.scenario?.hasPrefix("auth-") == true { return }
            session = AuthSession(access_token: "maestro-token", refresh_token: "",
                                  expires_at: .greatestFiniteMagnitude, user: .init(id: "maestro-user"))
            return
        }
        #endif
        if let data = SessionKeychain.read() { session = try? JSONDecoder().decode(AuthSession.self, from: data) }
    }

    static func nonce() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func pkceChallenge(_ value: String) -> String {
        Data(SHA256.hash(data: Data(value.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func availableProviders() async throws -> AuthProviders {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled {
            providerChecks += 1
            switch MaestroEnvironment.scenario {
            case "auth-timeout" where providerChecks == 1:
                try await Task.sleep(for: .seconds(60))
            case "auth-unavailable": return AuthProviders(external: ["apple": false, "google": false])
            case "auth-error" where providerChecks == 1: throw URLError(.notConnectedToInternet)
            default: break
            }
            return AuthProviders(external: ["apple": true, "google": false])
        }
        #endif
        guard Configuration.configured,
              let url = URL(string: Configuration.value("SUPABASE_URL") + "/auth/v1/settings") else {
            throw AppError.message("El inicio de sesión no está disponible ahora.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(Configuration.value("SUPABASE_ANON_KEY"), forHTTPHeaderField: "apikey")
        let (data, response) = try await providerSession.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw AppError.message("No hemos podido comprobar las opciones de acceso.")
        }
        return try JSONDecoder().decode(AuthProviders.self, from: data)
    }

    func signInWithApple(identityToken: String, nonce: String) async throws {
        let data = try await call("token?grant_type=id_token", body: ["provider": "apple", "id_token": identityToken, "nonce": nonce])
        try save(JSONDecoder().decode(AuthSession.self, from: data))
    }

    func signInWithGoogle() async throws {
        guard Configuration.configured,
              let redirect = URL(string: "empezar://auth-callback"),
              var components = URLComponents(string: Configuration.value("SUPABASE_URL") + "/auth/v1/authorize") else {
            throw AppError.message("El inicio de sesión no está disponible ahora. Vuelve a intentarlo más tarde.")
        }
        let verifier = Self.nonce()
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirect.absoluteString),
            URLQueryItem(name: "flow_type", value: "pkce"),
            URLQueryItem(name: "code_challenge", value: Self.pkceChallenge(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ]
        guard let authorizationURL = components.url else { throw AppError.message("No se pudo iniciar sesión con Google.") }
        let callback = try await authenticate(at: authorizationURL)
        guard callback.scheme == "empezar", callback.host == "auth-callback" else {
            throw AppError.message("No hemos podido completar el inicio de sesión. Vuelve a intentarlo.")
        }
        let callbackItems = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems
        if let message = callbackItems?.first(where: { $0.name == "error_description" })?.value {
            throw AppError.message(message)
        }
        guard let code = callbackItems?.first(where: { $0.name == "code" })?.value else {
            throw AppError.message("Google no devolvió una autorización válida.")
        }
        let data = try await call("token?grant_type=pkce", body: ["auth_code": code, "code_verifier": verifier])
        try save(JSONDecoder().decode(AuthSession.self, from: data))
    }

    private func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "empezar") { [weak self] callback, error in
                self?.webAuthenticationSession = nil
                if let callback { continuation.resume(returning: callback) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: AppError.message("Inicio de sesión cancelado."))
                } else {
                    continuation.resume(throwing: error ?? AppError.message("No se pudo completar el inicio de sesión."))
                }
            }
            session.presentationContextProvider = webAuthenticationContext
            session.prefersEphemeralWebBrowserSession = true
            webAuthenticationSession = session
            guard session.start() else {
                webAuthenticationSession = nil
                continuation.resume(throwing: AppError.message("No se pudo abrir el inicio de sesión."))
                return
            }
        }
    }
    func refreshProfile() async throws {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled { return }
        #endif
        guard let account = session?.user.id,
              let url = URL(string: Configuration.value("SUPABASE_URL") + "/auth/v1/user") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        request.setValue(Configuration.value("SUPABASE_ANON_KEY"), forHTTPHeaderField: "apikey")
        let (data, response) = try await providerSession.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let current = session, current.user.id == account else { return }
        let user = try JSONDecoder().decode(AuthSession.User.self, from: data)
        guard user.id == account else { return }
        try save(AuthSession(access_token: current.access_token, refresh_token: current.refresh_token,
                             expires_at: current.expires_at, user: user))
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
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled { session = nil; return }
        #endif
        if let token = session?.access_token { _ = try? await call("logout", body: [:], bearer: token) }
        clear()
    }
    private func call(_ path: String, body: [String: Any], bearer: String? = nil) async throws -> Data {
        guard Configuration.configured, let url = URL(string: Configuration.value("SUPABASE_URL") + "/auth/v1/" + path) else { throw AppError.message("El inicio de sesión no está disponible ahora. Vuelve a intentarlo más tarde.") }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 20
        r.setValue(Configuration.value("SUPABASE_ANON_KEY"), forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { r.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = payload?["msg"] as? String ?? payload?["error_description"] as? String
            throw AppError.message(message ?? "No hemos podido iniciar sesión. Inténtalo de nuevo dentro de un momento.")
        }
        return data
    }
}

@MainActor private final class WebAuthenticationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
