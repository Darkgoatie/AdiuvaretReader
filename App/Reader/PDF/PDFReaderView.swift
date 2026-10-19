import SwiftUI
import PDFKit
import ReaderDesign
import ReaderStore
import ReaderFormats

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
final class PDFBookModel {
    let session: ReaderSession
    var document: PDFDocument?
    var failure: String?
    @ObservationIgnored weak var view: PDFView?

    init(session: ReaderSession) { self.session = session }

    var pageCount: Int { document?.pageCount ?? 0 }

    func load() {
        guard document == nil else { return }
        guard let url = Services.url(for: session.book) else { failure = "This file could not be found."; return }
        guard let doc = PDFDocument(url: url) else { failure = "This PDF could not be opened. It may be damaged."; return }
        if doc.isLocked { failure = "This PDF is password protected and cannot be opened here."; return }
        document = doc
        session.toc = outline(doc)
        session.stepper = { [weak self] delta in self?.step(delta) }
        session.clearSelectionHook = { [weak self] in self?.view?.clearSelection() }
        session.contextProvider = { [weak self] in
            guard let self, let doc = self.document, let view = self.view, let page = view.currentPage else { return nil }
            let index = doc.index(for: page)
            var text = page.string ?? ""
            if text.count < 600, let next = doc.page(at: index + 1)?.string { text += "\n" + next }
            return PassageContext(text: text, fraction: 0, source: ReadingPosition.page(index).label())
        }
        session.searchProvider = { [weak self] q in await self?.search(q) ?? [] }
        session.hitPosition = { hit in .page(hit.chapter) }
    }

    private func outline(_ doc: PDFDocument) -> [TocItem] {
        var items: [TocItem] = []
        func walk(_ node: PDFOutline?) {
            guard let node else { return }
            for i in 0..<node.numberOfChildren {
                guard let child = node.child(at: i) else { continue }
                if let label = child.label, let page = child.destination?.page {
                    items.append(TocItem(id: items.count, title: label, position: .page(doc.index(for: page))))
                }
                walk(child)
            }
        }
        walk(doc.outlineRoot)
        return items
    }

    func goTo(page index: Int) {
        guard let doc = document, let page = doc.page(at: min(max(index, 0), doc.pageCount - 1)) else { return }
        view?.go(to: page)
    }

    func step(_ delta: Int) {
        guard let view, let doc = document, let current = view.currentPage else { return }
        goTo(page: doc.index(for: current) + delta)
    }

    func pageChanged() {
        guard let view, let doc = document, let page = view.currentPage, doc.pageCount > 0 else { return }
        let i = doc.index(for: page)
        session.record(.page(i), progress: Double(i + 1) / Double(doc.pageCount))
    }

    func handle(_ jump: Jump) {
        if case .page(let p) = jump.position {
            goTo(page: p)
            if let q = jump.find, let doc = document, let sel = doc.findString(q, withOptions: .caseInsensitive).first(where: { s in s.pages.first.map { doc.index(for: $0) == p } ?? false }) {
                view?.setCurrentSelection(sel, animate: true)
                view?.go(to: sel)
            }
        }
    }

    private func search(_ query: String) async -> [SearchHit] {
        guard let doc = document else { return [] }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        var hits: [SearchHit] = []
        for sel in doc.findString(q, withOptions: [.caseInsensitive, .diacriticInsensitive]).prefix(200) {
            guard let page = sel.pages.first else { continue }
            let extended = sel.copy() as? PDFSelection
            extended?.extend(atStart: 30)
            extended?.extend(atEnd: 60)
            let snippet = (extended?.string ?? sel.string ?? q).replacingOccurrences(of: "\n", with: " ")
            hits.append(SearchHit(id: hits.count, chapter: doc.index(for: page), offset: 0, length: q.count, snippet: snippet))
        }
        return hits
    }
}

/// A dark reading theme inverts the page colours; images invert too, which is the usual trade for a dark PDF.
struct DarkPages: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.colorInvert() } else { content }
    }
}

struct PDFBookView: View {
    let model: PDFBookModel
    private let prefs = ReaderPreferences.shared

    var body: some View {
        Group {
            if let doc = model.document {
                PDFKitView(model: model, document: doc, ground: prefs.theme.groundColor)
                    .modifier(DarkPages(on: prefs.theme == .dark))
            } else if let failure = model.failure {
                ContentUnavailableView("Cannot open this PDF", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .background(prefs.theme.groundColor)
        .onAppear { model.load() }
    }
}

#if canImport(UIKit)
struct PDFKitView: UIViewRepresentable {
    let model: PDFBookModel
    let document: PDFDocument
    let ground: Color

    func makeCoordinator() -> PDFCoordinator { PDFCoordinator(model) }

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.usePageViewController(false)
        v.pageShadowsEnabled = false
        model.view = v
        context.coordinator.attach(v)
        if let f = model.session.startFragment, f.hasPrefix("page="), let n = Int(f.dropFirst(5)) {
            model.goTo(page: n - 1)
            model.session.startFragment = nil
        } else if let saved = model.session.book.locator, case .page(let p)? = ReadingPosition(encoded: saved) { model.goTo(page: p) }
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        v.backgroundColor = UIColor(ground)
        model.view = v
    }
}
#else
struct PDFKitView: NSViewRepresentable {
    let model: PDFBookModel
    let document: PDFDocument
    let ground: Color

    func makeCoordinator() -> PDFCoordinator { PDFCoordinator(model) }

    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.pageShadowsEnabled = false
        model.view = v
        context.coordinator.attach(v)
        if let saved = model.session.book.locator, case .page(let p)? = ReadingPosition(encoded: saved) { model.goTo(page: p) }
        return v
    }

    func updateNSView(_ v: PDFView, context: Context) {
        v.backgroundColor = NSColor(ground)
        model.view = v
    }
}
#endif

@MainActor
final class PDFCoordinator: NSObject {
    let model: PDFBookModel
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init(_ model: PDFBookModel) { self.model = model }

    func attach(_ view: PDFView) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.pageChanged() }
        })
        observers.append(center.addObserver(forName: .PDFViewSelectionChanged, object: view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.session.selection = view.currentSelection?.string ?? "" }
        })
        #if canImport(UIKit)
        let tap = TapRecognizer.make { [weak self] in self?.model.session.chromeVisible.toggle() }
        view.addGestureRecognizer(tap)
        #endif
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
}

#if canImport(UIKit)
enum TapRecognizer {
    @MainActor static func make(_ action: @escaping () -> Void) -> UITapGestureRecognizer {
        let r = ClosureTap(action)
        r.cancelsTouchesInView = false
        return r
    }

    final class ClosureTap: UITapGestureRecognizer, UIGestureRecognizerDelegate {
        private let action: () -> Void
        init(_ action: @escaping () -> Void) {
            self.action = action
            super.init(target: nil, action: nil)
            addTarget(self, action: #selector(fire))
            delegate = self
        }
        @objc private func fire() { action() }
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
    }
}
#endif
