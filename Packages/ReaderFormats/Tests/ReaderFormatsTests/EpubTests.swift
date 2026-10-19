import Testing
import Foundation
@testable import ReaderFormats

@Suite struct EpubTests {
    private func sampleEpub() throws -> URL {
        var z = ZipBuilder()
        z.add("mimetype", "application/epub+zip")
        z.add("META-INF/container.xml", """
        <?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
        """, deflate: true)
        z.add("OEBPS/content.opf", """
        <?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Sample Book</dc:title><dc:creator>A. Writer</dc:creator></metadata>
        <manifest><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/><item id="c1" href="ch%201.xhtml" media-type="application/xhtml+xml"/><item id="c2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/><item id="img" href="a.png" media-type="image/png"/></manifest>
        <spine toc="ncx"><itemref idref="c1"/><itemref idref="c2"/></spine></package>
        """, deflate: true)
        z.add("OEBPS/toc.ncx", """
        <?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap><navPoint id="a"><navLabel><text>First</text></navLabel><content src="ch%201.xhtml"/></navPoint><navPoint id="b"><navLabel><text>Second</text></navLabel><content src="text/ch2.xhtml#x"/></navPoint></navMap></ncx>
        """)
        z.add("OEBPS/ch 1.xhtml", "<html><body><p>Hello &amp; welcome</p></body></html>", deflate: true)
        z.add("OEBPS/text/ch2.xhtml", "<html><body><p>Second chapter</p></body></html>")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
        try z.build().write(to: url)
        return url
    }

    @Test func zipReadsStoredAndDeflated() throws {
        var z = ZipBuilder()
        z.add("a.txt", "stored text")
        z.add("dir/b.txt", String(repeating: "deflate me ", count: 100), deflate: true)
        let zip = try ZipArchive(data: z.build())
        #expect(zip.entries.count == 2)
        #expect(String(data: try zip.data(named: "a.txt")!, encoding: .utf8) == "stored text")
        #expect(String(data: try zip.data(named: "dir/b.txt")!, encoding: .utf8) == String(repeating: "deflate me ", count: 100))
        #expect(try zip.data(named: "missing") == nil)
    }

    @Test func zipRejectsGarbage() {
        #expect(throws: ZipError.notAnArchive) { try ZipArchive(data: Data("not a zip file at all, just text".utf8)) }
    }

    @Test func zipRejectsPathTraversal() throws {
        var z = ZipBuilder()
        z.add("../evil.txt", "x")
        let zip = try ZipArchive(data: z.build())
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(throws: ZipError.unsafePath) { try zip.extractAll(to: dir) }
    }

    @Test func opensEpubWithTocAndSpine() throws {
        let file = try sampleEpub()
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let book = try EpubBook.open(at: file, cache: cache)
        #expect(book.title == "Sample Book")
        #expect(book.author == "A. Writer")
        #expect(book.spine.map(\.path) == ["OEBPS/ch 1.xhtml", "OEBPS/text/ch2.xhtml"])
        #expect(book.toc.map(\.title) == ["First", "Second"])
        #expect(book.toc.map(\.spineIndex) == [0, 1])
        let html = try String(contentsOf: book.chapterURL(0), encoding: .utf8)
        #expect(HTMLText.plain(from: html) == "Hello & welcome")
        let again = try EpubBook.open(at: file, cache: cache)
        #expect(again.spine.count == 2)
    }

    @Test func readsMetadataOnly() throws {
        let file = try sampleEpub()
        let md = EpubBook.metadata(at: file)
        #expect(md?.title == "Sample Book")
        #expect(md?.author == "A. Writer")
        #expect(EpubBook.metadata(at: URL(fileURLWithPath: "/nonexistent.epub")) == nil)
    }

    @Test func cssCarriesSettings() {
        let css = EpubCSS.make(text: "#111111", ground: "#FAF7F2", link: "#0B7551", fontStack: "serif", fontSize: 21.4, lineHeight: 1.6, sidePadding: 30, fontFileURL: "file:///f.ttf")
        #expect(css.contains("font-size:21px"))
        #expect(css.contains("line-height:1.6"))
        #expect(css.contains("#FAF7F2"))
        #expect(css.contains("url('file:///f.ttf')"))
        #expect(!EpubCSS.make(text: "#1", ground: "#2", link: "#3", fontStack: "s", fontSize: 18, lineHeight: 1.5, sidePadding: 20, fontFileURL: nil).contains("@font-face"))
    }

    @Test func labels() {
        #expect(ReadingPosition.chapter(index: 2, fraction: 0).label() == "Chapter 3")
        #expect(ReadingPosition.page(0).label() == "Page 1")
        #expect(ReadingPosition.block(39).label(isCode: true) == "Line 40")
        #expect(ReadingPosition.block(3).label() == "Section 4")
    }

    @Test func nearPositions() {
        #expect(ReadingPosition.chapter(index: 2, fraction: 0.50).isNear(.chapter(index: 2, fraction: 0.52)))
        #expect(!ReadingPosition.chapter(index: 2, fraction: 0.5).isNear(.chapter(index: 3, fraction: 0.5)))
        #expect(ReadingPosition.page(4).isNear(.page(4)))
        #expect(!ReadingPosition.page(4).isNear(.block(4)))
    }

    @Test func htmlTextStripsMarkup() {
        let html = "<html><head><style>p{color:red}</style></head><body><h1>Title</h1><p>One &lt;b&gt; &#65;</p><script>x()</script><p>Two</p></body></html>"
        #expect(HTMLText.plain(from: html) == "Title\nOne <b> A\nTwo")
    }

    @Test func positionRoundTrip() {
        for p in [ReadingPosition.chapter(index: 3, fraction: 0.5), .page(12), .block(7)] {
            #expect(ReadingPosition(encoded: p.encoded) == p)
        }
        #expect(ReadingPosition(encoded: "junk") == nil)
        #expect(abs(ReadingPosition.overall(chapter: 1, fraction: 0.5, count: 3) - 0.5) < 0.0001)
    }
}
