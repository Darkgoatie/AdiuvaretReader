import Foundation

public enum EpubError: Error, Equatable {
    case missingContainer
    case missingPackage
    case emptySpine
}

public struct EpubBook: Sendable {
    public struct SpineItem: Sendable, Identifiable {
        public let id: Int
        public let path: String
    }

    public struct TocEntry: Sendable, Identifiable {
        public let id: Int
        public let title: String
        public let spineIndex: Int
    }

    public let title: String
    public let author: String
    public let root: URL
    public let spine: [SpineItem]
    public let toc: [TocEntry]

    public func chapterURL(_ index: Int) -> URL {
        root.appendingPathComponent(spine[min(max(index, 0), spine.count - 1)].path)
    }

    /// Opens the book, extracting it into `cache` once. The cache folder can be deleted at any time and is rebuilt on the next open.
    public static func open(at file: URL, cache: URL) throws -> EpubBook {
        let zip = try ZipArchive(contentsOf: file)
        guard let containerData = try zip.data(named: "META-INF/container.xml"),
              let container = XMLTree.parse(containerData),
              let rootfile = container.first(named: "rootfile"),
              let opfPath = rootfile.attrs["full-path"]
        else { throw EpubError.missingContainer }
        guard let opfData = try zip.data(named: opfPath), let opf = XMLTree.parse(opfData) else { throw EpubError.missingPackage }

        let marker = cache.appendingPathComponent(".extracted")
        if !FileManager.default.fileExists(atPath: marker.path) {
            try? FileManager.default.removeItem(at: cache)
            try zip.extractAll(to: cache)
            try Data().write(to: marker)
        }

        let baseDir = (opfPath as NSString).deletingLastPathComponent
        func resolve(_ href: String) -> String {
            let clean = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
            let decoded = clean.removingPercentEncoding ?? clean
            return normalize(baseDir.isEmpty ? decoded : baseDir + "/" + decoded)
        }

        let metadata = opf.first(named: "metadata")
        let title = metadata?.first(named: "title")?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let author = metadata?.first(named: "creator")?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var manifest: [String: (href: String, type: String, properties: String)] = [:]
        for item in opf.first(named: "manifest")?.descendants(named: "item") ?? [] {
            if let id = item.attrs["id"], let href = item.attrs["href"] {
                manifest[id] = (href, item.attrs["media-type"] ?? "", item.attrs["properties"] ?? "")
            }
        }

        var spine: [SpineItem] = []
        var indexByPath: [String: Int] = [:]
        for ref in opf.first(named: "spine")?.descendants(named: "itemref") ?? [] {
            guard ref.attrs["linear"] != "no", let id = ref.attrs["idref"], let item = manifest[id],
                  item.type.contains("html") else { continue }
            let path = resolve(item.href)
            indexByPath[path] = spine.count
            spine.append(SpineItem(id: spine.count, path: path))
        }
        guard !spine.isEmpty else { throw EpubError.emptySpine }

        var toc: [TocEntry] = []
        func add(_ title: String, _ href: String) {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, let idx = indexByPath[resolve(href)] else { return }
            toc.append(TocEntry(id: toc.count, title: t, spineIndex: idx))
        }
        if let nav = manifest.values.first(where: { $0.properties.split(separator: " ").contains("nav") }),
           let data = try zip.data(named: resolve(nav.href)), let html = String(data: data, encoding: .utf8) {
            for (t, h) in navLinks(html) { add(t, h) }
        } else if let tocID = opf.first(named: "spine")?.attrs["toc"], let ncx = manifest[tocID],
                  let data = try zip.data(named: resolve(ncx.href)), let tree = XMLTree.parse(data) {
            for point in tree.descendants(named: "navPoint") {
                if let text = point.child(named: "navLabel")?.child(named: "text")?.text, let src = point.child(named: "content")?.attrs["src"] {
                    add(text, src)
                }
            }
        }
        return EpubBook(title: title, author: author, root: cache, spine: spine, toc: toc)
    }

    /// Title and author read from the package file only, without extracting the book.
    public static func metadata(at file: URL) -> (title: String, author: String)? {
        guard let zip = try? ZipArchive(contentsOf: file),
              let containerData = try? zip.data(named: "META-INF/container.xml"),
              let container = XMLTree.parse(containerData),
              let opfPath = container.first(named: "rootfile")?.attrs["full-path"],
              let opfData = try? zip.data(named: opfPath),
              let opf = XMLTree.parse(opfData)
        else { return nil }
        let md = opf.first(named: "metadata")
        let title = md?.first(named: "title")?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let author = md?.first(named: "creator")?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (title, author)
    }

    static func normalize(_ path: String) -> String {
        var out: [Substring] = []
        for part in path.split(separator: "/") {
            if part == ".." { _ = out.popLast() } else if part != "." { out.append(part) }
        }
        return out.joined(separator: "/")
    }

    static func navLinks(_ html: String) -> [(String, String)] {
        var scope = html
        if let re = try? NSRegularExpression(pattern: #"<nav[^>]*epub:type="toc"[^>]*>(.*?)</nav>"#, options: [.dotMatchesLineSeparators, .caseInsensitive]),
           let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), let r = Range(m.range(at: 1), in: html) {
            scope = String(html[r])
        }
        guard let re = try? NSRegularExpression(pattern: #"<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = scope as NSString
        return re.matches(in: scope, range: NSRange(location: 0, length: ns.length)).map {
            (HTMLText.plain(from: ns.substring(with: $0.range(at: 2))), ns.substring(with: $0.range(at: 1)))
        }
    }
}
