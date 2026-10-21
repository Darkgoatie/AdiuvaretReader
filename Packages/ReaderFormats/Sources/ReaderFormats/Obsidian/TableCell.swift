import Foundation

/// What a table cell holds. A cell may carry a structure (`smiles:CCO`), a reaction (`smiles:CC>>CCO` or `rxn:`), a formula in LaTeX
/// without dollar signs, or ordinary text. Formulas written with dollar signs are left to the inline renderer.
enum TableCell {
    case text(String)
    case molecule(String)
    case reaction(String)

    private static let prefixes = ["smiles:", "smi:", "rxn:", "reaction:", "reaktion:"]
    private static let smilesHeaders: Set<String> = ["smiles", "smi", "smiles string", "canonical smiles", "isomeric smiles", "smiles-string"]
    private static let smilesCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@+-[]()=#/\\.%>:*")
    static let maxSource = 4000

    /// The commands a cell with no dollar signs may hold and still be read as a formula.
    private static let latexCommands: Set<String> = Set("""
        frac dfrac tfrac sqrt sum prod int oint lim infty partial nabla cdot times div pm mp leq geq neq approx equiv sim to rightarrow leftarrow Rightarrow
        Leftarrow leftrightarrow alpha beta gamma delta epsilon varepsilon theta lambda mu nu pi rho sigma tau phi varphi chi psi omega Gamma Delta Theta
        Lambda Pi Sigma Phi Psi Omega mathbb mathcal mathbf mathrm text vec hat bar overline left right begin end log ln sin cos tan exp min max det in
        notin subset subseteq cup cap forall exists neg land lor ldots cdots binom xrightarrow ce
        """.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))

    /// `header` is the header of the cell's column. A column called SMILES holds structures without a prefix. A header cell is never a structure.
    static func classify(_ cell: String, header: String, isHeader: Bool) -> TableCell {
        let c = cell.trimmingCharacters(in: .whitespaces)
        if !isHeader, let source = structure(c, header: header) {
            return ChemBlock.isReactionLine(source) ? .reaction(source) : .molecule(source)
        }
        return .text(cell)
    }

    private static func structure(_ cell: String, header: String) -> String? {
        var body = cell
        if body.hasPrefix("`"), body.hasSuffix("`"), body.count > 2 { body = String(body.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces) }
        let lower = body.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            let rest = body.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            guard !rest.isEmpty, rest.count <= maxSource, !rest.contains(where: { $0.isWhitespace }) else { return nil }
            return rest
        }
        guard !body.isEmpty, body.count <= maxSource, !body.contains(where: { $0.isWhitespace }) else { return nil }
        if smilesHeaders.contains(header.trimmingCharacters(in: .whitespaces).lowercased()) { return body }
        // A reaction needs no prefix: reactants>agents>products made only of SMILES characters.
        if ChemBlock.isReactionLine(body), body.count >= 6, body.allSatisfy({ smilesCharacters.contains($0) }), body.contains(where: { $0.isLetter }) { return body }
        return nil
    }

    /// A cell written in LaTeX with no dollar signs, such as `\frac{a}{b}` or `x \to \infty`. Text with a command in the middle of a sentence, a path
    /// such as `C:\Users\x`, and anything with a command the typesetter does not know stay text.
    static func bareLatex(_ s: String) -> String? {
        guard !s.contains("$"), s.contains("\\") else { return nil }
        let c = Array(s)
        var i = 0
        var found = false
        var rest = ""
        while i < c.count {
            if c[i] == "\\", i + 1 < c.count {
                var j = i + 1
                while j < c.count, c[j].isASCII, c[j].isLetter { j += 1 }
                if j > i + 1 {
                    guard latexCommands.contains(String(c[(i + 1)..<j])) else { return nil }
                    found = true
                    rest += " "
                    i = j
                    continue
                }
                i += 2
                continue
            }
            rest.append(c[i])
            i += 1
        }
        guard found else { return nil }
        let longWords = rest.split(whereSeparator: { !$0.isLetter }).filter { $0.count >= 4 }
        return longWords.isEmpty ? s : nil
    }

    /// For each character: whether it sits inside a formula (`$..$`, `$$..$$`, `\(..\)`, `\[..\]`). A table splits its cells with this, so the
    /// bars inside `$|x|$` or `$P(A|B)$` do not cut a cell in two. Prices, lone dollar signs and code spans are not formulas.
    static func mathMask(_ c: [Character]) -> [Bool] {
        var mask = [Bool](repeating: false, count: c.count)
        func mark(_ from: Int, _ to: Int) { for k in from...to { mask[k] = true } }
        func find(_ needle: [Character], from start: Int) -> Int? {
            guard start >= 0, c.count >= needle.count else { return nil }
            var j = start
            while j + needle.count <= c.count { if Array(c[j..<(j + needle.count)]) == needle { return j }; j += 1 }
            return nil
        }
        func blank(_ a: Int, _ b: Int) -> Bool { String(c[a..<b]).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func closingDollar(from start: Int) -> Int? {
            guard start < c.count, !c[start].isWhitespace else { return nil }
            var j = start
            while j < c.count {
                if c[j] == "\n" { return nil }
                if c[j] == "\\" { j += 2; continue }
                if c[j] == "$" {
                    let beforeOK = !c[j - 1].isWhitespace
                    let afterOK = j + 1 >= c.count || !c[j + 1].isNumber
                    return beforeOK && afterOK ? j : nil
                }
                j += 1
            }
            return nil
        }
        var i = 0
        while i < c.count {
            let ch = c[i]
            if ch == "`", i + 1 < c.count, let end = c[(i + 1)...].firstIndex(of: "`") { i = end + 1; continue }
            if ch == "\\", i + 1 < c.count {
                let n = c[i + 1]
                if n == "$" { i += 2; continue }
                if n == "(" || n == "[" {
                    let closer: [Character] = ["\\", n == "(" ? ")" : "]"]
                    if let e = find(closer, from: i + 2), !blank(i + 2, e) { mark(i, e + 1); i = e + 2; continue }
                }
                i += 2
                continue
            }
            if ch == "$" {
                if i + 1 < c.count, c[i + 1] == "$", let e = find(["$", "$"], from: i + 2), !blank(i + 2, e) { mark(i, e + 1); i = e + 2; continue }
                if let e = closingDollar(from: i + 1), !blank(i + 1, e) { mark(i, e); i = e + 1; continue }
            }
            i += 1
        }
        return mask
    }
}
