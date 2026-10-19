import Foundation

/// The text handed to the assistant: what the user selected, or the part of the book around where they are.
public struct Passage: Equatable, Sendable {
    public let text: String
    /// Where it comes from, for example "Chapter 3" or "Page 12". Shown with every answer.
    public let source: String
    public let isSelection: Bool
    public let wasTrimmed: Bool

    /// About 1,500 tokens, so prompt, passage and answer fit the 4,096-token floor.
    public static let defaultBudget = 4_500

    public init(text: String, source: String, isSelection: Bool, wasTrimmed: Bool) {
        self.text = text
        self.source = source
        self.isSelection = isSelection
        self.wasTrimmed = wasTrimmed
    }

    /// A selection, cut to the budget at a word edge.
    public static func selection(_ text: String, source: String, budget: Int = defaultBudget) -> Passage? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        guard t.count > budget else { return Passage(text: t, source: source, isSelection: true, wasTrimmed: false) }
        return Passage(text: cut(String(t.prefix(budget))), source: source, isSelection: true, wasTrimmed: true)
    }

    /// The part of `chapter` around `fraction` (0 to 1) of the way through, cut to the budget at paragraph or word edges.
    public static func around(_ chapter: String, fraction: Double, source: String, budget: Int = defaultBudget) -> Passage? {
        let t = chapter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        guard t.count > budget else { return Passage(text: t, source: source, isSelection: false, wasTrimmed: false) }
        let chars = Array(t)
        let centre = Int(Double(chars.count) * min(max(fraction, 0), 1))
        var lo = max(0, centre - budget / 4)
        var hi = min(chars.count, lo + budget)
        lo = max(0, hi - budget)
        hi = min(chars.count, lo + budget)
        var slice = String(chars[lo..<hi])
        if lo > 0, let nl = slice.firstIndex(of: "\n") ?? slice.firstIndex(of: " ") { slice = String(slice[slice.index(after: nl)...]) }
        if hi < chars.count { slice = cut(slice) }
        return Passage(text: slice, source: source, isSelection: false, wasTrimmed: true)
    }

    private static func cut(_ s: String) -> String {
        guard let i = s.lastIndex(where: { $0 == " " || $0 == "\n" }), s.distance(from: s.startIndex, to: i) > s.count / 2 else { return s }
        return String(s[..<i])
    }
}
