import XCTest

final class GlobalTradingTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ scenario: String = "happy") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", scenario, "-has-onboarded-v0", "YES", "-preview-tab", "1", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        let asset = app.descendants(matching: .any)["asset-AAPL"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 10)); asset.tap()
        app.buttons["detail-buy"].tap()
        XCTAssertTrue(app.buttons["Revisar orden"].waitForExistence(timeout: 5))
        return app
    }
    private func confirm(_ app: XCUIApplication) {
        app.buttons["Revisar orden"].tap()
        app.buttons["Confirmar orden virtual"].tap()
        XCTAssertTrue(app.staticTexts["Orden en marcha"].waitForExistence(timeout: 5))
    }
    func testReviewAllowsEditingBeforeSubmissionAndPendingOrderCanBeCancelled() {
        let app = launch()
        app.buttons["Revisar orden"].tap()
        let edit = app.buttons["edit-order"]
        for _ in 0..<3 where !edit.isHittable { app.swipeUp() }
        edit.tap()
        let quantity = app.textFields["trade-quantity"]
        for _ in 0..<3 where !quantity.isHittable { app.swipeDown() }
        XCTAssertTrue(quantity.waitForExistence(timeout: 3))
        app.buttons["Añadir una unidad"].tap()
        confirm(app)
        app.buttons["Ver mi orden"].tap()
        XCTAssertTrue(app.buttons["edit-pending-order"].waitForExistence(timeout: 5))
        app.buttons["Cancelar orden"].tap()
        XCTAssertTrue(app.staticTexts["Orden cancelada. La reserva se ha liberado."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["edit-pending-order"].exists)
    }
    func testPendingOrderCanBeEditedAndExecutesWithoutManualAction() {
        let app = launch()
        confirm(app)
        app.buttons["Ver mi orden"].tap()
        XCTAssertTrue(app.buttons["edit-pending-order"].waitForExistence(timeout: 5))
        app.buttons["edit-pending-order"].tap()
        XCTAssertTrue(app.textFields["trade-quantity"].waitForExistence(timeout: 5))
        app.buttons["Añadir una unidad"].tap()
        app.buttons["Revisar orden"].tap()
        app.buttons["Guardar cambios"].tap()
        XCTAssertTrue(app.staticTexts["Orden en marcha"].waitForExistence(timeout: 5))
        app.buttons["Listo"].tap()
        XCTAssertTrue(app.staticTexts["Compra de AAPL"].firstMatch.waitForExistence(timeout: 40))
        let pending = app.buttons["edit-pending-order"]
        XCTAssertTrue(NSPredicate(format: "exists == false").evaluate(with: pending) || XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: pending)], timeout: 40) == .completed)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Executed simulation order"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testClosedMarketAllowsClearlyLabelledSimulation() {
        let app = launch("market-closed")
        XCTAssertTrue(app.buttons["Revisar orden"].isEnabled)
        confirm(app)
        XCTAssertTrue(app.staticTexts["La ejecución continúa aunque cierres la app."].exists)
    }
}
