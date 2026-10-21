import Testing
@testable import ReaderFormats

@Suite struct EpubCSSMathTests {
    private var css: String {
        EpubCSS.make(text: "#222222", ground: "#FAF7F0", link: "#00AA77", fontStack: "serif", fontSize: 19, lineHeight: 1.5, sidePadding: 30, fontFileURL: nil)
    }

    @Test func screenReaderCopyOfMathStaysHiddenWithoutKatexStyleSheet() {
        #expect(css.contains(".katex-mathml{position:absolute!important;clip:rect(1px,1px,1px,1px)!important"))
    }

    @Test func pageRulesDoNotResizeOrRecolourKatexDrawings() {
        #expect(css.contains("svg:not(.katex svg)"))
        #expect(!css.contains("img,svg,video{"))
        // :where() keeps the rule at zero specificity, so highlights, tags and callouts can still set their own background.
        #expect(css.contains("body *:where(:not(.katex, .katex *)){color:inherit!important"))
        #expect(!css.contains("body *:not(.katex):not(.katex *){"))
    }
}
