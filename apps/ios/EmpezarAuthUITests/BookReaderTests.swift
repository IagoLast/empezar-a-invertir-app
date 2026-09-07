import XCTest

final class BookReaderTests: XCTestCase {
    func testBookReadingCompletionAndResumeWithNativeTabs() {
        let app = XCUIApplication()
        let arguments = ["-maestro-scenario", "happy", "-has-onboarded-v0", "YES", "-preview-tab", "2", "-preview-profile", "NO", "-preview-screen", "main"]
        app.launchArguments = arguments + ["-reset-book-progress", "YES"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Aprender"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Movimientos"].exists)
        XCTAssertTrue(app.staticTexts["0 de 20"].exists)
        let library = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        library.name = "Book library and native tabs"; library.lifetime = .keepAlways; add(library)
        app.buttons["book-resume"].tap()
        XCTAssertTrue(app.staticTexts["book-chapter-title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Introducción"].exists)
        app.buttons["book-reading-options"].tap()
        app.buttons["Ir al final de la lección"].tap()
        let complete = app.buttons["book-complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.buttons["Lección completada"].waitForExistence(timeout: 3))
        app.buttons["book-next"].tap()
        XCTAssertTrue(app.staticTexts["Dinero"].waitForExistence(timeout: 3))
        app.buttons["book-reading-options"].tap()
        app.buttons["El oro"].tap()
        XCTAssertTrue(app.staticTexts["El oro"].waitForExistence(timeout: 3))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Book chapter reader"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate()
        app.launchArguments = arguments + ["-reset-book-progress", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["1 de 20"].waitForExistence(timeout: 10))
        app.buttons["book-resume"].tap()
        XCTAssertTrue(app.staticTexts["El oro"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["El oro"].isHittable)
        app.tabBars.buttons["Cartera"].tap()
        XCTAssertTrue(app.buttons["open-profile"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Aprender"].tap()
        XCTAssertTrue(app.staticTexts["El oro"].isHittable)
    }
}
