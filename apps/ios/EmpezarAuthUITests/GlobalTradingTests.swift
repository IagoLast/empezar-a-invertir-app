import XCTest

final class GlobalTradingTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ scenario: String = "happy") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", scenario, "-has-onboarded-v0", "YES", "-preview-tab", "1", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        let search = app.textFields["asset-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("AAPL\n")
        let asset = app.descendants(matching: .any)["search-result-AAPL"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 10)); asset.tap()
        app.buttons["detail-buy"].tap()
        XCTAssertTrue(app.buttons["Revisar orden"].waitForExistence(timeout: 5))
        return app
    }
    private func confirm(_ app: XCUIApplication) {
        app.buttons["Revisar orden"].tap()
        app.buttons["Confirmar operación"].tap()
        XCTAssertTrue(app.staticTexts["Operación completada"].waitForExistence(timeout: 5))
    }
    func testReviewCanBeEditedAndPurchaseImmediatelyAppearsInHistory() {
        let app = launch()
        XCTAssertTrue(app.segmentedControls["purchase-order-type"].exists)
        app.buttons["Revisar orden"].tap()
        app.buttons["edit-order"].tap()
        let quantity = app.textFields["trade-quantity"]
        XCTAssertTrue(quantity.waitForExistence(timeout: 3))
        app.buttons["Añadir una unidad"].tap()
        confirm(app)
        app.buttons["Ver operaciones"].tap()
        XCTAssertTrue(app.staticTexts["Compra de AAPL"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "2 unidades", "1,00")).firstMatch.exists)
        XCTAssertFalse(app.buttons["edit-pending-order"].exists)
        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(app.staticTexts["AAPL · 2 unidades"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Portfolio after immediate purchase"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLimitOrderExplainsSimulationAndUsesChosenPrice() {
        let app = launch()
        let picker = app.segmentedControls["purchase-order-type"]
        for _ in 0..<3 where !picker.isHittable { app.swipeUp() }
        picker.buttons["Limitada"].tap()
        app.buttons["explain-order-type"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "sin esperar a que cambie la cotización real")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Entendido"].tap()
        let limit = app.textFields["limit-price"]
        for _ in 0..<3 where !limit.isHittable { app.swipeUp() }
        limit.tap(); limit.typeText("95")
        app.toolbars.buttons["Listo"].tap()
        confirm(app)
        app.buttons["Ver operaciones"].tap()
        XCTAssertTrue(app.staticTexts["Compra de AAPL"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "95,00")).firstMatch.exists)
    }
    func testClosedMarketAllowsClearlyLabelledSimulation() {
        let app = launch("market-closed")
        XCTAssertTrue(app.buttons["Revisar orden"].isEnabled)
        confirm(app)
        XCTAssertTrue(app.staticTexts["Tu saldo y tus inversiones ya están actualizados."].exists)
    }
    func testLostResponseIsResolvedWithoutADuplicatePurchase() {
        let app = launch("trade-response-lost")
        app.buttons["Revisar orden"].tap()
        app.buttons["Confirmar operación"].tap()
        XCTAssertTrue(app.staticTexts["No se recibió la confirmación."].waitForExistence(timeout: 5))
        app.buttons["Confirmar operación"].tap()
        XCTAssertTrue(app.staticTexts["Operación completada"].waitForExistence(timeout: 5))
        app.buttons["Ver operaciones"].tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "Compra de AAPL").count, 1)
    }
}
