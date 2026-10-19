import Foundation

/// Tags found in a note: inline `#tag` and the `tags` property. Code, math and comments are skipped.
public enum TagIndex {
    public static func tags(in source: String) -> [String] {
        let (props, body) = Frontmatter.split(source.replacingOccurrences(of: "\r\n", with: "\n"))
        var found = Frontmatter.tags(props)
        var inFence = false
        guard let re = try? NSRegularExpression(pattern: #"(?<![\w&#/])#([\p{L}\p{N}_\-/]*[\p{L}_\-/][\p{L}\p{N}_\-/]*)"#) else { return found }
        for line in Comments.strip(body.components(separatedBy: "\n")) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") || t.hasPrefix("~~~") { inFence.toggle(); continue }
            if inFence { continue }
            var text = line
            for p in [#"`[^`]*`"#, #"\$[^$\n]*\$"#, #"\[\[[^\]]*\]\]"#, #"\]\([^)]*\)"#] {
                text = text.replacingOccurrences(of: p, with: " ", options: .regularExpression)
            }
            let ns = text as NSString
            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) { found.append(ns.substring(with: m.range(at: 1))) }
        }
        var seen = Set<String>()
        return found.filter { seen.insert($0.lowercased()).inserted }
    }

    /// True when `tag` or a tag nested under it (`project` matches `project/alpha`) is in the list.
    public static func matches(_ tags: [String], query: String) -> Bool {
        let q = query.hasPrefix("#") ? String(query.dropFirst()) : query
        guard !q.isEmpty else { return false }
        return tags.contains { $0.lowercased() == q.lowercased() || $0.lowercased().hasPrefix(q.lowercased() + "/") }
    }
}
