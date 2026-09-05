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
    func testFractionalAndPlainISO() {
        XCTAssertNotNil(ISO.date("2026-09-05T10:00:00.123Z"))
        XCTAssertNotNil(ISO.date("2026-09-05T10:00:00Z"))
    }
}
