import Foundation
import ReaderStore
import ReaderDesign

#if canImport(UIKit)
import UIKit
import PencilKit
import PDFKit
import WebKit

/// Carries a UIKit object across the isolation boundary of a delegate callback. UIKit calls these on the main thread.
struct Unchecked<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }

/// A PDF view that can own the tool picker, so the picker stays up while the page canvases scroll in and out.
final class InkPDFView: PDFView {
    override var canBecomeFirstResponder: Bool { true }
}

/// A canvas on a PDF page. PDFKit may resize the page's overlay as the zoom changes, so the canvas says whenever its size changes.
final class InkPageCanvas: PKCanvasView {
    var onResize: ((InkPageCanvas) -> Void)?
    private var lastWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        guard abs(bounds.width - lastWidth) > 0.01 else { return }
        lastWidth = bounds.width
        onResize?(self)
    }
}

@MainActor
enum InkCanvas {
    /// A transparent canvas. A finger scrolls the page underneath unless the user lets fingers draw in the tool picker, and the Apple Pencil draws.
    static func make(dark: Bool, page: Bool = false) -> PKCanvasView {
        let c: PKCanvasView = page ? InkPageCanvas() : PKCanvasView()
        c.backgroundColor = .clear
        c.isOpaque = false
        c.drawingPolicy = .default
        c.isScrollEnabled = false
        c.bounces = false
        c.showsVerticalScrollIndicator = false
        c.showsHorizontalScrollIndicator = false
        c.overrideUserInterfaceStyle = dark ? .dark : .light
        c.isUserInteractionEnabled = false
        return c
    }
}

/// Ink on text that reflows (Markdown, text, EPUB, LaTeX): one canvas on top of the web view's own scroll view, so it scrolls with the text.
/// The ink belongs to the chapter and to the text layout it was drawn on, and each layout keeps its own ink.
@MainActor
final class WebInk: NSObject, PKCanvasViewDelegate {
    static let maxHeight: CGFloat = 30_000

    let bookID: UUID
    private let store = InkStore.standard()
    private let picker = PKToolPicker()
    private(set) var canvas: PKCanvasView?
    private weak var scrollView: UIScrollView?
    private var sizeObservation: NSKeyValueObservation?
    private var page: String?
    private var key: String?
    private var baseline = Data()
    private var saveTask: Task<Void, Never>?
    var onHasInk: ((Bool) -> Void)?

    var dark = false { didSet { canvas?.overrideUserInterfaceStyle = dark ? .dark : .light } }
    var active = false { didSet { if active != oldValue { applyActive() } } }

    init(bookID: UUID) {
        self.bookID = bookID
        super.init()
    }

    func attach(to webView: WKWebView) {
        guard scrollView !== webView.scrollView else { return }
        let c = InkCanvas.make(dark: dark)
        c.delegate = self
        c.isUserInteractionEnabled = active
        webView.scrollView.addSubview(c)
        scrollView = webView.scrollView
        sizeObservation = webView.scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.relayout() }
        }
        canvas = c
        lockZoom()
        relayout()
    }

    private func relayout() {
        guard let canvas, let sv = scrollView else { return }
        let size = CGSize(width: max(sv.contentSize.width, sv.bounds.width), height: min(max(sv.contentSize.height, sv.bounds.height), Self.maxHeight))
        if canvas.frame.size != size || canvas.frame.origin != .zero {
            canvas.frame = CGRect(origin: .zero, size: size)
            canvas.contentSize = size
        }
        sv.bringSubviewToFront(canvas)
    }

    /// Loads the ink of this chapter at the current text layout. Called when a chapter has loaded and when the layout changes.
    func show(page: String) {
        self.page = page
        let p = ReaderPreferences.shared
        let signature = InkLayout.signature(font: p.font.rawValue, fontSize: p.fontSize, lineSpacing: p.lineSpacing, margin: p.margin,
                                            width: Double(scrollView?.bounds.width ?? 0))
        let newKey = InkLayout.key(page: page, signature: signature)
        guard newKey != key else { return }
        flush()
        key = newKey
        let drawing = store.load(bookID: bookID, key: newKey).flatMap { try? PKDrawing(data: $0.drawing) } ?? PKDrawing()
        canvas?.drawing = drawing
        canvas?.undoManager?.removeAllActions()
        baseline = canvas?.drawing.dataRepresentation() ?? Data()
        updateZoomLock()
    }

    func refreshLayout() { if let page { show(page: page) } }

    /// The page is about to be replaced. Saves what was drawn and empties the canvas so ink never lands on the wrong chapter.
    func leavePage() {
        flush()
        key = nil
        page = nil
        canvas?.drawing = PKDrawing()
        baseline = canvas?.drawing.dataRepresentation() ?? Data()
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard let canvas, let key else { return }
        let data = canvas.drawing.dataRepresentation()
        guard data != baseline else { return }
        baseline = data
        if canvas.drawing.strokes.isEmpty { store.remove(bookID: bookID, key: key) }
        else { try? store.save(InkPage(layout: key, drawing: data), bookID: bookID, key: key) }
        onHasInk?(store.hasInk(bookID: bookID))
    }

    func clearAll() {
        saveTask?.cancel()
        store.removeAll(bookID: bookID)
        canvas?.drawing = PKDrawing()
        baseline = canvas?.drawing.dataRepresentation() ?? Data()
        onHasInk?(false)
        updateZoomLock()
    }

    private func applyActive() {
        guard let canvas else { return }
        canvas.isUserInteractionEnabled = active
        if active {
            picker.addObserver(canvas)
            picker.setVisible(true, forFirstResponder: canvas)
            Task { @MainActor in canvas.becomeFirstResponder() }
        } else {
            picker.setVisible(false, forFirstResponder: canvas)
            picker.removeObserver(canvas)
            canvas.resignFirstResponder()
            flush()
        }
        updateZoomLock()
    }

    /// Ink sits at fixed positions in the page, and the canvas is not part of what a pinch scales, so zoom would pull the ink away from
    /// the text. Text pages never zoom: the font size and margins in Appearance change the size of the text, and the ink follows.
    func lockZoom() {
        guard let sv = scrollView else { return }
        sv.pinchGestureRecognizer?.isEnabled = false
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 1
        if sv.zoomScale != 1 { sv.setZoomScale(1, animated: false) }
    }

    private func updateZoomLock() { lockZoom() }

    nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        MainActor.assumeIsolated { self.changed() }
    }

    private func changed() {
        updateZoomLock()
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}

/// Ink on a PDF: PDFKit gives every page its own overlay, and each overlay is a canvas. The ink is saved per page in page units,
/// so it stays where it was drawn at any zoom.
@MainActor
final class PDFInk: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, PKToolPickerObserver {
    private struct Entry {
        var page: PDFPage
        var index: Int
        /// The canvas width the drawing's coordinates are currently in.
        var applied: CGFloat
        var baseline: Data
    }

    let bookID: UUID
    private let store = InkStore.standard()
    private let picker = PKToolPicker()
    private weak var pdfView: PDFView?
    private var canvases: [ObjectIdentifier: PKCanvasView] = [:]
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var dirty: Set<ObjectIdentifier> = []
    private var saveTask: Task<Void, Never>?
    nonisolated(unsafe) private var scaleObserver: NSObjectProtocol?
    var onHasInk: ((Bool) -> Void)?

    var active = false { didSet { if active != oldValue { applyActive() } } }

    init(bookID: UUID) {
        self.bookID = bookID
        super.init()
        picker.addObserver(self)
    }

    deinit { if let scaleObserver { NotificationCenter.default.removeObserver(scaleObserver) } }

    func attach(_ view: PDFView) {
        pdfView = view
        view.pageOverlayViewProvider = self
        if let scaleObserver { NotificationCenter.default.removeObserver(scaleObserver) }
        scaleObserver = NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcileAll() }
        }
    }

    // MARK: PDFPageOverlayViewProvider

    nonisolated func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
        let box = Unchecked((view, page))
        return MainActor.assumeIsolated { self.canvas(for: box.value.1, in: box.value.0) }
    }

    nonisolated func pdfView(_ pdfView: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
        let box = Unchecked((overlayView, page))
        MainActor.assumeIsolated { if let c = box.value.0 as? PKCanvasView { self.display(c, page: box.value.1) } }
    }

    nonisolated func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
        let box = Unchecked((overlayView, page))
        MainActor.assumeIsolated { if let c = box.value.0 as? PKCanvasView { self.end(c, page: box.value.1) } }
    }

    private func canvas(for page: PDFPage, in view: PDFView) -> PKCanvasView {
        let pid = ObjectIdentifier(page)
        if let existing = canvases[pid] { return existing }
        let c = InkCanvas.make(dark: false, page: true)
        (c as? InkPageCanvas)?.onResize = { [weak self] canvas in MainActor.assumeIsolated { self?.reconcile(canvas) } }
        c.isUserInteractionEnabled = active
        c.delegate = self
        picker.addObserver(c)
        canvases[pid] = c
        entries[ObjectIdentifier(c)] = Entry(page: page, index: view.document?.index(for: page) ?? 0, applied: 0, baseline: Data())
        return c
    }

    private func display(_ c: PKCanvasView, page: PDFPage, attempt: Int = 0) {
        let id = ObjectIdentifier(c)
        guard var e = entries[id] else { return }
        let width = c.bounds.width
        guard width > 1 else {
            if attempt < 3 { Task { @MainActor in try? await Task.sleep(nanoseconds: 80_000_000); self.display(c, page: page, attempt: attempt + 1) } }
            return
        }
        c.contentSize = c.bounds.size
        guard e.applied == 0 else { reconcile(c); return }
        var drawing = store.load(bookID: bookID, key: "p\(e.index)").flatMap { try? PKDrawing(data: $0.drawing) } ?? PKDrawing()
        let pageWidth = page.bounds(for: .cropBox).width
        if pageWidth > 1 { drawing = drawing.transformed(using: CGAffineTransform(scaleX: width / pageWidth, y: width / pageWidth)) }
        c.drawing = drawing
        c.undoManager?.removeAllActions()
        e.applied = width
        e.baseline = c.drawing.dataRepresentation()
        entries[id] = e
    }

    private func end(_ c: PKCanvasView, page: PDFPage) {
        save(c)
        picker.removeObserver(c)
        canvases.removeValue(forKey: ObjectIdentifier(page))
        entries.removeValue(forKey: ObjectIdentifier(c))
        dirty.remove(ObjectIdentifier(c))
    }

    /// When PDFKit sizes a page canvas to the zoom instead of scaling it, the drawing is scaled with it.
    private func reconcile(_ c: PKCanvasView) {
        let id = ObjectIdentifier(c)
        guard var e = entries[id], e.applied > 0, c.bounds.width > 1 else { return }
        let r = c.bounds.width / e.applied
        guard abs(r - 1) > 0.001 else { return }
        c.drawing = c.drawing.transformed(using: CGAffineTransform(scaleX: r, y: r))
        c.contentSize = c.bounds.size
        e.applied = c.bounds.width
        e.baseline = c.drawing.dataRepresentation()
        entries[id] = e
    }

    private func reconcileAll() { for c in canvases.values { reconcile(c) } }

    private func save(_ c: PKCanvasView) {
        reconcile(c)
        let id = ObjectIdentifier(c)
        guard var e = entries[id], e.applied > 0 else { return }
        let data = c.drawing.dataRepresentation()
        guard data != e.baseline else { return }
        let key = "p\(e.index)"
        if c.drawing.strokes.isEmpty {
            store.remove(bookID: bookID, key: key)
        } else {
            let pageWidth = e.page.bounds(for: .cropBox).width
            let normal = pageWidth > 1 ? c.drawing.transformed(using: CGAffineTransform(scaleX: pageWidth / e.applied, y: pageWidth / e.applied)) : c.drawing
            try? store.save(InkPage(layout: "pdf", drawing: normal.dataRepresentation()), bookID: bookID, key: key)
        }
        e.baseline = data
        entries[id] = e
        onHasInk?(store.hasInk(bookID: bookID))
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        dirty.removeAll()
        for c in canvases.values { save(c) }
    }

    func clearAll() {
        saveTask?.cancel()
        store.removeAll(bookID: bookID)
        for c in canvases.values {
            c.drawing = PKDrawing()
            if var e = entries[ObjectIdentifier(c)] { e.baseline = c.drawing.dataRepresentation(); entries[ObjectIdentifier(c)] = e }
        }
        onHasInk?(false)
    }

    private func applyActive() {
        for c in canvases.values { c.isUserInteractionEnabled = active }
        guard let pdfView else { return }
        if active {
            picker.setVisible(true, forFirstResponder: pdfView)
            Task { @MainActor in pdfView.becomeFirstResponder() }
        } else {
            picker.setVisible(false, forFirstResponder: pdfView)
            pdfView.resignFirstResponder()
            flush()
        }
    }

    // MARK: Delegates

    nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        let id = ObjectIdentifier(canvasView)
        MainActor.assumeIsolated {
            self.dirty.insert(id)
            self.saveTask?.cancel()
            self.saveTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled, let self else { return }
                self.flush()
            }
        }
    }

    /// Every page canvas takes the tool chosen in the picker, not only the one that has focus.
    nonisolated func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        let box = Unchecked(toolPicker)
        MainActor.assumeIsolated {
            let tool = box.value.selectedTool
            for c in self.canvases.values { c.tool = tool }
        }
    }
}
#else
@MainActor final class WebInk {
    init(bookID: UUID) {}
    var onHasInk: ((Bool) -> Void)?
    var dark = false
    var active = false
    func show(page: String) {}
    func refreshLayout() {}
    func leavePage() {}
    func flush() {}
    func clearAll() {}
}
@MainActor final class PDFInk {
    init(bookID: UUID) {}
    var onHasInk: ((Bool) -> Void)?
    var active = false
    func flush() {}
    func clearAll() {}
}
#endif
