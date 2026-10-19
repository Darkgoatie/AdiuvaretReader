import Foundation

public struct FolderImportReport: Sendable, Equatable {
    public let destination: String
    public let imported: Int
    public let removedFromSource: Int
    public let failed: Int
}

public enum FolderImportError: Error, Equatable {
    case unreadable
}

public enum FolderImport {
    /// Brings every file under `source` into a new folder of `store` named after the source, keeping the subfolders.
    /// With `move`, an original is deleted only after its copy was written; folders left empty are removed, the chosen folder itself stays.
    public static func run(source: URL, into store: FileStore, move: Bool) throws -> FolderImportReport {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let rootPath = source.resolvingSymlinksInPath().path
        guard let walker = fm.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            throw FolderImportError.unreadable
        }

        var files: [(url: URL, relative: String)] = []
        var folders: [(url: URL, relative: String)] = []
        for case let url as URL in walker {
            let path = url.resolvingSymlinksInPath().path
            guard path.hasPrefix(rootPath + "/") else { continue }
            let relative = String(path.dropFirst(rootPath.count + 1))
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                folders.append((url, relative))
            } else {
                files.append((url, relative))
            }
        }

        let base = source.lastPathComponent.isEmpty ? "Imported" : source.lastPathComponent
        var destination = ""
        var n = 1
        while destination.isEmpty {
            let name = n == 1 ? base : "\(base) \(n)"
            if let made = try? store.createFolder(named: name) { destination = made } else if n > 500 { throw FolderImportError.unreadable }
            n += 1
        }

        for f in folders {
            if let dir = try? store.resolve(destination + "/" + f.relative) { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        }

        var imported = 0, removed = 0, failed = 0
        for f in files {
            guard let target = try? store.resolve(destination + "/" + f.relative) else { failed += 1; continue }
            do {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: f.url, to: target)
                imported += 1
                if move, (try? fm.removeItem(at: f.url)) != nil { removed += 1 }
            } catch {
                failed += 1
            }
        }

        if move {
            for d in folders.sorted(by: { $0.relative.count > $1.relative.count }) {
                if let left = try? fm.contentsOfDirectory(atPath: d.url.path), left.isEmpty { try? fm.removeItem(at: d.url) }
            }
        }
        return FolderImportReport(destination: destination, imported: imported, removedFromSource: removed, failed: failed)
    }
}
