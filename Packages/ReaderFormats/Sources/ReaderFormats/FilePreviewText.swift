import Foundation

public enum FilePreviewText {
    public enum Kind: Sendable { case plain, markdown, latex, code }

    /// The first lines of a file, cleaned up to look like a small page: no heading marks or emphasis stars, long lines cut.
    public static func snippet(_ data: Data, kind: Kind, maxLines: Int = 14, maxWidth: Int = 48) -> String {
        var text = String(decoding: data.prefix(6000), as: UTF8.self)
        if kind == .latex { text = LatexConverter.toMarkdown(text) }
        var lines: [String] = []
        var lastBlank = true
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var line = String(raw)
            if kind == .code {
                while let last = line.last, last == " " || last == "\t" { line.removeLast() }
                line = line.replacingOccurrences(of: "\t", with: "  ")
            } else {
                line = line.trimmingCharacters(in: .whitespaces)
                if kind != .plain {
                    while line.hasPrefix("#") { line.removeFirst() }
                    line = line.trimmingCharacters(in: .whitespaces)
                    if line == "$$" || line.hasPrefix("```") { continue }
                    line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                }
            }
            if line.isEmpty {
                if lastBlank { continue }
                lastBlank = true
                lines.append("")
            } else {
                lastBlank = false
                lines.append(String(line.prefix(maxWidth)))
            }
            if lines.count >= maxLines { break }
        }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
