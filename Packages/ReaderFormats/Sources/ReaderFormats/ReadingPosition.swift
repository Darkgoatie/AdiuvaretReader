import Foundation

/// A place in a book, stored as text so one field serves every format.
public enum ReadingPosition: Equatable, Sendable {
    case chapter(index: Int, fraction: Double)
    case page(Int)
    case block(Int)

    public var encoded: String {
        switch self {
        case .chapter(let i, let f): "c:\(i):\(String(format: "%.4f", min(max(f, 0), 1)))"
        case .page(let p): "p:\(p)"
        case .block(let b): "b:\(b)"
        }
    }

    public init?(encoded: String) {
        let parts = encoded.split(separator: ":").map(String.init)
        switch (parts.first, parts.count) {
        case ("c", 3):
            guard let i = Int(parts[1]), let f = Double(parts[2]) else { return nil }
            self = .chapter(index: i, fraction: f)
        case ("p", 2):
            guard let p = Int(parts[1]) else { return nil }
            self = .page(p)
        case ("b", 2):
            guard let b = Int(parts[1]) else { return nil }
            self = .block(b)
        default:
            return nil
        }
    }

    /// True when both are in the same place for the purpose of a bookmark: same page or block, or the same chapter within 3 percent.
    public func isNear(_ other: ReadingPosition) -> Bool {
        switch (self, other) {
        case (.chapter(let a, let fa), .chapter(let b, let fb)): return a == b && abs(fa - fb) < 0.03
        case (.page(let a), .page(let b)): return a == b
        case (.block(let a), .block(let b)): return a == b
        default: return false
        }
    }

    /// A short name for the place, such as "Chapter 3", "Page 12" or "Line 40".
    public func label(isCode: Bool = false) -> String {
        switch self {
        case .chapter(let i, _): "Chapter \(i + 1)"
        case .page(let p): "Page \(p + 1)"
        case .block(let b): isCode ? "Line \(b + 1)" : "Section \(b + 1)"
        }
    }

    public static func overall(chapter: Int, fraction: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(max((Double(chapter) + min(max(fraction, 0), 1)) / Double(count), 0), 1)
    }
}
