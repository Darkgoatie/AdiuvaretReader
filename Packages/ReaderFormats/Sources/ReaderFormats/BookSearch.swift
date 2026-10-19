import Foundation

public struct SearchHit: Identifiable, Equatable, Sendable {
    public let id: Int
    public let chapter: Int
    public let offset: Int
    public let length: Int
    public let snippet: String

    public init(id: Int, chapter: Int, offset: Int, length: Int, snippet: String) {
        self.id = id
        self.chapter = chapter
        self.offset = offset
        self.length = length
        self.snippet = snippet
    }
}

public enum BookSearch {
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Matches of `query` in each text, ignoring case and accents. `chapter` is the index the caller gave the text.
    public static func search(query: String, texts: [(chapter: Int, text: String)], limit: Int = 200) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        var hits: [SearchHit] = []
        for (chapter, text) in texts {
            var from = text.startIndex
            while let r = text.range(of: q, options: options, range: from..<text.endIndex) {
                let lo = text.index(r.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
                let hi = text.index(r.upperBound, offsetBy: 80, limitedBy: text.endIndex) ?? text.endIndex
                let snippet = text[lo..<hi].replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                hits.append(SearchHit(id: hits.count, chapter: chapter, offset: text.distance(from: text.startIndex, to: r.lowerBound),
                                      length: text.distance(from: r.lowerBound, to: r.upperBound), snippet: snippet))
                if hits.count >= limit { return hits }
                from = r.upperBound
            }
        }
        return hits
    }

    /// Indices of the lines that contain `query`.
    public static func lineMatches(_ lines: [String], query: String) -> [Int] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return lines.indices.filter { lines[$0].range(of: q, options: options) != nil }
    }
}
