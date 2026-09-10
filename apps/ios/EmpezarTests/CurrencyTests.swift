import XCTest
@testable import Empezar

final class CurrencyTests: XCTestCase {
    private var rates: ExchangeRates {
        ExchangeRates(base: "EUR", date: String(ISO8601DateFormatter().string(from: .now).prefix(10)), source: "Test", rates: ["EUR": 1, "USD": Decimal(string: "1.2")!, "JPY": 180])
    }
    func testReportingConversionPreservesSettlementValue() {
        let money = CurrencyMoney(currency: "EUR", exchangeRates: rates)
        XCTAssertEqual(money.value(12000), 100)
        XCTAssertEqual(money.settlementCents("100,00", buying: true), 12000)
        XCTAssertEqual(CurrencyMoney(currency: "JPY", exchangeRates: rates).value(12000), 18000)
    }
    func testLimitsRoundConservatively() {
        let money = CurrencyMoney(currency: "EUR", exchangeRates: rates)
        XCTAssertEqual(money.settlementCents("0.01", buying: true), 1)
        XCTAssertEqual(money.settlementCents("0.01", buying: false), 2)
        XCTAssertNil(money.settlementCents("-1", buying: true))
        XCTAssertNil(money.settlementCents("nan", buying: true))
    }
    func testMissingAndExpiredRatesDoNotRelabelDollars() {
        XCTAssertNil(CurrencyMoney(currency: "EUR", exchangeRates: nil).value(100))
        XCTAssertEqual(CurrencyMoney(currency: "USD", exchangeRates: nil).value(100), 1)
        let old = ExchangeRates(base: "EUR", date: "2020-01-01", source: "Test", rates: ["EUR": 1, "USD": 1])
        XCTAssertNil(CurrencyMoney(currency: "EUR", exchangeRates: old).settlementCents("100", buying: true))
    }
}
