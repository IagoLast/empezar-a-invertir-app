import XCTest

final class InterfaceReviewTests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testOrderSheetExplainsChoicesAndReturnsToEditableLimitOrder() {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", "happy", "-has-onboarded-v0", "YES", "-preview-tab", "0", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        XCTAssertTrue(app.buttons["open-profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Movimientos"].exists)
        capture("Polished portfolio and Liquid Glass tabs")
        app.buttons["open-profile"].tap()
        XCTAssertTrue(app.buttons["appearance-picker"].waitForExistence(timeout: 3))
        capture("Polished profile")
        app.buttons["Cerrar"].tap()
        app.buttons["Comprar activos"].tap()
        let asset = app.descendants(matching: .any)["asset-AAPL"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 3)); asset.tap()
        app.buttons["detail-buy"].tap()
        let selector = app.buttons["purchase-order-type"]
        XCTAssertTrue(selector.waitForExistence(timeout: 3))
        capture("Polished market purchase")
        selector.tap()
        XCTAssertTrue(app.buttons["order-option-market"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["order-option-limit"].exists)
        capture("Order type bottom sheet")
        app.buttons["order-learn-limit"].tap()
        XCTAssertTrue(app.staticTexts["Un ejemplo con números"].waitForExistence(timeout: 3))
        capture("Limit order explanation")
        app.buttons["Elegir esta opción"].tap()
        let limit = app.textFields["limit-price"]
        XCTAssertTrue(limit.waitForExistence(timeout: 3))
        limit.tap(); limit.typeText("95")
        app.toolbars.buttons["Listo"].tap()
        XCTAssertTrue(app.buttons["Revisar orden"].isEnabled)
        capture("Polished limit purchase")
        XCTAssertFalse(app.staticTexts["Orden guardada"].exists)
    }
}
