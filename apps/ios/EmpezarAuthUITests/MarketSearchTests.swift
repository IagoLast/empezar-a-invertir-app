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
    func testInternationalResultsAreGroupedAndKeepTheirExchange() {
        let app = launch()
        app.textFields["asset-search"].tap()
        app.textFields["asset-search"].typeText("world\n")
        let stock = app.buttons["search-result-TSCO.LON"]
        XCTAssertTrue(stock.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["search-category-stocks"].exists)
        XCTAssertTrue(app.staticTexts["TSCO.LON · Londres"].firstMatch.exists)
        let funds = app.staticTexts["search-category-funds"]
        reveal(funds, in: app)
        XCTAssertTrue(app.buttons["search-result-VWRL.L"].exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "International categorized search"; attachment.lifetime = .keepAlways; add(attachment)
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
