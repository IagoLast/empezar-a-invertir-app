import XCTest

final class InterfaceReviewTests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testPriceSelectorKeepsCustomPriceEditable() {
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
        let quantity = app.textFields["trade-quantity"]
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Elegir precio"].tap()
        XCTAssertTrue(app.textFields["limit-price"].waitForExistence(timeout: 3))
        capture("Editable simulation price")
    }
}
