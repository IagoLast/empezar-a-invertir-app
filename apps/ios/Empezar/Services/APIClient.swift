import Foundation

struct APIProblem: Decodable, LocalizedError {
    let error, message: String
    var errorDescription: String? { message }
}
@MainActor final class APIClient {
    let auth: AuthStore
    init(auth: AuthStore) { self.auth = auth }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: Configuration.value("API_BASE_URL") + "/api/" + path) else { throw AppError.message("No se puede conectar.") }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 20
        request.setValue("Bearer \(try await auth.token())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AppError.message("Respuesta no válida.") }
        guard (200..<300).contains(response.statusCode) else {
            if let problem = try? JSONDecoder().decode(APIProblem.self, from: data) { throw problem }
            throw AppError.message("No se pudo completar. Puedes volver a intentarlo.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
