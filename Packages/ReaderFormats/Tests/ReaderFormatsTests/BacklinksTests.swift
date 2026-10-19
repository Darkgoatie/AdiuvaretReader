import Testing
@testable import ReaderFormats

@Suite struct BacklinksTests {
    private let paths = ["Index.md", "Notes/Alpha.md", "Notes/Beta.md", "Other/Alpha.md", "Gamma.md"]

    @Test func findsWikilinksAndEmbedsWithAliasesAndHeadings() {
        let index = VaultIndex(paths: paths)
        let notes: [(path: String, text: String)] = [
            ("Index.md", "# Index\nSee [[Gamma]] and more"),
            ("Notes/Alpha.md", "Plain text only"),
            ("Notes/Beta.md", "Alias [[Gamma|the third]] here"),
            ("Other/Alpha.md", "Embed ![[Gamma#Heading]]\n[[Gamma]] again"),
        ]
        let found = Backlinks.find(to: "Gamma.md", notes: notes, index: index)
        #expect(found.map(\.path) == ["Index.md", "Notes/Beta.md", "Other/Alpha.md"])
        #expect(found[1].snippet == "Alias [[Gamma|the third]] here")
    }

    @Test func aLinkMustResolveToTheSameFileNotJustTheSameName() {
        let index = VaultIndex(paths: paths)
        let notes: [(path: String, text: String)] = [("Notes/Beta.md", "Go to [[Alpha]]"), ("Index.md", "Go to [[Other/Alpha]]")]
        #expect(Backlinks.find(to: "Notes/Alpha.md", notes: notes, index: index).map(\.path) == ["Notes/Beta.md"])
        #expect(Backlinks.find(to: "Other/Alpha.md", notes: notes, index: index).map(\.path) == ["Index.md"])
    }

    @Test func aNoteDoesNotLinkBackToItself() {
        let index = VaultIndex(paths: paths)
        #expect(Backlinks.find(to: "Gamma.md", notes: [("Gamma.md", "I am [[Gamma]]")], index: index).isEmpty)
    }

    @Test func parsesSeveralTargetsOnOneLine() {
        #expect(Backlinks.targets(in: "[[A]] and [[B|x]] and [[C#h]] and [[D^id]]") == ["A", "B", "C", "D"])
        #expect(Backlinks.targets(in: "[[unclosed").isEmpty)
    }
}
