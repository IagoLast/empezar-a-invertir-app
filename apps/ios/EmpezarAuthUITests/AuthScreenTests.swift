import XCTest

final class AuthScreenTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openAuth(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", scenario, "-has-seen-introduction", "YES",
                               "-preview-tab", "1", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        return app
    }

    private func refresh(_ app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTimeoutStopsSpinnerAndPullToRefreshRecovers() {
        let app = openAuth("auth-timeout")
        XCTAssertTrue(app.descendants(matching: .any)["auth-loading"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["sign-in-apple"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["auth-load-error"].firstMatch.waitForExistence(timeout: 12))
        XCTAssertFalse(app.descendants(matching: .any)["auth-loading"].firstMatch.exists)
        capture("Auth timeout")
        refresh(app)
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sign-in-apple"].isEnabled)
        XCTAssertFalse(app.buttons["sign-in-google"].exists)
        capture("Auth recovered")
    }

    func testOfflineErrorKeepsAuthenticationRequiredAndRefreshRecovers() {
        let app = openAuth("auth-error")
        XCTAssertTrue(app.descendants(matching: .any)["auth-load-error"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Cerrar"].exists)
        XCTAssertFalse(app.buttons["auth-explore"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        refresh(app)
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
    }

    func testDisabledProvidersCannotBypassAuthentication() {
        let app = openAuth("auth-unavailable")
        XCTAssertTrue(app.descendants(matching: .any)["auth-unavailable"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sign-in-apple"].exists)
        XCTAssertFalse(app.buttons["sign-in-google"].exists)
        XCTAssertFalse(app.buttons["Cerrar"].exists)
        XCTAssertFalse(app.buttons["auth-explore"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testIntroductionShowsThreeStepsThenAppleSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", "guest", "-has-seen-introduction", "NO"]
        app.launch()
        for title in ["Aprende a invertir", "La bolsa no es complicada", "Este es tu primer paso"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["sign-in-apple"].exists)
            app.buttons["introduction-next"].tap()
        }
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.terminate()
        app.launchArguments = ["-maestro-scenario", "guest"]
        app.launch()
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
    }

    func testNewAccountCanEnterHomeWithoutBuyingCash() {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", "first-purchase", "-preview-tab", "0", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home-cash-banner"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Añadir saldo ficticio"].exists)
        app.buttons["Añadir saldo ficticio"].tap()
        XCTAssertTrue(app.navigationBars["Saldo virtual"].waitForExistence(timeout: 5))
        app.buttons["Cerrar"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }
}
