import Foundation

public struct ProseBlock: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case heading(Int), paragraph, code, listItem, quote, rule, math
    }

    public let id: Int
    public let kind: Kind
    public let text: String
}

public enum ProseParser {
    /// Plain text: paragraphs separated by blank lines, line breaks inside a paragraph kept.
    public static func plain(_ source: String) -> [ProseBlock] {
        var blocks: [ProseBlock] = []
        var current: [String] = []
        func flush() {
            if !current.isEmpty { blocks.append(ProseBlock(id: blocks.count, kind: .paragraph, text: current.joined(separator: "\n"))) }
            current = []
        }
        for line in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { flush() } else { current.append(String(line)) }
        }
        flush()
        return blocks
    }

    /// The common Markdown blocks. Inline marks (emphasis, links, code) are left for the renderer.
    public static func markdown(_ source: String) -> [ProseBlock] {
        var blocks: [ProseBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var inFence = false
        var inMath = false
        var math: [String] = []

        func add(_ kind: ProseBlock.Kind, _ text: String) { blocks.append(ProseBlock(id: blocks.count, kind: kind, text: text)) }
        func flush() {
            if !paragraph.isEmpty { add(.paragraph, paragraph.joined(separator: " ")) }
            paragraph = []
        }

        for raw in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inFence { add(.code, code.joined(separator: "\n")); code = [] } else { flush() }
                inFence.toggle()
                continue
            }
            if inFence { code.append(line); continue }
            if inMath {
                if trimmed.hasSuffix("$$") {
                    let rest = String(trimmed.dropLast(2))
                    if !rest.isEmpty { math.append(rest) }
                    add(.math, math.joined(separator: "\n"))
                    math = []
                    inMath = false
                } else {
                    math.append(line)
                }
                continue
            }
            if trimmed.hasPrefix("$$") {
                flush()
                let rest = String(trimmed.dropFirst(2))
                if rest.count >= 2, rest.hasSuffix("$$") {
                    add(.math, String(rest.dropLast(2)).trimmingCharacters(in: .whitespaces))
                } else {
                    inMath = true
                    math = rest.isEmpty ? [] : [rest]
                }
                continue
            }
            if trimmed.isEmpty { flush(); continue }
            if let level = headingLevel(trimmed) {
                flush()
                add(.heading(level), String(trimmed.drop { $0 == "#" }).trimmingCharacters(in: .whitespaces))
            } else if trimmed.count >= 3, trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }), Set(trimmed).count == 1 {
                flush(); add(.rule, "")
            } else if let item = listItem(trimmed) {
                flush(); add(.listItem, item)
            } else if trimmed.hasPrefix(">") {
                flush(); add(.quote, String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else {
                paragraph.append(trimmed)
            }
        }
        if inFence { add(.code, code.joined(separator: "\n")) }
        if inMath { add(.math, math.joined(separator: "\n")) }
        flush()
        return blocks
    }

    private static func headingLevel(_ s: String) -> Int? {
        let hashes = s.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), s.dropFirst(hashes).first == " " else { return nil }
        return hashes
    }

    private static func listItem(_ s: String) -> String? {
        for p in ["- ", "* ", "+ "] where s.hasPrefix(p) { return String(s.dropFirst(2)) }
        let digits = s.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, s.dropFirst(digits.count).hasPrefix(". ") { return String(s.dropFirst(digits.count + 2)) }
        return nil
    }
}
