import SwiftUI
import Observation

public enum ReadingFont: String, CaseIterable, Identifiable, Sendable {
    case sans, serif, system

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .sans: "Google Sans"
        case .serif: "Serif"
        case .system: "System"
        }
    }

    /// CSS font stack for web content.
    public var css: String {
        switch self {
        case .sans: "'Google Sans', -apple-system, sans-serif"
        case .serif: "'New York', Georgia, serif"
        case .system: "-apple-system, sans-serif"
        }
    }

    public func font(size: CGFloat) -> Font {
        switch self {
        case .sans: .custom("Google Sans", size: size)
        case .serif: .system(size: size, design: .serif)
        case .system: .system(size: size)
        }
    }
}

public enum ReaderLimits {
    public static let fontSize: ClosedRange<Double> = 12...34
    public static let lineSpacing: ClosedRange<Double> = 1.1...2.2
    public static let margin: ClosedRange<Double> = 0...4

    public static func clamp(_ v: Double, _ r: ClosedRange<Double>) -> Double { min(max(v, r.lowerBound), r.upperBound) }
}

/// How the user wants text laid out. A global setting kept in UserDefaults, which one book can override for itself.
@Observable
public final class ReaderPreferences: @unchecked Sendable {
    public static let shared = ReaderPreferences()

    public var theme: ReadingTheme { didSet { save() } }
    public var font: ReadingFont { didSet { save() } }
    public var fontSize: Double { didSet { save() } }
    public var lineSpacing: Double { didSet { save() } }
    public var margin: Double { didSet { save() } }
    /// Stops the screen from locking while a book is open.
    public var keepScreenOn: Bool { didSet { defaults.set(keepScreenOn, forKey: "reader.keepAwake") } }

    /// The book whose own settings are showing, and whether it has them.
    public private(set) var bookScope: UUID?
    public private(set) var isScoped = false

    private let defaults: UserDefaults
    private var loading = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = ReadingTheme.resolve(defaults.string(forKey: "reader.theme"))
        font = ReadingFont(rawValue: defaults.string(forKey: "reader.font") ?? "") ?? .sans
        fontSize = ReaderLimits.clamp((defaults.object(forKey: "reader.size") as? Double) ?? 19, ReaderLimits.fontSize)
        lineSpacing = ReaderLimits.clamp((defaults.object(forKey: "reader.spacing") as? Double) ?? 1.5, ReaderLimits.lineSpacing)
        margin = ReaderLimits.clamp((defaults.object(forKey: "reader.margin") as? Double) ?? 1, ReaderLimits.margin)
        keepScreenOn = (defaults.object(forKey: "reader.keepAwake") as? Bool) ?? true
    }

    private func overrideKey(_ id: UUID) -> String { "reader.book." + id.uuidString }

    private var current: [String: Any] {
        ["theme": theme.rawValue, "font": font.rawValue,
         "size": ReaderLimits.clamp(fontSize, ReaderLimits.fontSize),
         "spacing": ReaderLimits.clamp(lineSpacing, ReaderLimits.lineSpacing),
         "margin": ReaderLimits.clamp(margin, ReaderLimits.margin)]
    }

    private func apply(_ d: [String: Any]) {
        loading = true
        defer { loading = false }
        theme = ReadingTheme.resolve(d["theme"] as? String)
        font = ReadingFont(rawValue: (d["font"] as? String) ?? "") ?? .sans
        fontSize = ReaderLimits.clamp((d["size"] as? Double) ?? 19, ReaderLimits.fontSize)
        lineSpacing = ReaderLimits.clamp((d["spacing"] as? Double) ?? 1.5, ReaderLimits.lineSpacing)
        margin = ReaderLimits.clamp((d["margin"] as? Double) ?? 1, ReaderLimits.margin)
    }

    private var globalValues: [String: Any] {
        ["theme": defaults.string(forKey: "reader.theme") as Any, "font": defaults.string(forKey: "reader.font") as Any,
         "size": defaults.object(forKey: "reader.size") as Any, "spacing": defaults.object(forKey: "reader.spacing") as Any,
         "margin": defaults.object(forKey: "reader.margin") as Any]
    }

    private func save() {
        guard !loading else { return }
        if let id = bookScope {
            if isScoped { defaults.set(current, forKey: overrideKey(id)) }
            else { writeGlobal() }
        } else { writeGlobal() }
    }

    private func writeGlobal() {
        defaults.set(theme.rawValue, forKey: "reader.theme")
        defaults.set(font.rawValue, forKey: "reader.font")
        defaults.set(ReaderLimits.clamp(fontSize, ReaderLimits.fontSize), forKey: "reader.size")
        defaults.set(ReaderLimits.clamp(lineSpacing, ReaderLimits.lineSpacing), forKey: "reader.spacing")
        defaults.set(ReaderLimits.clamp(margin, ReaderLimits.margin), forKey: "reader.margin")
    }

    /// Called when a book opens. Applies that book's own settings if it has any.
    public func enter(book id: UUID) {
        bookScope = id
        if let own = defaults.dictionary(forKey: overrideKey(id)) {
            isScoped = true
            apply(own)
        } else {
            isScoped = false
            apply(globalValues)
        }
    }

    /// Called when the book closes. Brings the global settings back.
    public func leave(book id: UUID? = nil) {
        if let id, bookScope != id { return }
        bookScope = nil
        isScoped = false
        apply(globalValues)
    }

    /// Turns "only for this book" on or off. Off drops the book's own settings and returns to the global ones.
    public func setScoped(_ on: Bool) {
        guard let id = bookScope, on != isScoped else { return }
        if on {
            isScoped = true
            defaults.set(current, forKey: overrideKey(id))
        } else {
            isScoped = false
            defaults.removeObject(forKey: overrideKey(id))
            apply(globalValues)
        }
    }

    /// Side padding in points for the current margin level.
    public var sidePadding: CGFloat { CGFloat(16 + margin * 14) }
}
