import Foundation

public struct AnnotationRecord: Sendable, Equatable {
    public let kind: AnnotationKind
    public let label: String
    public let quote: String
    public let note: String
    public let createdAt: Date

    public init(kind: AnnotationKind, label: String, quote: String, note: String, createdAt: Date) {
        self.kind = kind
        self.label = label
        self.quote = quote
        self.note = note
        self.createdAt = createdAt
    }
}

public enum AnnotationExport {
    /// A plain Markdown file of the user's highlights, notes and bookmarks, in the order given.
    public static func markdown(title: String, author: String, records: [AnnotationRecord]) -> String {
        var out = "# \(title)\n"
        if !author.isEmpty { out += "\n\(author)\n" }
        let groups: [(String, AnnotationKind)] = [("Highlights", .highlight), ("Notes", .note), ("Bookmarks", .bookmark)]
        for (heading, kind) in groups {
            let items = records.filter { $0.kind == kind }
            guard !items.isEmpty else { continue }
            out += "\n## \(heading)\n"
            for r in items {
                out += "\n"
                if !r.quote.isEmpty { out += r.quote.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }.joined(separator: "\n") + "\n" }
                if !r.note.isEmpty { out += (r.quote.isEmpty ? "" : "\n") + r.note + "\n" }
                if r.quote.isEmpty && r.note.isEmpty { out += "- " + r.label + "\n" } else { out += "\n(" + r.label + ")\n" }
            }
        }
        return out
    }
}
