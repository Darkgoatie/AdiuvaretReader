import Foundation

public struct Backlink: Identifiable, Equatable, Sendable {
    public var id: String { path }
    public let path: String
    /// The first line of the note that links here.
    public let snippet: String
}

/// Finds the notes of a vault that link to one note with `[[wikilinks]]` or `![[embeds]]`.
public enum Backlinks {
    public static func find(to current: String, notes: [(path: String, text: String)], index: VaultIndex) -> [Backlink] {
        var out: [Backlink] = []
        for note in notes where note.path != current {
            for line in note.text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard line.contains("[[") else { continue }
                if targets(in: String(line)).contains(where: { index.resolve($0, from: note.path) == current }) {
                    out.append(Backlink(path: note.path, snippet: clip(String(line))))
                    break
                }
            }
        }
        return out.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func targets(in line: String) -> [String] {
        var out: [String] = []
        var rest = Substring(line)
        while let open = rest.range(of: "[[") {
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "]]") else { break }
            var target = String(after[..<close.lowerBound])
            if let bar = target.firstIndex(of: "|") { target = String(target[..<bar]) }
            if let hash = target.firstIndex(of: "#") { target = String(target[..<hash]) }
            if let caret = target.firstIndex(of: "^") { target = String(target[..<caret]) }
            target = target.trimmingCharacters(in: .whitespaces)
            if !target.isEmpty { out.append(target) }
            rest = after[close.upperBound...]
        }
        return out
    }

    private static func clip(_ line: String) -> String {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count > 140 ? String(t.prefix(140)) + "..." : t
    }
}
