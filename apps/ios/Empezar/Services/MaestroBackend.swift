#if DEBUG && targetEnvironment(simulator)
import Foundation

/// Opt-in HTTP fixtures for simulator UI tests. Never compiled into device/Release builds.
enum MaestroEnvironment {
    static let scenario = UserDefaults.standard.string(forKey: "maestro-scenario")
    static var enabled: Bool { scenario != nil }
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MaestroURLProtocol.self]
        return URLSession(configuration: configuration)
    }()
}

final class MaestroURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var portfolio = Portfolio.empty
    private static var failedState = false
    private static var failedLesson = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        do {
            let (status, data) = try respond()
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private func body() throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    private func respond() throws -> (Int, Data) {
        func json<T: Encodable>(_ value: T) throws -> (Int, Data) { (200, try JSONEncoder().encode(value)) }
        func problem(_ code: String, _ message: String, status: Int = 409) throws -> (Int, Data) {
            (status, try JSONSerialization.data(withJSONObject: ["error": code, "message": message]))
        }
        guard ["happy", "guest", "trade-rejected", "trade-response-lost", "market-closed", "quote-expired", "state-retry", "lesson-retry", "auth-timeout", "auth-error", "auth-unavailable"].contains(MaestroEnvironment.scenario ?? "") else {
            return try problem("UNKNOWN_SCENARIO", "Escenario Maestro desconocido.", status: 500)
        }
        let publicQuote = request.httpMethod == "GET" && ["/api/quote", "/api/search", "/api/history"].contains(request.url?.path ?? "")
        guard request.url?.host == "maestro.invalid",
              publicQuote || request.value(forHTTPHeaderField: "Authorization") == "Bearer maestro-token" else {
            return try problem("UNEXPECTED_REQUEST", "Petición Maestro inesperada.", status: 500)
        }
        let symbol = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "symbol" })?.value ?? ""
        switch (request.httpMethod ?? "GET", request.url!.path) {
        case ("GET", "/api/search"):
            return (200, try JSONSerialization.data(withJSONObject: ["results": [["symbol": "ITX.MC", "name": "Inditex", "kind": "stock", "exchange": "Madrid"]]]))
        case ("GET", "/api/history"):
            let points: [[String: Any]] = (0..<20).map { index -> [String: Any] in
                let value = Double(index)
                let date = Date().addingTimeInterval((value - 20) * 86400)
                return ["date": ISO8601DateFormatter().string(from: date),
                        "open": 50.0 + value, "high": 52.0 + value, "low": 49.0 + value, "close": 51.0 + value]
            }
            return (200, try JSONSerialization.data(withJSONObject: ["currency": symbol == "ITX.MC" ? "EUR" : "USD", "source": "Maestro fixture", "points": points]))
        case ("GET", "/api/state"):
            if MaestroEnvironment.scenario == "state-retry" && !Self.failedState {
                Self.failedState = true
                return try problem("UNAVAILABLE", "No se puede cargar la cartera. Inténtalo de nuevo.", status: 503)
            }
            return try json(Self.portfolio)
        case ("GET", "/api/quote"):
            guard Content.instruments.contains(where: { $0.symbol == symbol }) || symbol == "ITX.MC" else {
                return try problem("INVALID_INPUT", "Símbolo desconocido.")
            }
            let now = ISO8601DateFormatter().string(from: Date())
            var quote = Quote(id: "maestro-\(symbol)", symbol: symbol, priceCents: 10_000,
                              currency: "USD", changePercent: 1.5, asOf: now, fetchedAt: now,
                              expiresAt: MaestroEnvironment.scenario == "quote-expired" ? "2000-01-01T00:00:00Z" : "2099-01-01T00:00:00Z",
                              marketOpen: MaestroEnvironment.scenario != "market-closed", tradable: true,
                              mode: "realtime", delaySeconds: 0, source: "Maestro fixture")
            if symbol == "ITX.MC" {
                quote.nativePrice = 90; quote.nativeCurrency = "EUR"; quote.exchangeRate = 1.111111
                quote.name = "Inditex"; quote.kind = "stock"
            }
            Self.portfolio.quotes.removeAll { $0.symbol == symbol }
            Self.portfolio.quotes.append(quote)
            return try json(quote)
        case ("GET", "/api/fundamentals"):
            return try json(["available": false])
        case ("POST", "/api/lesson"):
            if MaestroEnvironment.scenario == "lesson-retry" && !Self.failedLesson {
                Self.failedLesson = true
                return try problem("UNAVAILABLE", "No se pudo guardar la lección. Inténtalo de nuevo.", status: 503)
            }
            struct LessonBody: Decodable { let lessonId: String }
            let input = try JSONDecoder().decode(LessonBody.self, from: body())
            guard Content.lessons.contains(where: { $0.id == input.lessonId }) else {
                return try problem("INVALID_INPUT", "Lección desconocida.")
            }
            if !Self.portfolio.completedLessons.contains(input.lessonId) {
                Self.portfolio.completedLessons.append(input.lessonId)
            }
            return try json(Self.portfolio)
        case ("POST", "/api/trade"):
            let trade = try JSONDecoder().decode(TradeRequest.self, from: body())
            if Self.portfolio.orders.contains(where: { $0.requestId == trade.requestId }) {
                return try json(Self.portfolio)
            }
            guard trade.units > 0, trade.units <= 100000, ["buy", "sell"].contains(trade.side),
                  let quote = Self.portfolio.quotes.first(where: { $0.id == trade.quoteId && $0.symbol == trade.symbol }) else {
                return try problem("INVALID_INPUT", "Operación no válida.")
            }
            if MaestroEnvironment.scenario == "trade-rejected" {
                return try problem("INSUFFICIENT_CASH", "Saldo insuficiente según el servidor.")
            }
            let old = Self.portfolio.positions.first { $0.symbol == trade.symbol }
            let amount = Int64(trade.units) * quote.priceCents
            let buying = trade.side == "buy"
            guard !buying || Self.portfolio.cashCents >= amount + 100 else {
                return try problem("INSUFFICIENT_CASH", "Saldo insuficiente según el servidor.")
            }
            guard buying || (old?.units ?? 0) >= trade.units else {
                return try problem("INSUFFICIENT_UNITS", "No tienes tantas unidades para vender.")
            }
            let units = (old?.units ?? 0) + (buying ? trade.units : -trade.units)
            let cost = buying ? (old?.costCents ?? 0) + amount + 100 :
                Int64((Double(old?.costCents ?? 0) * Double(units) / Double(old!.units)).rounded())
            Self.portfolio.cashCents += buying ? -amount - 100 : amount - 100
            Self.portfolio.positions.removeAll { $0.symbol == trade.symbol }
            if units > 0 { Self.portfolio.positions.append(Position(symbol: trade.symbol, units: units, costCents: cost)) }
            Self.portfolio.orders.insert(Order(id: UUID().uuidString, requestId: trade.requestId,
                symbol: trade.symbol, side: trade.side, units: trade.units, priceCents: quote.priceCents,
                feeCents: 100, createdAt: ISO8601DateFormatter().string(from: Date())), at: 0)
            if MaestroEnvironment.scenario == "trade-response-lost" {
                // The server committed the order, but the client never received its state.
                return try problem("UNAVAILABLE", "No se recibió la confirmación. Comprueba la operación pendiente.", status: 503)
            }
            return try json(Self.portfolio)
        default:
            return try problem("UNMOCKED_REQUEST", "Endpoint sin fixture: \(request.httpMethod ?? "") \(request.url!.path)", status: 500)
        }
    }
}
#endif
