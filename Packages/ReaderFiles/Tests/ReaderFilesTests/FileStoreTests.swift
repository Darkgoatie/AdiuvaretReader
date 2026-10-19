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

    @Test func listsAllFolders() throws {
        let s = store()
        try s.createFolder(named: "B")
        try s.createFolder(named: "A")
        try s.createFolder(named: "C", in: "A")
        try write(s, "A/f.txt")
        #expect(s.allFolders() == ["A", "A/C", "B"])
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

    @Test func externalListAndCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: dir.appendingPathComponent("sub/b.txt"))
        try Data("x".utf8).write(to: dir.appendingPathComponent("a.txt"))
        let d = UserDefaults(suiteName: "test." + UUID().uuidString)!
        let ext = ExternalFolderStore(defaults: d, scoped: false)
        let folder = try ext.add(dir)
        #expect(ext.list(folder).map(\.name) == ["sub", "a.txt"])
        #expect(ext.list(folder, subpath: "sub").map(\.relativePath) == ["sub/b.txt"])
        #expect(ext.list(folder, subpath: "../x").isEmpty)
        let s = store()
        let copied = try ext.copy(folder, subpath: "sub/b.txt", into: s)
        #expect(copied == "b.txt")
        #expect(try String(contentsOf: s.resolve("b.txt"), encoding: .utf8) == "hello")
        #expect(throws: ExternalError.unsafePath) { try ext.copy(folder, subpath: "../a", into: s) }
    }

    @Test func scanFindsOnlyNewOpenableFiles() {
        let found = LibraryScan.unindexed(files: ["a.epub", "b.pdf", "c.exe", "d/e.txt"], known: ["a.epub"]) { $0.hasSuffix(".pdf") || $0.hasSuffix(".txt") }
        #expect(found == ["b.pdf", "d/e.txt"])
    }

    private func makeSource() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Reading")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub/deep"), withIntermediateDirectories: true)
        try Data("a".utf8).write(to: dir.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: dir.appendingPathComponent("sub/b.md"))
        try Data("c".utf8).write(to: dir.appendingPathComponent("sub/deep/c.pdf"))
        try Data("h".utf8).write(to: dir.appendingPathComponent(".DS_Store"))
        return dir
    }

    @Test func folderImportCopyKeepsOriginals() throws {
        let src = try makeSource()
        let s = store()
        let report = try FolderImport.run(source: src, into: s, move: false)
        #expect(report == FolderImportReport(destination: "Reading", imported: 3, removedFromSource: 0, failed: 0))
        #expect(Set(s.allFiles()) == ["Reading/a.txt", "Reading/sub/b.md", "Reading/sub/deep/c.pdf"])
        #expect(FileManager.default.fileExists(atPath: src.appendingPathComponent("a.txt").path))
        #expect(try String(contentsOf: s.resolve("Reading/sub/b.md"), encoding: .utf8) == "b")
    }

    @Test func folderImportMoveRemovesOriginalsAndEmptyFolders() throws {
        let src = try makeSource()
        let s = store()
        let report = try FolderImport.run(source: src, into: s, move: true)
        #expect(report.imported == 3 && report.removedFromSource == 3 && report.failed == 0)
        #expect(!FileManager.default.fileExists(atPath: src.appendingPathComponent("a.txt").path))
        #expect(!FileManager.default.fileExists(atPath: src.appendingPathComponent("sub").path))
        #expect(FileManager.default.fileExists(atPath: src.path))
        #expect(s.allFiles().count == 3)
    }

    @Test func folderImportNeverOverwritesAnExistingFolder() throws {
        let s = store()
        _ = try FolderImport.run(source: try makeSource(), into: s, move: false)
        let second = try FolderImport.run(source: try makeSource(), into: s, move: false)
        #expect(second.destination == "Reading 2")
        #expect(s.allFiles().count == 6)
    }

    @Test func readerLinksRoundTrip() throws {
        let url = try #require(ReaderLink.url(path: "Notes & More/Chapter 1.md", fragment: "Big Heading"))
        #expect(url.scheme == "adiuvaretreader")
        let parsed = try #require(ReaderLink.parse(url))
        #expect(parsed.path == "Notes & More/Chapter 1.md")
        #expect(parsed.fragment == "Big Heading")
        #expect(ReaderLink.parse(try #require(ReaderLink.url(path: "a.pdf")))?.fragment == nil)
    }

    @Test func readerLinksRejectBadPaths() {
        #expect(ReaderLink.url(path: "") == nil)
        #expect(ReaderLink.url(path: "../secret") == nil)
        #expect(ReaderLink.url(path: "a/../../b") == nil)
        #expect(ReaderLink.url(path: "/etc/passwd") == nil)
        #expect(ReaderLink.parse(URL(string: "https://example.com/open?path=a")!) == nil)
        #expect(ReaderLink.parse(URL(string: "adiuvaretreader://open?path=../x")!) == nil)
        #expect(ReaderLink.parse(URL(string: "adiuvaretreader://other?path=a")!) == nil)
        #expect(ReaderLink.parse(URL(string: "adiuvaretreader://open")!) == nil)
    }
}
