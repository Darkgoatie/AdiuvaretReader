import Testing
import Foundation
@testable import ReaderStore

@Suite struct ZoneTests {
    private let page = CGSize(width: 600, height: 800)

    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> ZoneRect { ZoneRect(x: x, y: y, width: w, height: h) }

    private func store() -> ZoneStore {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("zones-" + UUID().uuidString, isDirectory: true)
        return ZoneStore(root: base.appendingPathComponent("Zones"), ink: InkStore(root: base.appendingPathComponent("ZoneInk")))
    }

    // MARK: rectangles

    @Test func aDragBecomesFractionsOfThePage() throws {
        let z = try #require(ZoneRect(rect: CGRect(x: 60, y: 80, width: 300, height: 400), inPage: page))
        #expect(abs(z.x - 0.1) < 1e-9 && abs(z.y - 0.1) < 1e-9 && abs(z.width - 0.5) < 1e-9 && abs(z.height - 0.5) < 1e-9)
    }

    @Test func fractionsGoBackToTheSameRectangleOnAnySize() throws {
        let original = CGRect(x: 72, y: 130, width: 410, height: 215)
        let z = try #require(ZoneRect(rect: original, inPage: page))
        let back = z.rect(inPage: page)
        #expect(abs(back.minX - original.minX) < 1e-6 && abs(back.minY - original.minY) < 1e-6)
        #expect(abs(back.width - original.width) < 1e-6 && abs(back.height - original.height) < 1e-6)
        // on the same page shown twice as large
        let big = z.rect(inPage: CGSize(width: 1200, height: 1600))
        #expect(abs(big.minX - 144) < 1e-6 && abs(big.height - 430) < 1e-6)
    }

    @Test func aDragFromAnyCornerIsTheSame() throws {
        let a = try #require(ZoneRect(rect: CGRect(x: 100, y: 200, width: 150, height: 100), inPage: page))
        let b = try #require(ZoneRect(rect: CGRect(x: 250, y: 300, width: -150, height: -100), inPage: page))
        #expect(a == b)
    }

    @Test func theOutsideOfThePageIsCutOff() throws {
        let z = try #require(ZoneRect(rect: CGRect(x: -100, y: 700, width: 400, height: 300), inPage: page))
        #expect(z.isValid)
        #expect(abs(z.x) < 1e-9 && abs(z.y - 700.0 / 800) < 1e-9)
        #expect(abs(z.width - 300.0 / 600) < 1e-9 && abs(z.height - 100.0 / 800) < 1e-9)
    }

    @Test func tooSmallOrOutsideIsRefused() {
        #expect(ZoneRect(rect: CGRect(x: 100, y: 100, width: 5, height: 200), inPage: page) == nil)
        #expect(ZoneRect(rect: CGRect(x: 100, y: 100, width: 200, height: 5), inPage: page) == nil)
        #expect(ZoneRect(rect: CGRect(x: 900, y: 100, width: 100, height: 100), inPage: page) == nil)
        #expect(ZoneRect(rect: CGRect(x: 0, y: 0, width: 100, height: 100), inPage: .zero) == nil)
    }

    @Test func theWholePageIsAZone() throws {
        let z = try #require(ZoneRect(rect: CGRect(origin: .zero, size: page), inPage: page))
        #expect(z == rect(0, 0, 1, 1) && z.isValid)
    }

    @Test func validityCatchesBadNumbers() {
        #expect(rect(0.1, 0.1, 0.5, 0.5).isValid)
        #expect(!rect(-0.2, 0.1, 0.5, 0.5).isValid)
        #expect(!rect(0.6, 0.1, 0.6, 0.5).isValid)
        #expect(!rect(0.1, 0.1, 0.001, 0.5).isValid)
        #expect(!rect(.nan, 0.1, 0.5, 0.5).isValid)
        #expect(!rect(0.1, .infinity, 0.5, 0.5).isValid)
    }

    @Test func theAspectIsThatOfTheMarkedPart() {
        let z = rect(0.1, 0.1, 0.5, 0.25)
        #expect(abs(z.aspect(inPage: page) - (0.25 * 800) / (0.5 * 600)) < 1e-9)
        // a landscape page shows the same fractions with another shape
        #expect(abs(z.aspect(inPage: CGSize(width: 800, height: 600)) - (0.25 * 600) / (0.5 * 800)) < 1e-9)
    }

    // MARK: badge

    @Test func theBadgeSitsInsideTheTopRight() {
        let zone = CGRect(x: 50, y: 100, width: 400, height: 200)
        let b = ZoneGeometry.badge(in: zone)
        #expect(zone.contains(b))
        #expect(b.maxX > zone.maxX - 10 && b.minY < zone.minY + 10)
        #expect(b.width == ZoneGeometry.badgeSide && b.width == b.height)
    }

    @Test func aSmallZoneGetsASmallBadge() {
        let tiny = CGRect(x: 10, y: 10, width: 30, height: 24)
        let b = ZoneGeometry.badge(in: tiny)
        #expect(b.width >= 14 && b.width <= 14.0001)
        #expect(ZoneGeometry.badge(in: CGRect(x: 10, y: 10, width: 60, height: 50)).width == 25)
    }

    @Test func theHitAreaIsLargerThanTheBadge() {
        let zone = CGRect(x: 50, y: 100, width: 400, height: 200)
        let b = ZoneGeometry.badge(in: zone), h = ZoneGeometry.hitArea(in: zone)
        #expect(h.contains(b))
        #expect(abs(h.width - (b.width + 2 * ZoneGeometry.hitPadding)) < 1e-9)
        #expect(!h.contains(CGPoint(x: zone.minX + 5, y: zone.maxY - 5)))
    }

    @Test func aTapOnABadgeFindsItsZone() {
        var l = ZoneList()
        let a = l.add(page: 0, rect: rect(0.1, 0.1, 0.6, 0.2))
        let b = l.add(page: 0, rect: rect(0.1, 0.5, 0.6, 0.2))
        let c = l.add(page: 1, rect: rect(0.1, 0.1, 0.6, 0.2))
        func centre(_ z: Zone) -> CGPoint {
            let badge = ZoneGeometry.badge(in: z.rect.rect(inPage: page)); return CGPoint(x: badge.midX, y: badge.midY)
        }
        #expect(l.badgeHit(onPage: 0, at: centre(a), pageSize: page)?.id == a.id)
        #expect(l.badgeHit(onPage: 0, at: centre(b), pageSize: page)?.id == b.id)
        #expect(l.badgeHit(onPage: 1, at: centre(c), pageSize: page)?.id == c.id)
        // the same spot on the wrong page, or on the zone's body away from its badge, is no hit
        #expect(l.badgeHit(onPage: 2, at: centre(a), pageSize: page) == nil)
        #expect(l.badgeHit(onPage: 0, at: CGPoint(x: 100, y: 130), pageSize: page) == nil)
        // a finger near the badge still counts
        let near = CGPoint(x: centre(a).x - 25, y: centre(a).y + 25)
        #expect(l.badgeHit(onPage: 0, at: near, pageSize: page)?.id == a.id)
    }

    @Test func overlappingBadgesGoToTheNearestOne() {
        var l = ZoneList()
        // two zones that end at nearly the same corner
        let outer = l.add(page: 0, rect: rect(0.1, 0.1, 0.8, 0.5))
        let inner = l.add(page: 0, rect: rect(0.2, 0.15, 0.68, 0.3))
        let bo = ZoneGeometry.badge(in: outer.rect.rect(inPage: page)), bi = ZoneGeometry.badge(in: inner.rect.rect(inPage: page))
        #expect(l.badgeHit(onPage: 0, at: CGPoint(x: bo.midX, y: bo.midY), pageSize: page)?.id == outer.id)
        #expect(l.badgeHit(onPage: 0, at: CGPoint(x: bi.midX, y: bi.midY), pageSize: page)?.id == inner.id)
    }

    // MARK: writing page layout

    @Test func theCopiedPartFillsTheWidthInsideTheMargin() {
        let f = ZoneLayout.clipFrame(width: 500, aspect: 0.5)
        let m = ZoneLayout.margin * 0.5
        #expect(abs(f.minX - m) < 1e-9 && abs(f.minY - m) < 1e-9)
        #expect(abs(f.width - (500 - 2 * m)) < 1e-9 && abs(f.height - f.width * 0.5) < 1e-9)
    }

    @Test func strangeAspectsAreKeptInRange() {
        #expect(ZoneLayout.clipFrame(width: 500, aspect: 0).height > 0)
        #expect(ZoneLayout.clipFrame(width: 500, aspect: .nan).height > 0)
        #expect(ZoneLayout.clipFrame(width: 500, aspect: 80).height <= ZoneLayout.clipFrame(width: 500, aspect: 5).height + 1e-9)
        #expect(ZoneLayout.clipFrame(width: 0, aspect: 1).width >= 1)
    }

    @Test func thePageAlwaysHasAScreenOfFreeSpaceUnderTheCopiedPart() {
        let h = ZoneLayout.contentHeight(clipBottom: 300, inkBottom: 0, viewport: 800)
        #expect(h >= 1100 && h < 1100 + ZoneLayout.step)
    }

    @Test func thePageGrowsAsTheUserWritesDown() {
        let a = ZoneLayout.contentHeight(clipBottom: 300, inkBottom: 400, viewport: 800)
        let b = ZoneLayout.contentHeight(clipBottom: 300, inkBottom: 2000, viewport: 800)
        let c = ZoneLayout.contentHeight(clipBottom: 300, inkBottom: 6000, viewport: 800)
        #expect(a == ZoneLayout.contentHeight(clipBottom: 300, inkBottom: 0, viewport: 800))
        #expect(b >= 2000 + 800 * 0.6 && c >= 6000 + 800 * 0.6 && b < c)
        #expect(b.truncatingRemainder(dividingBy: ZoneLayout.step) == 0)
    }

    @Test func thePageHasALimit() {
        #expect(ZoneLayout.contentHeight(clipBottom: 300, inkBottom: 90_000, viewport: 800) == ZoneLayout.maxContentHeight)
        #expect(ZoneLayout.contentHeight(clipBottom: 300, inkBottom: .infinity, viewport: 800) >= 1100)
        #expect(ZoneLayout.contentHeight(clipBottom: 300, inkBottom: .nan, viewport: -5) >= 300)
    }

    @Test func theScaleIsRelativeToTheLogicalWidth() {
        #expect(ZoneLayout.scale(forWidth: 1000) == 1)
        #expect(ZoneLayout.scale(forWidth: 500) == 0.5)
        #expect(ZoneLayout.scale(forWidth: 0) == 1)
    }

    // MARK: list

    @Test func zonesStayInReadingOrder() {
        var l = ZoneList()
        let c = l.add(page: 2, rect: rect(0.1, 0.1, 0.5, 0.2))
        let a = l.add(page: 0, rect: rect(0.1, 0.6, 0.5, 0.2))
        let b = l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        let d = l.add(page: 0, rect: rect(0.1, 0.3, 0.5, 0.2))
        #expect(l.zones.map(\.id) == [b.id, d.id, a.id, c.id])
        #expect(l.number(of: b.id) == 1 && l.number(of: c.id) == 4)
        #expect(l.number(of: "nope") == nil)
    }

    @Test func sideBySideZonesAtTheSameHeightGoLeftToRight() {
        var l = ZoneList()
        let right = l.add(page: 0, rect: rect(0.55, 0.2, 0.4, 0.2))
        let left = l.add(page: 0, rect: rect(0.05, 0.2, 0.4, 0.2))
        #expect(l.zones.map(\.id) == [left.id, right.id])
    }

    @Test func idsAreSafeAsFileNamesAndUnique() {
        var l = ZoneList()
        for i in 0..<300 { l.add(page: i % 7, rect: rect(0.1, Double(i % 10) / 20, 0.5, 0.04)) }
        #expect(Set(l.zones.map(\.id)).count == 300)
        #expect(l.zones.allSatisfy { InkStore.isValid(key: $0.id) })
    }

    @Test func aZoneCanBeRenamedAndFallsBackToItsNumber() {
        var l = ZoneList()
        let a = l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        let b = l.add(page: 0, rect: rect(0.1, 0.5, 0.5, 0.2))
        #expect(l.displayTitle(of: a) == "Zone 1" && l.displayTitle(of: b) == "Zone 2")
        l.rename(id: b.id, to: "  Question 7(b)  ")
        #expect(l.zone(id: b.id)?.title == "Question 7(b)")
        #expect(l.displayTitle(of: l.zone(id: b.id)!) == "Question 7(b)")
        l.rename(id: b.id, to: "   ")
        #expect(l.displayTitle(of: l.zone(id: b.id)!) == "Zone 2")
        l.rename(id: b.id, to: String(repeating: "x", count: 500))
        #expect(l.zone(id: b.id)?.title.count == ZoneList.maxTitle)
        l.rename(id: "nope", to: "x")
        #expect(l.zones.count == 2)
    }

    @Test func removingAZoneRenumbersTheRest() {
        var l = ZoneList()
        let a = l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        let b = l.add(page: 0, rect: rect(0.1, 0.4, 0.5, 0.2))
        let c = l.add(page: 0, rect: rect(0.1, 0.7, 0.5, 0.2))
        #expect(l.remove(id: b.id)?.id == b.id)
        #expect(l.remove(id: b.id) == nil)
        #expect(l.number(of: c.id) == 2 && l.number(of: a.id) == 1)
        #expect(l.displayTitle(of: c) == "Zone 2")
    }

    @Test func nextAndPreviousFollowTheOrder() {
        var l = ZoneList()
        let a = l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        let b = l.add(page: 0, rect: rect(0.1, 0.4, 0.5, 0.2))
        let c = l.add(page: 1, rect: rect(0.1, 0.1, 0.5, 0.2))
        #expect(l.next(after: a.id)?.id == b.id && l.next(after: b.id)?.id == c.id && l.next(after: c.id) == nil)
        #expect(l.previous(before: c.id)?.id == b.id && l.previous(before: a.id) == nil)
        #expect(l.next(after: "nope") == nil && l.previous(before: "nope") == nil)
    }

    @Test func zonesOnAPage() {
        var l = ZoneList()
        l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        l.add(page: 3, rect: rect(0.1, 0.1, 0.5, 0.2))
        l.add(page: 3, rect: rect(0.1, 0.5, 0.5, 0.2))
        #expect(l.zones(onPage: 3).count == 2 && l.zones(onPage: 0).count == 1 && l.zones(onPage: 9).isEmpty)
    }

    @Test func aNegativePageIsMovedToTheFirst() {
        var l = ZoneList()
        let z = l.add(page: -4, rect: rect(0.1, 0.1, 0.5, 0.2))
        #expect(z.page == 0)
    }

    // MARK: store

    @Test func theListSurvivesSavingAndLoading() throws {
        let s = store(), book = UUID()
        var l = ZoneList()
        let a = l.add(page: 4, rect: rect(0.1, 0.2, 0.7, 0.3), title: "Q1", now: Date(timeIntervalSince1970: 5_000))
        l.add(page: 1, rect: rect(0.0, 0.0, 1.0, 0.5))
        try s.save(l, bookID: book)
        let back = s.load(bookID: book)
        #expect(back == l)
        #expect(back.zone(id: a.id)?.title == "Q1")
        #expect(s.load(bookID: UUID()).zones.isEmpty)
    }

    @Test func savingAnEmptyListRemovesTheFile() throws {
        let s = store(), book = UUID()
        var l = ZoneList()
        let z = l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        try s.save(l, bookID: book)
        #expect(!s.load(bookID: book).zones.isEmpty)
        l.remove(id: z.id)
        try s.save(l, bookID: book)
        #expect(s.load(bookID: book).zones.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: s.root.appendingPathComponent(book.uuidString + ".json").path))
    }

    @Test func aDamagedFileGivesAnEmptyList() throws {
        let s = store(), book = UUID()
        try FileManager.default.createDirectory(at: s.root, withIntermediateDirectories: true)
        try Data("not json {".utf8).write(to: s.root.appendingPathComponent(book.uuidString + ".json"))
        #expect(s.load(bookID: book).zones.isEmpty)
    }

    @Test func badZonesInAFileAreDropped() throws {
        let s = store(), book = UUID()
        let json = """
        {"zones":[
          {"id":"zaaaa0001","page":0,"rect":{"x":0.1,"y":0.1,"width":0.5,"height":0.2},"title":"ok","createdAt":0},
          {"id":"../evil","page":0,"rect":{"x":0.1,"y":0.1,"width":0.5,"height":0.2},"title":"path","createdAt":0},
          {"id":"zaaaa0002","page":-1,"rect":{"x":0.1,"y":0.1,"width":0.5,"height":0.2},"title":"page","createdAt":0},
          {"id":"zaaaa0003","page":0,"rect":{"x":0.8,"y":0.1,"width":0.5,"height":0.2},"title":"outside","createdAt":0},
          {"id":"zaaaa0001","page":1,"rect":{"x":0.1,"y":0.1,"width":0.5,"height":0.2},"title":"again","createdAt":0},
          {"id":"zaaaa0004","page":0,"rect":{"x":0.1,"y":0.5,"width":0.5,"height":0.2},"title":"second","createdAt":0}
        ]}
        """
        try FileManager.default.createDirectory(at: s.root, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: s.root.appendingPathComponent(book.uuidString + ".json"))
        let l = s.load(bookID: book)
        #expect(l.zones.map(\.id) == ["zaaaa0001", "zaaaa0004"])
        #expect(l.zones.first?.title == "ok")
    }

    @Test func writingIsKeptPerZoneAndApartFromTheList() throws {
        let s = store(), book = UUID()
        try s.saveWriting(InkPage(layout: "zone", drawing: Data([1, 2, 3])), bookID: book, zoneID: "zaaaa0001")
        try s.saveWriting(InkPage(layout: "zone", drawing: Data([9])), bookID: book, zoneID: "zaaaa0002")
        #expect(s.loadWriting(bookID: book, zoneID: "zaaaa0001")?.drawing == Data([1, 2, 3]))
        #expect(s.writtenIDs(bookID: book) == ["zaaaa0001", "zaaaa0002"])
        s.removeWriting(bookID: book, zoneID: "zaaaa0001")
        #expect(s.writtenIDs(bookID: book) == ["zaaaa0002"])
        #expect(s.loadWriting(bookID: book, zoneID: "zaaaa0001") == nil)
        #expect(s.writtenIDs(bookID: UUID()).isEmpty)
    }

    @Test func writingToAnUnsafeIDIsRefused() {
        let s = store()
        var refused = false
        do { try s.saveWriting(InkPage(layout: "zone", drawing: Data([1])), bookID: UUID(), zoneID: "../x") } catch { refused = true }
        #expect(refused)
    }

    @Test func removingABookRemovesItsZonesAndWriting() throws {
        let s = store(), a = UUID(), b = UUID()
        var l = ZoneList()
        let z = l.add(page: 0, rect: rect(0.1, 0.1, 0.5, 0.2))
        try s.save(l, bookID: a)
        try s.save(l, bookID: b)
        try s.saveWriting(InkPage(layout: "zone", drawing: Data([1])), bookID: a, zoneID: z.id)
        try s.saveWriting(InkPage(layout: "zone", drawing: Data([1])), bookID: b, zoneID: z.id)
        s.removeAll(bookID: a)
        #expect(s.load(bookID: a).zones.isEmpty && s.writtenIDs(bookID: a).isEmpty)
        #expect(s.load(bookID: b).zones.count == 1 && s.writtenIDs(bookID: b) == [z.id])
    }

    @Test func zoneWritingIsNotCountedAsInkOnTheFile() throws {
        let s = store(), book = UUID()
        try s.saveWriting(InkPage(layout: "zone", drawing: Data([1])), bookID: book, zoneID: "zaaaa0001")
        let ordinary = InkStore(root: s.ink.root.deletingLastPathComponent().appendingPathComponent("Ink"))
        #expect(!ordinary.hasInk(bookID: book))
        ordinary.removeAll(bookID: book)
        #expect(s.writtenIDs(bookID: book) == ["zaaaa0001"])
    }
}
