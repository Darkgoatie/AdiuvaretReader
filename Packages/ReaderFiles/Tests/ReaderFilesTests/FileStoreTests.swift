import Testing
import Foundation
@testable import ReaderFiles

@Suite struct FileStoreTests {
    private func store() -> FileStore {
        FileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func write(_ s: FileStore, _ path: String, _ text: String = "x") throws {
        let url = try s.resolve(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func createListRename() throws {
        let s = store()
        let a = try s.createFolder(named: "Books")
        #expect(a == "Books")
        try write(s, "Books/one.txt")
        #expect(try s.list("Books").map(\.name) == ["one.txt"])
        #expect(try s.rename("Books/one.txt", to: "two.txt") == "Books/two.txt")
        #expect(throws: FileStoreError.nameCollision) { try s.createFolder(named: "Books") }
        try write(s, "Books/three.txt")
        #expect(throws: FileStoreError.nameCollision) { try s.rename("Books/three.txt", to: "two.txt") }
        #expect(throws: FileStoreError.invalidName) { try s.rename("Books/two.txt", to: "a/b") }
        #expect(throws: FileStoreError.invalidName) { try s.createFolder(named: "  ") }
    }

    @Test func moveAndCopyNeverOverwrite() throws {
        let s = store()
        try s.createFolder(named: "A")
        try s.createFolder(named: "B")
        try write(s, "A/f.txt", "from A")
        try write(s, "B/f.txt", "from B")
        let moved = try s.move("A/f.txt", toFolder: "B")
        #expect(moved == "B/f 2.txt")
        #expect(try String(contentsOf: s.resolve("B/f.txt"), encoding: .utf8) == "from B")
        let copied = try s.copy("B/f.txt", toFolder: "A")
        #expect(copied == "A/f.txt")
        #expect(FileManager.default.fileExists(atPath: try s.resolve("B/f.txt").path))
    }

    @Test func moveIntoOwnSubfolderIsRejected() throws {
        let s = store()
        try s.createFolder(named: "A")
        try s.createFolder(named: "B", in: "A")
        #expect(throws: FileStoreError.moveIntoSelf) { try s.move("A", toFolder: "A/B") }
        #expect(throws: FileStoreError.moveIntoSelf) { try s.move("A", toFolder: "A") }
        #expect(throws: FileStoreError.moveIntoSelf) { try s.copy("A", toFolder: "A/B") }
    }

    @Test func pathsCannotEscapeRoot() throws {
        let s = store()
        #expect(throws: FileStoreError.outsideRoot) { try s.resolve("../x") }
        #expect(throws: FileStoreError.outsideRoot) { try s.resolve("/etc/passwd") }
        #expect(throws: FileStoreError.outsideRoot) { try s.resolve("a/../../x") }
        #expect(throws: FileStoreError.outsideRoot) { try s.list("..") }
    }

    @Test func trashRestoreAndPurge() throws {
        let s = store()
        try s.createFolder(named: "A")
        try write(s, "A/doc.txt")
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        try s.trash("A/doc.txt", now: t0)
        #expect(try s.list("A").isEmpty)
        let trashed = s.recentlyDeleted()
        #expect(trashed.count == 1)
        #expect(trashed[0].originalPath == "A/doc.txt")
        #expect(try s.list("").map(\.name) == ["A"])
        #expect(try s.restore(trashed[0].id) == "A/doc.txt")
        #expect(s.recentlyDeleted().isEmpty)

        try s.trash("A/doc.txt", now: t0)
        #expect(s.purgeExpired(now: t0.addingTimeInterval(29 * 86_400)) == 0)
        #expect(s.purgeExpired(now: t0.addingTimeInterval(31 * 86_400)) == 1)
        #expect(s.recentlyDeleted().isEmpty)
    }

    @Test func restoreWhenFolderIsGoneGoesToRoot() throws {
        let s = store()
        try s.createFolder(named: "A")
        try write(s, "A/doc.txt")
        try s.trash("A/doc.txt")
        try s.trash("A")
        let doc = s.recentlyDeleted().first { $0.name == "doc.txt" }!
        #expect(try s.restore(doc.id) == "doc.txt")
    }

    @Test func searchSizeAndSort() throws {
        let s = store()
        try write(s, "Novels/Dune.epub", "12345")
        try write(s, "Novels/Emma.epub", "1234567890")
        try write(s, "notes.md", "abc")
        #expect(s.search("dune").map(\.relativePath) == ["Novels/Dune.epub"])
        #expect(s.search("novel").map(\.name) == ["Novels"])
        #expect(s.size(of: "Novels") == 15)
        #expect(Set(s.allFiles()) == ["Novels/Dune.epub", "Novels/Emma.epub", "notes.md"])
        #expect(try s.list("Novels", sort: .size).map(\.name) == ["Emma.epub", "Dune.epub"])
        #expect(try s.list("", sort: .name).first?.isDirectory == true)
        #expect(!s.allFiles().contains { $0.contains(FileStore.trashName) })
    }

    @Test func secondStoreSeesFileWrittenByFirst() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let a = FileStore(root: root)
        let b = FileStore(root: root)
        try write(a, "shared.pdf")
        #expect(try b.list().map(\.name) == ["shared.pdf"])
    }

    @Test func addCopyFromOutside() throws {
        let s = store()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try Data("hi".utf8).write(to: outside)
        let first = try s.addCopy(of: outside)
        let second = try s.addCopy(of: outside)
        #expect(first != second)
        #expect(s.allFiles().count == 2)
    }

    @Test func externalFolderBookmarkResolves() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: dir.appendingPathComponent("a.txt"))
        let d = UserDefaults(suiteName: "test." + UUID().uuidString)!
        let ext = ExternalFolderStore(defaults: d, scoped: false)
        let folder = try ext.add(dir)
        let again = ExternalFolderStore(defaults: d, scoped: false)
        #expect(again.folders.map(\.name) == [dir.lastPathComponent])
        let url = try #require(again.resolve(folder))
        #expect(again.contents(of: url).map(\.lastPathComponent) == ["a.txt"])
        again.remove(folder.id)
        #expect(again.folders.isEmpty)
    }

    @Test func scanFindsOnlyNewOpenableFiles() {
        let found = LibraryScan.unindexed(files: ["a.epub", "b.pdf", "c.exe", "d/e.txt"], known: ["a.epub"]) { $0.hasSuffix(".pdf") || $0.hasSuffix(".txt") }
        #expect(found == ["b.pdf", "d/e.txt"])
    }
}
