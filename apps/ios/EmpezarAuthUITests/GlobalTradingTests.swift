import XCTest

final class GlobalTradingTests: XCTestCase {
    private func launch(_ scenario: String = "happy") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", scenario, "-has-onboarded-v0", "YES", "-preview-tab", "0", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        XCTAssertTrue(app.buttons["Comprar activos"].waitForExistence(timeout: 10))
        app.buttons["Comprar activos"].tap()
        let search = app.textFields["asset-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Inditex\n")
        let asset = app.descendants(matching: .any)["search-result-ITX.MC"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 5)); asset.tap()
        XCTAssertTrue(app.buttons["detail-buy"].waitForExistence(timeout: 5))
        return app
    }

    func testBuyInternationalAssetAndSellFromPortfolio() {
        let app = launch()
        XCTAssertFalse(app.buttons["detail-sell"].isEnabled)
        app.buttons["detail-buy"].tap()
        XCTAssertTrue(app.buttons["Revisar compra"].waitForExistence(timeout: 5))
        app.buttons["Revisar compra"].tap()
        app.buttons["Confirmar compra virtual"].tap()
        XCTAssertTrue(app.staticTexts["Compra completada"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Listo"].tap()
        XCTAssertTrue(app.buttons["detail-sell"].isEnabled)
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Cartera"].tap()
        let sell = app.buttons["sell-position-ITX.MC"]
        for _ in 0..<4 where !sell.isHittable { app.swipeUp() }
        XCTAssertTrue(sell.waitForExistence(timeout: 5)); sell.tap()
        XCTAssertTrue(app.buttons["Revisar venta"].waitForExistence(timeout: 5))
        app.buttons["Revisar venta"].tap()
        app.buttons["Confirmar venta virtual"].tap()
        XCTAssertTrue(app.staticTexts["Venta completada"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Listo"].tap()
        XCTAssertFalse(sell.exists)
    }

    func testClosedMarketOffersExplicitLimitOrderInsteadOfDeadEnd() {
        let app = launch("market-closed")
        app.buttons["detail-buy"].tap()
        let create = app.buttons["Crear orden limitada"]
        XCTAssertTrue(create.waitForExistence(timeout: 5)); create.tap()
        XCTAssertTrue(app.textFields["limit-price"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Revisar orden"].isEnabled)
        XCTAssertFalse(app.staticTexts["Orden guardada"].exists)
    }
}
