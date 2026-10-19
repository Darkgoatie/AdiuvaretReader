import Foundation

public enum LatexConverter {
    /// A readable Markdown form of a LaTeX document: sections, lists, emphasis and math are kept, the preamble and layout commands are dropped.
    public static func toMarkdown(_ source: String) -> String {
        var s = source.replacingOccurrences(of: "\r\n", with: "\n")
        s = replace(s, #"(?<!\\)%[^\n]*"#, "")
        var title = "", author = ""
        if let t = capture(s, #"\\title\{([^}]*)\}"#) { title = t }
        if let a = capture(s, #"\\author\{([^}]*)\}"#) { author = a }
        if let r = s.range(of: "\\begin{document}") { s = String(s[r.upperBound...]) }
        if let r = s.range(of: "\\end{document}") { s = String(s[..<r.lowerBound]) }
        s = replace(s, #"\\begin\{(equation|equation\*|displaymath)\}(.*?)\\end\{\1\}"#, "\n\n$$$2$$\n\n", dotAll: true)
        s = replace(s, #"\\begin\{(align|align\*|aligned|gather|gather\*|multline|multline\*|eqnarray\*?)\}(.*?)\\end\{\1\}"#, "\n\n$$\\begin{aligned}$2\\end{aligned}$$\n\n", dotAll: true)
        s = replace(s, #"\\\[(.*?)\\\]"#, "\n\n$$$1$$\n\n", dotAll: true)
        s = replace(s, #"\\chapter\*?\{([^}]*)\}"#, "\n\n# $1\n\n")
        s = replace(s, #"\\subsubsection\*?\{([^}]*)\}"#, "\n\n#### $1\n\n")
        s = replace(s, #"\\subsection\*?\{([^}]*)\}"#, "\n\n### $1\n\n")
        s = replace(s, #"\\section\*?\{([^}]*)\}"#, "\n\n## $1\n\n")
        s = replace(s, #"\\begin\{abstract\}"#, "\n\n**Abstract.** ")
        s = replace(s, #"\\end\{abstract\}"#, "\n\n")
        s = replace(s, #"\\begin\{(itemize|enumerate)\}"#, "\n")
        s = replace(s, #"\\end\{(itemize|enumerate)\}"#, "\n")
        s = replace(s, #"\\item\s*"#, "\n- ")
        s = replace(s, #"\\(textbf|mathbf)\{([^}]*)\}"#, "**$2**")
        s = replace(s, #"\\(emph|textit)\{([^}]*)\}"#, "*$2*")
        s = replace(s, #"\\texttt\{([^}]*)\}"#, "`$1`")
        s = replace(s, #"\\(label|cite|ref|eqref|usepackage|documentclass|maketitle|tableofcontents|newpage|clearpage|centering|noindent|vspace|hspace)(\[[^\]]*\])?(\{[^}]*\})?"#, "")
        s = s.replacingOccurrences(of: "\\\\", with: "\n").replacingOccurrences(of: "~", with: " ")
        s = s.replacingOccurrences(of: "``", with: "\u{201C}").replacingOccurrences(of: "\'\'", with: "\u{201D}")
        s = replace(s, #"\n{3,}"#, "\n\n")
        var head = ""
        if !title.isEmpty { head += "# \(title)\n\n" }
        if !author.isEmpty { head += "\(author)\n\n" }
        return head + s.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func replace(_ s: String, _ pattern: String, _ template: String, dotAll: Bool = false) -> String {
        var options: NSRegularExpression.Options = []
        if dotAll { options.insert(.dotMatchesLineSeparators) }
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }

    private static func capture(_ s: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern), let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }
}
