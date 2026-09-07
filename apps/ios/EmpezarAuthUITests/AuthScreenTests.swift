import XCTest

final class AuthScreenTests: XCTestCase {
    private func openAuth(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-maestro-scenario", scenario, "-has-onboarded-v0", "YES",
                               "-preview-tab", "1", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launch()
        let asset = app.descendants(matching: .any)["asset-AAPL"].firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 10)); asset.tap()
        let login = app.buttons["Iniciar sesión"]
        XCTAssertTrue(login.waitForExistence(timeout: 5)); login.tap()
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

    func testOfflineErrorCanBeDismissedAndReopened() {
        let app = openAuth("auth-error")
        XCTAssertTrue(app.descendants(matching: .any)["auth-load-error"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["auth-explore"].tap()
        XCTAssertTrue(app.buttons["Iniciar sesión"].waitForExistence(timeout: 5))
        app.buttons["Iniciar sesión"].tap()
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
    }

    func testDisabledProvidersOfferAnExitWithoutBrokenButtons() {
        let app = openAuth("auth-unavailable")
        XCTAssertTrue(app.descendants(matching: .any)["auth-unavailable"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sign-in-apple"].exists)
        XCTAssertFalse(app.buttons["sign-in-google"].exists)
        capture("Auth unavailable")
        app.buttons["auth-explore"].tap()
        XCTAssertTrue(app.buttons["Iniciar sesión"].waitForExistence(timeout: 5))
    }

    func testClosingWhileLoadingDoesNotBlockNextPresentation() {
        let app = openAuth("auth-timeout")
        XCTAssertTrue(app.descendants(matching: .any)["auth-loading"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Cerrar"].tap()
        app.buttons["Iniciar sesión"].tap()
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
    }
}
