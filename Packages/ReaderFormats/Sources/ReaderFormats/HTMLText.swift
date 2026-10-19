import Foundation

public enum HTMLText {
    /// Visible text of an HTML or XHTML document, with block ends as line breaks.
    public static func plain(from html: String) -> String {
        var s = html
        s = replace(s, #"<(script|style)[^>]*>.*?</\1>"#, " ", dotAll: true)
        s = replace(s, #"<!--.*?-->"#, " ", dotAll: true)
        s = replace(s, #"<br\s*/?>|</(p|div|h[1-6]|li|tr|blockquote)>"#, "\n")
        s = replace(s, #"<[^>]+>"#, "")
        s = decodeEntities(s)
        s = replace(s, #"[ \t\x{00A0}]+"#, " ")
        s = replace(s, #" ?\n ?"#, "\n")
        s = replace(s, #"\n{3,}"#, "\n\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func replace(_ s: String, _ pattern: String, _ with: String, dotAll: Bool = false) -> String {
        var options: NSRegularExpression.Options = [.caseInsensitive]
        if dotAll { options.insert(.dotMatchesLineSeparators) }
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: with)
    }

    public static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = s
        let named = ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&rsquo;": "\u{2019}", "&lsquo;": "\u{2018}", "&mdash;": "\u{2014}", "&ndash;": "\u{2013}", "&hellip;": "\u{2026}"]
        for (k, v) in named { out = out.replacingOccurrences(of: k, with: v) }
        if let re = try? NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);") {
            let ns = out as NSString
            var result = ""
            var last = 0
            for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)) {
                result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let code = ns.substring(with: m.range(at: 1))
                let value = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let v = value, let scalar = Unicode.Scalar(v) { result.unicodeScalars.append(scalar) }
                last = m.range.location + m.range.length
            }
            result += ns.substring(from: last)
            out = result
        }
        return out.replacingOccurrences(of: "&amp;", with: "&")
    }
}
