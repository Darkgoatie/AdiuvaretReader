import SwiftUI
import PDFKit
import ReaderStore
import ReaderDesign

#if canImport(UIKit)
import UIKit
import PencilKit

/// The page a zone opens: the marked part of the PDF copied to the top, and free space under it to write in. A PDF with no room for answers
/// gets a page for each question this way. The writing belongs to the zone and is kept apart from the ink on the PDF itself.
struct ZoneView: View {
    let controller: ZoneController
    let model: PDFBookModel
    let dark: Bool
    let ground: Color

    @AppStorage("zoneFingerDraws") private var fingerSetting = ""
    @State private var renaming: String?
    @State private var confirmDelete = false

    private var zone: Zone? { controller.opened.flatMap { controller.list.zone(id: $0.id) } }

    /// A finger writes by default on an iPhone, which has no Pencil. On an iPad the Pencil writes and a finger scrolls, until the user changes it.
    private var fingerDraws: Bool {
        fingerSetting.isEmpty ? UIDevice.current.userInterfaceIdiom == .phone : fingerSetting == "on"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let zone, let page = model.document?.page(at: zone.page) {
                    ZoneCanvas(store: controller.store, bookID: controller.bookID, zone: zone, page: page, dark: dark, ground: ground,
                               fingerDraws: fingerDraws, onWriting: { controller.noteWriting(zoneID: zone.id, has: $0) })
                        .id(zone.id)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    ContentUnavailableView("This zone is gone", systemImage: "rectangle.dashed")
                }
            }
            .background(ground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .preferredColorScheme(dark ? .dark : .light)
        .alert("Name this zone", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Zone name", text: Binding(get: { renaming ?? "" }, set: { renaming = $0 }))
            Button("Save") {
                if let zone, let name = renaming { controller.rename(zone, to: name) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Delete this zone and everything written in it?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete zone", role: .destructive) { if let zone { controller.delete(zone) } }
        } message: { Text("The PDF itself is not changed.") }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button { controller.close() } label: { Label("Back to PDF", systemImage: "chevron.backward").labelStyle(.titleAndIcon) }
        }
        ToolbarItem(placement: .principal) {
            if let zone {
                VStack(spacing: 0) {
                    Text(controller.title(of: zone)).font(DS.Typography.headline).lineLimit(1)
                    Text("Page \(zone.page + 1)").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let zone {
                let previous = controller.list.previous(before: zone.id), next = controller.list.next(after: zone.id)
                Button { if let previous { controller.open(previous) } } label: { Label("Previous zone", systemImage: "chevron.up") }
                    .disabled(previous == nil)
                Button { if let next { controller.open(next) } } label: { Label("Next zone", systemImage: "chevron.down") }
                    .disabled(next == nil)
                Button { fingerSetting = fingerDraws ? "off" : "on" } label: {
                    Label(fingerDraws ? "Finger writes" : "Pencil writes", systemImage: fingerDraws ? "hand.draw.fill" : "hand.draw")
                }
                Menu {
                    Button { renaming = zone.title } label: { Label("Rename", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete zone", systemImage: "trash") }
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
    }
}

struct ZoneCanvas: UIViewRepresentable {
    let store: ZoneStore
    let bookID: UUID
    let zone: Zone
    let page: PDFPage
    let dark: Bool
    let ground: Color
    let fingerDraws: Bool
    let onWriting: (Bool) -> Void

    func makeUIView(context: Context) -> ZoneWritingView {
        let v = ZoneWritingView(store: store, bookID: bookID, zone: zone, page: page, dark: dark)
        v.fingerDraws = fingerDraws
        v.onWriting = onWriting
        return v
    }

    func updateUIView(_ v: ZoneWritingView, context: Context) {
        v.backgroundColor = UIColor(ground)
        v.fingerDraws = fingerDraws
        v.onWriting = onWriting
    }

    static func dismantleUIView(_ v: ZoneWritingView, coordinator: ()) { v.close() }
}

/// A scrolling page: the copied part at the top, a canvas over the whole page. What is written is kept at a fixed logical width, so it comes back
/// at the same size on any device and when the screen turns. The page grows as the user writes towards its end.
@MainActor
final class ZoneWritingView: UIScrollView, PKCanvasViewDelegate {
    private let store: ZoneStore
    private let bookID: UUID
    private let zone: Zone
    private let page: PDFPage
    private let dark: Bool
    private let canvas = PKCanvasView()
    private let clip = UIImageView()
    private let frameLine = UIView()
    private let picker = PKToolPicker()
    /// Points per logical unit the canvas drawing is currently in; zero until the first layout.
    private var applied: CGFloat = 0
    private var baseline = Data()
    private var saveTask: Task<Void, Never>?
    private var pageHeight: CGFloat = 0
    private var closed = false
    var onWriting: ((Bool) -> Void)?

    var fingerDraws = true {
        didSet {
            canvas.drawingPolicy = fingerDraws ? .anyInput : .pencilOnly
            // with a finger drawing, scrolling takes two fingers
            panGestureRecognizer.minimumNumberOfTouches = fingerDraws ? 2 : 1
        }
    }

    init(store: ZoneStore, bookID: UUID, zone: Zone, page: PDFPage, dark: Bool) {
        self.store = store
        self.bookID = bookID
        self.zone = zone
        self.page = page
        self.dark = dark
        super.init(frame: .zero)
        alwaysBounceVertical = true
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        keyboardDismissMode = .interactive

        clip.contentMode = .scaleToFill
        clip.layer.cornerRadius = Radius.s
        clip.layer.masksToBounds = true
        clip.layer.borderWidth = 1
        clip.layer.borderColor = UIColor(DS.Colors.separator).cgColor
        addSubview(clip)

        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = fingerDraws ? .anyInput : .pencilOnly
        canvas.overrideUserInterfaceStyle = dark ? .dark : .light
        canvas.delegate = self
        addSubview(canvas)
        picker.addObserver(canvas)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !closed else { return }
        picker.setVisible(true, forFirstResponder: canvas)
        Task { @MainActor [weak self] in self?.canvas.becomeFirstResponder() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        guard w > 1 else { return }
        let s = ZoneLayout.scale(forWidth: Double(w))
        if abs(Double(applied) - s) > 0.0001 { rebuild(width: w, scale: CGFloat(s)) }
    }

    // MARK: layout

    /// Called at the first layout and whenever the width changes: the copied part is drawn again at the new width and the writing is scaled with it.
    private func rebuild(width w: CGFloat, scale s: CGFloat) {
        let margin = CGFloat(ZoneLayout.margin) * s
        let clipWidth = max(1, w - 2 * margin)
        if let image = ZoneClip.image(page: page, zone: zone.rect, width: clipWidth, scale: max(1, traitCollection.displayScale), invert: dark) {
            clip.image = image
            let aspect = Double(image.size.height / max(1, image.size.width))
            clip.frame = ZoneLayout.clipFrame(width: Double(w), aspect: aspect)
        } else {
            clip.image = nil
            clip.frame = ZoneLayout.clipFrame(width: Double(w), aspect: zone.rect.aspect(inPage: page.bounds(for: .cropBox).size))
        }

        if applied == 0 {
            let saved = store.loadWriting(bookID: bookID, zoneID: zone.id).flatMap { try? PKDrawing(data: $0.drawing) } ?? PKDrawing()
            canvas.drawing = saved.transformed(using: CGAffineTransform(scaleX: s, y: s))
            canvas.undoManager?.removeAllActions()
        } else {
            let r = s / applied
            canvas.drawing = canvas.drawing.transformed(using: CGAffineTransform(scaleX: r, y: r))
        }
        applied = s
        baseline = canvas.drawing.dataRepresentation()
        pageHeight = 0
        resize()
    }

    /// The page is always at least a screen taller than the copied part, and grows ahead of the lowest stroke. It never shrinks while it is open.
    private func resize() {
        guard applied > 0 else { return }
        let inkBottom = canvas.drawing.strokes.isEmpty ? 0 : Double(canvas.drawing.bounds.maxY)
        let h = ZoneLayout.contentHeight(clipBottom: Double(clip.frame.maxY), inkBottom: inkBottom, viewport: Double(bounds.height))
        pageHeight = max(pageHeight, CGFloat(h))
        let size = CGSize(width: bounds.width, height: pageHeight)
        if canvas.frame.size != size { canvas.frame = CGRect(origin: .zero, size: size) }
        if contentSize != size { contentSize = size }
    }

    // MARK: saving

    nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        MainActor.assumeIsolated {
            self.resize()
            self.saveTask?.cancel()
            self.saveTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                self?.flush()
            }
        }
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard applied > 0 else { return }
        let data = canvas.drawing.dataRepresentation()
        guard data != baseline else { return }
        baseline = data
        if canvas.drawing.strokes.isEmpty {
            store.removeWriting(bookID: bookID, zoneID: zone.id)
            onWriting?(false)
        } else {
            let normal = canvas.drawing.transformed(using: CGAffineTransform(scaleX: 1 / applied, y: 1 / applied))
            try? store.saveWriting(InkPage(layout: "zone", drawing: normal.dataRepresentation()), bookID: bookID, zoneID: zone.id)
            onWriting?(true)
        }
    }

    /// Called when the page goes away: saves what was written and puts the tool picker down.
    func close() {
        flush()
        closed = true
        picker.setVisible(false, forFirstResponder: canvas)
        picker.removeObserver(canvas)
        canvas.resignFirstResponder()
    }
}
#endif
