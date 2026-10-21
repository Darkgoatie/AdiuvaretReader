import SwiftUI

/// The colours of one reading surface, resolved for the current light or dark appearance.
public struct ReadingSurface: Sendable, Equatable {
    public let ground, text, secondaryText, link: RGB
    public let isDark: Bool

    public var groundColor: Color { Color(red: ground.r, green: ground.g, blue: ground.b) }
    public var textColor: Color { Color(red: text.r, green: text.g, blue: text.b) }
    public var secondaryColor: Color { Color(red: secondaryText.r, green: secondaryText.g, blue: secondaryText.b) }
    public var code: CodePalette { CodePalette.for(isDark ? .dark : .paper) }
    /// The ground with every channel flipped, for views that are inverted afterwards (PDF pages in dark).
    public var invertedGroundColor: Color { Color(red: 1 - ground.r, green: 1 - ground.g, blue: 1 - ground.b) }
}

/// Reading surfaces. `auto` follows the app: its theme and its light or dark appearance, so the reader never changes
/// contrast when the user goes in or out of a book. The others are fixed.
public enum ReadingTheme: String, CaseIterable, Identifiable, Sendable {
    case auto, paper, sepia, dark

    public var id: String { rawValue }
    public static let `default`: ReadingTheme = .auto

    public var title: String {
        switch self {
        case .auto: "Match app"
        case .paper: "Paper"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    /// True when the theme picks its own light or dark look, and so does not follow the system.
    public var isFixed: Bool { self != .auto }

    /// The colours to read with. `dark` is the current appearance and `app` the chosen app theme; only `auto` uses them.
    public func surface(dark: Bool, app: AppTheme) -> ReadingSurface {
        switch self {
        case .auto:
            let p = app.palette
            func pick(_ pair: TokenPair) -> RGB { dark ? pair.dark : pair.light }
            return ReadingSurface(ground: pick(p.background), text: pick(p.textPrimary), secondaryText: pick(p.textSecondary),
                                  link: pick(p.accentText), isDark: dark)
        case .paper:
            return ReadingSurface(ground: Palette.background.light, text: Palette.textPrimary.light,
                                  secondaryText: Palette.textSecondary.light, link: Palette.accentText.light, isDark: false)
        case .sepia:
            return ReadingSurface(ground: RGB(hex: 0xF1E7D0), text: RGB(hex: 0x3B3226), secondaryText: RGB(hex: 0x6B5B45),
                                  link: RGB(hex: 0x0B6A49), isDark: false)
        case .dark:
            return ReadingSurface(ground: Palette.background.dark, text: Palette.textPrimary.dark,
                                  secondaryText: Palette.textSecondary.dark, link: Palette.accentText.dark, isDark: true)
        }
    }

    public static func resolve(_ raw: String?) -> ReadingTheme { raw.flatMap(ReadingTheme.init(rawValue:)) ?? .default }
}

/// Syntax colours for the code viewer, one set per reading theme, each at least 4.5:1 on that ground.
public struct CodePalette: Sendable {
    public let keyword, string, comment, number, text: RGB

    public static func `for`(_ theme: ReadingTheme) -> CodePalette {
        switch theme {
        case .paper, .auto:
            CodePalette(keyword: RGB(hex: 0x0B7551), string: RGB(hex: 0x8F5200), comment: RGB(hex: 0x655E55), number: RGB(hex: 0x2F54B8), text: RGB(hex: 0x1F1B16))
        case .sepia:
            CodePalette(keyword: RGB(hex: 0x0B6A49), string: RGB(hex: 0x7A4600), comment: RGB(hex: 0x5E5240), number: RGB(hex: 0x2A4AA8), text: RGB(hex: 0x3B3226))
        case .dark:
            CodePalette(keyword: RGB(hex: 0x3FD1A0), string: RGB(hex: 0xF0B14A), comment: RGB(hex: 0xA9A196), number: RGB(hex: 0x9DB4FF), text: RGB(hex: 0xF4EFE8))
        }
    }
}
