import SwiftUI

struct LearnView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let account = store.auth.session?.user.id ?? "guest"
        BookLibraryView(account: account).id(account)
    }
}

private struct BookLibraryView: View {
    @StateObject private var reading: BookReadingStore
    init(account: String) { _reading = StateObject(wrappedValue: BookReadingStore(account: account)) }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tu libro para\naprender a invertir").font(.largeTitle.weight(.bold))
                    Text("Iago Lastra · \(BookContent.lessons.count) lecciones").font(.subheadline).foregroundStyle(Theme.muted)
                    Text("Lee a tu ritmo, desde tu relación con el dinero hasta las acciones, los bonos y los fondos.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tu lectura").font(.headline)
                        Spacer()
                        Text("\(reading.completedCount) de \(BookContent.lessons.count)").font(.subheadline).monospacedDigit().accessibilityIdentifier("book-progress")
                    }
                    ProgressView(value: Double(reading.completedCount), total: Double(BookContent.lessons.count)).tint(Theme.accent)
                    NavigationLink {
                        BookReaderView(lesson: reading.resumeLesson ?? BookContent.lessons[0], reading: reading)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bookmark.fill")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reading.resumeLesson == nil ? "Empezar a leer" : "Continuar leyendo").font(.headline)
                                Text((reading.resumeLesson ?? BookContent.lessons[0]).title).font(.subheadline)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }.frame(minHeight: 52)
                    }.accessibilityIdentifier("book-resume")
                }.padding(22).dataCard()
                ForEach(BookSection.allCases) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            let lessons = BookContent.lessons.filter { $0.section == section }
                            ForEach(lessons) { lesson in
                                NavigationLink { BookReaderView(lesson: lesson, reading: reading) } label: {
                                    HStack(alignment: .center, spacing: 14) {
                                        Text(lesson.number.formatted(.number.precision(.integerLength(2)))).font(.headline.monospacedDigit())
                                            .foregroundStyle(Theme.accent).frame(width: 34)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(lesson.title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                            Text("\(lesson.minutes) min de lectura").font(.caption).foregroundStyle(Theme.muted)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: reading.progress.completed.contains(lesson.id) ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundStyle(Theme.accent)
                                    }.padding(.vertical, 18).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("lesson-\(lesson.id)")
                                if lesson.id != lessons.last?.id { Divider().overlay(Theme.line) }
                            }
                        }.padding(.horizontal, 18).dataCard()
                    }
                }
                NavigationLink { ValuationView() } label: {
                    Label("Probar el laboratorio de valoración", systemImage: "slider.horizontal.3").font(.subheadline.weight(.semibold)).frame(minHeight: 48)
                }
                Text("Disponible sin conexión. Tu punto de lectura y las lecciones completadas se guardan en este dispositivo.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }.padding(20).padding(.top, 12)
        }.appCanvas().navigationTitle("Aprender").navigationBarTitleDisplayMode(.inline)
    }
}

struct BookReaderView: View {
    @ObservedObject var reading: BookReadingStore
    @State private var currentID: String
    init(lesson: BookLesson, reading: BookReadingStore) {
        self.reading = reading
        _currentID = State(initialValue: lesson.id)
    }
    private var lesson: BookLesson { BookContent.lessons.first { $0.id == currentID } ?? BookContent.lessons[0] }
    var body: some View {
        BookChapterView(lesson: lesson, reading: reading) { next in currentID = next.id }
            .id(currentID)
    }
}

private struct BookChapterView: View {
    let lesson: BookLesson
    @ObservedObject var reading: BookReadingStore
    var selectLesson: (BookLesson) -> Void
    @State private var visibleBlock: String?
    @State private var restored = false
    @State private var showReadingOptions = false
    @AppStorage("book-large-text") private var largeText = false
    private var next: BookLesson? { BookContent.lessons.first { $0.number == lesson.number + 1 } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("LECCIÓN \(lesson.number) DE \(BookContent.lessons.count)").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(Theme.accent)
                    Text(lesson.title).font(.largeTitle.weight(.bold)).accessibilityIdentifier("book-chapter-title")
                    Text("\(lesson.section.title) · \(lesson.minutes) min").font(.subheadline).foregroundStyle(Theme.muted)
                    Divider()
                }.id("chapter-start")
                ForEach(lesson.blocks) { block in
                    BookBlockView(block: block, largeText: largeText).id(block.id)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Divider()
                    PrimaryButton(title: reading.progress.completed.contains(lesson.id) ? "Lección completada" : "Marcar como completada", icon: "checkmark", disabled: reading.progress.completed.contains(lesson.id)) {
                        reading.complete(lesson)
                    }.accessibilityIdentifier("book-complete")
                    if let next {
                        Button { selectLesson(next) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Siguiente lección").font(.caption).foregroundStyle(Theme.muted)
                                    Text(next.title).font(.headline)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }.frame(minHeight: 60)
                        }.accessibilityIdentifier("book-next")
                    } else {
                        Text("Has llegado al final del libro. Puedes volver al índice y releer cualquier lección.").foregroundStyle(Theme.muted)
                    }
                }.padding(.top, 12).id("chapter-end")
            }.scrollTargetLayout().padding(.horizontal, 24).padding(.vertical, 20)
        }.scrollPosition(id: $visibleBlock, anchor: .top)
            .appCanvas().navigationTitle("Lección \(lesson.number)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showReadingOptions = true } label: {
                        Image(systemName: "textformat.size").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("Opciones de lectura").accessibilityIdentifier("book-reading-options")

                }
            }
            .sheet(isPresented: $showReadingOptions) {
                ReadingOptionsSheet(lesson: lesson, largeText: $largeText) { visibleBlock = $0 }
            }
            .onAppear {
                visibleBlock = reading.progress.positions[lesson.id] ?? "chapter-start"
                reading.open(lesson)
                restored = true
            }
            .onChange(of: visibleBlock) { _, value in
                if restored, let value { reading.remember(value, in: lesson) }
            }
    }
}

private struct BookBlockView: View {
    let block: BookBlock
    let largeText: Bool
    private func markdown(_ value: String) -> Text {
        Text((try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value))
    }
    var body: some View {
        Group {
            switch block.kind {
            case .heading:
                markdown(block.text).font((block.level ?? 3) <= 3 ? .title2.weight(.bold) : .title3.weight(.semibold))
                    .padding(.top, 12).accessibilityAddTraits(.isHeader)
            case .paragraph:
                markdown(block.text)
            case .quote:
                HStack(alignment: .top, spacing: 16) {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 3)
                    markdown(block.text).italic()
                }.fixedSize(horizontal: false, vertical: true).padding(16).background(Theme.pale, in: RoundedRectangle(cornerRadius: 14))
            case .listItem:
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(block.marker ?? "•").foregroundStyle(Theme.accent)
                    markdown(block.text).frame(maxWidth: .infinity, alignment: .leading)
                }
            case .table:
                if let rows = block.rows, let headers = rows.first {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(rows.dropFirst().enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                                    if index == 0 { markdown(cell).font(.headline) }
                                    else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if index < headers.count { markdown(headers[index]).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted) }
                                            markdown(cell)
                                        }
                                    }
                                }
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).dataCard()
                        }
                    }
                }
            case .divider: Divider()
            }
        }.font(largeText ? .title3 : .body).lineSpacing(7).textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReadingOptionsSheet: View {
    let lesson: BookLesson
    @Binding var largeText: Bool
    let jump: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Una lectura a tu medida").font(.title2.weight(.bold))
                    HStack(spacing: 12) {
                        sizeButton("Normal", enlarged: false)
                        sizeButton("Grande", enlarged: true)
                    }
                    Text("En esta lección").font(.headline)
                    VStack(spacing: 0) {
                        sectionButton("Volver al principio", target: "chapter-start")
                        ForEach(lesson.blocks.filter { $0.kind == .heading }) { heading in
                            Divider()
                            sectionButton(heading.text, target: heading.id)
                        }
                        Divider()
                        sectionButton("Ir al final de la lección", target: "chapter-end")
                    }.padding(.horizontal, 18).dataCard()
                }.padding(20)
            }.appCanvas().navigationTitle("Opciones de lectura").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
    private func sizeButton(_ title: String, enlarged: Bool) -> some View {
        Button { largeText = enlarged } label: {
            VStack(spacing: 8) {
                Text("Aa").font(enlarged ? .largeTitle : .title2)
                Text(title).font(.subheadline.weight(.semibold))
            }.frame(maxWidth: .infinity, minHeight: 96)
                .foregroundStyle(largeText == enlarged ? Theme.accent : Theme.muted)
                .background(largeText == enlarged ? Theme.pale : Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(largeText == enlarged ? Theme.accent : .clear) }
        }.buttonStyle(.plain).accessibilityAddTraits(largeText == enlarged ? .isSelected : [])
    }
    private func sectionButton(_ title: String, target: String) -> some View {
        Button { jump(target); dismiss() } label: {
            HStack { Text(title).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.down").font(.caption) }
                .font(.subheadline).frame(minHeight: 52).padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
