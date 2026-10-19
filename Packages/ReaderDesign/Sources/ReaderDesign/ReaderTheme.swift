import SwiftUI

/// Reading surfaces. Each has its own ground and text colour, tested for 4.5:1, and never carries a wallpaper.
public enum ReadingTheme: String, CaseIterable, Identifiable, Sendable {
    case paper, sepia, dark

    public var id: String { rawValue }
    public static let `default`: ReadingTheme = .paper

    public var title: String {
        switch self {
        case .paper: "Paper"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    public var ground: RGB {
        switch self {
        case .paper: Palette.background.light
        case .sepia: RGB(hex: 0xF1E7D0)
        case .dark: Palette.background.dark
        }
    }

    public var text: RGB {
        switch self {
        case .paper: Palette.textPrimary.light
        case .sepia: RGB(hex: 0x3B3226)
        case .dark: Palette.textPrimary.dark
        }
    }

    public var secondaryText: RGB {
        switch self {
        case .paper: Palette.textSecondary.light
        case .sepia: RGB(hex: 0x6B5B45)
        case .dark: Palette.textSecondary.dark
        }
    }

    /// Links and the accent used as text on this ground.
    public var link: RGB {
        switch self {
        case .paper: Palette.accentText.light
        case .sepia: RGB(hex: 0x0B6A49)
        case .dark: Palette.accentText.dark
        }
    }

    public var groundColor: Color { Color(red: ground.r, green: ground.g, blue: ground.b) }
    public var textColor: Color { Color(red: text.r, green: text.g, blue: text.b) }

    public static func resolve(_ raw: String?) -> ReadingTheme { raw.flatMap(ReadingTheme.init(rawValue:)) ?? .default }
}

/// Syntax colours for the code viewer, one set per reading theme, each at least 4.5:1 on that ground.
public struct CodePalette: Sendable {
    public let keyword, string, comment, number, text: RGB

    public static func `for`(_ theme: ReadingTheme) -> CodePalette {
        switch theme {
        case .paper:
            CodePalette(keyword: RGB(hex: 0x0B7551), string: RGB(hex: 0x8F5200), comment: RGB(hex: 0x655E55), number: RGB(hex: 0x2F54B8), text: RGB(hex: 0x1F1B16))
        case .sepia:
            CodePalette(keyword: RGB(hex: 0x0B6A49), string: RGB(hex: 0x7A4600), comment: RGB(hex: 0x5E5240), number: RGB(hex: 0x2A4AA8), text: RGB(hex: 0x3B3226))
        case .dark:
            CodePalette(keyword: RGB(hex: 0x3FD1A0), string: RGB(hex: 0xF0B14A), comment: RGB(hex: 0xA9A196), number: RGB(hex: 0x9DB4FF), text: RGB(hex: 0xF4EFE8))
        }
    }
}
