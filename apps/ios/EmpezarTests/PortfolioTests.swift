import XCTest
@testable import Empezar

final class PortfolioTests: XCTestCase {
    func testTopUpsAreNotProfit() {
        var p = Portfolio.empty
        p.cashCents += 1_000_000
        p.contributedCents += 1_000_000
        XCTAssertEqual(p.profitCents, 0)
    }
    func testMissingQuoteDoesNotInventValuation() {
        var p = Portfolio.empty
        p.positions = [Position(symbol: "AAPL", units: 2, costCents: 40000)]
        XCTAssertNil(p.equityCents)
        XCTAssertNil(p.profitCents)
    }
    func testCashIsPartOfEquity() { XCTAssertEqual(Portfolio.empty.equityCents, 1_000_000) }
    func testInvestedValueExcludesCash() {
        var p = Portfolio.empty
        p.positions = [Position(symbol: "AAPL", units: 2, costCents: 40100)]
        p.quotes = [quote(price: 22000)]
        XCTAssertEqual(p.investedCents, 44000)
        XCTAssertEqual(p.equityCents, 1_044_000)
        p.quotes = []
        XCTAssertNil(p.investedCents)
    }
    func testPositionResultIncludesAcquisitionFees() {
        let position = Position(symbol: "AAPL", units: 2, costCents: 40100)
        XCTAssertEqual(position.averageCostCents, 20050)
        XCTAssertEqual(position.marketValueCents(at: quote(price: 22000)), 44000)
        XCTAssertEqual(position.profitCents(at: quote(price: 22000)), 3900)
        XCTAssertEqual(position.profitCents(at: quote(price: 19000)), -2100)
    }
    private func quote(price: Int64) -> Quote {
        Quote(id: "test", symbol: "AAPL", priceCents: price, currency: "USD", changePercent: 0,
              asOf: "2026-09-05T10:00:00Z", fetchedAt: "2026-09-05T10:00:00Z", expiresAt: "2026-09-05T10:01:00Z",
              marketOpen: false, tradable: false, mode: "eod", delaySeconds: 0, source: "test")
    }
    func testFractionalAndPlainISO() {
        XCTAssertNotNil(ISO.date("2026-09-05T10:00:00.123Z"))
        XCTAssertNotNil(ISO.date("2026-09-05T10:00:00Z"))
    }
}
