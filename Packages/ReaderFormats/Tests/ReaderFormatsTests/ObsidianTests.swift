import Testing
import Foundation
@testable import ReaderFormats

@Suite struct ObsidianTests {
    private let paths = ["Notes/Algorithm Notes.md", "Meeting Notes 2024-01-10.md", "Images/Architecture Diagram.png", "Docs/Paper.pdf", "A/Same.md", "B/Deep/Same.md", "Home.md"]

    private func ctx(_ current: String = "Home.md", notes: [String: String] = [:]) -> ObsidianContext {
        ObsidianContext(index: VaultIndex(paths: paths), currentPath: current,
                        fileURL: { "file:///vault/" + $0.replacingOccurrences(of: " ", with: "%20") },
                        readNote: { notes[$0] })
    }

    private func html(_ md: String, notes: [String: String] = [:]) -> String {
        ObsidianMarkdown.page(title: "t", source: md, ctx: ctx(notes: notes))
    }

    // MARK: properties

    @Test func frontmatterProperties() {
        let src = "---\ntitle: \"My Note\"\ntags:\n  - project\n  - active\naliases: [Alt One, \"Alt Two\"]\nstatus: in-progress\n---\n# Body"
        let (props, body) = Frontmatter.split(src)
        #expect(body == "# Body")
        #expect(props.first { $0.key == "title" }?.values == ["My Note"])
        #expect(Frontmatter.tags(props) == ["project", "active"])
        #expect(props.first { $0.key == "aliases" }?.values == ["Alt One", "Alt Two"])
        #expect(props.first { $0.key == "status" }?.isList == false)
        #expect(Frontmatter.split("---\nnot yaml\n---\ntext").properties.isEmpty)
        #expect(Frontmatter.split("no frontmatter").body == "no frontmatter")
    }

    @Test func propertiesPanelAndCssclassesHidden() {
        let out = html("---\ntags: [a, b]\ncssclasses: [wide]\ndate: 2024-01-15\n---\nText")
        #expect(out.contains("class=\"ob-properties\""))
        #expect(out.contains("href=\"obsidian-tag:a\""))
        #expect(out.contains("2024-01-15"))
        #expect(!out.contains("cssclasses"))
    }

    // MARK: links

    @Test func wikilinksResolveWithAliasAndHeading() {
        let out = html("See [[Algorithm Notes]] and [[Algorithm Notes|the algorithm]] and [[Algorithm Notes#Sorting]] and [[Missing Note]].")
        #expect(out.contains("href=\"obsidian-note:Notes/Algorithm%20Notes.md\">Algorithm Notes</a>"))
        #expect(out.contains(">the algorithm</a>"))
        #expect(out.contains("href=\"obsidian-note:Notes/Algorithm%20Notes.md#Sorting\">Algorithm Notes &gt; Sorting</a>"))
        #expect(out.contains("is-unresolved\" href=\"obsidian-missing:Missing%20Note\">Missing Note</a>"))
    }

    @Test func sameNoteHeadingLinkAndAnchors() {
        let out = html("# Top Section\n\nGo to [[#Top Section]].")
        #expect(out.contains("<h1 id=\"h-top-section\">Top Section</h1>"))
        #expect(out.contains("href=\"#h-top-section\">Top Section</a>"))
    }

    @Test func nearestDuplicateWins() {
        let index = VaultIndex(paths: paths)
        #expect(index.resolve("Same", from: "B/Deep/x.md") == "B/Deep/Same.md")
        #expect(index.resolve("Same", from: "A/x.md") == "A/Same.md")
        #expect(index.resolve("same") != nil)
        #expect(index.resolve("Docs/Paper.pdf") == "Docs/Paper.pdf")
        #expect(index.resolve("nothing") == nil)
        #expect(index.resolve("../Home", from: "Notes/x.md") == "Home.md")
    }

    @Test func markdownLinks() {
        let out = html("[site](https://example.com) and [note](Notes/Algorithm%20Notes.md) and [gone](nope.md)")
        #expect(out.contains("<a href=\"https://example.com\">site</a>"))
        #expect(out.contains("href=\"obsidian-note:Notes/Algorithm%20Notes.md\">note</a>"))
        #expect(out.contains("is-unresolved"))
    }

    // MARK: embeds

    @Test func imageEmbedWithWidth() {
        let out = html("![[Architecture Diagram.png|300]]")
        #expect(out.contains("<img class=\"ob-img\" src=\"file:///vault/Images/Architecture%20Diagram.png\""))
        #expect(out.contains("width=\"300\""))
        #expect(html("![[nope.png]]").contains("Image not found: nope.png"))
        #expect(html("![alt|200](https://x.com/a.png)").contains("Online image not loaded"))
    }

    @Test func noteAndSectionAndBlockEmbeds() {
        let notes = ["Notes/Algorithm Notes.md": "# Sorting\nQuick sort is fast.\n\n# Searching\nBinary search.\n\nA tagged line. ^key-line\n"]
        let section = html("![[Algorithm Notes#Sorting]]", notes: notes)
        #expect(section.contains("Quick sort is fast."))
        #expect(!section.contains("Binary search"))
        let block = html("![[Algorithm Notes#^key-line]]", notes: notes)
        #expect(block.contains("A tagged line."))
        #expect(!block.contains("^key-line"))
        let whole = html("![[Algorithm Notes]]", notes: notes)
        #expect(whole.contains("class=\"ob-embed\"") && whole.contains("Binary search"))
        #expect(html("![[Missing]]").contains("Note not found: Missing"))
        #expect(html("![[Algorithm Notes#Nope]]", notes: notes).contains("Section not found: Nope"))
    }

    @Test func pdfEmbedLinksToPage() {
        #expect(html("![[Paper.pdf#page=3]]").contains("href=\"obsidian-note:Docs/Paper.pdf#page=3\">Paper.pdf, page 3</a>"))
    }

    @Test func embedsCannotLoopForever() {
        let notes = ["Home.md": "Again ![[Home]]"]
        let out = html("![[Home]]", notes: notes)
        #expect(out.contains("nested too deeply"))
    }

    // MARK: formatting

    @Test func highlightTagsAndComments() {
        let out = html("This is ==important== and #project/alpha here. %%hidden%% shown\n\n%%\nwhole block\n%%\n\nAfter")
        #expect(out.contains("<mark class=\"ob-hl\">important</mark>"))
        #expect(out.contains("href=\"obsidian-tag:project/alpha\">#project/alpha</a>"))
        #expect(!out.contains("hidden") && !out.contains("whole block"))
        #expect(out.contains("shown") && out.contains("After"))
    }

    @Test func tagRulesMatchObsidian() {
        let out = html("Issue #123 is not a tag, but #v2 is. Colour #FF0000? Heading#nope. A url http://x.com/a#frag. \\#escaped")
        #expect(!out.contains("obsidian-tag:123"))
        #expect(out.contains("obsidian-tag:v2"))
        #expect(!out.contains("obsidian-tag:nope"))
        #expect(!out.contains("obsidian-tag:frag"))
        #expect(!out.contains("obsidian-tag:escaped"))
    }

    @Test func calloutsWithAliasesTitlesAndFolding() {
        let out = html("> [!warning] Custom Title\n> Body text\n\n> [!faq]- Closed one\n> Hidden\n\n> [!tip]+ Open one\n> Visible\n\n> [!important]\n> Alias of tip\n\n> plain quote")
        #expect(out.contains("callout co-warning"))
        #expect(out.contains("Custom Title"))
        #expect(out.contains("<details class=\"callout co-question\">"))
        #expect(out.contains("<details class=\"callout co-tip\" open>"))
        #expect(out.contains("callout co-tip\"><div class=\"co-head\">") && out.contains(">Important<"))
        #expect(out.contains("<blockquote>"))
    }

    @Test func nestedCallouts() {
        let out = html("> [!note] Outer\n> text\n> > [!tip] Inner\n> > inside")
        #expect(out.contains("co-note") && out.contains("co-tip") && out.contains("inside"))
    }

    @Test func tasksAndNestedLists() {
        let out = html("- [x] Initial planning\n- [ ] Development phase\n  - [ ] Backend implementation\n  - [x] Frontend design\n- plain item\n\n1. one\n2. two")
        #expect(out.contains("contains-task-list"))
        #expect(out.contains("is-checked\"><span class=\"task-box\" role=\"checkbox\" aria-checked=\"true\">"))
        #expect(out.contains("Backend implementation"))
        #expect(out.contains("<ol>"))
        #expect(out.components(separatedBy: "<ul").count >= 3)
    }

    @Test func tablesWithAlignment() {
        let out = html("| Name | Qty |\n|:-----|----:|\n| Apple | 3 |\n| Pear | 12 |")
        #expect(out.contains("<th style=\"text-align:left\">Name</th>"))
        #expect(out.contains("<td style=\"text-align:right\">12</td>"))
        let piped = html("| A | B |\n|---|---|\n| [[Home\\|x]] | y |")
        #expect(piped.contains("<td>"))
    }

    @Test func footnotes() {
        let out = html("Text with a note[^1] and inline.^[Inline text]\n\n[^1]: Footnote content.\n")
        #expect(out.contains("class=\"fn-ref\"><a href=\"#fn-1\""))
        #expect(out.contains("<li id=\"fn-1\">Footnote content."))
        #expect(out.contains("title=\"Inline text\""))
        #expect(!out.contains("[^1]:"))
    }

    @Test func blockIdsAndRules() {
        let out = html("This paragraph can be linked to. ^my-block-id\n\n---\n\nNext")
        #expect(out.contains("<p id=\"^my-block-id\">This paragraph can be linked to.</p>"))
        #expect(out.contains("<hr>"))
    }

    @Test func mathCodeAndMermaidAreProtected() {
        let out = html("Inline $a_1 * b_2 ==x==$ and `==code== #notatag`.\n\n$$\n\\frac{a}{b} = c\n$$\n\n```swift\nlet x = ==1== // #nope\n```\n\n```mermaid\ngraph TD\n A-->B\n```")
        #expect(out.contains("$a_1 * b_2 ==x==$"))
        #expect(out.contains("<code>==code== #notatag</code>"))
        #expect(out.contains("<div class=\"math-block\">$$\n\\frac{a}{b} = c\n$$</div>"))
        #expect(out.contains("let x = ==1== // #nope"))
        #expect(out.contains("ob-mermaid"))
        #expect(!out.contains("obsidian-tag:nope") && !out.contains("obsidian-tag:notatag"))
    }

    @Test func escapesAndEmphasis() {
        let out = html("**bold** *it* _it2_ ***both*** ~~gone~~ \\*literal\\* snake_case_word 2*3*4")
        #expect(out.contains("<strong>bold</strong>") && out.contains("<em>it</em>") && out.contains("<em>it2</em>"))
        #expect(out.contains("<strong><em>both</em></strong>") && out.contains("<del>gone</del>"))
        #expect(out.contains("*literal*"))
        #expect(out.contains("snake_case_word"))
    }

    @Test func fullExampleFromObsidianHelp() {
        let md = "---\ntitle: Project Alpha\ndate: 2024-01-15\ntags:\n  - project\n  - active\nstatus: in-progress\n---\n\n# Project Alpha\n\nThis project aims to [[improve workflow]] using modern techniques.\n\n> [!important] Key Deadline\n> The first milestone is due on ==January 30th==.\n\n## Tasks\n\n- [x] Initial planning\n- [ ] Development phase\n  - [ ] Backend implementation\n\n## Notes\n\nThe algorithm uses $O(n \\log n)$ sorting. See [[Algorithm Notes#Sorting]] for details.\n\n![[Architecture Diagram.png|600]]\n\nReviewed in [[Meeting Notes 2024-01-10#Decisions]].\n"
        let out = html(md)
        #expect(out.contains("<h1 id=\"h-project-alpha\">") && out.contains("<h2 id=\"h-tasks\">"))
        #expect(out.contains("co-tip") && out.contains("<mark class=\"ob-hl\">January 30th</mark>"))
        #expect(out.contains("$O(n \\log n)$"))
        #expect(out.contains("width=\"600\""))
        #expect(out.contains("improve workflow</a>") && out.contains("is-unresolved"))
        #expect(out.contains("obsidian-note:Meeting%20Notes%202024-01-10.md#Decisions"))
    }

    @Test func crlfFilesRender() {
        #expect(html("---\r\ntags: [a]\r\n---\r\n# Title\r\n\r\nText").contains("<h1 id=\"h-title\">Title</h1>"))
    }

    // MARK: tags and sections

    @Test func tagIndexAndNestedMatching() {
        let tags = TagIndex.tags(in: "---\ntags: [project]\n---\nBody #todo/home and `#code` and $#math$\n\n```\n#fenced\n```\n[[Note#Heading]] #todo/home")
        #expect(tags == ["project", "todo/home"])
        #expect(TagIndex.matches(tags, query: "#todo"))
        #expect(TagIndex.matches(tags, query: "todo/home"))
        #expect(!TagIndex.matches(tags, query: "#tod"))
        #expect(!TagIndex.matches(tags, query: "#"))
    }

    @Test func sectionExtraction() {
        let src = "# A\nalpha\n## A1\nsub\n# B\nbeta\n```\n# not a heading\n```\n"
        #expect(NoteSections.heading(in: src, named: "A")?.joined(separator: "\n").contains("sub") == true)
        #expect(NoteSections.heading(in: src, named: "A1")?.contains("beta") == false)
        #expect(NoteSections.heading(in: src, named: "B")?.contains("# not a heading") == true)
        #expect(NoteSections.heading(in: src, named: "Z") == nil)
        #expect(NoteSections.block(in: "Para one ^id1\nsecond line\n\nOther", id: "id1")?.first == "Para one")
        #expect(NoteSections.block(in: "> quote\n\n^qid\n", id: "qid") == ["> quote"])
    }

    @Test func slugs() {
        #expect(Slug.make("Hello, World! 2") == "hello-world-2")
        #expect(Slug.make("  Édition  ") == "édition")
    }
}
