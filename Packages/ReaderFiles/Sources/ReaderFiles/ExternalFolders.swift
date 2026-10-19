import Foundation

public struct ExternalFolder: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    let bookmark: Data
}

/// Folders the user chose outside the app, remembered with security-scoped bookmarks. They are only read; files are copied in to keep.
public final class ExternalFolderStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let scoped: Bool

    public init(defaults: UserDefaults = .standard, key: String = "files.external", scoped: Bool? = nil) {
        self.defaults = defaults
        self.key = key
        #if os(macOS)
        self.scoped = scoped ?? true
        #else
        self.scoped = scoped ?? false
        #endif
    }

    public var folders: [ExternalFolder] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ExternalFolder].self, from: data)) ?? []
    }

    private func save(_ list: [ExternalFolder]) {
        defaults.set(try? JSONEncoder().encode(list), forKey: key)
    }

    #if os(macOS)
    private var createOptions: URL.BookmarkCreationOptions { scoped ? [.withSecurityScope] : [] }
    private var resolveOptions: URL.BookmarkResolutionOptions { scoped ? [.withSecurityScope] : [] }
    #else
    private var createOptions: URL.BookmarkCreationOptions { [] }
    private var resolveOptions: URL.BookmarkResolutionOptions { [] }
    #endif

    @discardableResult
    public func add(_ url: URL) throws -> ExternalFolder {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: createOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        var list = folders.filter { $0.name != url.lastPathComponent || $0.bookmark != data }
        let folder = ExternalFolder(id: UUID(), name: url.lastPathComponent, bookmark: data)
        list.append(folder)
        save(list)
        return folder
    }

    public func remove(_ id: UUID) { save(folders.filter { $0.id != id }) }

    /// The folder's current URL, or nil when it no longer exists. Call `startAccessingSecurityScopedResource` on it before reading.
    public func resolve(_ folder: ExternalFolder) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: folder.bookmark, options: resolveOptions, relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: createOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
            save(folders.map { $0.id == folder.id ? ExternalFolder(id: $0.id, name: $0.name, bookmark: fresh) : $0 })
        }
        return url
    }

    /// Lists a folder's direct contents, with access opened for the call.
    public func contents(of url: URL) -> [URL] {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])) ?? [])
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

public struct ExternalEntry: Identifiable, Hashable, Sendable {
    public var id: String { relativePath }
    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let size: Int64
}

public enum ExternalError: Error, Equatable {
    case unavailable
    case unsafePath
}

extension ExternalFolderStore {
    private func target(_ folder: ExternalFolder, _ subpath: String) throws -> (root: URL, url: URL) {
        let parts = subpath.split(separator: "/", omittingEmptySubsequences: true)
        if parts.contains("..") { throw ExternalError.unsafePath }
        guard let root = resolve(folder) else { throw ExternalError.unavailable }
        return (root, parts.reduce(root) { $0.appendingPathComponent(String($1)) })
    }

    /// Direct contents of `subpath` inside the folder. Folders come first.
    public func list(_ folder: ExternalFolder, subpath: String = "") -> [ExternalEntry] {
        guard let t = try? target(folder, subpath) else { return [] }
        let access = t.root.startAccessingSecurityScopedResource()
        defer { if access { t.root.stopAccessingSecurityScopedResource() } }
        let urls = (try? FileManager.default.contentsOfDirectory(at: t.url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        let entries = urls.map { u -> ExternalEntry in
            let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let rel = subpath.isEmpty ? u.lastPathComponent : subpath + "/" + u.lastPathComponent
            return ExternalEntry(name: u.lastPathComponent, relativePath: rel, isDirectory: v?.isDirectory ?? false, size: Int64(v?.fileSize ?? 0))
        }
        return entries.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Copies one file or folder from the external folder into `dest`. The original is left alone.
    @discardableResult
    public func copy(_ folder: ExternalFolder, subpath: String, into dest: FileStore, folderPath: String = "") throws -> String {
        let t = try target(folder, subpath)
        let access = t.root.startAccessingSecurityScopedResource()
        defer { if access { t.root.stopAccessingSecurityScopedResource() } }
        return try dest.addCopy(of: t.url, toFolder: folderPath)
    }
}

public enum SharedSpace {
    public static let groupID = "group.com.halit.adiuvaret"

    /// The shared folder inside the App Group container, or nil when this build is not signed with the group.
    public static func store(group: String = groupID) -> FileStore? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return FileStore(root: base.appendingPathComponent("Shared", isDirectory: true))
    }
}

public enum LibraryScan {
    /// Paths in `files` that have no book yet and are a kind the reader can open.
    public static func unindexed(files: [String], known: Set<String>, canOpen: (String) -> Bool) -> [String] {
        files.filter { !known.contains($0) && canOpen($0) }
    }
}
