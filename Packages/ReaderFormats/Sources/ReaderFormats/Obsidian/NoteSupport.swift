import Foundation

public struct NoteProperty: Equatable, Sendable {
    public let key: String
    public let values: [String]
    public let isList: Bool

    public init(key: String, values: [String], isList: Bool) {
        self.key = key
        self.values = values
        self.isList = isList
    }
}

/// The YAML block at the top of a note, read the way Obsidian reads properties: `key: value`, `key: [a, b]` and `- item` lists.
public enum Frontmatter {
    public static func split(_ source: String) -> (properties: [NoteProperty], body: String) {
        let lines = source.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else { return ([], source) }
        var end: Int?
        var i = 1
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t == "---" || t == "..." { end = i; break }
            i += 1
        }
        guard let e = end else { return ([], source) }
        let block = Array(lines[1..<e])
        let looksLikeYAML = block.isEmpty || block.contains { $0.contains(":") }
        guard looksLikeYAML else { return ([], source) }
        return (parse(block), lines[(e + 1)...].joined(separator: "\n"))
    }

    public static func tags(_ properties: [NoteProperty]) -> [String] {
        properties
            .filter { ["tags", "tag"].contains($0.key.lowercased()) }
            .flatMap { $0.values }
            .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }
    }

    static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.count >= 2, (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
            t = String(t.dropFirst().dropLast())
        }
        return t
    }

    static func parse(_ lines: [String]) -> [NoteProperty] {
        var out: [NoteProperty] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix(" "), !line.hasPrefix("\t"), !line.hasPrefix("-"), !line.hasPrefix("#") else {
                i += 1
                continue
            }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let rest = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            i += 1
            if key.isEmpty { continue }
            if rest.isEmpty {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") { items.append(clean(String(t.dropFirst(2)))); i += 1 }
                    else if t == "-" || t.isEmpty { i += 1 }
                    else { break }
                }
                out.append(NoteProperty(key: key, values: items.filter { !$0.isEmpty }, isList: true))
            } else if rest.hasPrefix("["), rest.hasSuffix("]") {
                let inner = String(rest.dropFirst().dropLast())
                let items = inner.split(separator: ",").map { clean(String($0)) }.filter { !$0.isEmpty }
                out.append(NoteProperty(key: key, values: items, isList: true))
            } else if ["tags", "tag"].contains(key.lowercased()) {
                let items = rest.split(whereSeparator: { $0 == "," || $0 == " " }).map { clean(String($0)) }.filter { !$0.isEmpty }
                out.append(NoteProperty(key: key, values: items, isList: true))
            } else {
                out.append(NoteProperty(key: key, values: [clean(rest)], isList: false))
            }
        }
        return out
    }
}

/// Finds the file a link points to among the files of a vault, the way Obsidian resolves `[[Note]]`:
/// the extension is optional (`.md` is assumed), a folder path narrows the match, and a name that exists twice goes to the closest one.
public struct VaultIndex: Sendable {
    private let paths: [String]
    private let lower: [String]

    public init(paths: [String]) {
        self.paths = paths
        self.lower = paths.map { $0.lowercased() }
    }

    public func resolve(_ target: String, from current: String? = nil) -> String? {
        var t = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        let currentDir = current.map { ($0 as NSString).deletingLastPathComponent } ?? ""
        if t.hasPrefix("./") || t.hasPrefix("../") {
            t = Self.normalize(currentDir.isEmpty ? t : currentDir + "/" + t)
        }
        while t.hasPrefix("/") { t.removeFirst() }
        let key = t.lowercased()
        let wanted = key.hasSuffix(".md") ? [key] : [key + ".md", key]
        var best: String?
        for (i, lp) in lower.enumerated() {
            for w in wanted where lp == w || lp.hasSuffix("/" + w) {
                best = better(best, paths[i], currentDir)
                break
            }
        }
        return best
    }

    private func better(_ a: String?, _ b: String, _ dir: String) -> String {
        guard let a else { return b }
        let aSame = (a as NSString).deletingLastPathComponent == dir
        let bSame = (b as NSString).deletingLastPathComponent == dir
        if aSame != bSame { return aSame ? a : b }
        let ac = a.split(separator: "/").count
        let bc = b.split(separator: "/").count
        if ac != bc { return ac < bc ? a : b }
        return a < b ? a : b
    }

    static func normalize(_ path: String) -> String {
        var out: [Substring] = []
        for part in path.split(separator: "/") {
            if part == ".." { _ = out.popLast() } else if part != "." { out.append(part) }
        }
        return out.joined(separator: "/")
    }
}

public enum Slug {
    /// Lower case letters and digits joined by single dashes; used for heading anchors.
    public static func make(_ s: String) -> String {
        var out = ""
        var lastDash = true
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastDash = false
            } else if !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }
}

/// The parts of a note that `![[Note#Heading]]` and `![[Note#^id]]` embed.
public enum NoteSections {
    private static func heading(of line: String) -> (level: Int, text: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        let hashes = t.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), t.dropFirst(hashes).first == " " else { return nil }
        var text = String(t.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") { text.removeLast() }
        return (hashes, text.trimmingCharacters(in: .whitespaces))
    }

    private static func isFence(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("```") || t.hasPrefix("~~~")
    }

    public static func heading(in source: String, named name: String) -> [String]? {
        let lines = source.components(separatedBy: "\n")
        let want = name.trimmingCharacters(in: .whitespaces).lowercased()
        var start: Int?
        var level = 0
        var inFence = false
        for (i, line) in lines.enumerated() {
            if isFence(line) { inFence.toggle(); continue }
            if inFence { continue }
            guard let h = heading(of: line) else { continue }
            if let s = start {
                if h.level <= level { return Array(lines[s..<i]) }
            } else if h.text.lowercased() == want {
                start = i
                level = h.level
            }
        }
        if let s = start { return Array(lines[s...]) }
        return nil
    }

    private static func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespaces).isEmpty }

    public static func block(in source: String, id: String) -> [String]? {
        var lines = source.components(separatedBy: "\n")
        let marker = "^" + id
        for i in lines.indices {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t == marker {
                var hi = i - 1
                while hi >= 0, blank(lines[hi]) { hi -= 1 }
                guard hi >= 0 else { return nil }
                var lo = hi
                while lo > 0, !blank(lines[lo - 1]) { lo -= 1 }
                return Array(lines[lo...hi])
            }
            if t.hasSuffix(" " + marker) || t.hasSuffix("\t" + marker) {
                var lo = i
                while lo > 0, !blank(lines[lo - 1]) { lo -= 1 }
                var hi = i
                while hi < lines.count - 1, !blank(lines[hi + 1]) { hi += 1 }
                if let r = lines[i].range(of: marker, options: .backwards) {
                    lines[i] = String(lines[i][..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                return Array(lines[lo...hi])
            }
        }
        return nil
    }
}

/// `%%comment%%` text, inline or across lines, is removed before rendering. Code fences are left alone.
public enum Comments {
    public static func strip(_ lines: [String]) -> [String] {
        var out: [String] = []
        var inComment = false
        var inFence = false
        for l in lines {
            let t = l.trimmingCharacters(in: .whitespaces)
            if !inComment, t.hasPrefix("```") || t.hasPrefix("~~~") {
                inFence.toggle()
                out.append(l)
                continue
            }
            if inFence { out.append(l); continue }
            var line = l
            var result = ""
            while true {
                if let r = line.range(of: "%%") {
                    if !inComment { result += line[..<r.lowerBound] }
                    line = String(line[r.upperBound...])
                    inComment.toggle()
                } else {
                    if !inComment { result += line }
                    break
                }
            }
            out.append(result)
        }
        return out
    }
}
