import XCTest
@testable import Empezar

final class PortfolioTests: XCTestCase {
    func testAccessRequiresConfirmedPurchaseAndSurvivesSpendingCash() {
        var portfolio = Portfolio.empty
        XCTAssertFalse(portfolio.hasConfirmedCashPurchase)
        portfolio.cashCents = 1_000_000
        XCTAssertFalse(portfolio.hasConfirmedCashPurchase)
        portfolio.purchases = [PurchaseReceipt(transactionId: "paid", productId: "ei.cash.10000", credited: false, refunded: false)]
        XCTAssertFalse(portfolio.hasConfirmedCashPurchase)
        portfolio.purchases = [PurchaseReceipt(transactionId: "paid", productId: "ei.cash.10000", credited: true, refunded: false)]
        portfolio.cashCents = 0
        XCTAssertTrue(portfolio.hasConfirmedCashPurchase)
        portfolio.purchases = [PurchaseReceipt(transactionId: "paid", productId: "ei.cash.10000", credited: true, refunded: true)]
        XCTAssertFalse(portfolio.hasConfirmedCashPurchase)
    }

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
    func testCashIsPartOfEquity() { XCTAssertEqual(Portfolio.empty.equityCents, 0) }
    func testInvestedValueExcludesCash() {
        var p = Portfolio.empty
        p.positions = [Position(symbol: "AAPL", units: 2, costCents: 40100)]
        p.quotes = [quote(price: 22000)]
        XCTAssertEqual(p.investedCents, 44000)
        XCTAssertEqual(p.equityCents, 44_000)
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
    func testFreshQuotesRequireBothMarketOpenAndTradable() {
        for marketOpen in [false, true] {
            for tradable in [false, true] {
                let q = tradingQuote(marketOpen: marketOpen, tradable: tradable, expiresAt: "2099-01-01T00:00:00Z")
                XCTAssertEqual(q.canTrade, marketOpen && tradable)
            }
        }
    }
    func testExpiredOrMalformedQuoteCannotBeTraded() {
        for expiry in ["2000-01-01T00:00:00Z", "invalid", ""] {
            let q = tradingQuote(marketOpen: true, tradable: true, expiresAt: expiry)
            XCTAssertTrue(q.expired)
            XCTAssertFalse(q.canTrade)
        }
    }
    func testStaleValuationOnlyDependsOnOwnedAssets() {
        var p = Portfolio.empty
        p.quotes = [quote(price: 10000)]
        XCTAssertFalse(p.hasStaleValuation)
        p.positions = [Position(symbol: "AAPL", units: 1, costCents: 10100)]
        XCTAssertTrue(p.hasStaleValuation)
        p.quotes = [tradingQuote(marketOpen: true, tradable: true, expiresAt: "2099-01-01T00:00:00Z")]
        XCTAssertFalse(p.hasStaleValuation)
        p.quotes = []
        XCTAssertTrue(p.hasStaleValuation)
    }
    func testRoundTripAtSamePriceLosesOnlyCommissions() {
        var p = Portfolio.empty
        p.cashCents = 1_000_000
        p.contributedCents = 1_000_000
        p.cashCents -= 10100
        p.positions = [Position(symbol: "AAPL", units: 1, costCents: 10100)]
        p.quotes = [quote(price: 10000)]
        XCTAssertEqual(p.profitCents, -100)
        p.cashCents += 9900
        p.positions = []
        XCTAssertEqual(p.profitCents, -200)
        XCTAssertEqual(p.equityCents, 999800)
    }
    func testOneMissingQuoteMakesEntireValuationUnknown() {
        var p = Portfolio.empty
        p.positions = [
            Position(symbol: "AAPL", units: 1, costCents: 10100),
            Position(symbol: "MSFT", units: 1, costCents: 10100)
        ]
        p.quotes = [quote(price: 10000)]
        XCTAssertNil(p.equityCents)
        XCTAssertNil(p.investedCents)
        XCTAssertNil(p.profitCents)
    }
    func testZeroUnitPositionHasNoAverageCost() {
        XCTAssertEqual(Position(symbol: "AAPL", units: 0, costCents: 0).averageCostCents, 0)
    }
    private func tradingQuote(marketOpen: Bool, tradable: Bool, expiresAt: String) -> Quote {
        Quote(id: "quote", symbol: "AAPL", priceCents: 10000, currency: "USD", changePercent: 0,
              asOf: "2026-09-05T10:00:00Z", fetchedAt: "2026-09-05T10:00:00Z", expiresAt: expiresAt,
              marketOpen: marketOpen, tradable: tradable, mode: "realtime", delaySeconds: 0, source: "test")
    }

    func testAuthProviderAvailabilityRequiresExplicitEnablement() throws {
        let disabled = try JSONDecoder().decode(AuthProviders.self, from: Data(#"{"external":{"google":false,"apple":false,"email":true}}"#.utf8))
        XCTAssertFalse(disabled.googleEnabled)
        XCTAssertFalse(disabled.appleEnabled)
        let googleOnly = try JSONDecoder().decode(AuthProviders.self, from: Data(#"{"external":{"google":true}}"#.utf8))
        XCTAssertTrue(googleOnly.googleEnabled)
        XCTAssertFalse(googleOnly.appleEnabled)
    }

}
