import Foundation

public enum ProseHTML {
    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Inline Markdown marks on already escaped text: code, bold, emphasis and links with http(s) or relative targets.
    static func inline(_ escaped: String) -> String {
        var s = escaped
        func apply(_ pattern: String, _ template: String) {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return }
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
        }
        apply(#"`([^`]+)`"#, "<code>$1</code>")
        apply(#"\*\*([^*]+)\*\*"#, "<strong>$1</strong>")
        apply(#"(?<![*\w])\*([^*\s][^*]*)\*(?![*\w])"#, "<em>$1</em>")
        apply(#"\[([^\]]+)\]\((https?://[^)\s]+)\)"#, "<a href=\"$2\">$1</a>")
        return s
    }

    /// A complete HTML page for blocks of text, so plain text and Markdown files use the same reading view as EPUB.
    public static func page(title: String, blocks: [ProseBlock], markdown: Bool) -> String {
        var body = ""
        var inList = false
        func closeList() { if inList { body += "</ul>\n"; inList = false } }
        for b in blocks {
            if b.kind != .listItem { closeList() }
            let text = escape(b.text)
            let rich = markdown ? inline(text) : text
            switch b.kind {
            case .heading(let l): body += "<h\(l)>\(rich)</h\(l)>\n"
            case .paragraph: body += "<p>\(markdown ? rich : rich.replacingOccurrences(of: "\n", with: "<br>"))</p>\n"
            case .code: body += "<pre><code>\(text)</code></pre>\n"
            case .listItem:
                if !inList { body += "<ul>\n"; inList = true }
                body += "<li>\(rich)</li>\n"
            case .quote: body += "<blockquote>\(rich)</blockquote>\n"
            case .rule: body += "<hr>\n"
            }
        }
        closeList()
        return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>\(escape(title))</title></head><body>\n\(body)</body></html>"
    }
}
