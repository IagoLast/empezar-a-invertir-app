import XCTest

final class MarketSearchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", "happy", "-has-onboarded-v0", "YES", "-preview-tab", "1", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        XCTAssertTrue(app.textFields["asset-search"].waitForExistence(timeout: 10))
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    func testEmptySearchAndUnknownQueryDoNotShowBundledAssets() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Busca tu próxima inversión"].exists)
        XCTAssertFalse(app.buttons["search-result-AAPL"].exists)
        XCTAssertFalse(app.buttons["search-result-ITX.MC"].exists)
        app.textFields["asset-search"].tap()
        app.textFields["asset-search"].typeText("nomatch123\n")
        XCTAssertTrue(app.staticTexts["Sin resultados"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search-result-AAPL"].exists)
        app.buttons["Borrar búsqueda"].tap()
        XCTAssertTrue(app.staticTexts["Busca tu próxima inversión"].exists)
    }
    func testSearchFieldKeepsItsFrameWhileTypingAndShowingResults() {
        let app = launch()
        let search = app.textFields["asset-search"]
        let initial = search.frame
        search.tap(); search.typeText("world\n")
        XCTAssertTrue(app.buttons["search-result-TSCO.L"].waitForExistence(timeout: 10))
        XCTAssertEqual(search.frame.minX, initial.minX, accuracy: 1)
        XCTAssertEqual(search.frame.minY, initial.minY, accuracy: 1)
        XCTAssertEqual(search.frame.width, initial.width, accuracy: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Stable search header"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDetailReservesQuoteAndHistorySpaceWhileLoading() {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", "slow-market", "-has-onboarded-v0", "YES", "-preview-tab", "1", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        let search = app.textFields["asset-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("AAPL\n")
        let asset = app.buttons["search-result-AAPL"]
        XCTAssertTrue(asset.waitForExistence(timeout: 10)); asset.tap()
        let quote = app.descendants(matching: .any)["detail-quote-card"].firstMatch
        let history = app.descendants(matching: .any)["detail-history-card"].firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: 2))
        let initialQuote = quote.frame
        let initialHistory = history.frame
        let loading = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        loading.name = "Detail placeholders"; loading.lifetime = .keepAlways; add(loading)
        XCTAssertTrue(app.staticTexts["Último precio disponible"].waitForExistence(timeout: 20))
        XCTAssertEqual(quote.frame.height, initialQuote.height, accuracy: 1)
        XCTAssertEqual(history.frame.minY, initialHistory.minY, accuracy: 1)
        XCTAssertEqual(history.frame.height, initialHistory.height, accuracy: 1)
        let chart = app.descendants(matching: .any)["asset-chart"].firstMatch
        for _ in 0..<3 where !chart.isHittable { app.swipeUp() }
        XCTAssertTrue(chart.waitForExistence(timeout: 30))
        let loaded = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        loaded.name = "Detail after loading"; loaded.lifetime = .keepAlways; add(loaded)
    }
    func testInternationalResultsKeepTheirExchange() {
        let app = launch()
        app.textFields["asset-search"].tap()
        app.textFields["asset-search"].typeText("world\n")
        let stock = app.buttons["search-result-TSCO.L"]
        XCTAssertTrue(stock.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TSCO.L · Londres"].firstMatch.exists)
        let funds = app.buttons["search-result-VWRL.L"]
        reveal(funds, in: app)
        XCTAssertTrue(app.buttons["search-result-VWRL.L"].exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "International search"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testBrandSearchFindsInditexWithCoverageNoticeAndOpensItsIdentity() {
        let app = launch()
        app.textFields["asset-search"].tap()
        app.textFields["asset-search"].typeText("inditex\n")
        let result = app.buttons["search-result-ITX.MC"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cotización según cobertura"].firstMatch.exists)
        reveal(result, in: app); result.tap()
        XCTAssertTrue(app.navigationBars["ITX.MC"].waitForExistence(timeout: 5))
    }
}
