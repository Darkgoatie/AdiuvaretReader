import Testing
import Foundation
@testable import ReaderStore

@Suite struct LibraryFolderTests {
    private func makeFolder() throws -> (LibraryFolder, URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (LibraryFolder(root: tmp.appendingPathComponent("Library")), tmp)
    }

    @Test func detectsFormats() {
        #expect(BookFormat.detect(fileName: "a.EPUB") == .epub)
        #expect(BookFormat.detect(fileName: "a.pdf") == .pdf)
        #expect(BookFormat.detect(fileName: "a.md") == .markdown)
        #expect(BookFormat.detect(fileName: "main.rs") == .code)
        #expect(BookFormat.detect(fileName: "a.exe") == nil)
        #expect(BookFormat.detect(fileName: "noext") == nil)
    }

    @Test func importsThreeFilesAndKeepsCollisions() throws {
        let (folder, tmp) = try makeFolder()
        var paths: [String] = []
        for name in ["one.epub", "two.pdf", "three.txt"] {
            let src = tmp.appendingPathComponent(name)
            try Data("x".utf8).write(to: src)
            paths.append(try folder.importFile(at: src).relativePath)
        }
        #expect(paths == ["one.epub", "two.pdf", "three.txt"])
        let again = try folder.importFile(at: tmp.appendingPathComponent("one.epub"))
        #expect(again.relativePath == "one 2.epub")
        #expect(FileManager.default.fileExists(atPath: folder.url(for: "one.epub").path))
    }

    @Test func rejectsUnsupported() throws {
        let (folder, tmp) = try makeFolder()
        let src = tmp.appendingPathComponent("a.exe")
        try Data("x".utf8).write(to: src)
        #expect(throws: LibraryError.unsupported) { try folder.importFile(at: src) }
    }

    @Test func titleFromFileName() {
        #expect(LibraryFolder.title(fromFileName: "The_Hobbit.epub") == "The Hobbit")
    }
}
