import Testing
import Foundation
@testable import ReaderDesign

@Suite struct ReadingThemeTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "test." + UUID().uuidString)! }

    @Test(arguments: ReadingTheme.allCases, AppTheme.allCases, [false, true])
    func textContrast(theme: ReadingTheme, app: AppTheme, dark: Bool) {
        let s = theme.surface(dark: dark, app: app)
        #expect(s.text.contrast(with: s.ground) >= 4.5)
        #expect(s.secondaryText.contrast(with: s.ground) >= 4.5)
        #expect(s.link.contrast(with: s.ground) >= 4.5)
    }

    @Test(arguments: ReadingTheme.allCases, AppTheme.allCases, [false, true])
    func codeContrast(theme: ReadingTheme, app: AppTheme, dark: Bool) {
        let s = theme.surface(dark: dark, app: app)
        let p = s.code
        for c in [p.keyword, p.string, p.comment, p.number, p.text] { #expect(c.contrast(with: s.ground) >= 4.5) }
    }

    @Test(arguments: AppTheme.allCases)
    func matchAppUsesTheAppsOwnColoursInBothAppearances(app: AppTheme) {
        let p = app.palette
        let light = ReadingTheme.auto.surface(dark: false, app: app)
        let dark = ReadingTheme.auto.surface(dark: true, app: app)
        #expect(light.ground == p.background.light && light.text == p.textPrimary.light && !light.isDark)
        #expect(dark.ground == p.background.dark && dark.text == p.textPrimary.dark && dark.isDark)
    }

    @Test func darkAppGivesLightTextOnADarkGroundAndLightAppTheOpposite() {
        let dark = ReadingTheme.auto.surface(dark: true, app: .adiuvaret)
        let light = ReadingTheme.auto.surface(dark: false, app: .adiuvaret)
        #expect(dark.text.luminance > 0.5 && dark.ground.luminance < 0.1)
        #expect(light.text.luminance < 0.1 && light.ground.luminance > 0.5)
    }

    @Test func fixedThemesIgnoreTheAppearance() {
        for theme in [ReadingTheme.paper, .sepia, .dark] {
            #expect(theme.surface(dark: true, app: .ocean) == theme.surface(dark: false, app: .graphite))
            #expect(theme.isFixed)
        }
        #expect(!ReadingTheme.auto.isFixed)
        #expect(ReadingTheme.dark.surface(dark: false, app: .adiuvaret).isDark)
        #expect(!ReadingTheme.paper.surface(dark: true, app: .adiuvaret).isDark)
    }

    @Test func matchAppIsTheDefaultAndUnknownFallsBackToIt() {
        #expect(ReadingTheme.default == .auto)
        #expect(ReadingTheme.resolve("nope") == .auto)
        #expect(ReadingTheme.resolve(nil) == .auto)
        #expect(ReadingTheme.resolve("sepia") == .sepia)
    }

    @Test func oldStoredThemesMigrate() {
        let paper = defaults(); paper.set("paper", forKey: "reader.theme")
        #expect(ReaderPreferences.storedTheme(paper) == .auto)
        let sepia = defaults(); sepia.set("sepia", forKey: "reader.theme")
        #expect(ReaderPreferences.storedTheme(sepia) == .sepia)
        let dark = defaults(); dark.set("dark", forKey: "reader.theme")
        #expect(ReaderPreferences.storedTheme(dark) == .dark)
        #expect(ReaderPreferences.storedTheme(defaults()) == .auto)
    }

    @Test func aNewChoiceIsKeptAndWinsOverTheOldKey() {
        let d = defaults(); d.set("sepia", forKey: "reader.theme")
        let p = ReaderPreferences(defaults: d)
        #expect(p.theme == .sepia)
        p.theme = .paper
        #expect(ReaderPreferences(defaults: d).theme == .paper)
        p.theme = .auto
        #expect(ReaderPreferences(defaults: d).theme == .auto)
    }

    @Test func prefsSurfaceFollowsTheAppearance() {
        let p = ReaderPreferences(defaults: defaults())
        #expect(p.theme == .auto)
        #expect(p.surface(dark: true).isDark && !p.surface(dark: false).isDark)
        p.theme = .sepia
        #expect(!p.surface(dark: true).isDark)
    }

    @Test func invertedGroundForPdfPages() {
        let s = ReadingTheme.dark.surface(dark: true, app: .adiuvaret)
        #expect(s.invertedGroundColor != s.groundColor)
    }
}
