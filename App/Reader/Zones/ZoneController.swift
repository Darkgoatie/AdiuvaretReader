import SwiftUI
import PDFKit
import ReaderStore

/// The zones of the open PDF: the list, which of them have writing in them, whether the user is marking a new one, and which one is open.
/// The data itself lives in ReaderStore (`ZoneStore`), in files apart from the library and from the ink on the file.
@MainActor
@Observable
final class ZoneController {
    let bookID: UUID
    private(set) var list = ZoneList()
    private(set) var written: Set<String> = []
    /// Counts every change, so the views that draw badges know to redraw.
    private(set) var revision = 0
    /// The next one-finger drag on the PDF marks a zone.
    var marking = false
    /// The zone whose writing page is shown, if any.
    var opened: Zone?
    var showList = false

    @ObservationIgnored let store = ZoneStore.standard()
    @ObservationIgnored var toast: ((String) -> Void)?
    /// Scrolls the PDF to a page, set by the PDF model.
    @ObservationIgnored var jumpTo: ((Int) -> Void)?

    init(bookID: UUID) {
        self.bookID = bookID
        reload()
    }

    func reload() {
        list = store.load(bookID: bookID)
        written = store.writtenIDs(bookID: bookID)
        revision += 1
    }

    var hasZones: Bool { !list.zones.isEmpty }

    func title(of zone: Zone) -> String { list.displayTitle(of: zone) }

    /// A new zone opens at once, so the user can start writing.
    @discardableResult
    func add(page: Int, rect: ZoneRect) -> Zone {
        let zone = list.add(page: page, rect: rect)
        persist()
        marking = false
        opened = zone
        return zone
    }

    func rename(_ zone: Zone, to title: String) {
        list.rename(id: zone.id, to: title)
        persist()
    }

    /// Removes the zone and what was written in it. When its writing page is open, that closes and the PDF shows the page it came from.
    func delete(_ zone: Zone) {
        let wasOpen = opened?.id == zone.id
        list.remove(id: zone.id)
        store.removeWriting(bookID: bookID, zoneID: zone.id)
        written.remove(zone.id)
        persist()
        if wasOpen { opened = nil; jumpTo?(zone.page) }
    }

    func open(_ zone: Zone) {
        marking = false
        opened = zone
    }

    /// Leaves the writing page and shows the PDF at the page the zone came from, so the user can go on to the next question.
    func close() {
        guard let zone = opened else { return }
        opened = nil
        jumpTo?(zone.page)
    }

    func noteWriting(zoneID: String, has: Bool) {
        let before = written
        if has { written.insert(zoneID) } else { written.remove(zoneID) }
        if written != before { revision += 1 }
    }

    private func persist() {
        try? store.save(list, bookID: bookID)
        revision += 1
    }
}
