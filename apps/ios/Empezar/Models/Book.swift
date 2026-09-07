import Foundation
import Combine

enum BookSection: String, Codable, CaseIterable, Identifiable {
    case introduction, fundamentals, investments, conclusion
    var id: String { rawValue }
    var title: String {
        switch self {
        case .introduction: return "Antes de empezar"
        case .fundamentals: return "Conceptos financieros básicos"
        case .investments: return "Dónde invertir"
        case .conclusion: return "Para seguir tu camino"
        }
    }
}
struct BookBlock: Codable, Identifiable {
    enum Kind: String, Codable { case heading, paragraph, quote, listItem, table, divider }
    let id: String
    let kind: Kind
    let text: String
    let level: Int?
    let marker: String?
    let rows: [[String]]?
}
struct BookLesson: Codable, Identifiable {
    let id: String
    let section: BookSection
    let number: Int
    let title: String
    let minutes: Int
    let blocks: [BookBlock]
}
enum BookContent {
    static let lessons: [BookLesson] = Content.load("book")
}

@MainActor final class BookReadingStore: ObservableObject {
    struct Progress: Codable {
        var completed: Set<String> = []
        var lastLessonID: String?
        var positions: [String: String] = [:]
    }
    @Published private(set) var progress: Progress
    private let defaults: UserDefaults
    private let key: String
    init(account: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "book-reading-\(account.lowercased())"
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled && defaults.bool(forKey: "reset-book-progress") { defaults.removeObject(forKey: key) }
        #endif
        progress = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Progress.self, from: $0) } ?? Progress()
    }
    var completedCount: Int { BookContent.lessons.filter { progress.completed.contains($0.id) }.count }
    var resumeLesson: BookLesson? { BookContent.lessons.first { $0.id == progress.lastLessonID } }
    func open(_ lesson: BookLesson) { progress.lastLessonID = lesson.id; save() }
    func remember(_ blockID: String, in lesson: BookLesson) {
        guard (blockID == "chapter-start" || blockID == "chapter-end") || lesson.blocks.contains(where: { $0.id == blockID }) else { return }
        progress.positions[lesson.id] = blockID
        save()
    }
    func complete(_ lesson: BookLesson) { progress.completed.insert(lesson.id); save() }
    private func save() {
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: key) }
    }
}
