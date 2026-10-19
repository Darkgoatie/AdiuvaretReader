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

    static func removeCache(for id: UUID) {
        try? FileManager.default.removeItem(at: epubCache(for: id))
        try? FileManager.default.removeItem(at: pageURL(for: id))
    }
}
