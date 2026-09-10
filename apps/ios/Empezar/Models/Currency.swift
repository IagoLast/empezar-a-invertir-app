import Foundation

struct DisplayCurrency: Identifiable, Hashable {
    let id: String
    var title: String { Locale(identifier: "es_ES").localizedString(forCurrencyCode: id)?.capitalized ?? id }
    static let supported = ["EUR", "USD", "GBP", "CHF", "JPY", "CAD", "AUD", "MXN", "BRL", "CNY", "INR", "SEK", "NOK", "DKK", "PLN"].map { DisplayCurrency(id: $0) }
}

struct ExchangeRates: Codable {
    let base, date, source: String
    let rates: [String: Decimal]
    func isCurrent(at now: Date = .now) -> Bool {
        guard base == "EUR", let stamp = ISO.date(date + "T00:00:00Z") else { return false }
        return stamp <= now.addingTimeInterval(86400) && now.timeIntervalSince(stamp) <= 7 * 86400
    }
    func rate(from: String, to: String, now: Date = .now) -> Decimal? {
        if from == to { return 1 }
        guard isCurrent(at: now), let source = rates[from], source > 0, let destination = rates[to], destination > 0 else { return nil }
        return destination / source
    }
}

struct CurrencyMoney {
    let currency: String
    let exchangeRates: ExchangeRates?
    var usdRate: Decimal? { exchangeRates?.rate(from: "USD", to: currency) ?? (currency == "USD" ? 1 : nil) }
    var available: Bool { usdRate != nil }
    func value(_ cents: Int64) -> Decimal? {
        if cents == 0 { return 0 }
        guard available else { return nil }
        if currency == "USD" { return Decimal(cents) / 100 }
        guard let rates = exchangeRates?.rates, let usd = rates["USD"], let target = rates[currency] else { return nil }
        return Decimal(cents) * target / usd / 100
    }
    func text(_ cents: Int64) -> String {
        guard let amount = value(cents) else { return "— \(currency)" }
        return amount.formatted(.currency(code: currency).locale(Locale(identifier: "es_ES")))
    }
    func signed(_ cents: Int64) -> String { (cents > 0 && available ? "+" : "") + text(cents) }
    func inputText(_ cents: Int64) -> String {
        guard let value = value(cents) else { return "" }
        return value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(2)))
    }
    // A buy limit rounds down in settlement cents; a sell limit rounds up.
    func settlementCents(_ input: String, buying: Bool) -> Int64? {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: #"^[0-9]{1,10}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), amount > 0,
              available else { return nil }
        let usd = currency == "USD" ? Decimal(1) : exchangeRates!.rates["USD"]!
        let target = currency == "USD" ? Decimal(1) : exchangeRates!.rates[currency]!
        var raw = amount * usd * 100 / target
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 0, buying ? .down : .up)
        guard rounded > 0, rounded <= 1_000_000_000 else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
