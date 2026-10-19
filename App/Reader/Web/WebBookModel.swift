import SwiftUI
import ReaderStore
import ReaderFormats

/// EPUB, plain text and Markdown share one model: a list of chapter files shown one at a time in the web view.
@MainActor
@Observable
final class WebBookModel {
    let session: ReaderSession
    let controller = WebReaderController()

    var chapters: [URL] = []
    var chapter = 0
    var request: WebRequest?
    var fraction = 0.0
    var failure: String?

    @ObservationIgnored private var texts: [(chapter: Int, text: String)]?

    init(session: ReaderSession) { self.session = session }

    func load() async {
        guard request == nil, let url = Services.url(for: session.book) else {
            if request == nil { failure = "This file could not be found." }
            return
        }
        let id = session.book.id
        do {
            switch session.book.format {
            case .epub:
                let cache = WebAssets.epubCache(for: id)
                let epub = try await Task.detached { try EpubBook.open(at: url, cache: cache) }.value
                chapters = epub.spine.indices.map { epub.chapterURL($0) }
                session.toc = epub.toc.map { TocItem(id: $0.id, title: $0.title, position: .chapter(index: $0.spineIndex, fraction: 0)) }
            case .text, .markdown, .latex:
                let format = session.book.format
                let isMarkdown = format != .text
                let title = session.book.title
                let page = WebAssets.pageURL(for: id)
                let relative = session.book.relativePath
                let shared = session.book.isShared
                let files = shared ? Services.shared : Services.files
                try await Task.detached {
                    let data = try Data(contentsOf: url)
                    let source = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                    let html: String
                    if format == .markdown {
                        html = ObsidianMarkdown.page(title: title, source: source, ctx: ObsidianVault.context(for: relative, shared: shared, files: files))
                    } else if format == .latex {
                        html = ProseHTML.page(title: title, blocks: ProseParser.markdown(LatexConverter.toMarkdown(source)), markdown: true)
                    } else {
                        html = ProseHTML.page(title: title, blocks: ProseParser.plain(source), markdown: false)
                    }
                    try html.write(to: page, atomically: true, encoding: .utf8)
                }.value
                chapters = [page]
            default:
                failure = "This file type is not shown here."
                return
            }
        } catch {
            failure = "This file could not be opened. It may be damaged."
            return
        }
        guard !chapters.isEmpty else { failure = "This book has no readable pages."; return }
        var index = 0
        var start = 0.0
        if let saved = session.book.locator, case .chapter(let i, let f)? = ReadingPosition(encoded: saved) {
            index = min(max(i, 0), chapters.count - 1)
            start = f
        }
        installHooks()
        var anchor: String?
        if let f = session.startFragment, !f.isEmpty, chapters.count == 1 {
            anchor = f.hasPrefix("^") ? f : "h-" + Slug.make(f)
            session.startFragment = nil
        }
        open(chapter: index, fraction: start, anchor: anchor)
    }

    private func installHooks() {
        session.stepper = { [weak self] delta in self?.step(delta) }
        session.clearSelectionHook = { [weak self] in self?.controller.clearSelection() }
        session.contextProvider = { [weak self] in
            guard let self else { return nil }
            let text = await self.controller.text()
            return PassageContext(text: text, fraction: self.fraction, source: ReadingPosition.chapter(index: self.chapter, fraction: 0).label())
        }
        session.searchProvider = { [weak self] query in await self?.search(query) ?? [] }
        session.hitPosition = { hit in .chapter(index: hit.chapter, fraction: 0) }
    }

    func open(chapter index: Int, fraction f: Double = 0, find: String? = nil, anchor: String? = nil) {
        let i = min(max(index, 0), chapters.count - 1)
        chapter = i
        fraction = f
        session.selection = ""
        request = WebRequest(url: chapters[i], fraction: f, find: find, anchor: anchor)
        report()
    }

    func step(_ delta: Int) {
        let next = chapter + delta
        guard chapters.indices.contains(next) else { return }
        open(chapter: next)
    }

    func scrolled(_ f: Double) {
        fraction = f
        report()
    }

    private func report() {
        session.record(.chapter(index: chapter, fraction: fraction),
                       progress: ReadingPosition.overall(chapter: chapter, fraction: fraction, count: chapters.count))
    }

    func handle(_ jump: Jump) {
        if case .chapter(let i, let f) = jump.position { open(chapter: i, fraction: f, find: jump.find) }
    }

    /// A tapped link to another chapter file or note. Returns true when it was one.
    func link(_ url: URL) -> Bool {
        if url.scheme == "obsidian-note" { openNote(url); return true }
        if url.scheme == "obsidian-tag" { session.showSearch = true; session.pendingQuery = "#" + (url.absoluteString.dropFirst("obsidian-tag:".count).removingPercentEncoding ?? ""); return true }
        if url.scheme == "obsidian-missing" { session.toast = "That note does not exist in this library."; return true }
        let target = url.deletingFragment().standardizedFileURL.path
        guard let i = chapters.firstIndex(where: { $0.standardizedFileURL.path == target }) else { return false }
        open(chapter: i, anchor: url.fragment)
        return true
    }

    /// Follows `[[Note]]`, `[[Note#Heading]]` and PDF links by opening the target in the same reader, so Back returns here.
    private func openNote(_ url: URL) {
        let raw = String(url.absoluteString.dropFirst("obsidian-note:".count))
        let parts = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let path = parts[0].removingPercentEncoding ?? parts[0]
        let fragment = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : nil
        session.openNote?(path, fragment)
    }

    private func search(_ query: String) async -> [SearchHit] {
        if texts == nil {
            let urls = chapters
            texts = await Task.detached {
                urls.enumerated().map { (chapter: $0.offset, text: HTMLText.plain(from: (try? String(contentsOf: $0.element, encoding: .utf8)) ?? "")) }
            }.value
        }
        return BookSearch.search(query: query, texts: texts ?? [])
    }
}
