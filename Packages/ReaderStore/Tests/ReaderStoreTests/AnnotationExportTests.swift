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
}
