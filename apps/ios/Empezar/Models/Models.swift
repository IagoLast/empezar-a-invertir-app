import Foundation

struct Instrument: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol, name, kind, category, monogram, color, summary, question, risk, learn, source: String
    static func market(symbol: String, name: String? = nil, kind: String = "stock", exchange: String = "") -> Instrument {
        if let existing = Content.instruments.first(where: { $0.symbol == symbol }) { return existing }
        return Instrument(symbol: symbol, name: name ?? symbol, kind: kind, category: exchange.isEmpty ? (kind == "stock" ? "Acción" : "ETF") : exchange,
                          monogram: String(symbol.prefix(2)), color: "#245B48",
                          summary: kind == "stock" ? "Una acción representa una parte de una empresa. Conoce su negocio y sus riesgos antes de invertir." : "Un ETF reúne una cesta de activos. Consulta su composición, costes y riesgos antes de invertir.",
                          question: "¿Por qué invertirías en este activo?", risk: "El precio puede bajar y puedes perder parte o todo lo invertido. Las divisas también afectan al resultado.",
                          learn: "Practica con una cantidad pequeña y revisa cómo cambia el valor de tu inversión.",
                          source: "https://finnhub.io")
    }
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
    var averageDailyVolume: Int64? = nil
    var logoURL: String? = nil
    var nativePrice: Double? = nil
    var nativeCurrency: String? = nil
    var exchangeRate: Double? = nil
    var fxAsOf: String? = nil
    var name: String? = nil
    var kind: String? = nil
    var nativePriceText: String { nativePrice.flatMap { price in nativeCurrency.map { price.formatted(.currency(code: $0)) } } ?? Money.text(priceCents) }
    var usesConversion: Bool { nativeCurrency != nil && nativeCurrency != "USD" }
    var expired: Bool { (ISO.date(expiresAt) ?? .distantPast) <= Date() }
    var canTrade: Bool { marketOpen && tradable && !expired }
    var status: String {
        if !marketOpen { return "Mercado cerrado · último precio" }
        if expired { return "Precio pendiente de actualizar" }
        if mode == "cached" { return tradable ? "Último precio disponible" : "Precio pendiente de actualizar" }
        if mode == "delayed" { return "Diferido \(delaySeconds / 60) min" }
        if mode == "eod" { return "Precio de cierre" }
        return tradable ? "Último precio disponible" : "Precio pendiente de actualizar"
    }
}
struct Position: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let units: Int
    let costCents: Int64
    var averageCostCents: Int64 { units > 0 ? Int64((Double(costCents) / Double(units)).rounded()) : 0 }
    func marketValueCents(at quote: Quote) -> Int64 { Int64(units) * quote.priceCents }
    func profitCents(at quote: Quote) -> Int64 { marketValueCents(at: quote) - costCents }
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
    var simulatedOrders: [SimulatedOrder]? = nil
    var reservedCashCents: Int64? = nil
    var availableCashCents: Int64 { max(0, cashCents - (reservedCashCents ?? 0)) }
    var queuedOrders: [SimulatedOrder] { (simulatedOrders ?? []).filter { $0.status == "pending" } }
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
    var investedCents: Int64? { equityCents.map { $0 - cashCents } }
    var profitCents: Int64? { equityCents.map { $0 - contributedCents } }
    var hasStaleValuation: Bool { positions.contains { quote($0.symbol)?.expired ?? true } }
}
struct TradeRequest: Codable {
    let requestId, symbol, side: String
    let units: Int
    let quoteId: String
    var limitCents: Int64? = nil
    var revision: Int? = nil
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

struct LocalLimitOrder: Codable, Identifiable {
    let id: String
    let symbol: String
    let units: Int
    let limitCents: Int64
    let createdAt: Date
    func accepts(_ quote: Quote) -> Bool {
        quote.symbol == symbol && quote.canTrade && quote.priceCents <= limitCents
    }
}

struct SimulatedOrder: Codable, Identifiable {
    let id, symbol, side: String
    let units: Int
    let priceCents: Int64
    let limitCents: Int64?
    let status: String
    let revision: Int
    let createdAt, executeAt: String
    let averageDailyVolume: Int64?
    var editable: Bool { status == "pending" && (ISO.date(executeAt) ?? .distantPast) > Date() }
    var totalCents: Int64 { priceCents * Int64(units) + (side == "buy" ? 100 : -100) }
}
