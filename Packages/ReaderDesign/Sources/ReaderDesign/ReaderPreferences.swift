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

/// How the user wants text laid out. One global setting, kept in UserDefaults.
@Observable
public final class ReaderPreferences: @unchecked Sendable {
    public static let shared = ReaderPreferences()

    public var theme: ReadingTheme { didSet { save() } }
    public var font: ReadingFont { didSet { save() } }
    public var fontSize: Double { didSet { save() } }
    public var lineSpacing: Double { didSet { save() } }
    public var margin: Double { didSet { save() } }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = ReadingTheme.resolve(defaults.string(forKey: "reader.theme"))
        font = ReadingFont(rawValue: defaults.string(forKey: "reader.font") ?? "") ?? .sans
        fontSize = ReaderLimits.clamp((defaults.object(forKey: "reader.size") as? Double) ?? 19, ReaderLimits.fontSize)
        lineSpacing = ReaderLimits.clamp((defaults.object(forKey: "reader.spacing") as? Double) ?? 1.5, ReaderLimits.lineSpacing)
        margin = ReaderLimits.clamp((defaults.object(forKey: "reader.margin") as? Double) ?? 1, ReaderLimits.margin)
    }

    private func save() {
        defaults.set(theme.rawValue, forKey: "reader.theme")
        defaults.set(font.rawValue, forKey: "reader.font")
        defaults.set(ReaderLimits.clamp(fontSize, ReaderLimits.fontSize), forKey: "reader.size")
        defaults.set(ReaderLimits.clamp(lineSpacing, ReaderLimits.lineSpacing), forKey: "reader.spacing")
        defaults.set(ReaderLimits.clamp(margin, ReaderLimits.margin), forKey: "reader.margin")
    }

    /// Side padding in points for the current margin level.
    public var sidePadding: CGFloat { CGFloat(16 + margin * 14) }
}
