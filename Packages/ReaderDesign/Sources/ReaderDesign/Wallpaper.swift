import SwiftUI
import Observation

/// What is painted behind the chat and the drawer. None is the plain theme background and the default.
public enum WallpaperKind: String, CaseIterable, Identifiable, Sendable {
    case none, scenery, gradient, pattern, solid, photo

    public var id: String { rawValue }
    public static let `default`: WallpaperKind = .none

    public var title: String {
        switch self {
        case .none: "None"
        case .scenery: "Scenery"
        case .gradient: "Gradient"
        case .pattern: "Pattern"
        case .solid: "Solid colour"
        case .photo: "Your photo"
        }
    }

    public static func resolve(_ raw: String?) -> WallpaperKind { raw.flatMap(WallpaperKind.init(rawValue:)) ?? .default }
}

/// A bundled landscape photo, licensed free to use by Pexels. The files are `wallpaper-<id>.jpg` and `wallpaper-<id>-thumb.jpg` in the app.
public struct WallpaperScene: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let photographer: String
    public let pexelsID: Int
    public let pageSlug: String

    public var file: String { "wallpaper-\(id)" }
    public var thumbnail: String { "wallpaper-\(id)-thumb" }
    public var pageURL: String { "https://www.pexels.com/photo/\(pageSlug)-\(pexelsID)/" }

    public static let all: [WallpaperScene] = [
        WallpaperScene(id: "foggy-forest", title: "Foggy forest", photographer: "eberhard grossgasteiger", pexelsID: 1367192, pageSlug: "photo-of-foggy-forest"),
        WallpaperScene(id: "pine-fog", title: "Pine fog", photographer: "Trace Hudson", pexelsID: 2529973, pageSlug: "photo-of-pine-trees-covered-by-fog"),
        WallpaperScene(id: "ocean-foam", title: "Ocean foam", photographer: "Ma Fe Hermelie Ferrer", pexelsID: 8668005, pageSlug: "aerial-view-of-ocean-waves"),
        WallpaperScene(id: "sea-sunset", title: "Sea sunset", photographer: "Pew Nguyen", pexelsID: 17594421, pageSlug: "sunset-over-the-sea"),
        WallpaperScene(id: "dusk-coast", title: "Dusk coast", photographer: "Christopher Seufert", pexelsID: 7751553, pageSlug: "sunset-over-a-sea"),
        WallpaperScene(id: "aurora-coast", title: "Aurora coast", photographer: "Tobias Bjørkli", pexelsID: 1938353, pageSlug: "northern-lights"),
        WallpaperScene(id: "aurora-green", title: "Green aurora", photographer: "Matthew DeVries", pexelsID: 3179737, pageSlug: "northern-lights-at-night"),
        WallpaperScene(id: "waterfall-hills", title: "Waterfall", photographer: "Jayanth Muppaneni", pexelsID: 28762575, pageSlug: "scenic-waterfall-in-lush-green-landscape"),
        WallpaperScene(id: "alpine-lake", title: "Alpine lake", photographer: "Francesco Ungaro", pexelsID: 1526713, pageSlug: "mountain-and-lake"),
        WallpaperScene(id: "snow-peaks", title: "Snow peaks", photographer: "Francesco Ungaro", pexelsID: 29858041, pageSlug: "stunning-winter-sunrise-over-snowy-mountains"),
        WallpaperScene(id: "milky-way", title: "Milky Way", photographer: "Mengliu Di", pexelsID: 3213577, pageSlug: "milky-way-over-mountains-at-night"),
        WallpaperScene(id: "misty-hills", title: "Misty hills", photographer: "Ama Journey", pexelsID: 34575126, pageSlug: "misty-morning-over-lush-green-hills-landscape"),
        WallpaperScene(id: "dawn-hills", title: "Dawn hills", photographer: "Nguyen Giang", pexelsID: 29525961, pageSlug: "dawn-mist-over-green-hills-in-phu-th-vietnam"),
    ]

    public static func resolve(_ raw: String?) -> WallpaperScene { all.first { $0.id == raw } ?? all[0] }
}

/// Soft gradients, one set of stops for light mode and one for dark, kept quiet so message text stays readable.
public enum WallpaperGradient: String, CaseIterable, Identifiable, Sendable {
    case dawn, ocean, forest, dusk, graphite

    public var id: String { rawValue }
    public static let `default`: WallpaperGradient = .dawn

    public var title: String {
        switch self {
        case .dawn: "Dawn"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .dusk: "Dusk"
        case .graphite: "Graphite"
        }
    }

    public func stops(dark: Bool) -> [String] {
        switch (self, dark) {
        case (.dawn, false): ["#FFF1E6", "#FDE2E4", "#E2ECF9"]
        case (.dawn, true): ["#2B1F2A", "#33222B", "#1E2633"]
        case (.ocean, false): ["#E3F2FD", "#D6EEF5", "#E8F5F0"]
        case (.ocean, true): ["#0F2230", "#10303A", "#13282B"]
        case (.forest, false): ["#E8F5E9", "#DDEFD9", "#F1F6E3"]
        case (.forest, true): ["#10261A", "#173223", "#1E2A15"]
        case (.dusk, false): ["#EDE7F6", "#E1E4F8", "#F6E6EE"]
        case (.dusk, true): ["#1F1A33", "#231E3B", "#2F1D2C"]
        case (.graphite, false): ["#F2F2F4", "#E6E7EA", "#F4F4F5"]
        case (.graphite, true): ["#1A1B1E", "#222327", "#18191B"]
        }
    }

    public static func resolve(_ raw: String?) -> WallpaperGradient { raw.flatMap(WallpaperGradient.init(rawValue:)) ?? .default }
}

/// Patterns drawn in the theme's accent colour over its background, at low strength.
public enum WallpaperPattern: String, CaseIterable, Identifiable, Sendable {
    case dots, grid, lines, waves

    public var id: String { rawValue }
    public static let `default`: WallpaperPattern = .dots

    public var title: String {
        switch self {
        case .dots: "Dots"
        case .grid: "Grid"
        case .lines: "Diagonal lines"
        case .waves: "Waves"
        }
    }

    public static func resolve(_ raw: String?) -> WallpaperPattern { raw.flatMap(WallpaperPattern.init(rawValue:)) ?? .default }
}

public enum WallpaperColor {
    /// `#RRGGBB` or `RRGGBB` as fractions, or nil when the text is not a six-digit hex colour.
    public static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var t = hex.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#") { t.removeFirst() }
        guard t.count == 6, t.allSatisfy(\.isHexDigit), let v = UInt32(t, radix: 16) else { return nil }
        return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    public static func color(_ hex: String) -> Color? { rgb(hex).map { Color(red: $0.r, green: $0.g, blue: $0.b) } }

    public static func hex(red: Double, green: Double, blue: Double) -> String {
        func byte(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

/// The chosen wallpaper. Observable, so open screens repaint when it changes.
@Observable
public final class WallpaperStore: @unchecked Sendable {
    public static let shared = WallpaperStore()
    public static let maxDim = 0.6
    public static let defaultSolid = "#1F2A44"

    private static let kindKey = "settings.wallpaper.kind"
    private static let gradientKey = "settings.wallpaper.gradient"
    private static let patternKey = "settings.wallpaper.pattern"
    private static let solidKey = "settings.wallpaper.solid"
    private static let sceneKey = "settings.wallpaper.scene"
    private static let dimKey = "settings.wallpaper.dim"

    public var kind: WallpaperKind { didSet { UserDefaults.standard.set(kind.rawValue, forKey: Self.kindKey) } }
    public var gradient: WallpaperGradient { didSet { UserDefaults.standard.set(gradient.rawValue, forKey: Self.gradientKey) } }
    public var pattern: WallpaperPattern { didSet { UserDefaults.standard.set(pattern.rawValue, forKey: Self.patternKey) } }
    public var sceneID: String { didSet { UserDefaults.standard.set(sceneID, forKey: Self.sceneKey) } }
    public var solidHex: String { didSet { UserDefaults.standard.set(solidHex, forKey: Self.solidKey) } }
    /// How much of the background colour is laid over a photo, 0 to `maxDim`, so text stays readable.
    public var dim: Double { didSet { UserDefaults.standard.set(Self.clamp(dim), forKey: Self.dimKey) } }

    public static func clamp(_ value: Double) -> Double { min(max(value, 0), maxDim) }

    /// The first time the app runs, before the user has chosen anything, one bundled scene becomes the wallpaper. A choice already stored,
    /// including "None", is never replaced. `pick` returns an index below the count it is given.
    public static func seedFirstLaunch(defaults d: UserDefaults = .standard, pick: (Int) -> Int = { Int.random(in: 0..<$0) }) {
        guard d.object(forKey: kindKey) == nil, d.object(forKey: sceneKey) == nil else { return }
        let count = WallpaperScene.all.count
        let index = min(max(pick(count), 0), count - 1)
        d.set(WallpaperKind.scenery.rawValue, forKey: kindKey)
        d.set(WallpaperScene.all[index].id, forKey: sceneKey)
        if d.object(forKey: dimKey) == nil { d.set(seededDim, forKey: dimKey) }
    }

    public static let seededDim = 0.35

    private init() {
        Self.seedFirstLaunch()
        let d = UserDefaults.standard
        sceneID = WallpaperScene.resolve(d.string(forKey: Self.sceneKey)).id
        kind = WallpaperKind.resolve(d.string(forKey: Self.kindKey))
        gradient = WallpaperGradient.resolve(d.string(forKey: Self.gradientKey))
        pattern = WallpaperPattern.resolve(d.string(forKey: Self.patternKey))
        let stored = d.string(forKey: Self.solidKey) ?? Self.defaultSolid
        solidHex = WallpaperColor.rgb(stored) == nil ? Self.defaultSolid : stored
        dim = Self.clamp((d.object(forKey: Self.dimKey) as? Double) ?? 0.25)
    }
}
