import Foundation

/// Renders a note the way Obsidian's reading view shows it.
public enum ObsidianMarkdown {
    static let calloutAliases: [String: String] = [
        "summary": "abstract", "tldr": "abstract", "hint": "tip", "important": "tip", "check": "success", "done": "success",
        "help": "question", "faq": "question", "caution": "warning", "attention": "warning", "fail": "failure", "missing": "failure",
        "error": "danger", "cite": "quote",
    ]
    static let calloutIcons: [String: String] = [
        "note": "\u{270E}", "abstract": "\u{2630}", "info": "i", "todo": "\u{2610}", "tip": "\u{2605}", "success": "\u{2713}",
        "question": "?", "warning": "!", "failure": "\u{2715}", "danger": "\u{26A1}", "bug": "\u{2022}", "example": "\u{2261}", "quote": "\u{201C}",
    ]

    public static func page(title: String, source: String, ctx: ObsidianContext) -> String {
        let (props, body) = Frontmatter.split(source.replacingOccurrences(of: "\r\n", with: "\n"))
        var html = propertiesHTML(props)
        html += renderBody(body, ctx: ctx)
        return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>\(ObsidianInline.esc(title))</title></head><body class=\"obsidian\">\n\(html)</body></html>"
    }

    // MARK: Properties

    static func propertiesHTML(_ props: [NoteProperty]) -> String {
        let shown = props.filter { !["cssclasses", "cssclass"].contains($0.key.lowercased()) }
        guard !shown.isEmpty else { return "" }
        var rows = ""
        for p in shown {
            let isTags = ["tags", "tag"].contains(p.key.lowercased())
            var value = ""
            if isTags || p.isList {
                value = p.values.map { v -> String in
                    let t = v.hasPrefix("#") ? String(v.dropFirst()) : v
                    return isTags
                        ? "<a class=\"ob-tag\" href=\"obsidian-tag:\(ObsidianInline.attr(t))\">\(ObsidianInline.esc(t))</a>"
                        : "<span class=\"ob-chip\">\(ObsidianInline.esc(v))</span>"
                }.joined(separator: " ")
            } else {
                value = ObsidianInline.esc(p.values.first ?? "")
            }
            rows += "<div class=\"ob-prop\"><div class=\"ob-prop-key\">\(ObsidianInline.esc(p.key))</div><div class=\"ob-prop-val\">\(value)</div></div>\n"
        }
        return "<div class=\"ob-properties\">\n\(rows)</div>\n"
    }

    // MARK: Body

    public static func renderBody(_ source: String, ctx: ObsidianContext) -> String {
        var lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        lines = Comments.strip(lines)
        var footnoteDefs: [(id: String, text: String)] = []
        lines = extractFootnotes(lines, into: &footnoteDefs)
        var numbers: [String: Int] = [:]
        for (i, d) in footnoteDefs.enumerated() { numbers[d.id] = i + 1 }

        var html = renderBlocks(lines[...], ctx: ctx, footnotes: numbers)
        if !footnoteDefs.isEmpty {
            html += "<section class=\"footnotes\"><hr><ol>\n"
            for d in footnoteDefs {
                let slug = Slug.make(d.id)
                html += "<li id=\"fn-\(ObsidianInline.attr(slug))\">\(ObsidianInline.render(d.text, ctx: ctx, footnotes: numbers)) <a class=\"fn-back\" href=\"#fnref-\(ObsidianInline.attr(slug))\">\u{21A9}</a></li>\n"
            }
            html += "</ol></section>\n"
        }
        return html
    }

    static func extractFootnotes(_ lines: [String], into defs: inout [(id: String, text: String)]) -> [String] {
        var out: [String] = []
        var i = 0
        var inFence = false
        guard let re = ObsidianInline.regex(#"^\[\^([^\]\s]+)\]:\s?(.*)$"#) else { return lines }
        while i < lines.count {
            let l = lines[i]
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") || t.hasPrefix("~~~") { inFence.toggle() }
            if !inFence, let m = re.firstMatch(in: l, range: NSRange(location: 0, length: (l as NSString).length)) {
                let ns = l as NSString
                var text = ns.substring(with: m.range(at: 2))
                i += 1
                while i < lines.count, lines[i].hasPrefix("    ") || lines[i].hasPrefix("\t") {
                    text += " " + lines[i].trimmingCharacters(in: .whitespaces)
                    i += 1
                }
                defs.append((ns.substring(with: m.range(at: 1)), text))
                continue
            }
            out.append(l)
            i += 1
        }
        return out
    }

    // MARK: Blocks

    private static func indent(of line: String) -> Int {
        var n = 0
        for ch in line {
            if ch == " " { n += 1 } else if ch == "\t" { n += 4 } else { break }
        }
        return n
    }

    private static func isBlank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespaces).isEmpty }

    private static func headingLevel(_ t: String) -> Int? {
        let h = t.prefix { $0 == "#" }.count
        guard (1...6).contains(h), t.dropFirst(h).first == " " else { return nil }
        return h
    }

    private static func fence(_ t: String) -> (marker: String, lang: String)? {
        for m in ["```", "~~~"] where t.hasPrefix(m) {
            let ticks = String(t.prefix { $0 == m.first! })
            return (ticks, String(t.dropFirst(ticks.count)).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func listMarker(_ line: String) -> (indent: Int, ordered: Bool, start: Int, content: String)? {
        let ind = indent(of: line)
        let t = line.trimmingCharacters(in: .whitespaces)
        for p in ["- ", "* ", "+ "] where t.hasPrefix(p) { return (ind, false, 1, String(t.dropFirst(2))) }
        let digits = t.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, digits.count < 10 {
            let rest = t.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") { return (ind, true, Int(digits) ?? 1, String(rest.dropFirst(2))) }
        }
        return nil
    }

    private static func isRule(_ t: String) -> Bool {
        let compact = t.replacingOccurrences(of: " ", with: "")
        return compact.count >= 3 && Set(compact).count == 1 && ["-", "*", "_"].contains(compact.first!)
    }

    private static func isTableRow(_ t: String) -> Bool { t.contains("|") }

    private static func tableDivider(_ t: String) -> [String]? {
        let cells = splitRow(t)
        guard !cells.isEmpty else { return nil }
        var aligns: [String] = []
        for c in cells {
            let x = c.trimmingCharacters(in: .whitespaces)
            guard x.count >= 1, x.allSatisfy({ $0 == "-" || $0 == ":" }), x.contains("-") else { return nil }
            aligns.append(x.hasPrefix(":") && x.hasSuffix(":") ? "center" : x.hasSuffix(":") ? "right" : x.hasPrefix(":") ? "left" : "")
        }
        return aligns
    }

    static func splitRow(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") && !t.hasSuffix("\\|") { t.removeLast() }
        var cells: [String] = []
        var cur = ""
        var prev: Character = " "
        var depth = 0
        for ch in t {
            if ch == "[" { depth += 1 } else if ch == "]" { depth = max(0, depth - 1) }
            if ch == "|", prev != "\\", depth == 0 { cells.append(cur); cur = "" } else { cur.append(ch) }
            prev = ch
        }
        cells.append(cur)
        return cells.map { $0.replacingOccurrences(of: "\\|", with: "|") }
    }

    static func renderBlocks(_ input: ArraySlice<String>, ctx: ObsidianContext, footnotes: [String: Int]) -> String {
        let lines = Array(input)
        var html = ""
        var i = 0
        var paragraph: [String] = []

        func inline(_ s: String) -> String { ObsidianInline.render(s, ctx: ctx, footnotes: footnotes) }
        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            var text = paragraph.joined(separator: "\n")
            var idAttr = ""
            if let re = ObsidianInline.regex(#"(?:^|\s)\^([A-Za-z0-9\-]+)\s*$"#), let m = re.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                idAttr = " id=\"^\((text as NSString).substring(with: m.range(at: 1)))\""
                text = (text as NSString).replacingCharacters(in: m.range, with: "")
            }
            let body = text.components(separatedBy: "\n").map { inline($0.trimmingCharacters(in: .whitespaces)) }.joined(separator: "\n")
            html += "<p\(idAttr)>\(body)</p>\n"
            paragraph = []
        }

        while i < lines.count {
            let line = lines[i]
            let t = line.trimmingCharacters(in: .whitespaces)

            if isBlank(line) { flushParagraph(); i += 1; continue }

            if let f = fence(t) {
                flushParagraph()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(f.marker) { code.append(lines[i]); i += 1 }
                i += 1
                let body = code.joined(separator: "\n")
                if f.lang.lowercased() == "mermaid" {
                    html += "<pre class=\"ob-mermaid\"><code>\(ObsidianInline.esc(body))</code></pre>\n<p class=\"ob-note\">Diagram source (diagrams are not drawn in the reader)</p>\n"
                } else {
                    let cls = f.lang.isEmpty ? "" : " class=\"language-\(ObsidianInline.attr(f.lang))\""
                    html += "<pre><code\(cls)>\(ObsidianInline.esc(body))</code></pre>\n"
                }
                continue
            }

            if t.hasPrefix("$$") {
                flushParagraph()
                var buffer = [String(t.dropFirst(2))]
                if t.count > 3, t.hasSuffix("$$") {
                    html += "<div class=\"math-block\">$$\(ObsidianInline.esc(String(t.dropFirst(2).dropLast(2))))$$</div>\n"
                    i += 1
                    continue
                }
                i += 1
                while i < lines.count {
                    let tt = lines[i].trimmingCharacters(in: .whitespaces)
                    if tt.hasSuffix("$$") { buffer.append(String(tt.dropLast(2))); i += 1; break }
                    buffer.append(lines[i])
                    i += 1
                }
                html += "<div class=\"math-block\">$$\(ObsidianInline.esc(buffer.joined(separator: "\n")))$$</div>\n"
                continue
            }

            if let level = headingLevel(t) {
                flushParagraph()
                var text = String(t.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                while text.hasSuffix("#") { text.removeLast() }
                text = text.trimmingCharacters(in: .whitespaces)
                html += "<h\(level) id=\"h-\(ObsidianInline.attr(Slug.make(text)))\">\(inline(text))</h\(level)>\n"
                i += 1
                continue
            }

            if isRule(t), !(listMarker(line) != nil && t.hasPrefix("- ") ) {
                flushParagraph(); html += "<hr>\n"; i += 1; continue
            }

            if t.hasPrefix(">") {
                flushParagraph()
                var quote: [String] = []
                while i < lines.count {
                    let q = lines[i].trimmingCharacters(in: .whitespaces)
                    guard q.hasPrefix(">") else { break }
                    var s = String(q.dropFirst())
                    if s.hasPrefix(" ") { s.removeFirst() }
                    quote.append(s)
                    i += 1
                }
                html += renderQuote(quote, ctx: ctx, footnotes: footnotes)
                continue
            }

            if i + 1 < lines.count, isTableRow(t), let aligns = tableDivider(lines[i + 1].trimmingCharacters(in: .whitespaces)),
               splitRow(t).count == aligns.count {
                flushParagraph()
                let head = splitRow(t)
                i += 2
                var rows: [[String]] = []
                while i < lines.count, !isBlank(lines[i]), isTableRow(lines[i]) { rows.append(splitRow(lines[i].trimmingCharacters(in: .whitespaces))); i += 1 }
                func cell(_ tag: String, _ text: String, _ n: Int) -> String {
                    let a = n < aligns.count && !aligns[n].isEmpty ? " style=\"text-align:\(aligns[n])\"" : ""
                    return "<\(tag)\(a)>\(inline(text.trimmingCharacters(in: .whitespaces)))</\(tag)>"
                }
                html += "<div class=\"ob-table\"><table><thead><tr>" + head.enumerated().map { cell("th", $1, $0) }.joined() + "</tr></thead><tbody>\n"
                for r in rows { html += "<tr>" + (0..<head.count).map { cell("td", $0 < r.count ? r[$0] : "", $0) }.joined() + "</tr>\n" }
                html += "</tbody></table></div>\n"
                continue
            }

            if listMarker(line) != nil {
                flushParagraph()
                let (out, next) = renderList(lines, from: i, ctx: ctx, footnotes: footnotes)
                html += out
                i = next
                continue
            }

            if indent(of: line) >= 4, paragraph.isEmpty {
                var code: [String] = []
                while i < lines.count, isBlank(lines[i]) || indent(of: lines[i]) >= 4 {
                    code.append(String(lines[i].dropFirst(min(4, lines[i].prefix { $0 == " " }.count))))
                    i += 1
                }
                while code.last.map(isBlank) == true { code.removeLast() }
                html += "<pre><code>\(ObsidianInline.esc(code.joined(separator: "\n")))</code></pre>\n"
                continue
            }

            // a line that only embeds something stays a block of its own
            if t.hasPrefix("![["), t.hasSuffix("]]"), paragraph.isEmpty, !t.dropFirst(3).dropLast(2).contains("]]") {
                html += "<div class=\"ob-embed-line\">\(inline(t))</div>\n"
                i += 1
                continue
            }

            paragraph.append(line)
            i += 1
        }
        flushParagraph()
        return html
    }

    // MARK: Callouts and quotes

    static func renderQuote(_ quote: [String], ctx: ObsidianContext, footnotes: [String: Int]) -> String {
        if let first = quote.first, let re = ObsidianInline.regex(#"^\[!([A-Za-z0-9_\-]+)\]([+\-]?)\s*(.*)$"#),
           let m = re.firstMatch(in: first, range: NSRange(location: 0, length: (first as NSString).length)) {
            let ns = first as NSString
            let raw = ns.substring(with: m.range(at: 1)).lowercased()
            let fold = ns.substring(with: m.range(at: 2))
            var title = ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespaces)
            let type = calloutAliases[raw] ?? raw
            if title.isEmpty { title = raw.prefix(1).uppercased() + raw.dropFirst() }
            let icon = calloutIcons[type] ?? calloutIcons["note"]!
            let rest = Array(quote.dropFirst())
            let content = renderBlocks(rest[...], ctx: ctx, footnotes: footnotes)
            let known = calloutIcons[type] != nil ? type : "note"
            let head = "<span class=\"co-icon\">\(icon)</span><span class=\"co-title\">\(ObsidianInline.render(title, ctx: ctx, footnotes: footnotes))</span>"
            if fold.isEmpty {
                return "<div class=\"callout co-\(known)\"><div class=\"co-head\">\(head)</div><div class=\"co-body\">\(content)</div></div>\n"
            }
            let open = fold == "+" ? " open" : ""
            return "<details class=\"callout co-\(known)\"\(open)><summary class=\"co-head\">\(head)</summary><div class=\"co-body\">\(content)</div></details>\n"
        }
        return "<blockquote>\(renderBlocks(quote[...], ctx: ctx, footnotes: footnotes))</blockquote>\n"
    }

    // MARK: Lists

    static func renderList(_ lines: [String], from start: Int, ctx: ObsidianContext, footnotes: [String: Int]) -> (String, Int) {
        guard let first = listMarker(lines[start]) else { return ("", start + 1) }
        let baseIndent = first.indent
        let ordered = first.ordered
        let tag = ordered ? "ol" : "ul"
        var html = "<\(tag)\(ordered && first.start != 1 ? " start=\"\(first.start)\"" : "")>\n"
        var i = start
        var hasTasks = false

        while i < lines.count {
            let line = lines[i]
            if isBlank(line) {
                var j = i
                while j < lines.count, isBlank(lines[j]) { j += 1 }
                if j < lines.count, let m = listMarker(lines[j]), m.indent >= baseIndent, m.ordered == ordered || m.indent > baseIndent { i = j; continue }
                break
            }
            guard let m = listMarker(line), m.indent == baseIndent else { break }
            var content = m.content
            var task: Bool?
            if content.hasPrefix("[ ] ") || content == "[ ]" { task = false; content = String(content.dropFirst(min(4, content.count))) }
            else if content.lowercased().hasPrefix("[x] ") || content.lowercased() == "[x]" { task = true; content = String(content.dropFirst(min(4, content.count))) }
            else if content.hasPrefix("[") , content.count >= 3, content.dropFirst(2).first == "]", content.dropFirst(3).first == " " || content.count == 3 {
                task = true
                content = String(content.dropFirst(min(4, content.count)))
            }
            i += 1
            var child: [String] = []
            var extra: [String] = []
            while i < lines.count {
                let l = lines[i]
                if isBlank(l) {
                    var j = i
                    while j < lines.count, isBlank(lines[j]) { j += 1 }
                    if j < lines.count, indent(of: lines[j]) > baseIndent { child.append(""); i += 1; continue }
                    break
                }
                if indent(of: l) > baseIndent {
                    if listMarker(l) != nil { child.append(l) } else if child.isEmpty { extra.append(l.trimmingCharacters(in: .whitespaces)) } else { child.append(l) }
                    i += 1
                } else { break }
            }
            var inner = ObsidianInline.render(([content] + extra).joined(separator: "\n"), ctx: ctx, footnotes: footnotes)
            if !child.isEmpty { inner += "\n" + renderBlocks(child[...], ctx: ctx, footnotes: footnotes) }
            if let task {
                hasTasks = true
                html += "<li class=\"task-list-item\(task ? " is-checked" : "")\"><span class=\"task-box\" role=\"checkbox\" aria-checked=\"\(task)\">\(task ? "\u{2713}" : "")</span>\(inner)</li>\n"
            } else {
                html += "<li>\(inner)</li>\n"
            }
        }
        html += "</\(tag)>\n"
        if hasTasks { html = html.replacingOccurrences(of: "<\(tag)>", with: "<\(tag) class=\"contains-task-list\">", options: [], range: html.range(of: "<\(tag)>")) }
        return (html, i)
    }
}
