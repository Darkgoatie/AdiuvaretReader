import Foundation
import ReaderDesign

/// Files the web view reads: extracted EPUBs, generated pages for text and Markdown, and the reading font.
enum WebAssets {
    static let root: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Reader", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func epubCache(for id: UUID) -> URL {
        root.appendingPathComponent("epub", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func pageURL(for id: UUID) -> URL {
        let dir = root.appendingPathComponent("pages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(id.uuidString + ".html")
    }

    /// The bundled Google Sans file copied under the web root, so pages are allowed to load it.
    static let fontFileURL: URL? = {
        guard let source = DesignSystemFonts.fileURL(named: "GoogleSans_GRAD-opsz-wght") else { return nil }
        let dir = root.appendingPathComponent("fonts", isDirectory: true)
        let target = dir.appendingPathComponent("GoogleSans.ttf")
        if !FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: source, to: target)
        }
        return FileManager.default.fileExists(atPath: target.path) ? target : nil
    }()

    /// KaTeX copied under the web root, with its fonts in the `fonts` folder the style sheet expects. Returns the style sheet URL.
    static let katexStyleURL: URL? = {
        let dir = root.appendingPathComponent("katex", isDirectory: true)
        let fonts = dir.appendingPathComponent("fonts", isDirectory: true)
        let css = dir.appendingPathComponent("katex.min.css")
        let fm = FileManager.default
        let bundledFonts = Bundle.main.urls(forResourcesWithExtension: "woff2", subdirectory: nil) ?? []
        let have = (try? fm.contentsOfDirectory(atPath: fonts.path))?.count ?? 0
        if fm.fileExists(atPath: css.path), have >= bundledFonts.count { return css }
        try? fm.removeItem(at: dir)
        guard let source = Bundle.main.url(forResource: "katex.min", withExtension: "css") else { return nil }
        try? fm.createDirectory(at: fonts, withIntermediateDirectories: true)
        try? fm.copyItem(at: source, to: css)
        for f in bundledFonts {
            try? fm.copyItem(at: f, to: fonts.appendingPathComponent(f.lastPathComponent))
        }
        return fm.fileExists(atPath: css.path) ? css : nil
    }()

    /// RDKit's JavaScript wrapper and the drawing script. Read only when a page has a molecule block.
    static let chemScript: String = {
        func read(_ name: String) -> String {
            Bundle.main.url(forResource: name, withExtension: "js").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        }
        let r = read("RDKit_minimal"), c = read("chem")
        return r.isEmpty || c.isEmpty ? "" : r + "\n;\n" + c
    }()

    /// RDKit's WebAssembly module as base64 pieces, small enough to hand to the page one call at a time.
    static func chemWasmChunks(size: Int = 786_432) -> [String] {
        guard let url = Bundle.main.url(forResource: "RDKit_minimal", withExtension: "wasm"), let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
        return stride(from: 0, to: data.count, by: size).map { data.subdata(in: $0..<min($0 + size, data.count)).base64EncodedString() }
    }

    /// katex.min.js, the chemistry extension and auto-render.min.js joined into one script for the reader's own content world.
    static let katexScript: String = {
        func read(_ name: String) -> String {
            Bundle.main.url(forResource: name, withExtension: "js").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        }
        let k = read("katex.min"), a = read("auto-render.min"), m = read("mhchem.min")
        return k.isEmpty || a.isEmpty ? "" : k + "\n;\n" + m + "\n;\n" + a
    }()

    static func removeCache(for id: UUID) {
        try? FileManager.default.removeItem(at: epubCache(for: id))
        try? FileManager.default.removeItem(at: pageURL(for: id))
    }
}
