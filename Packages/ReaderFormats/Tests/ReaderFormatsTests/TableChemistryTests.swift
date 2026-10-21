import Testing
@testable import ReaderFormats

@Suite struct TableChemistryTests {
    private func render(_ md: String) -> String { ObsidianMarkdown.renderBody(md, ctx: .empty) }

    @Test func reactionLinesAreRecognised() {
        #expect(ChemBlock.isReactionLine("CC(=O)O.OCC>>CC(=O)OCC.O"))
        #expect(ChemBlock.isReactionLine("CCO>[Cr]>CC=O"))
        #expect(!ChemBlock.isReactionLine("CCO"))
        #expect(!ChemBlock.isReactionLine(">>CC"))
        #expect(!ChemBlock.isReactionLine("A>B>C>D"))
    }

    @Test func aBlockOfReactionLinesIsMarkedAsAReaction() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "arrow: equilibrium\nconditions: H2SO4 | heat\nCC(=O)O.OCC>>CC(=O)OCC.O"))
        #expect(b.isReaction && b.arrow == "reversible" && b.conditions == "H2SO4 | heat")
        let html = b.html()
        #expect(html.contains("data-reaction=\"1\"") && html.contains("data-arrow=\"reversible\"") && html.contains("data-conditions=\"H2SO4 | heat\""))
    }

    @Test func aPlainMoleculeBlockIsNotAReaction() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "CCO ethanol\nCC(=O)O"))
        #expect(!b.isReaction && !b.html().contains("data-reaction"))
        let mol = try #require(ChemBlock.make(lang: "mol", body: "x>>y"))
        #expect(!mol.isReaction)
    }

    @Test func arrowOptionsAndAliases() throws {
        for (word, arrow) in [("reversible", "reversible"), ("both", "reversible"), ("<=>", "reversible"), ("back", "back"), ("<-", "back"), ("forward", "forward"), ("x", "forward")] {
            let b = try #require(ChemBlock.make(lang: "smiles", body: "arrow: \(word)\nA>>B"))
            #expect(b.arrow == arrow, Comment(rawValue: word))
        }
    }

    @Test func structureCellsAreMarkedForDrawing() {
        let html = render("| Name | Structure |\n|---|---|\n| Ethanol | smiles:CCO |\n| Aspirin | `smi:CC(=O)Oc1ccccc1C(=O)O` |")
        #expect(html.contains("class=\"chem-cell\" data-kind=\"mol\"") && html.contains("data-src=\"CCO\""))
        #expect(html.contains("data-src=\"CC(=O)Oc1ccccc1C(=O)O\""))
    }

    @Test func reactionCellsAreMarkedWithOrWithoutAPrefix() {
        let html = render("| Step | Scheme |\n|---|---|\n| 1 | rxn:CC(=O)O.OCC>>CC(=O)OCC.O |\n| 2 | CC(=O)O.OCC>>CC(=O)OCC.O |")
        #expect(html.components(separatedBy: "data-kind=\"rxn\"").count == 3)
    }

    @Test func aColumnCalledSmilesNeedsNoPrefixAndItsHeaderStaysText() {
        let html = render("| Name | SMILES |\n|---|---|\n| Water | O |")
        #expect(html.contains("data-kind=\"mol\"") && html.contains("data-src=\"O\""))
        #expect(html.contains("<th>SMILES</th>"))
    }

    @Test func ordinaryCellsAreNotStructures() {
        let html = render("| A | B |\n|---|---|\n| smiles: has spaces | text |\n| CCO | plain |")
        #expect(!html.contains("chem-cell"))
    }

    @Test func structureCellsFollowTheNotesDefaultStyle() {
        let html = render("---\nchem-style: bw\n---\n| A |\n|---|\n| smiles:CCO |")
        #expect(html.contains("data-style=\"bw\""))
    }

    @Test func barsInsideFormulasStayInTheirCell() {
        let cells = ObsidianMarkdown.splitRow("| $|x|$ | $P(A|B)$ | plain |")
        #expect(cells.count == 3)
        #expect(cells[0].trimmingCharacters(in: .whitespaces) == "$|x|$")
        #expect(cells[1].trimmingCharacters(in: .whitespaces) == "$P(A|B)$")
        #expect(ObsidianMarkdown.splitRow("| a \\| b | c |").count == 2)
        #expect(ObsidianMarkdown.splitRow("| costs $5 | and $6 |").count == 2)
        #expect(ObsidianMarkdown.splitRow("| `a|b` | c |").count == 3)
    }

    @Test func formulasInTableCellsKeepTheirDelimiters() {
        let html = render("| f | value |\n|---|---|\n| $x^2$ | 4 |")
        #expect(html.contains("<td>$x^2$</td>") || html.contains("$x^2$"))
    }

    @Test func bareLatexInACellIsTypeset() {
        #expect(TableCell.bareLatex("\\frac{a}{b}") == "\\frac{a}{b}")
        #expect(TableCell.bareLatex("x \\to \\infty") == "x \\to \\infty")
        #expect(TableCell.bareLatex("C:\\Users\\halit") == nil)
        #expect(TableCell.bareLatex("see \\frac{a}{b} in the previous chapter") == nil)
        #expect(TableCell.bareLatex("\\unknowncommand{x}") == nil)
        #expect(TableCell.bareLatex("$\\frac{a}{b}$") == nil)
        let html = render("| f |\n|---|\n| \\frac{a}{b} |")
        #expect(html.contains("<td>$\\frac{a}{b}$</td>"))
    }

    @Test func mathMaskIgnoresPricesAndCodeSpans() {
        func on(_ s: String) -> Int { TableCell.mathMask(Array(s)).filter { $0 }.count }
        #expect(on("$x$") == 3)
        #expect(on("costs $5 and $6") == 0)
        #expect(on("`$x$`") == 0)
        #expect(on("\\$x\\$") == 0)
        #expect(on("\\(a\\)") == 5)
    }
}
