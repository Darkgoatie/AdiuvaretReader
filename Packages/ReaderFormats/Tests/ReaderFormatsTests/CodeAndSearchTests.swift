import Testing
import Foundation
@testable import ReaderFormats

@Suite struct CodeAndSearchTests {
    @Test func detectsLanguage() {
        #expect(CodeLanguage.detect(fileName: "a.swift").name == "Swift")
        #expect(CodeLanguage.detect(fileName: "run", firstLine: "#!/usr/bin/env python3").name == "Python")
        #expect(CodeLanguage.detect(fileName: "notes.xyz").name == "Plain")
    }

    @Test func tokenizesSwift() {
        let src = "let x = 42 // answer\nprint(\"hi\")"
        let lines = CodeTokenizer.tokenize(src, language: CodeLanguage.detect(fileName: "a.swift"))
        #expect(lines.count == 2)
        #expect(lines[0].contains(CodeToken(kind: .keyword, text: "let")))
        #expect(lines[0].contains(CodeToken(kind: .number, text: "42")))
        #expect(lines[0].last == CodeToken(kind: .comment, text: "// answer"))
        #expect(lines[1].contains(CodeToken(kind: .string, text: "\"hi\"")))
    }

    @Test func blockCommentSpansLines() {
        let lines = CodeTokenizer.tokenize("a /* one\ntwo */ b", language: CodeLanguage.detect(fileName: "a.c"))
        #expect(lines[1].first == CodeToken(kind: .comment, text: "two */"))
        #expect(lines[1].last?.kind == .plain)
    }

    @Test func tokensRebuildSource() {
        let src = "fn main() {\n    let s = \"a\\\"b\"; // c\n}"
        let lines = CodeTokenizer.tokenize(src, language: CodeLanguage.detect(fileName: "a.rs"))
        #expect(lines.map { $0.map(\.text).joined() }.joined(separator: "\n") == src)
    }

    @Test func largeFileTokenizesQuickly() {
        let line = "let value = compute(\"text\", 12345) // note\n"
        let src = String(repeating: line, count: 120_000)
        #expect(src.utf8.count > 5_000_000)
        let start = Date()
        let lines = CodeTokenizer.tokenize(src, language: CodeLanguage.detect(fileName: "a.swift"))
        #expect(lines.count == 120_001)
        #expect(Date().timeIntervalSince(start) < 20)
    }

    @Test func markdownBlocks() {
        let md = "# Title\n\nSome text\nmore text\n\n- item\n1. first\n> quote\n\n```\ncode\n```\n---"
        let blocks = ProseParser.markdown(md)
        #expect(blocks.map(\.kind) == [.heading(1), .paragraph, .listItem, .listItem, .quote, .code, .rule])
        #expect(blocks[1].text == "Some text more text")
        #expect(blocks[5].text == "code")
    }

    @Test func plainParagraphs() {
        #expect(ProseParser.plain("one\ntwo\n\n\nthree").map(\.text) == ["one\ntwo", "three"])
    }

    @Test func searchFindsAcrossChaptersIgnoringCase() {
        let hits = BookSearch.search(query: "café", texts: [(0, "No match here"), (1, "A small CAFE on the corner. Another cafe.")])
        #expect(hits.count == 2)
        #expect(hits.allSatisfy { $0.chapter == 1 })
        #expect(hits[0].snippet.contains("small"))
        #expect(BookSearch.search(query: "a", texts: [(0, "aaa")]).isEmpty)
        #expect(BookSearch.lineMatches(["Alpha", "beta", "ALPHA beta"], query: "alpha") == [0, 2])
    }
}
