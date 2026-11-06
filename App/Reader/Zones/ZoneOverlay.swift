import SwiftUI
import ReaderStore
import ReaderDesign

#if canImport(UIKit)
import UIKit
import PDFKit
import PencilKit

/// Draws the zones over a PDF: an outline around each marked part and a badge in its top right corner that opens the zone's writing page.
/// It sits above the PDF view and not inside it, so the dark reading theme, which inverts the PDF view, does not turn its colours.
/// Touches that hit no badge go on to the PDF underneath.
///
/// While the user is marking, a one-finger drag on the PDF draws a rectangle and becomes a new zone; the PDF's own scrolling then needs two fingers.
struct ZoneLayer: UIViewRepresentable {
    let model: PDFBookModel
    let controller: ZoneController

    func makeUIView(context: Context) -> ZoneOverlay {
        let o = ZoneOverlay(controller: controller)
        o.provider = { [weak model] in model?.view }
        return o
    }

    func updateUIView(_ o: ZoneOverlay, context: Context) {
        // reading these makes SwiftUI call this again when the zones, their writing or the marking state change
        _ = controller.revision
        _ = controller.marking
        o.refresh()
    }
}

final class ZoneBadgeButton: UIButton {
    var zoneID = ""
}

@MainActor
final class ZoneOverlay: UIView {
    let controller: ZoneController
    var provider: (() -> PDFView?)?

    private weak var pdf: PDFView?
    private var outlines: [String: UIView] = [:]
    private var badges: [String: ZoneBadgeButton] = [:]
    private let band = UIView()
    private let markPan = UIPanGestureRecognizer()
    private var origin: CGPoint?
    private var startPage: PDFPage?
    private var markingApplied = false
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    nonisolated(unsafe) private var offsetObservation: NSKeyValueObservation?
    private var attachTries = 0

    init(controller: ZoneController) {
        self.controller = controller
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        band.isUserInteractionEnabled = false
        band.isHidden = true
        band.layer.borderWidth = 2
        band.layer.cornerRadius = 4
        addSubview(band)
        markPan.addTarget(self, action: #selector(dragged(_:)))
        markPan.minimumNumberOfTouches = 1
        markPan.maximumNumberOfTouches = 1
        markPan.isEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
    }

    /// Only the badges take touches. Everything else, including the drag that marks a zone, goes to the PDF view.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for b in badges.values where !b.isHidden && b.frame.insetBy(dx: -ZoneGeometry.hitPadding, dy: -ZoneGeometry.hitPadding).contains(point) { return b }
        return nil
    }

    // MARK: following the PDF view

    private func attachIfNeeded() {
        guard pdf == nil else { return }
        guard let v = provider?() else {
            // the PDF view is made in the same pass as this layer, so it may not be there yet
            if attachTries < 8 {
                attachTries += 1
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    self?.refresh()
                }
            }
            return
        }
        pdf = v
        v.addGestureRecognizer(markPan)
        let center = NotificationCenter.default
        for name in [Notification.Name.PDFViewScaleChanged, .PDFViewPageChanged, .PDFViewVisiblePagesChanged, .PDFViewDocumentChanged] {
            observers.append(center.addObserver(forName: name, object: v, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        if let scroll = Self.scrollViews(in: v).first {
            offsetObservation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    /// The PDF view's own scroll views, not the ink canvases that sit inside its pages.
    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        for sub in view.subviews where !(sub is PKCanvasView) {
            if let s = sub as? UIScrollView { found.append(s) }
            found += scrollViews(in: sub)
        }
        return found
    }

    /// While marking, one finger marks and two fingers scroll.
    private func applyMarking(_ on: Bool) {
        guard let pdf, on != markingApplied else { return }
        markingApplied = on
        markPan.isEnabled = on
        for s in Self.scrollViews(in: pdf) { s.panGestureRecognizer.minimumNumberOfTouches = on ? 2 : 1 }
        if !on { band.isHidden = true; origin = nil }
    }

    // MARK: drawing

    func refresh() {
        attachIfNeeded()
        guard let pdf, let doc = pdf.document else { return }
        applyMarking(controller.marking)
        let accent = UIColor(DS.Colors.accent)
        let onAccent = UIColor(DS.Colors.onAccent)
        var keep = Set<String>()
        for zone in controller.list.zones {
            guard let page = doc.page(at: zone.page) else { continue }
            let frame = convert(pdf.convert(page.bounds(for: .cropBox), from: page), from: pdf)
            let r = zone.rect.rect(inPage: frame.size).offsetBy(dx: frame.minX, dy: frame.minY)
            guard r.intersects(bounds.insetBy(dx: -60, dy: -60)) else { continue }
            keep.insert(zone.id)

            let outline = outlines[zone.id] ?? {
                let o = UIView()
                o.isUserInteractionEnabled = false
                o.layer.cornerRadius = 4
                o.layer.borderWidth = 1.5
                insertSubview(o, belowSubview: band)
                outlines[zone.id] = o
                return o
            }()
            outline.frame = r
            outline.layer.borderColor = accent.withAlphaComponent(0.85).cgColor
            outline.backgroundColor = accent.withAlphaComponent(0.06)

            let badge = badges[zone.id] ?? {
                let b = ZoneBadgeButton(type: .custom)
                b.zoneID = zone.id
                b.addAction(UIAction { [weak self, weak b] _ in
                    guard let self, let b, let z = self.controller.list.zone(id: b.zoneID) else { return }
                    self.controller.open(z)
                }, for: .touchUpInside)
                addSubview(b)
                badges[zone.id] = b
                return b
            }()
            let box = ZoneGeometry.badge(in: r)
            let isWritten = controller.written.contains(zone.id)
            badge.frame = box
            badge.layer.cornerRadius = min(8, box.width / 3)
            badge.layer.borderWidth = 1.5
            badge.layer.borderColor = accent.cgColor
            badge.backgroundColor = isWritten ? accent : UIColor(DS.Colors.surface)
            let number = controller.list.number(of: zone.id).map(String.init) ?? ""
            badge.setTitle(box.width >= 26 ? number : "", for: .normal)
            badge.setTitleColor(isWritten ? onAccent : accent, for: .normal)
            badge.titleLabel?.font = UIFont.systemFont(ofSize: min(16, box.width * 0.45), weight: .semibold)
            badge.accessibilityLabel = "Open " + controller.title(of: zone)
            badge.accessibilityValue = isWritten ? "Has writing" : "Empty"
        }
        for id in outlines.keys where !keep.contains(id) { outlines.removeValue(forKey: id)?.removeFromSuperview() }
        for id in badges.keys where !keep.contains(id) { badges.removeValue(forKey: id)?.removeFromSuperview() }
        for b in badges.values { bringSubviewToFront(b) }
        band.layer.borderColor = accent.cgColor
        band.backgroundColor = accent.withAlphaComponent(0.15)
    }

    // MARK: marking

    @objc private func dragged(_ g: UIPanGestureRecognizer) {
        guard controller.marking else { return }
        let p = g.location(in: self)
        switch g.state {
        case .began:
            let t = g.translation(in: self)
            let start = CGPoint(x: p.x - t.x, y: p.y - t.y)
            origin = start
            startPage = pdf?.page(for: convert(start, to: pdf), nearest: true)
            band.isHidden = false
            band.frame = CGRect(origin: start, size: .zero)
            bringSubviewToFront(band)
        case .changed:
            if let o = origin { band.frame = CGRect(x: min(o.x, p.x), y: min(o.y, p.y), width: abs(p.x - o.x), height: abs(p.y - o.y)) }
        case .ended:
            let rect = band.frame
            band.isHidden = true
            origin = nil
            finish(rect)
        default:
            band.isHidden = true
            origin = nil
        }
    }

    /// The rectangle is turned into fractions of the page it started on, measured against the page as the PDF view shows it.
    private func finish(_ rect: CGRect) {
        guard let pdf, let doc = pdf.document, let page = startPage else { return }
        let frame = convert(pdf.convert(page.bounds(for: .cropBox), from: page), from: pdf)
        let local = rect.offsetBy(dx: -frame.minX, dy: -frame.minY)
        guard let zr = ZoneRect(rect: local, inPage: frame.size) else {
            controller.toast?("Too small. Drag over the whole question.")
            return
        }
        controller.add(page: doc.index(for: page), rect: zr)
    }
}
#endif
