import XCTest
@testable import Empezar

final class TradingExperienceTests: XCTestCase {
    func testExistingSessionWithoutMetadataStillDecodes() throws {
        let user = try JSONDecoder().decode(AuthSession.User.self, from: Data(#"{"id":"user"}"#.utf8))
        XCTAssertNil(user.avatarURL)
        XCTAssertEqual(user.displayName, "Mi cuenta")
    }
    func testProviderAvatarAndInitials() throws {
        let user = try JSONDecoder().decode(AuthSession.User.self, from: Data(#"{"id":"user","user_metadata":{"full_name":"Ana López","avatar_url":"https://example.com/photo.jpg"}}"#.utf8))
        XCTAssertEqual(user.initials, "AL")
        XCTAssertEqual(user.avatarURL?.absoluteString, "https://example.com/photo.jpg")
    }
    func testInternationalInstrumentRemainsRepresentableOutsideBundledCatalog() {
        let instrument = Instrument.market(symbol: "ITX.MC", name: "Inditex", exchange: "Madrid")
        XCTAssertEqual(instrument.symbol, "ITX.MC")
        XCTAssertEqual(instrument.name, "Inditex")
        XCTAssertTrue(MarketRegion.spain.includes(instrument.symbol))
        XCTAssertFalse(MarketRegion.unitedStates.includes(instrument.symbol))
        XCTAssertTrue(MarketRegion.europe.includes("ASML.AS"))
    }
    func testHistoryDecodesProviderOHLCWithoutGeneratingSamples() throws {
        let history = try JSONDecoder().decode(PriceHistory.self, from: Data(#"{"currency":"EUR","source":"test","points":[{"date":"2026-09-07T10:00:00Z","open":50,"high":52,"low":49,"close":51}]}"#.utf8))
        XCTAssertEqual(history.points.count, 1)
        XCTAssertEqual(history.points[0].open, 50)
        XCTAssertEqual(history.points[0].close, 51)
        XCTAssertEqual(history.currency, "EUR")
    }
    func testLimitOrderRequiresMatchingTradableQuoteAtOrBelowLimit() {
        let order = LocalLimitOrder(id: "order", symbol: "AAPL", units: 2, limitCents: 10000, createdAt: .now)
        XCTAssertTrue(order.accepts(quote(price: 10000)))
        XCTAssertTrue(order.accepts(quote(price: 9900)))
        XCTAssertFalse(order.accepts(quote(price: 10001)))
        XCTAssertFalse(order.accepts(quote(price: 9900, symbol: "MSFT")))
        XCTAssertFalse(order.accepts(quote(price: 9900, open: false)))
        XCTAssertFalse(order.accepts(quote(price: 9900, expiry: "2000-01-01T00:00:00Z")))
    }
    private func quote(price: Int64, symbol: String = "AAPL", open: Bool = true, expiry: String = "2099-01-01T00:00:00Z") -> Quote {
        Quote(id: "quote", symbol: symbol, priceCents: price, currency: "USD", changePercent: 0,
              asOf: "2026-09-06T10:00:00Z", fetchedAt: "2026-09-06T10:00:00Z", expiresAt: expiry,
              marketOpen: open, tradable: true, mode: "realtime", delaySeconds: 0, source: "test")
    }
}
