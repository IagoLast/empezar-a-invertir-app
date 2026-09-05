import Foundation

struct Instrument: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol, name, kind, category, monogram, color, summary, question, risk, learn, source: String
}
struct Lesson: Codable, Identifiable, Hashable {
    let id, number, title, subtitle: String
    let minutes: Int
    let icon: String
    let paragraphs: [String]
    let takeaway, exercise: String
}
struct Quote: Codable, Identifiable {
    let id, symbol: String
    let priceCents: Int64
    let currency: String
    let changePercent: Double
    let asOf, fetchedAt, expiresAt: String
    let marketOpen, tradable: Bool
    let mode: String
    let delaySeconds: Int
    let source: String
    var expired: Bool { (ISO.date(expiresAt) ?? .distantPast) <= Date() }
    var canTrade: Bool { marketOpen && tradable && !expired }
    var status: String {
        if !marketOpen { return "Mercado cerrado · último precio" }
        if expired { return "Precio pendiente de actualizar" }
        if mode == "delayed" { return "Diferido \(delaySeconds / 60) min" }
        if mode == "eod" { return "Dato de cierre" }
        return tradable ? "Tiempo real · feed parcial" : "Precio pendiente de actualizar"
    }
}
struct Position: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let units: Int
    let costCents: Int64
}
struct Order: Codable, Identifiable {
    let id, requestId, symbol, side: String
    let units: Int
    let priceCents, feeCents: Int64
    let createdAt: String
}
struct PurchaseReceipt: Codable {
    let transactionId, productId: String
    let credited, refunded: Bool
}
struct Portfolio: Codable {
    let userId: String
    var cashCents, contributedCents: Int64
    let currency: String
    var positions: [Position]
    var quotes: [Quote]
    var orders: [Order]
    var completedLessons: [String]
    var purchases: [PurchaseReceipt]
    static let empty = Portfolio(userId: "", cashCents: 1_000_000, contributedCents: 1_000_000, currency: "USD", positions: [], quotes: [], orders: [], completedLessons: [], purchases: [])
    func quote(_ symbol: String) -> Quote? { quotes.first { $0.symbol == symbol } }
    var equityCents: Int64? {
        var total = cashCents
        for p in positions {
            guard let q = quote(p.symbol) else { return nil }
            total += Int64(p.units) * q.priceCents
        }
        return total
    }
    var profitCents: Int64? { equityCents.map { $0 - contributedCents } }
    var hasStaleValuation: Bool { positions.contains { quote($0.symbol)?.expired ?? true } }
}
struct TradeRequest: Codable {
    let requestId, symbol, side: String
    let units: Int
    let quoteId: String
}
struct Fundamentals: Decodable {
    let available: Bool
    let symbol: String?
    let pe, eps: Double?
    let fetchedAt: String?
    let period: String?
}
enum ISO {
    static func date(_ value: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
enum Money {
    static func text(_ cents: Int64) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD").locale(Locale(identifier: "es_ES")))
    }
    static func signed(_ cents: Int64) -> String { (cents > 0 ? "+" : "") + text(cents) }
}
enum Content {
    static let instruments: [Instrument] = load("catalog")
    static let lessons: [Lesson] = load("lessons")
    static func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(T.self, from: data) else {
            preconditionFailure("Missing bundled content. Run npm run ios:prepare before generating the Xcode project.")
        }
        return value
    }
}
