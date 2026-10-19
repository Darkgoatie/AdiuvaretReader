import Foundation

public enum LibraryError: Error, Equatable {
    case unsupported
    case unreadable
}

/// The folder where imported files live. Paths stored in the database are relative to it, so a moved container still resolves.
public struct LibraryFolder: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public static func standard() -> LibraryFolder {
        let docs = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return LibraryFolder(root: docs.appendingPathComponent("Library", isDirectory: true))
    }

    public func url(for relativePath: String) -> URL { root.appendingPathComponent(relativePath) }

    /// Copies a file into the library and returns its relative path and format. A name that exists gets a numeric suffix, never an overwrite.
    public func importFile(at source: URL) throws -> (relativePath: String, format: BookFormat) {
        let name = source.lastPathComponent
        guard let format = BookFormat.detect(fileName: name) else { throw LibraryError.unsupported }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let target = uniqueURL(for: name)
        do { try fm.copyItem(at: source, to: target) } catch { throw LibraryError.unreadable }
        return (target.lastPathComponent, format)
    }

    func uniqueURL(for name: String) -> URL {
        let fm = FileManager.default
        var candidate = root.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        repeat {
            let next = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = root.appendingPathComponent(next)
            n += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    public static func title(fromFileName name: String) -> String {
        (name as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ")
    }
}
