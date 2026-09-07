import Foundation

struct APIProblem: Decodable, LocalizedError {
    let error, message: String
    var errorDescription: String? {
        switch error {
        case "UNAUTHORIZED", "SOCIAL_LOGIN_REQUIRED": return "Inicia sesión para continuar con tu cuenta."
        case "MARKET_UNAVAILABLE", "QUOTE_LOADING": return "No hemos podido obtener el precio. Vuelve a intentarlo en unos instantes."
        case "METHOD_NOT_ALLOWED", "TOO_LARGE", "INVALID_BODY": return "No hemos podido completar la acción. Vuelve a intentarlo."
        default: return message
        }
    }
}
@MainActor final class APIClient {
    let auth: AuthStore
    init(auth: AuthStore) { self.auth = auth }
    private var baseURL: String {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled { return "https://maestro.invalid" }
        #endif
        return Configuration.value("API_BASE_URL")
    }
    private var session: URLSession {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled { return MaestroEnvironment.session }
        #endif
        return .shared
    }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = true) async throws -> T {
        guard let url = URL(string: baseURL + "/api/" + path) else { throw AppError.message("No se puede conectar.") }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
        request.timeoutInterval = path.hasPrefix("quote?") ? 45 : 20
        if authenticated { request.setValue("Bearer \(try await auth.token())", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AppError.message("Respuesta no válida.") }
        guard (200..<300).contains(response.statusCode) else {
            if let problem = try? JSONDecoder().decode(APIProblem.self, from: data) { throw problem }
            throw AppError.message("No se pudo completar. Puedes volver a intentarlo.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Preserve actionable app errors without exposing SDK or decoding diagnostics.
enum UserMessage {
    static func describe(_ error: Error) -> String {
        if let problem = error as? APIProblem { return problem.errorDescription ?? "Vuelve a intentarlo." }
        if let problem = error as? AppError { return problem.localizedDescription }
        if error is URLError { return "No hemos podido conectar. Comprueba tu conexión y vuelve a intentarlo." }
        return "No hemos podido completar la acción. Vuelve a intentarlo en unos instantes."
    }
}
