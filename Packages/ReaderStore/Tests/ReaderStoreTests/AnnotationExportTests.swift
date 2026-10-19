import Testing
import Foundation
@testable import ReaderStore

@Suite struct AnnotationExportTests {
    @Test func exportContainsHighlightNoteAndBookmark() {
        let now = Date()
        let md = AnnotationExport.markdown(title: "Sample", author: "A. Writer", records: [
            AnnotationRecord(kind: .highlight, label: "Chapter 2", quote: "A line worth keeping", note: "", createdAt: now),
            AnnotationRecord(kind: .note, label: "Chapter 3", quote: "Other line", note: "My thought", createdAt: now),
            AnnotationRecord(kind: .bookmark, label: "Page 9", quote: "", note: "", createdAt: now),
        ])
        #expect(md.hasPrefix("# Sample\n\nA. Writer"))
        #expect(md.contains("## Highlights\n\n> A line worth keeping\n\n(Chapter 2)"))
        #expect(md.contains("## Notes"))
        #expect(md.contains("My thought"))
        #expect(md.contains("## Bookmarks\n\n- Page 9"))
    }

    @Test func emptyHasOnlyTitle() {
        #expect(AnnotationExport.markdown(title: "T", author: "", records: []) == "# T\n")
    }

    @Test func highlightColourShowsInTheLabelOnlyWhenGiven() {
        let now = Date()
        let md = AnnotationExport.markdown(title: "T", author: "", records: [
            AnnotationRecord(kind: .highlight, label: "Chapter 1", quote: "Plain", note: "", createdAt: now),
            AnnotationRecord(kind: .highlight, label: "Chapter 2", quote: "Coloured", note: "", createdAt: now, color: "yellow"),
        ])
        #expect(md.contains("(Chapter 1)"))
        #expect(md.contains("(Chapter 2, yellow)"))
    }

    @Test func highlightColoursResolveAndDefaultToGreen() {
        #expect(HighlightColor.resolve("pink") == .pink)
        #expect(HighlightColor.resolve("nonsense") == .green)
        #expect(BookAnnotation(bookID: UUID(), kind: .highlight, locator: "x").color == .green)
        #expect(BookAnnotation(bookID: UUID(), kind: .highlight, locator: "x", color: .blue).colorRaw == "blue")
    }

    @Test func storeStaysInTheAppsOwnFolder() {
        let url = StoreLocation.defaultStoreURL()
        #expect(url.lastPathComponent == "default.store")
        #expect(url.path.contains("Application Support"))
        #expect(!url.path.contains("AppGroup"))
    }
}
