import Testing
import Foundation
@testable import ReaderDesign

@Suite struct WallpaperTests {
    @Test func defaultsAreThePlainBackground() {
        #expect(WallpaperKind.default == .none)
        #expect(WallpaperKind.resolve(nil) == .none && WallpaperKind.resolve("nonsense") == .none && WallpaperKind.resolve("photo") == .photo)
        #expect(WallpaperGradient.resolve("x") == .dawn && WallpaperPattern.resolve("x") == .dots)
    }

    @Test func hexColoursParseOrFail() {
        #expect(WallpaperColor.rgb("#FF0000")?.r == 1 && WallpaperColor.rgb("00ff00")?.g == 1)
        #expect(WallpaperColor.rgb("#12345") == nil && WallpaperColor.rgb("#GGGGGG") == nil && WallpaperColor.rgb("") == nil)
        #expect(WallpaperColor.hex(red: 1, green: 0, blue: 0.5) == "#FF0080")
        #expect(WallpaperColor.hex(red: 2, green: -1, blue: 0) == "#FF0000")
    }

    @Test func everyGradientHasThreeValidStopsForBothModes() {
        for g in WallpaperGradient.allCases {
            for dark in [false, true] {
                let stops = g.stops(dark: dark)
                #expect(stops.count == 3 && stops.allSatisfy { WallpaperColor.rgb($0) != nil }, Comment(rawValue: "\(g) \(dark)"))
            }
        }
    }

    @Test func theCatalogIsComplete() {
        let scenes = WallpaperScene.all
        #expect(scenes.count >= 10)
        #expect(Set(scenes.map(\.id)).count == scenes.count && Set(scenes.map(\.pexelsID)).count == scenes.count)
        for s in scenes {
            #expect(!s.title.isEmpty && !s.photographer.isEmpty && s.pexelsID > 0, Comment(rawValue: s.id))
            #expect(s.file == "wallpaper-\(s.id)" && s.thumbnail == "wallpaper-\(s.id)-thumb", Comment(rawValue: s.id))
            #expect(s.pageURL == "https://www.pexels.com/photo/\(s.pageSlug)-\(s.pexelsID)/", Comment(rawValue: s.id))
            #expect(s.id.allSatisfy { $0.isLowercase || $0 == "-" }, Comment(rawValue: s.id))
        }
        #expect(WallpaperScene.resolve("nope") == scenes[0] && WallpaperScene.resolve(nil) == scenes[0] && WallpaperScene.resolve("milky-way").id == "milky-way")
    }

    private func freshDefaults() -> UserDefaults {
        let name = "wallpaper-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func firstLaunchPicksOneSceneOnce() {
        let d = freshDefaults()
        WallpaperStore.seedFirstLaunch(defaults: d, pick: { _ in 4 })
        #expect(d.string(forKey: "settings.wallpaper.kind") == "scenery")
        #expect(d.string(forKey: "settings.wallpaper.scene") == WallpaperScene.all[4].id)
        #expect(d.double(forKey: "settings.wallpaper.dim") == WallpaperStore.seededDim)
        WallpaperStore.seedFirstLaunch(defaults: d, pick: { _ in 1 })
        #expect(d.string(forKey: "settings.wallpaper.scene") == WallpaperScene.all[4].id)
    }

    @Test func aStoredChoiceIsNeverReplaced() {
        let none = freshDefaults()
        none.set("none", forKey: "settings.wallpaper.kind")
        WallpaperStore.seedFirstLaunch(defaults: none, pick: { _ in 0 })
        #expect(none.string(forKey: "settings.wallpaper.kind") == "none" && none.string(forKey: "settings.wallpaper.scene") == nil)
        let gradient = freshDefaults()
        gradient.set("gradient", forKey: "settings.wallpaper.kind")
        WallpaperStore.seedFirstLaunch(defaults: gradient, pick: { _ in 0 })
        #expect(gradient.string(forKey: "settings.wallpaper.kind") == "gradient")
    }

    @Test func theRandomIndexIsKeptInRange() {
        for raw in [-5, 0, 3, 999] {
            let d = freshDefaults()
            WallpaperStore.seedFirstLaunch(defaults: d, pick: { _ in raw })
            #expect(WallpaperScene.all.map(\.id).contains(d.string(forKey: "settings.wallpaper.scene") ?? ""), Comment(rawValue: "\(raw)"))
        }
    }

    @Test func dimStaysInRange() {
        #expect(WallpaperStore.clamp(-1) == 0 && WallpaperStore.clamp(0.3) == 0.3 && WallpaperStore.clamp(5) == WallpaperStore.maxDim)
        #expect(WallpaperColor.rgb(WallpaperStore.defaultSolid) != nil)
    }

    @Test func titlesAreSet() {
        for k in WallpaperKind.allCases { #expect(!k.title.isEmpty) }
        for g in WallpaperGradient.allCases { #expect(!g.title.isEmpty) }
        for p in WallpaperPattern.allCases { #expect(!p.title.isEmpty) }
    }
}
