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

    public var groundColor: Color { Color(red: ground.r, green: ground.g, blue: ground.b) }
    public var textColor: Color { Color(red: text.r, green: text.g, blue: text.b) }

    public static func resolve(_ raw: String?) -> ReadingTheme { raw.flatMap(ReadingTheme.init(rawValue:)) ?? .default }
}
