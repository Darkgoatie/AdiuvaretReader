import Foundation

/// A marked part of a page, as fractions of the page as it is shown: upright, from the top left, after the page's own rotation.
/// Fractions stay right at any zoom, on any device and for any page size.
public struct ZoneRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The smallest side a zone may have, as a share of the page. Smaller drags are taps that slipped, not zones.
    public static let minimumSide = 0.02

    /// A zone from a rectangle and the page it was drawn on, both in the same points: the page as it is shown, from its top left.
    /// The part outside the page is cut off; nil when what is left is too small or the page is empty.
    public init?(rect: CGRect, inPage page: CGSize) {
        guard page.width > 0, page.height > 0 else { return nil }
        let r = rect.standardized.intersection(CGRect(origin: .zero, size: page))
        guard !r.isNull, r.width / page.width >= Self.minimumSide, r.height / page.height >= Self.minimumSide else { return nil }
        x = Double(r.minX / page.width)
        y = Double(r.minY / page.height)
        width = Double(r.width / page.width)
        height = Double(r.height / page.height)
    }

    /// The rectangle on a page of this size, in points from the top left.
    public func rect(inPage page: CGSize) -> CGRect {
        CGRect(x: CGFloat(x) * page.width, y: CGFloat(y) * page.height, width: CGFloat(width) * page.width, height: CGFloat(height) * page.height)
    }

    /// Height over width of the marked part as it is shown.
    public func aspect(inPage page: CGSize) -> Double {
        let r = rect(inPage: page)
        return r.width > 0 ? Double(r.height / r.width) : 1
    }

    /// Inside the page and not smaller than the minimum. A saved file that fails this is dropped on load.
    public var isValid: Bool {
        let slack = 1e-6
        return [x, y, width, height].allSatisfy { $0.isFinite }
            && x >= -slack && y >= -slack
            && width >= Self.minimumSide - slack && height >= Self.minimumSide - slack
            && x + width <= 1 + slack && y + height <= 1 + slack
    }
}

/// Where the marker sits on a zone, and where a tap counts as a hit. All in points on the page as it is shown, from the top left.
public enum ZoneGeometry {
    public static let badgeSide: CGFloat = 40
    public static let hitPadding: CGFloat = 12

    /// The badge sits inside the top right corner. A small zone gets a smaller badge, so the badge never covers more than half of it.
    public static func badge(in zone: CGRect) -> CGRect {
        let side = min(badgeSide, max(14, min(zone.width, zone.height) / 2))
        let inset = min(4, side / 4)
        return CGRect(x: zone.maxX - side - inset, y: zone.minY + inset, width: side, height: side)
    }

    /// The badge with some room around it, so a finger does not have to hit it exactly.
    public static func hitArea(in zone: CGRect) -> CGRect {
        badge(in: zone).insetBy(dx: -hitPadding, dy: -hitPadding)
    }
}

/// How the writing page of a zone is laid out. The page is as wide as the screen; what is written on it is kept at a width of 1000 units,
/// so it comes back at the same size on any device and in any orientation.
public enum ZoneLayout {
    public static let logicalWidth: Double = 1000
    /// The space around the copied part, in logical units.
    public static let margin: Double = 24
    /// The longest the writing page may grow, in points.
    public static let maxContentHeight: Double = 30_000
    /// The page grows in steps, so it does not change size with every stroke.
    public static let step: Double = 50

    /// Points per logical unit on a screen of this width.
    public static func scale(forWidth width: Double) -> Double { width > 0 ? width / logicalWidth : 1 }

    /// Where the copied part sits at the top of the page: inside the margin, as wide as the page allows, as tall as the zone is.
    public static func clipFrame(width: Double, aspect: Double) -> CGRect {
        let m = margin * scale(forWidth: width)
        let w = max(1, width - 2 * m)
        let a = min(5, max(0.04, aspect.isFinite ? aspect : 1))
        return CGRect(x: m, y: m, width: w, height: w * a)
    }

    /// How tall the page is: always a full screen of free space under the copied part, and room under the lowest stroke so there is always more to write on.
    public static func contentHeight(clipBottom: Double, inkBottom: Double, viewport: Double) -> Double {
        let free = max(0, viewport)
        let wanted = max(clipBottom + free, inkBottom.isFinite ? inkBottom + free * 0.6 : 0)
        return min(maxContentHeight, (wanted / step).rounded(.up) * step)
    }
}

/// One zone: a marked part of a page, with a place of its own to write.
public struct Zone: Codable, Equatable, Identifiable, Sendable {
    /// Short and safe as a file name: it is also the key of the zone's writing.
    public let id: String
    public var page: Int
    public var rect: ZoneRect
    /// Empty means the zone is called by its number.
    public var title: String
    public var createdAt: Date

    public init(id: String, page: Int, rect: ZoneRect, title: String = "", createdAt: Date = Date()) {
        self.id = id
        self.page = page
        self.rect = rect
        self.title = title
        self.createdAt = createdAt
    }
}

/// The zones of one document, always in reading order: page by page, top to bottom, left to right.
public struct ZoneList: Codable, Equatable, Sendable {
    public private(set) var zones: [Zone] = []

    public init() {}

    public static let maxTitle = 80

    private static func reading(_ a: Zone, _ b: Zone) -> Bool {
        if a.page != b.page { return a.page < b.page }
        if a.rect.y != b.rect.y { return a.rect.y < b.rect.y }
        if a.rect.x != b.rect.x { return a.rect.x < b.rect.x }
        return a.id < b.id
    }

    /// A damaged or edited file cannot put a bad zone in the list: zones with an unsafe id, a rectangle outside the page, a negative page or a repeated id are dropped.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([Zone].self, forKey: .zones)
        var seen = Set<String>()
        zones = raw.filter { InkStore.isValid(key: $0.id) && $0.page >= 0 && $0.rect.isValid && seen.insert($0.id).inserted }
            .sorted(by: Self.reading)
    }

    @discardableResult
    public mutating func add(page: Int, rect: ZoneRect, title: String = "", now: Date = Date()) -> Zone {
        var id = Self.newID()
        while zones.contains(where: { $0.id == id }) { id = Self.newID() }
        let zone = Zone(id: id, page: max(0, page), rect: rect, title: Self.clean(title), createdAt: now)
        zones.append(zone)
        zones.sort(by: Self.reading)
        return zone
    }

    public mutating func rename(id: String, to title: String) {
        guard let i = zones.firstIndex(where: { $0.id == id }) else { return }
        zones[i].title = Self.clean(title)
    }

    @discardableResult
    public mutating func remove(id: String) -> Zone? {
        guard let i = zones.firstIndex(where: { $0.id == id }) else { return nil }
        return zones.remove(at: i)
    }

    public func zone(id: String) -> Zone? { zones.first { $0.id == id } }

    public func zones(onPage page: Int) -> [Zone] { zones.filter { $0.page == page } }

    /// Position in reading order, counted from 1.
    public func number(of id: String) -> Int? { zones.firstIndex { $0.id == id }.map { $0 + 1 } }

    /// What the zone is called: its title, or "Zone" and its number.
    public func displayTitle(of zone: Zone) -> String {
        if !zone.title.isEmpty { return zone.title }
        return "Zone \(number(of: zone.id) ?? 0)"
    }

    public func next(after id: String) -> Zone? {
        guard let i = zones.firstIndex(where: { $0.id == id }), i + 1 < zones.count else { return nil }
        return zones[i + 1]
    }

    public func previous(before id: String) -> Zone? {
        guard let i = zones.firstIndex(where: { $0.id == id }), i > 0 else { return nil }
        return zones[i - 1]
    }

    /// The zone whose badge a tap at `point` hits, on a page of this size, with the point and size in the same points
    /// (the page as it is shown, from its top left). When badges overlap, the one whose centre is nearest wins.
    public func badgeHit(onPage page: Int, at point: CGPoint, pageSize: CGSize) -> Zone? {
        var best: (zone: Zone, distance: CGFloat)?
        for zone in zones(onPage: page) {
            let area = ZoneGeometry.hitArea(in: zone.rect.rect(inPage: pageSize))
            guard area.contains(point) else { continue }
            let badge = ZoneGeometry.badge(in: zone.rect.rect(inPage: pageSize))
            let d = hypot(badge.midX - point.x, badge.midY - point.y)
            if best == nil || d < best!.distance { best = (zone, d) }
        }
        return best?.zone
    }

    private static func clean(_ title: String) -> String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxTitle))
    }

    private static func newID() -> String {
        "z" + String(format: "%08x", UInt32.random(in: 0...UInt32.max))
    }
}

/// Zones are kept apart from the library database and from the ink on the file itself. The list is one small JSON file per book,
/// and what the user writes in a zone is ink in a folder of its own, so removing all ink from a file never takes the zone writing with it.
public struct ZoneStore: Sendable {
    public let root: URL
    public let ink: InkStore

    public init(root: URL, ink: InkStore) {
        self.root = root
        self.ink = ink
    }

    public static func standard() -> ZoneStore {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return ZoneStore(root: base.appendingPathComponent("Zones", isDirectory: true),
                         ink: InkStore(root: base.appendingPathComponent("ZoneInk", isDirectory: true)))
    }

    private func file(_ bookID: UUID) -> URL { root.appendingPathComponent(bookID.uuidString + ".json") }

    public func load(bookID: UUID) -> ZoneList {
        guard let data = try? Data(contentsOf: file(bookID)), let list = try? JSONDecoder().decode(ZoneList.self, from: data) else { return ZoneList() }
        return list
    }

    public func save(_ list: ZoneList, bookID: UUID) throws {
        if list.zones.isEmpty {
            try? FileManager.default.removeItem(at: file(bookID))
            return
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(list).write(to: file(bookID), options: .atomic)
    }

    public func loadWriting(bookID: UUID, zoneID: String) -> InkPage? { ink.load(bookID: bookID, key: zoneID) }

    public func saveWriting(_ page: InkPage, bookID: UUID, zoneID: String) throws { try ink.save(page, bookID: bookID, key: zoneID) }

    public func removeWriting(bookID: UUID, zoneID: String) { ink.remove(bookID: bookID, key: zoneID) }

    /// The zones that have something written in them.
    public func writtenIDs(bookID: UUID) -> Set<String> { Set(ink.keys(bookID: bookID)) }

    /// For a book that is deleted: its zones and everything written in them.
    public func removeAll(bookID: UUID) {
        try? FileManager.default.removeItem(at: file(bookID))
        ink.removeAll(bookID: bookID)
    }
}
