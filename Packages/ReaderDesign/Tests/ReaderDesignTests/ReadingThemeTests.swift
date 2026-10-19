import Testing
@testable import ReaderDesign

@Suite struct ReadingThemeTests {
    @Test(arguments: ReadingTheme.allCases)
    func textContrast(theme: ReadingTheme) {
        #expect(theme.text.contrast(with: theme.ground) >= 4.5)
        #expect(theme.secondaryText.contrast(with: theme.ground) >= 4.5)
    }

    @Test(arguments: ReadingTheme.allCases)
    func codeAndLinkContrast(theme: ReadingTheme) {
        let p = CodePalette.for(theme)
        for c in [p.keyword, p.string, p.comment, p.number, p.text] { #expect(c.contrast(with: theme.ground) >= 4.5) }
        #expect(theme.link.contrast(with: theme.ground) >= 4.5)
    }

    @Test func unknownFallsBack() {
        #expect(ReadingTheme.resolve("nope") == .paper)
        #expect(ReadingTheme.resolve(nil) == .paper)
    }
}
