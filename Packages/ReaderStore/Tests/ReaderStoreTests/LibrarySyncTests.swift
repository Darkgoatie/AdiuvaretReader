import Testing
@testable import ReaderStore

@Suite struct LibrarySyncTests {
    private let canOpen: (String) -> Bool = { $0.hasSuffix(".epub") || $0.hasSuffix(".pdf") }

    @Test func addsOnlyNewOpenableFiles() {
        let plan = LibrarySync.plan(files: ["a.epub", "b.pdf", "c.png", "d/e.pdf"], books: [BookRef(path: "a.epub", missing: false)], trashedOriginals: [], canOpen: canOpen)
        #expect(plan.add == ["b.pdf", "d/e.pdf"])
        #expect(plan.delete.isEmpty)
    }

    @Test func trashedBooksAreKeptAsMissingThenRestored() {
        var plan = LibrarySync.plan(files: [], books: [BookRef(path: "a.epub", missing: false), BookRef(path: "dir/b.pdf", missing: false)],
                                    trashedOriginals: ["a.epub", "dir"], canOpen: canOpen)
        #expect(plan.markMissing == ["a.epub", "dir/b.pdf"])
        #expect(plan.delete.isEmpty)
        plan = LibrarySync.plan(files: ["a.epub"], books: [BookRef(path: "a.epub", missing: true)], trashedOriginals: [], canOpen: canOpen)
        #expect(plan.markPresent == ["a.epub"])
        #expect(plan.add.isEmpty)
    }

    @Test func goneFilesNotInTrashAreDeleted() {
        let plan = LibrarySync.plan(files: [], books: [BookRef(path: "x.epub", missing: true), BookRef(path: "y.pdf", missing: false)], trashedOriginals: [], canOpen: canOpen)
        #expect(plan.delete == ["x.epub", "y.pdf"])
    }

    @Test func rebaseFilesAndFolders() {
        #expect(LibrarySync.rebase("a.epub", from: "a.epub", to: "b.epub") == "b.epub")
        #expect(LibrarySync.rebase("dir/a.epub", from: "dir", to: "new/dir") == "new/dir/a.epub")
        #expect(LibrarySync.rebase("directory/a.epub", from: "dir", to: "x") == nil)
    }
}
