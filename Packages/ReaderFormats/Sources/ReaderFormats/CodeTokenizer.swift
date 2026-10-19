import Foundation

public enum TokenKind: UInt8, Sendable {
    case plain, keyword, string, comment, number
}

public struct CodeToken: Sendable, Equatable {
    public let kind: TokenKind
    public let text: String
}

public enum CodeTokenizer {
    /// One token list per line. Block comments carry over between lines. Lines longer than `maxLineLength` are cut.
    public static func tokenize(_ source: String, language: CodeLanguage, maxLineLength: Int = 2000) -> [[CodeToken]] {
        let lineComments = language.lineComments.map { Array($0) }
        let blockStart = language.blockComment.map { Array($0.0) }
        let blockEnd = language.blockComment.map { Array($0.1) }
        var inBlock = false
        var result: [[CodeToken]] = []

        for sub in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let chars = Array(sub.prefix(maxLineLength))
            var tokens: [CodeToken] = []
            var buffer = ""
            var bufferKind = TokenKind.plain

            func emit(_ kind: TokenKind, _ text: String) {
                if kind == bufferKind { buffer += text; return }
                if !buffer.isEmpty { tokens.append(CodeToken(kind: bufferKind, text: buffer)) }
                buffer = text
                bufferKind = kind
            }
            func matches(_ marker: [Character], at i: Int) -> Bool {
                guard !marker.isEmpty, i + marker.count <= chars.count else { return false }
                for k in 0..<marker.count where chars[i + k] != marker[k] { return false }
                return true
            }

            var i = 0
            lineLoop: while i < chars.count {
                if inBlock, let end = blockEnd {
                    var j = i
                    while j < chars.count, !matches(end, at: j) { j += 1 }
                    if j < chars.count { j += end.count; inBlock = false } else { j = chars.count }
                    emit(.comment, String(chars[i..<j]))
                    i = j
                    continue
                }
                if let start = blockStart, matches(start, at: i) {
                    emit(.comment, String(start))
                    i += start.count
                    inBlock = true
                    continue
                }
                for marker in lineComments where matches(marker, at: i) {
                    emit(.comment, String(chars[i...]))
                    i = chars.count
                    break lineLoop
                }
                let c = chars[i]
                if language.quotes.contains(c) {
                    var j = i + 1
                    while j < chars.count {
                        if chars[j] == "\\" { j += 2; continue }
                        if chars[j] == c { j += 1; break }
                        j += 1
                    }
                    j = min(j, chars.count)
                    emit(.string, String(chars[i..<j]))
                    i = j
                } else if c.isASCII, c.isNumber, i == 0 || !(chars[i - 1].isLetter || chars[i - 1] == "_") {
                    var j = i
                    while j < chars.count, chars[j].isASCII, chars[j].isLetter || chars[j].isNumber || chars[j] == "." || chars[j] == "_" { j += 1 }
                    emit(.number, String(chars[i..<j]))
                    i = j
                } else if c.isLetter || c == "_" {
                    var j = i
                    while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                    let word = String(chars[i..<j])
                    emit(language.keywords.contains(word) ? .keyword : .plain, word)
                    i = j
                } else {
                    emit(.plain, String(c))
                    i += 1
                }
            }
            if !buffer.isEmpty { tokens.append(CodeToken(kind: bufferKind, text: buffer)) }
            result.append(tokens)
        }
        return result
    }
}
