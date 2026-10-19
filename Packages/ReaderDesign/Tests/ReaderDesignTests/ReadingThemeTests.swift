import Testing
@testable import ReaderDesign

@Suite struct ReadingThemeTests {
    @Test(arguments: ReadingTheme.allCases)
    func textContrast(theme: ReadingTheme) {
        #expect(theme.text.contrast(with: theme.ground) >= 4.5)
        #expect(theme.secondaryText.contrast(with: theme.ground) >= 4.5)
    }

    @Test func unknownFallsBack() {
        #expect(ReadingTheme.resolve("nope") == .paper)
        #expect(ReadingTheme.resolve(nil) == .paper)
    }
}
