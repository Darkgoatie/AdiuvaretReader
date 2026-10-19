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

    public static func overall(chapter: Int, fraction: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(max((Double(chapter) + min(max(fraction, 0), 1)) / Double(count), 0), 1)
    }
}
