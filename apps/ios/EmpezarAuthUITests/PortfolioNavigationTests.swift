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
        XCTAssertTrue(app.tabBars.buttons["Cartera"].exists)
        XCTAssertTrue(app.tabBars.buttons["Mercados"].exists)
        XCTAssertTrue(app.tabBars.buttons["Movimientos"].exists)
        XCTAssertTrue(app.tabBars.buttons["Aprender"].exists)
        app.buttons["info-portfolioValue"].tap()
        XCTAssertTrue(app.staticTexts["Valor de mi cartera"].waitForExistence(timeout: 3))
        capture("Portfolio value explanation")
        app.buttons["Entendido"].tap()
        app.tabBars.buttons["Movimientos"].tap()
        XCTAssertTrue(app.buttons["info-activity"].firstMatch.waitForExistence(timeout: 3))
        app.tabBars.buttons["Cartera"].tap()
        app.buttons["Comprar activos"].tap()
        let asset = app.descendants(matching: .any)["asset-AAPL"].firstMatch
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
    private func saveLimitOrder(_ app: XCUIApplication) {
        app.buttons["Comprar activos"].tap()
        let asset = app.descendants(matching: .any)["asset-AAPL"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 3)); asset.tap()
        app.buttons["detail-buy"].tap()
        let orderType = app.buttons["purchase-order-type"]
        XCTAssertTrue(orderType.waitForExistence(timeout: 3)); orderType.tap()
        let limitOption = app.buttons["order-option-limit"]
        XCTAssertTrue(limitOption.waitForExistence(timeout: 3))
        limitOption.tap()
        let limit = app.textFields["limit-price"]
        limit.tap(); limit.typeText("100")
        if app.toolbars.buttons["Listo"].exists { app.toolbars.buttons["Listo"].tap() }
        app.buttons["Revisar orden"].tap()
        XCTAssertTrue(app.staticTexts["Revisa tu operación"].waitForExistence(timeout: 3))
        let save = app.buttons["Guardar orden de compra"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.staticTexts["Orden guardada"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Listo"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Cartera"].tap()
        app.tabBars.buttons["Movimientos"].tap()
        XCTAssertTrue(app.buttons["Comprobar y ejecutar"].waitForExistence(timeout: 3))
    }
    func testLimitOrderIsSavedAndCanBeCancelledFromActivity() {
        let app = launch()
        saveLimitOrder(app)
        capture("Pending local limit order")
        app.buttons["Cancelar orden"].tap()
        XCTAssertFalse(app.buttons["Comprobar y ejecutar"].exists)
    }
    func testRefreshingDoesNotExecuteLimitOrderButExplicitActionDoes() {
        let app = launch()
        saveLimitOrder(app)
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(app.buttons["Comprobar y ejecutar"].exists)
        XCTAssertTrue(app.buttons["info-activity"].firstMatch.exists)
        app.buttons["Comprobar y ejecutar"].tap()
        XCTAssertTrue(app.staticTexts["Orden limitada ejecutada. Tu cartera está actualizada."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Comprobar y ejecutar"].exists)
        XCTAssertTrue(app.staticTexts["Compra de AAPL"].exists)
        capture("Executed local limit order")
    }
}
