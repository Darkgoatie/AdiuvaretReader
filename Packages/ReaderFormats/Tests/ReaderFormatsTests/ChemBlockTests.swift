import Testing
@testable import ReaderFormats

@Suite struct ChemBlockTests {
    @Test func recognisesMoleculeFencesOnly() {
        for l in ["smiles", "SMILES", "smi", "mol", "molfile", "smiles extra"] { #expect(ChemBlock.isChemFence(l)) }
        for l in ["", "swift", "mermaid", "smile", "chem"] { #expect(!ChemBlock.isChemFence(l)) }
        #expect(ChemBlock.make(lang: "python", body: "x") == nil)
    }

    @Test func readsOptionsAboveTheMolecule() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "style: bw\nhydrogens: explicit\ntitle: Aspirin\nsize: large\nnumbers: true\nhighlight: 0, 3 5\nCC(=O)O"))
        #expect(b.style == "bw" && b.hydrogens == "explicit" && b.title == "Aspirin" && b.width == 420 && b.numbers)
        #expect(b.highlight == [0, 3, 5])
        #expect(b.body == "CC(=O)O" && !b.isMol)
    }

    @Test func aMoleculeWithAColonIsNotMistakenForAnOption() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "CC(=O)O aspirin: pain relief\nC=O"))
        #expect(b.title.isEmpty)
        #expect(b.body == "CC(=O)O aspirin: pain relief\nC=O")
    }

    @Test func styleNamesAndAliasesResolve() {
        #expect(ChemBlock.normalizeStyle("Skeletal") == "skeletal")
        #expect(ChemBlock.normalizeStyle("kekule") == "explicit")
        #expect(ChemBlock.normalizeStyle("Colour") == "color")
        #expect(ChemBlock.normalizeStyle("print") == "bw")
        #expect(ChemBlock.normalizeStyle("sketch") == "comic")
        #expect(ChemBlock.normalizeStyle("3d") == nil)
        for s in ChemBlock.styles { #expect(ChemBlock.normalizeStyle(s) == s) }
    }

    @Test func noteDefaultAppliesUntilTheBlockOverridesIt() throws {
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "CCO", defaultStyle: "kekule")).style == "explicit")
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "style: comic\nCCO", defaultStyle: "kekule")).style == "comic")
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "CCO", defaultStyle: "nonsense")).style == "skeletal")
    }

    @Test func unknownStyleFallsBackAndSaysSo() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "style: ball-and-stick\nCCO"))
        #expect(b.style == "skeletal" && b.unknownStyle == "ball-and-stick")
        #expect(b.html().contains("Unknown style"))
        #expect(!(try #require(ChemBlock.make(lang: "smiles", body: "style: bold\nCCO")).html().contains("Unknown style")))
    }

    @Test func widthIsClampedAndBadValuesIgnored() throws {
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "width: 99999\nC")).width == 700)
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "width: 5\nC")).width == 120)
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "width: 250px\nC")).width == 250)
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "width: wide\nC")).width == 300)
        #expect(try #require(ChemBlock.make(lang: "smiles", body: "highlight: 0, -4, 99999, x\nC")).highlight == [0])
    }

    @Test func molfilesKeepTheirHeaderLineAndOnlyTakeKnownOptions() throws {
        let molfile = "style: comic\nname: ethanal\n\n  Tool\n\n  1  0  0  0  0  0  0  0  0  0999 V2000\nM  END"
        let b = try #require(ChemBlock.make(lang: "mol", body: molfile))
        #expect(b.isMol && b.style == "comic" && b.title == "ethanal")
        #expect(b.body.hasSuffix("M  END") && b.body.contains("V2000"))
        let free = try #require(ChemBlock.make(lang: "mol", body: "Aspirin: from the lab\n  Tool\n\nM  END"))
        #expect(free.body.hasPrefix("Aspirin: from the lab"))
    }

    @Test func htmlEscapesEverythingTheUserWrote() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "title: <b>x</b> & \"y\"\nC<C"))
        let h = b.html()
        #expect(!h.contains("<b>") && h.contains("&lt;b&gt;x&lt;/b&gt;") && h.contains("&amp;"))
        #expect(h.contains("C&lt;C"))
        #expect(h.hasPrefix("<figure class=\"chem-block\" data-lang=\"smiles\" data-style=\"skeletal\" data-width=\"300\""))
    }

    @Test func noteRendersMoleculeBlocksAndTheChemStyleProperty() {
        let src = "---\nchem-style: bw\n---\n# T\n\n```smiles\ntitle: Water\nO\n```\n\n```smiles\nstyle: color\nCCO\n```\n\n```swift\nlet x = 1\n```\n"
        let html = ObsidianMarkdown.page(title: "T", source: src, ctx: .empty)
        #expect(html.contains("data-style=\"bw\"") && html.contains("data-style=\"color\""))
        #expect(html.contains("Water") && html.contains("class=\"chem-src\""))
        #expect(html.contains("language-swift"))
        #expect(!html.contains("language-smiles"))
    }
}
