import Foundation

/// How a note refers to other files and where the page may find them. Supplied by the app; the renderer itself touches no disk.
public struct ObsidianContext: Sendable {
    public var index: VaultIndex
    public var currentPath: String
    /// `file://` URL for a vault-relative path, or nil when the file cannot be reached.
    public var fileURL: @Sendable (String) -> String?
    /// Lines of another note, for `![[Note]]` embeds. Nil when it cannot be read.
    public var readNote: @Sendable (String) -> String?
    public var depth = 0
    /// The chem-style property of the note, the default for molecule blocks.
    public var chemStyle = "skeletal"

    public init(index: VaultIndex, currentPath: String, fileURL: @escaping @Sendable (String) -> String?, readNote: @escaping @Sendable (String) -> String?) {
        self.index = index
        self.currentPath = currentPath
        self.fileURL = fileURL
        self.readNote = readNote
    }

    public static let empty = ObsidianContext(index: VaultIndex(paths: []), currentPath: "", fileURL: { _ in nil }, readNote: { _ in nil })
}

/// Inline syntax: wikilinks, embeds, highlights, tags, footnote marks, block ids, math, code and the usual emphasis and links.
public enum ObsidianInline {
    public static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "avif"]

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    static func attr(_ s: String) -> String { esc(s).replacingOccurrences(of: "\"", with: "&quot;") }

    /// Pulls matches out of the text and leaves private-use placeholders, so later rules cannot touch them.
    final class Stash {
        var items: [String] = []
        func put(_ html: String) -> String {
            items.append(html)
            return "\u{E000}\(items.count - 1)\u{E001}"
        }
        func restore(_ s: String) -> String {
            var out = s
            var guardCount = 0
            while out.contains("\u{E000}"), guardCount < 6 {
                for (i, h) in items.enumerated() { out = out.replacingOccurrences(of: "\u{E000}\(i)\u{E001}", with: h) }
                guardCount += 1
            }
            return out
        }
    }

    static func regex(_ p: String, _ o: NSRegularExpression.Options = []) -> NSRegularExpression? { try? NSRegularExpression(pattern: p, options: o) }

    static func replace(_ s: String, _ re: NSRegularExpression?, _ f: (NSTextCheckingResult, NSString) -> String) -> String {
        guard let re else { return s }
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            out += f(m, ns)
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }

    static func group(_ m: NSTextCheckingResult, _ i: Int, _ ns: NSString) -> String? {
        let r = m.range(at: i)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }

    public static func render(_ text: String, ctx: ObsidianContext, footnotes: [String: Int] = [:]) -> String {
        let stash = Stash()
        var s = text

        // code spans first, then math, so nothing inside them is touched
        s = replace(s, regex(#"(`+)(.+?)\1"#)) { m, ns in stash.put("<code>\(esc(group(m, 2, ns) ?? ""))</code>") }
        for p in [#"\$\$.+?\$\$"#, #"\\\[.+?\\\]"#, #"\\\(.+?\\\)"#, #"(?<![\\$\w])\$(?![\s$])[^$\n]+?(?<![\s\\])\$(?![\d\w$])"#] {
            s = replace(s, regex(p, [.dotMatchesLineSeparators])) { m, ns in stash.put(esc(ns.substring(with: m.range))) }
        }

        // escapes such as \* or \[
        s = replace(s, regex(#"\\([\\`*_{}\[\]()#+\-.!|~=%^<>$])"#)) { m, ns in stash.put(esc(group(m, 1, ns) ?? "")) }

        // embeds and wikilinks
        s = replace(s, regex(#"!\[\[([^\]\n]+?)\]\]"#)) { m, ns in stash.put(embed(group(m, 1, ns) ?? "", ctx: ctx)) }
        s = replace(s, regex(#"\[\[([^\]\n]+?)\]\]"#)) { m, ns in stash.put(wikilink(group(m, 1, ns) ?? "", ctx: ctx)) }

        // markdown images and links
        s = replace(s, regex(#"!\[([^\]\n]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)"#)) { m, ns in
            let alt = group(m, 1, ns) ?? "", src = group(m, 2, ns) ?? ""
            return stash.put(markdownImage(alt: alt, src: src, ctx: ctx))
        }
        s = replace(s, regex(#"\[([^\]\n]+)\]\(<?([^)\s>]+)>?(?:\s+"[^"]*")?\)"#)) { m, ns in
            let label = group(m, 1, ns) ?? "", href = group(m, 2, ns) ?? ""
            return stash.put(markdownLink(label: label, href: href, ctx: ctx))
        }
        s = replace(s, regex(#"<(https?://[^>\s]+)>"#)) { m, ns in
            let u = group(m, 1, ns) ?? ""
            return stash.put("<a href=\"\(attr(u))\">\(esc(u))</a>")
        }

        // footnote references and inline footnotes
        s = replace(s, regex(#"\[\^([^\]\s]+)\]"#)) { m, ns in
            let id = group(m, 1, ns) ?? ""
            guard let n = footnotes[id] else { return esc(ns.substring(with: m.range)) }
            return stash.put("<sup class=\"fn-ref\"><a href=\"#fn-\(attr(Slug.make(id)))\" id=\"fnref-\(attr(Slug.make(id)))\">\(n)</a></sup>")
        }

        s = esc(s)

        // emphasis
        s = replace(s, regex(#"==([^=\n]+?)=="#)) { m, ns in "<mark class=\"ob-hl\">\(group(m, 1, ns) ?? "")</mark>" }
        s = replace(s, regex(#"~~([^~\n]+?)~~"#)) { m, ns in "<del>\(group(m, 1, ns) ?? "")</del>" }
        s = replace(s, regex(#"\*\*\*([^*\n]+?)\*\*\*"#)) { m, ns in "<strong><em>\(group(m, 1, ns) ?? "")</em></strong>" }
        s = replace(s, regex(#"\*\*([^*\n]+?)\*\*"#)) { m, ns in "<strong>\(group(m, 1, ns) ?? "")</strong>" }
        s = replace(s, regex(#"(?<![\w_])__([^_\n]+?)__(?![\w_])"#)) { m, ns in "<strong>\(group(m, 1, ns) ?? "")</strong>" }
        s = replace(s, regex(#"(?<![*\w])\*([^*\s][^*\n]*?)\*(?![*\w])"#)) { m, ns in "<em>\(group(m, 1, ns) ?? "")</em>" }
        s = replace(s, regex(#"(?<![\w_])_([^_\s][^_\n]*?)_(?![\w_])"#)) { m, ns in "<em>\(group(m, 1, ns) ?? "")</em>" }

        // inline footnotes ^[text]
        s = replace(s, regex(#"\^\[([^\]\n]+)\]"#)) { m, ns in "<sup class=\"fn-inline\" title=\"\(attr(group(m, 1, ns) ?? ""))\">\u{2020}</sup>" }

        // tags: #tag and #nested/tag, not in the middle of a word, not only digits
        s = replace(s, regex(#"(?<![\w&#/])#([\p{L}\p{N}_\-/]*[\p{L}_\-/][\p{L}\p{N}_\-/]*)"#)) { m, ns in
            let tag = group(m, 1, ns) ?? ""
            return "<a class=\"ob-tag\" href=\"obsidian-tag:\(attr(tag))\">#\(tag)</a>"
        }

        // trailing block id
        s = replace(s, regex(#"\s\^([A-Za-z0-9\-]+)\s*$"#)) { m, ns in "<span class=\"blk-id\" id=\"^\(attr(group(m, 1, ns) ?? ""))\"></span>" }

        return stash.restore(s)
    }

    // MARK: Links

    static func splitAlias(_ inner: String) -> (target: String, alias: String?) {
        guard let bar = inner.firstIndex(of: "|") else { return (inner, nil) }
        return (String(inner[..<bar]), String(inner[inner.index(after: bar)...]))
    }

    static func splitFragment(_ target: String) -> (path: String, fragment: String?) {
        guard let hash = target.firstIndex(of: "#") else { return (target, nil) }
        return (String(target[..<hash]), String(target[target.index(after: hash)...]))
    }

    static func wikilink(_ inner: String, ctx: ObsidianContext) -> String {
        let (target, alias) = splitAlias(inner)
        let (path, fragment) = splitFragment(target.trimmingCharacters(in: .whitespaces))
        let name = ((path.isEmpty ? ctx.currentPath : path) as NSString).lastPathComponent
        var shown = alias ?? target.trimmingCharacters(in: .whitespaces)
        if alias == nil, path.isEmpty, let f = fragment { shown = f.hasPrefix("^") ? ctx.currentPath : f }
        if alias == nil, !path.isEmpty, let f = fragment { shown = name + " > " + f }
        if alias == nil, fragment == nil { shown = (name as NSString).deletingPathExtension.isEmpty ? name : (path.hasSuffix(".md") ? (name as NSString).deletingPathExtension : name) }

        if path.isEmpty {
            let anchor = fragment.map { $0.hasPrefix("^") ? $0 : "h-" + Slug.make($0) } ?? ""
            return "<a class=\"internal-link\" href=\"#\(attr(anchor))\">\(esc(shown))</a>"
        }
        if let resolved = ctx.index.resolve(path, from: ctx.currentPath) {
            let href = "obsidian-note:" + (resolved.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? resolved) + (fragment.map { "#" + ($0.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? $0) } ?? "")
            return "<a class=\"internal-link\" href=\"\(href)\">\(esc(shown))</a>"
        }
        return "<a class=\"internal-link is-unresolved\" href=\"obsidian-missing:\((path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)) ?? path)\">\(esc(shown))</a>"
    }

    static func embed(_ inner: String, ctx: ObsidianContext) -> String {
        let (target, size) = splitAlias(inner)
        let (path, fragment) = splitFragment(target.trimmingCharacters(in: .whitespaces))
        let ext = (path as NSString).pathExtension.lowercased()
        let attrs = sizeAttributes(size)

        if imageExtensions.contains(ext) {
            if let resolved = ctx.index.resolve(path, from: ctx.currentPath), let url = ctx.fileURL(resolved) {
                return "<img class=\"ob-img\" src=\"\(attr(url))\" alt=\"\(attr((path as NSString).lastPathComponent))\"\(attrs)>"
            }
            return "<span class=\"ob-missing\">Image not found: \(esc(path))</span>"
        }
        if ["mp3", "m4a", "wav", "ogg", "flac"].contains(ext) {
            if let resolved = ctx.index.resolve(path, from: ctx.currentPath), let url = ctx.fileURL(resolved) {
                return "<audio controls src=\"\(attr(url))\"></audio>"
            }
            return "<span class=\"ob-missing\">Audio not found: \(esc(path))</span>"
        }
        if ["mp4", "mov", "m4v", "webm"].contains(ext) {
            if let resolved = ctx.index.resolve(path, from: ctx.currentPath), let url = ctx.fileURL(resolved) {
                return "<video controls playsinline src=\"\(attr(url))\"\(attrs)></video>"
            }
            return "<span class=\"ob-missing\">Video not found: \(esc(path))</span>"
        }
        if ext == "pdf" {
            let name = (path as NSString).lastPathComponent
            let page = fragment.flatMap { f in f.hasPrefix("page=") ? String(f.dropFirst(5)) : nil }
            let label = page.map { "\(name), page \($0)" } ?? name
            if let resolved = ctx.index.resolve(path, from: ctx.currentPath) {
                let href = "obsidian-note:" + (resolved.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? resolved) + (page.map { "#page=\($0)" } ?? "")
                return "<a class=\"ob-pdf\" href=\"\(href)\">\(esc(label))</a>"
            }
            return "<span class=\"ob-missing\">PDF not found: \(esc(path))</span>"
        }
        // a note, a heading or a block
        return embedNote(path: path, fragment: fragment, ctx: ctx)
    }

    static func sizeAttributes(_ size: String?) -> String {
        guard let size, !size.isEmpty else { return "" }
        let parts = size.split(separator: "x").map(String.init)
        if parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) { return " width=\"\(w)\" height=\"\(h)\"" }
        if parts.count == 1, let w = Int(parts[0]) { return " width=\"\(w)\"" }
        return ""
    }

    static func embedNote(path: String, fragment: String?, ctx: ObsidianContext) -> String {
        guard ctx.depth < 3 else { return "<span class=\"ob-missing\">Embeds are nested too deeply.</span>" }
        let target = path.isEmpty ? ctx.currentPath : (ctx.index.resolve(path, from: ctx.currentPath) ?? "")
        guard !target.isEmpty, let source = ctx.readNote(target) else {
            return "<span class=\"ob-missing\">Note not found: \(esc(path.isEmpty ? "this note" : path))</span>"
        }
        var body = Frontmatter.split(source).body.components(separatedBy: "\n")
        if let f = fragment, !f.isEmpty {
            let found = f.hasPrefix("^") ? NoteSections.block(in: body.joined(separator: "\n"), id: String(f.dropFirst())) : NoteSections.heading(in: body.joined(separator: "\n"), named: f)
            guard let section = found else { return "<span class=\"ob-missing\">Section not found: \(esc(f))</span>" }
            body = section
        }
        var inner = ctx
        inner.currentPath = target
        inner.depth = ctx.depth + 1
        let title = (target as NSString).deletingPathExtension.components(separatedBy: "/").last ?? target
        let html = ObsidianMarkdown.renderBody(body.joined(separator: "\n"), ctx: inner)
        return "<div class=\"ob-embed\"><div class=\"ob-embed-title\">\(esc(title))</div>\(html)</div>"
    }

    static func markdownImage(alt: String, src: String, ctx: ObsidianContext) -> String {
        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            return "<span class=\"ob-missing\">Online image not loaded: \(esc(alt.isEmpty ? src : alt))</span>"
        }
        let decoded = src.removingPercentEncoding ?? src
        var width = ""
        if let n = Int(alt.split(separator: "|").last.map(String.init) ?? ""), alt.contains("|") { width = " width=\"\(n)\"" }
        if let resolved = ctx.index.resolve(decoded, from: ctx.currentPath), let url = ctx.fileURL(resolved) {
            return "<img class=\"ob-img\" src=\"\(attr(url))\" alt=\"\(attr(alt))\"\(width)>"
        }
        return "<span class=\"ob-missing\">Image not found: \(esc(decoded))</span>"
    }

    static func markdownLink(label: String, href: String, ctx: ObsidianContext) -> String {
        if href.hasPrefix("http://") || href.hasPrefix("https://") || href.hasPrefix("mailto:") {
            return "<a href=\"\(attr(href))\">\(esc(label))</a>"
        }
        let decoded = href.removingPercentEncoding ?? href
        let (path, fragment) = splitFragment(decoded)
        if path.isEmpty { return "<a class=\"internal-link\" href=\"#h-\(attr(Slug.make(fragment ?? "")))\">\(esc(label))</a>" }
        if let resolved = ctx.index.resolve(path, from: ctx.currentPath) {
            let h = "obsidian-note:" + (resolved.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? resolved) + (fragment.map { "#" + $0 } ?? "")
            return "<a class=\"internal-link\" href=\"\(h)\">\(esc(label))</a>"
        }
        return "<a class=\"internal-link is-unresolved\" href=\"obsidian-missing:\(attr(path))\">\(esc(label))</a>"
    }
}
