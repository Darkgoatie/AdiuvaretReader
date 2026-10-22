import Testing
import Foundation
@testable import ReaderStore

@Suite struct InkStoreTests {
    private func store() -> InkStore {
        InkStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("ink-" + UUID().uuidString, isDirectory: true))
    }

    @Test func savesAndLoadsAPage() throws {
        let s = store(), id = UUID()
        let page = InkPage(layout: "c0", drawing: Data([1, 2, 3, 250]), updatedAt: Date(timeIntervalSince1970: 1_000))
        try s.save(page, bookID: id, key: "c0")
        #expect(s.load(bookID: id, key: "c0") == page)
        #expect(s.load(bookID: id, key: "c1") == nil)
        #expect(s.load(bookID: UUID(), key: "c0") == nil)
    }

    @Test func savingAgainReplacesThePage() throws {
        let s = store(), id = UUID()
        try s.save(InkPage(layout: "a", drawing: Data([1])), bookID: id, key: "p3")
        try s.save(InkPage(layout: "b", drawing: Data([9, 9])), bookID: id, key: "p3")
        #expect(s.load(bookID: id, key: "p3")?.drawing == Data([9, 9]))
        #expect(s.keys(bookID: id) == ["p3"])
    }

    @Test func removingAPageKeepsTheOthers() throws {
        let s = store(), id = UUID()
        for k in ["p1", "p2", "p10"] { try s.save(InkPage(layout: "pdf", drawing: Data([1])), bookID: id, key: k) }
        s.remove(bookID: id, key: "p2")
        #expect(s.keys(bookID: id) == ["p1", "p10"])
        #expect(s.hasInk(bookID: id))
    }

    @Test func removingABookRemovesAllItsInkAndNothingElse() throws {
        let s = store(), a = UUID(), b = UUID()
        try s.save(InkPage(layout: "pdf", drawing: Data([1])), bookID: a, key: "p1")
        try s.save(InkPage(layout: "pdf", drawing: Data([2])), bookID: b, key: "p1")
        s.removeAll(bookID: a)
        #expect(!s.hasInk(bookID: a))
        #expect(s.load(bookID: b, key: "p1")?.drawing == Data([2]))
    }

    @Test func keysCannotEscapeTheBooksFolder() {
        let s = store(), id = UUID()
        for bad in ["", "../x", "a/b", "a\\b", "p 1", ".hidden", "p1.ink", String(repeating: "a", count: 41)] {
            #expect(!InkStore.isValid(key: bad), Comment(rawValue: bad))
            #expect(throws: InkStoreError.badKey) { try s.save(InkPage(layout: "x", drawing: Data()), bookID: id, key: bad) }
            #expect(s.load(bookID: id, key: bad) == nil)
        }
        for good in ["p0", "c12", "chapter-3", "a_b", "c3-9f2a61bc"] { #expect(InkStore.isValid(key: good), Comment(rawValue: good)) }
    }

    @Test func aMissingBookHasNoInk() {
        let s = store()
        #expect(s.keys(bookID: UUID()).isEmpty)
        #expect(!s.hasInk(bookID: UUID()))
    }

    @Test func aDamagedFileReadsAsNoInk() throws {
        let s = store(), id = UUID()
        try s.save(InkPage(layout: "x", drawing: Data([1])), bookID: id, key: "c0")
        let url = s.root.appendingPathComponent(id.uuidString).appendingPathComponent("c0.ink")
        try Data("not json".utf8).write(to: url)
        #expect(s.load(bookID: id, key: "c0") == nil)
    }

    @Test func signatureChangesWithTheTextLayout() {
        let base = InkLayout.signature(font: "sans", fontSize: 18, lineSpacing: 1.5, margin: 0.5, width: 390)
        #expect(base == InkLayout.signature(font: "sans", fontSize: 18, lineSpacing: 1.5, margin: 0.5, width: 390.2))
        #expect(base != InkLayout.signature(font: "serif", fontSize: 18, lineSpacing: 1.5, margin: 0.5, width: 390))
        #expect(base != InkLayout.signature(font: "sans", fontSize: 19, lineSpacing: 1.5, margin: 0.5, width: 390))
        #expect(base != InkLayout.signature(font: "sans", fontSize: 18, lineSpacing: 1.6, margin: 0.5, width: 390))
        #expect(base != InkLayout.signature(font: "sans", fontSize: 18, lineSpacing: 1.5, margin: 0.6, width: 390))
        #expect(base != InkLayout.signature(font: "sans", fontSize: 18, lineSpacing: 1.5, margin: 0.5, width: 820))
    }

    @Test func eachLayoutGetsItsOwnValidKeyAndKeepsTheOthers() throws {
        let a = InkLayout.key(page: "c3", signature: "v1|sans|18.0|1.50|0.50|390")
        let b = InkLayout.key(page: "c3", signature: "v1|sans|20.0|1.50|0.50|390")
        #expect(a != b)
        #expect(a == InkLayout.key(page: "c3", signature: "v1|sans|18.0|1.50|0.50|390"))
        #expect(a.hasPrefix("c3-") && a.count == 11)
        #expect(InkStore.isValid(key: a) && InkStore.isValid(key: b))
        let s = store(), id = UUID()
        try s.save(InkPage(layout: a, drawing: Data([1])), bookID: id, key: a)
        try s.save(InkPage(layout: b, drawing: Data([2])), bookID: id, key: b)
        #expect(s.load(bookID: id, key: a)?.drawing == Data([1]))
        #expect(s.load(bookID: id, key: b)?.drawing == Data([2]))
        #expect(s.keys(bookID: id).filter { $0.hasPrefix("c3-") }.count == 2)
    }
}
