import XCTest

final class PortfolioNavigationTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", "happy", "-has-onboarded-v0", "YES", "-preview-tab", "0", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        XCTAssertTrue(app.buttons["open-profile"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testHomeHelpActivityAndChartNavigationWithTabs() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Inicio"].exists)
        XCTAssertTrue(app.tabBars.buttons["Invertir"].exists)
        XCTAssertTrue(app.tabBars.buttons["Operaciones"].exists)
        XCTAssertTrue(app.tabBars.buttons["Aprender"].exists)
        app.buttons["info-portfolioValue"].tap()
        XCTAssertTrue(app.staticTexts["Valor de mi cartera"].waitForExistence(timeout: 3))
        capture("Portfolio value explanation")
        app.buttons["Entendido"].tap()
        app.tabBars.buttons["Operaciones"].tap()
        XCTAssertTrue(app.buttons["info-activity"].firstMatch.waitForExistence(timeout: 3))
        app.tabBars.buttons["Inicio"].tap()
        app.buttons["home-invest"].tap()
        let search = app.textFields["asset-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("AAPL\n")
        let asset = app.descendants(matching: .any)["search-result-AAPL"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 3))
        asset.tap()
        app.swipeUp()
        let chartStyle = app.buttons["Velas"]
        XCTAssertTrue(chartStyle.waitForExistence(timeout: 3))
        chartStyle.tap()
        XCTAssertTrue(app.staticTexts["Histórico de precios"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["asset-chart"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Sin precio de referencia"].exists)
        capture("Historical candlestick chart")
    }
}
