import XCTest
@testable import Empezar

@MainActor final class BookReadingTests: XCTestCase {
    func testBundledBookContainsCompleteOrderedChapters() {
        XCTAssertEqual(BookContent.lessons.count, 20)
        XCTAssertEqual(BookContent.lessons.map(\.number), Array(1...20))
        XCTAssertEqual(BookContent.lessons.first?.id, "book-purpose")
        XCTAssertEqual(BookContent.lessons.last?.id, "book-conclusion")
        XCTAssertTrue(BookContent.lessons.allSatisfy { !$0.blocks.isEmpty })
        XCTAssertTrue(BookContent.lessons.flatMap(\.blocks).contains { $0.kind == .table })
    }
    func testReadingPositionAndCompletionSurviveRelaunchAndStayAccountScoped() {
        let suite = "book-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let lesson = BookContent.lessons[0]
        let reader = BookReadingStore(account: "first", defaults: defaults)
        reader.open(lesson)
        reader.remember(lesson.blocks[3].id, in: lesson)
        reader.complete(lesson)
        reader.complete(lesson)
        let restored = BookReadingStore(account: "first", defaults: defaults)
        XCTAssertEqual(restored.resumeLesson?.id, lesson.id)
        XCTAssertEqual(restored.progress.positions[lesson.id], lesson.blocks[3].id)
        XCTAssertEqual(restored.completedCount, 1)
        XCTAssertEqual(BookReadingStore(account: "second", defaults: defaults).completedCount, 0)
        XCTAssertNil(BookReadingStore(account: "guest", defaults: defaults).resumeLesson)
    }
    func testUnknownScrollTargetDoesNotReplaceBookmark() {
        let suite = "book-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let reader = BookReadingStore(account: "reader", defaults: defaults)
        let lesson = BookContent.lessons[0]
        reader.remember("chapter-start", in: lesson)
        reader.remember("missing", in: lesson)
        XCTAssertEqual(reader.progress.positions[lesson.id], "chapter-start")
    }
}
