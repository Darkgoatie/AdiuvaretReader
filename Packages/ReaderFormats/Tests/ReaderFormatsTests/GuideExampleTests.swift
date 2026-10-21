import Testing
@testable import ReaderFormats

/// The example note in docs/FILE_FORMAT_GUIDE.md, rendered by the real renderer.
@Suite struct GuideExampleTests {
    private let note = "---\ntitle: Esterification\ntags: [chemistry, organic]\nchem-style: skeletal\n---\n\n# Esterification\n\nAn acid and an alcohol give an ester and water. See also [[Reaction rates#Catalysts]].\n\n$$\\ce{CH3COOH + C2H5OH <=> CH3COOC2H5 + H2O}$$\n\n> [!note] Conditions\n> Heat under reflux with a few drops of conc. $\\ce{H2SO4}$ as catalyst. ==Remove water== to push the equilibrium right.\n\n```smiles\ntitle: Reactants and product\nsize: small\nCC(=O)O acetic acid\nCCO ethanol\nCC(=O)OCC ethyl acetate\n```\n\n| Compound | M (g/mol) | bp (C) |\n|:---------|----------:|-------:|\n| Ethanol  | 46.07     | 78     |\n| Ethyl acetate | 88.11 | 77   |\n\n## Checklist\n\n- [x] Write the equation\n- [ ] Draw the mechanism[^1]\n\n[^1]: Use `style: explicit` to show every hydrogen."

    private var ctx: ObsidianContext {
        ObsidianContext(index: VaultIndex(paths: ["Esterification.md", "Reaction rates.md"]), currentPath: "Esterification.md",
                        fileURL: { _ in nil }, readNote: { _ in nil })
    }

    @Test func exampleNoteRendersEveryFeature() {
        let html = ObsidianMarkdown.page(title: "Esterification", source: note, ctx: ctx)
        #expect(html.contains("<h1 id=\"h-esterification\">"))
        #expect(html.contains("ob-properties") && html.contains("href=\"obsidian-tag:chemistry\""))
        #expect(html.contains("obsidian-note:Reaction%20rates#Catalysts"))
        #expect(html.contains("\\ce{CH3COOH + C2H5OH &lt;=&gt; CH3COOC2H5 + H2O}"))
        #expect(html.contains("callout co-note") && html.contains("<mark class=\"ob-hl\">Remove water</mark>"))
        #expect(html.contains("data-style=\"skeletal\"") && html.contains("data-width=\"200\""))
        #expect(html.contains("Reactants and product"))
        #expect(html.contains("CC(=O)OCC ethyl acetate"))
        #expect(html.contains("<table>") && html.contains("text-align:right"))
        #expect(html.contains("task-list-item is-checked") && html.contains("contains-task-list"))
        #expect(html.contains("class=\"fn-ref\"") && html.contains("<li id=\"fn-1\">"))
    }

    @Test func unresolvedLinksAreMarked() {
        let html = ObsidianMarkdown.renderBody("See [[Nowhere]]", ctx: ctx)
        #expect(html.contains("is-unresolved"))
    }

    @Test func documentedCalloutAliasesMapToTheirTypes() {
        let pairs = ["summary": "abstract", "tldr": "abstract", "hint": "tip", "important": "tip", "check": "success", "done": "success",
                     "help": "question", "faq": "question", "caution": "warning", "attention": "warning", "fail": "failure",
                     "missing": "failure", "error": "danger", "cite": "quote"]
        for (alias, type) in pairs {
            let html = ObsidianMarkdown.renderBody("> [!\(alias)] T\n> body", ctx: .empty)
            #expect(html.contains("callout co-\(type)"), "\(alias)")
        }
        #expect(ObsidianMarkdown.renderBody("> [!whatever] T\n> x", ctx: .empty).contains("callout co-note"))
        #expect(ObsidianMarkdown.renderBody("> [!faq]- T\n> x", ctx: .empty).contains("<details class=\"callout co-question\">"))
        #expect(ObsidianMarkdown.renderBody("> [!tip]+ T\n> x", ctx: .empty).contains("<details class=\"callout co-tip\" open>"))
    }

    @Test func documentedSmilesColonRule() throws {
        let b = try #require(ChemBlock.make(lang: "smiles", body: "[nH:1]1cccc1"))
        #expect(b.title.isEmpty && b.body == "[nH:1]1cccc1")
    }

    @Test func documentedMolfileExampleKeepsItsNameLine() throws {
        let body = "style: comic\nname: ethanal\n\n  Tool\n\n  3  2  0  0  0  0  0  0  0  0999 V2000\nM  END"
        let b = try #require(ChemBlock.make(lang: "mol", body: body))
        #expect(b.style == "comic" && b.title == "ethanal" && b.body.contains("Tool"))
    }

    @Test func propertiesFollowTheDocumentedRules() {
        let (props, body) = Frontmatter.split("---\ntitle: \"Quoted\"\ntags: a b\naliases:\n  - One\n  - Two\nlist: [x, y]\n---\nBody")
        #expect(props.first { $0.key == "title" }?.values == ["Quoted"])
        #expect(Frontmatter.tags(props) == ["a", "b"])
        #expect(props.first { $0.key == "aliases" }?.values == ["One", "Two"])
        #expect(props.first { $0.key == "list" }?.values == ["x", "y"])
        #expect(body == "Body")
        #expect(Frontmatter.split("---\njust text\n---\nx").properties.isEmpty)
    }

    @Test func tagsNeedANonDigitAndNotAWordBefore() {
        #expect(ObsidianInline.render("#plan-2024 and #nested/tag", ctx: .empty).contains("obsidian-tag:plan-2024"))
        #expect(!ObsidianInline.render("issue #2024", ctx: .empty).contains("ob-tag"))
        #expect(!ObsidianInline.render("a#b", ctx: .empty).contains("ob-tag"))
    }
}
