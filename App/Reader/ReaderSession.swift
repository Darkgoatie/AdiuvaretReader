import SwiftUI
import SwiftData
import ReaderStore
import ReaderFormats
import ReaderAssistant

struct PassageContext {
    let text: String
    let fraction: Double
    let source: String
}

struct TocItem: Identifiable {
    let id: Int
    let title: String
    let position: ReadingPosition
}

struct Jump: Equatable {
    let id = UUID()
    let position: ReadingPosition
    var find: String?
}

@MainActor
@Observable
final class ReaderSession {
    let book: Book

    var selection = ""
    var pinnedSelection = ""
    var chromeVisible = true
    var showAssistant = false
    var showSettings = false
    var showAnnotations = false
    var showSearch = false
    var showContents = false
    var noteDraft: String?
    var position: ReadingPosition?
    var progress: Double = 0
    var jump: Jump?
    var toc: [TocItem] = []
    var contextProvider: (@MainActor () async -> PassageContext?)?
    var searchProvider: (@MainActor (String) async -> [SearchHit])?
    var hitPosition: ((SearchHit) -> ReadingPosition)?

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(book: Book) { self.book = book }

    var isCode: Bool { book.format == .code }

    func record(_ position: ReadingPosition, progress: Double) {
        self.position = position
        self.progress = min(max(progress, 0), 1)
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        if let p = position { book.locator = p.encoded }
        book.progress = progress
    }

    func go(to position: ReadingPosition, find: String? = nil) {
        jump = Jump(position: position, find: find)
    }

    func openAssistant() {
        pinnedSelection = selection
        showAssistant = true
    }

    func makePassage() async -> Passage? {
        let source = (position ?? .block(0)).label(isCode: isCode)
        if let p = Passage.selection(pinnedSelection, source: source) { return p }
        guard let ctx = await contextProvider?() else { return nil }
        return Passage.around(ctx.text, fraction: ctx.fraction, source: ctx.source)
    }
}
