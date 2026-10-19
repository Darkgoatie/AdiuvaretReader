import Foundation

public enum FileStoreError: Error, Equatable {
    case nameCollision
    case outsideRoot
    case moveIntoSelf
    case notFound
    case invalidName
}

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: String { relativePath }
    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let size: Int64
    public let modified: Date?
}

public struct TrashedItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let originalPath: String
    public let deletedAt: Date
    public let isDirectory: Bool
}

public enum FileSort: String, CaseIterable, Identifiable, Sendable {
    case name, date, size

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .name: "Name"
        case .date: "Date"
        case .size: "Size"
        }
    }
}

/// File operations inside one root folder. Every path is relative to the root, and nothing can reach outside it.
public struct FileStore: Sendable {
    public static let trashName = ".RecentlyDeleted"
    public static let retentionDays = 30

    public let root: URL

    public init(root: URL) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.root = root.resolvingSymlinksInPath()
    }

    // MARK: Paths

    public func resolve(_ relative: String) throws -> URL {
        if relative.hasPrefix("/") { throw FileStoreError.outsideRoot }
        let parts = relative.split(separator: "/", omittingEmptySubsequences: true)
        if parts.contains("..") { throw FileStoreError.outsideRoot }
        let url = parts.reduce(root) { $0.appendingPathComponent(String($1)) }
        let real = url.resolvingSymlinksInPath().path
        guard real == root.path || real.hasPrefix(root.path + "/") else { throw FileStoreError.outsideRoot }
        return url
    }

    private func relative(_ url: URL) -> String {
        let p = url.resolvingSymlinksInPath().path
        guard p.hasPrefix(root.path + "/") else { return "" }
        return String(p.dropFirst(root.path.count + 1))
    }

    static func validName(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && !n.contains("/") && !n.contains(":") && !n.hasPrefix(".") && n != ".." && n.utf8.count <= 255
    }

    private func isDirectory(_ url: URL) -> Bool {
        var d: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &d) && d.boolValue
    }

    private func item(_ url: URL, parent: String) -> FileItem {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        let dir = values?.isDirectory ?? false
        let name = url.lastPathComponent
        return FileItem(name: name, relativePath: parent.isEmpty ? name : parent + "/" + name, isDirectory: dir,
                        size: Int64(values?.fileSize ?? 0), modified: values?.contentModificationDate)
    }

    private func unique(_ name: String, in folder: URL) -> URL {
        let fm = FileManager.default
        var candidate = folder.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        repeat {
            candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    // MARK: Listing

    public func list(_ folder: String = "", sort: FileSort = .name) throws -> [FileItem] {
        let url = try resolve(folder)
        guard isDirectory(url) else { throw FileStoreError.notFound }
        let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let items = urls.map { item($0, parent: folder) }
        return Self.sorted(items, by: sort)
    }

    static func sorted(_ items: [FileItem], by sort: FileSort) -> [FileItem] {
        items.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            switch sort {
            case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date: return (a.modified ?? .distantPast) > (b.modified ?? .distantPast)
            case .size: return a.size > b.size
            }
        }
    }

    /// Every file and folder whose name contains `query`, anywhere under the root.
    public func search(_ query: String, limit: Int = 300) -> [FileItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var out: [FileItem] = []
        func walk(_ folder: String) {
            guard out.count < limit, let items = try? list(folder) else { return }
            for i in items {
                if i.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil { out.append(i) }
                if i.isDirectory { walk(i.relativePath) }
            }
        }
        walk("")
        return out
    }

    /// Relative paths of every file under the root.
    public func allFiles() -> [String] {
        var out: [String] = []
        func walk(_ folder: String) {
            guard let items = try? list(folder) else { return }
            for i in items { if i.isDirectory { walk(i.relativePath) } else { out.append(i.relativePath) } }
        }
        walk("")
        return out
    }

    public func size(of path: String) -> Int64 {
        guard let url = try? resolve(path) else { return 0 }
        if !isDirectory(url) { return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return ((try? list(path)) ?? []).reduce(0) { $0 + ($1.isDirectory ? size(of: $1.relativePath) : $1.size) }
    }

    // MARK: Changes

    @discardableResult
    public func createFolder(named name: String, in folder: String = "") throws -> String {
        guard Self.validName(name) else { throw FileStoreError.invalidName }
        let parent = try resolve(folder)
        let target = parent.appendingPathComponent(name.trimmingCharacters(in: .whitespaces), isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) { throw FileStoreError.nameCollision }
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        return relative(target)
    }

    @discardableResult
    public func rename(_ path: String, to newName: String) throws -> String {
        guard Self.validName(newName) else { throw FileStoreError.invalidName }
        let src = try resolve(path)
        guard FileManager.default.fileExists(atPath: src.path) else { throw FileStoreError.notFound }
        let dst = src.deletingLastPathComponent().appendingPathComponent(newName.trimmingCharacters(in: .whitespaces))
        if dst.path == src.path { return path }
        if FileManager.default.fileExists(atPath: dst.path) { throw FileStoreError.nameCollision }
        try FileManager.default.moveItem(at: src, to: dst)
        return relative(dst)
    }

    @discardableResult
    public func move(_ path: String, toFolder folder: String) throws -> String {
        let src = try resolve(path)
        let dstFolder = try resolve(folder)
        guard FileManager.default.fileExists(atPath: src.path) else { throw FileStoreError.notFound }
        let cleanFolder = folder.split(separator: "/").joined(separator: "/")
        let cleanPath = path.split(separator: "/").joined(separator: "/")
        if cleanFolder == cleanPath || cleanFolder.hasPrefix(cleanPath + "/") { throw FileStoreError.moveIntoSelf }
        let dst = unique(src.lastPathComponent, in: dstFolder)
        try FileManager.default.moveItem(at: src, to: dst)
        return relative(dst)
    }

    @discardableResult
    public func copy(_ path: String, toFolder folder: String) throws -> String {
        let src = try resolve(path)
        let dstFolder = try resolve(folder)
        guard FileManager.default.fileExists(atPath: src.path) else { throw FileStoreError.notFound }
        let cleanFolder = folder.split(separator: "/").joined(separator: "/")
        let cleanPath = path.split(separator: "/").joined(separator: "/")
        if cleanFolder == cleanPath || cleanFolder.hasPrefix(cleanPath + "/") { throw FileStoreError.moveIntoSelf }
        let dst = unique(src.lastPathComponent, in: dstFolder)
        try FileManager.default.copyItem(at: src, to: dst)
        return relative(dst)
    }

    /// Copies a file from outside the root into `folder`, never overwriting.
    @discardableResult
    public func addCopy(of external: URL, toFolder folder: String = "") throws -> String {
        let dstFolder = try resolve(folder)
        let dst = unique(external.lastPathComponent, in: dstFolder)
        try FileManager.default.copyItem(at: external, to: dst)
        return relative(dst)
    }

    // MARK: Recently Deleted

    private struct TrashInfo: Codable {
        let originalPath: String
        let deletedAt: Date
    }

    private var trashURL: URL { root.appendingPathComponent(Self.trashName, isDirectory: true) }

    public func trash(_ path: String, now: Date = Date()) throws {
        let src = try resolve(path)
        guard FileManager.default.fileExists(atPath: src.path) else { throw FileStoreError.notFound }
        let id = UUID().uuidString
        let box = trashURL.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: box, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: src, to: box.appendingPathComponent(src.lastPathComponent))
        let info = TrashInfo(originalPath: path.split(separator: "/").joined(separator: "/"), deletedAt: now)
        try JSONEncoder().encode(info).write(to: box.appendingPathComponent(".info.json"))
    }

    public func recentlyDeleted() -> [TrashedItem] {
        guard let boxes = try? FileManager.default.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil) else { return [] }
        var out: [TrashedItem] = []
        for box in boxes {
            guard let data = try? Data(contentsOf: box.appendingPathComponent(".info.json")),
                  let info = try? JSONDecoder().decode(TrashInfo.self, from: data),
                  let file = try? FileManager.default.contentsOfDirectory(at: box, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).first
            else { continue }
            out.append(TrashedItem(id: box.lastPathComponent, name: file.lastPathComponent, originalPath: info.originalPath,
                                   deletedAt: info.deletedAt, isDirectory: isDirectory(file)))
        }
        return out.sorted { $0.deletedAt > $1.deletedAt }
    }

    /// Puts an item back where it was, or in the root if its folder is gone. Returns the new path.
    @discardableResult
    public func restore(_ id: String) throws -> String {
        let box = trashURL.appendingPathComponent(id, isDirectory: true)
        guard let file = try? FileManager.default.contentsOfDirectory(at: box, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).first,
              let data = try? Data(contentsOf: box.appendingPathComponent(".info.json")),
              let info = try? JSONDecoder().decode(TrashInfo.self, from: data)
        else { throw FileStoreError.notFound }
        let parentPath = (info.originalPath as NSString).deletingLastPathComponent
        var parent = (try? resolve(parentPath)) ?? root
        if !isDirectory(parent) { parent = root }
        let dst = unique(file.lastPathComponent, in: parent)
        try FileManager.default.moveItem(at: file, to: dst)
        try? FileManager.default.removeItem(at: box)
        return relative(dst)
    }

    public func deletePermanently(_ id: String) {
        try? FileManager.default.removeItem(at: trashURL.appendingPathComponent(id, isDirectory: true))
    }

    public func emptyTrash() {
        for t in recentlyDeleted() { deletePermanently(t.id) }
    }

    /// Removes items deleted more than `retentionDays` ago. Returns how many.
    @discardableResult
    public func purgeExpired(now: Date = Date()) -> Int {
        let limit = TimeInterval(Self.retentionDays) * 86_400
        let old = recentlyDeleted().filter { now.timeIntervalSince($0.deletedAt) > limit }
        old.forEach { deletePermanently($0.id) }
        return old.count
    }
}
