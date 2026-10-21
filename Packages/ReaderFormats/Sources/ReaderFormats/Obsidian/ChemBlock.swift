import Foundation

/// A molecule block in a note: a fenced block tagged `smiles`, `smi`, `mol` or `molfile`.
/// Lines of the form `key: value` at the top choose how it is drawn. A note can set a default with the `chem-style` property.
public struct ChemBlock: Equatable, Sendable {
    public static let styles = ["skeletal", "explicit", "color", "bw", "comic", "compact", "bold"]
    static let aliases: [String: String] = [
        "kekule": "explicit", "kekulé": "explicit", "full": "explicit", "hydrogens": "explicit",
        "colour": "color", "colored": "color", "coloured": "color", "mono": "bw", "blackwhite": "bw", "print": "bw",
        "standard": "skeletal", "default": "skeletal", "textbook": "skeletal", "line": "skeletal",
        "sketch": "comic", "hand": "comic", "small": "compact", "thick": "bold",
    ]
    static let optionKeys: Set<String> = [
        "style", "hydrogens", "h", "numbers", "atom-numbers", "width", "size", "title", "caption", "name",
        "highlight", "stereo", "cip",
    ]
    static let sizes: [String: Int] = ["small": 200, "medium": 300, "large": 420]
    public static let widthRange = 120...700

    public var isMol: Bool
    public var style: String
    /// Nil follows the style, "explicit" draws every hydrogen, "implicit" hides them.
    public var hydrogens: String?
    public var width: Int
    public var numbers: Bool
    public var stereo: Bool
    public var highlight: [Int]
    public var title: String
    public var body: String
    /// The style that was asked for but is not known, so the block can say it fell back.
    public var unknownStyle: String?

    public static func isChemFence(_ lang: String) -> Bool {
        ["smiles", "smi", "mol", "molfile"].contains(lang.lowercased().split(separator: " ").first.map(String.init) ?? "")
    }

    /// The canonical style name for a word, or nil when it is not a style.
    public static func normalizeStyle(_ raw: String) -> String? {
        let k = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if styles.contains(k) { return k }
        return aliases[k]
    }

    /// Nil when the fence is not a molecule block.
    public static func make(lang: String, body: String, defaultStyle: String = "skeletal") -> ChemBlock? {
        guard isChemFence(lang) else { return nil }
        let isMol = ["mol", "molfile"].contains(lang.lowercased().split(separator: " ").first.map(String.init) ?? "")
        var block = ChemBlock(isMol: isMol, style: normalizeStyle(defaultStyle) ?? "skeletal", hydrogens: nil, width: 300,
                              numbers: false, stereo: false, highlight: [], title: "", body: "", unknownStyle: nil)
        var lines = body.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        while let first = lines.first {
            guard let (key, value) = option(first, known: isMol) else { break }
            block.apply(key, value)
            lines.removeFirst()
        }
        block.body = lines.joined(separator: "\n").trimmingCharacters(in: isMol ? CharacterSet(charactersIn: "\n") : .whitespacesAndNewlines)
        return block
    }

    /// `key: value` for a header line. Molfiles only accept known keys, because their first line is free text.
    private static func option(_ line: String, known onlyKnown: Bool) -> (String, String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let colon = t.firstIndex(of: ":"), colon != t.startIndex else { return nil }
        let after = t.index(after: colon)
        guard after == t.endIndex || t[after] == " " else { return nil }
        let key = String(t[..<colon]).lowercased()
        guard key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        if onlyKnown && !optionKeys.contains(key) { return nil }
        return (key, String(t[after...]).trimmingCharacters(in: .whitespaces))
    }

    private static func truthy(_ v: String) -> Bool { ["true", "yes", "on", "1", "show"].contains(v.lowercased()) }

    private mutating func apply(_ key: String, _ value: String) {
        switch key {
        case "style":
            if let s = ChemBlock.normalizeStyle(value) { style = s; unknownStyle = nil }
            else if !value.isEmpty { unknownStyle = value }
        case "hydrogens", "h":
            switch value.lowercased() {
            case "explicit", "show", "true", "yes", "all", "on": hydrogens = "explicit"
            case "implicit", "hide", "false", "no", "none", "off": hydrogens = "implicit"
            default: hydrogens = nil
            }
        case "numbers", "atom-numbers": numbers = ChemBlock.truthy(value)
        case "stereo", "cip": stereo = ChemBlock.truthy(value)
        case "size":
            if let w = ChemBlock.sizes[value.lowercased()] { width = w }
            else if let n = Int(value) { width = min(max(n, ChemBlock.widthRange.lowerBound), ChemBlock.widthRange.upperBound) }
        case "width":
            if let n = Int(value.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces)) {
                width = min(max(n, ChemBlock.widthRange.lowerBound), ChemBlock.widthRange.upperBound)
            }
        case "title", "caption", "name": title = value
        case "highlight":
            highlight = value.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Int($0) }.filter { $0 >= 0 && $0 < 10_000 }
        default: break
        }
    }

    public func html() -> String {
        let esc = ObsidianInline.esc
        var attrs = "data-lang=\"\(isMol ? "mol" : "smiles")\" data-style=\"\(style)\" data-width=\"\(width)\""
        if let hydrogens { attrs += " data-hydrogens=\"\(hydrogens)\"" }
        if numbers { attrs += " data-numbers=\"1\"" }
        if stereo { attrs += " data-stereo=\"1\"" }
        if !highlight.isEmpty { attrs += " data-highlight=\"\(highlight.map(String.init).joined(separator: ","))\"" }
        var out = "<figure class=\"chem-block\" \(attrs)>"
        if !title.isEmpty { out += "<figcaption class=\"chem-title\">\(esc(title))</figcaption>" }
        out += "<pre class=\"chem-src\">\(esc(body))</pre>"
        if let unknownStyle { out += "<div class=\"chem-note\">Unknown style \u{201C}\(esc(unknownStyle))\u{201D}, drawn as \(style). Styles: \(ChemBlock.styles.joined(separator: ", "))</div>" }
        return out + "</figure>\n"
    }
}
