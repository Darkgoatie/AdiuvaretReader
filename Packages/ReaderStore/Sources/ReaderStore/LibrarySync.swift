import Foundation

public struct BookRef: Sendable, Equatable {
    public let path: String
    public let missing: Bool

    public init(path: String, missing: Bool) {
        self.path = path
        self.missing = missing
    }
}

public enum LibrarySync {
    public struct Plan: Equatable, Sendable {
        public var add: [String] = []
        public var markMissing: [String] = []
        public var markPresent: [String] = []
        public var delete: [String] = []
        public init() {}
    }

    /// What to change so the book records match the files on disk.
    /// A record whose file is gone is kept (marked missing) while the file sits in Recently Deleted, and dropped otherwise.
    public static func plan(files: [String], books: [BookRef], trashedOriginals: [String], canOpen: (String) -> Bool) -> Plan {
        var plan = Plan()
        let fileSet = Set(files)
        let known = Set(books.map(\.path))
        plan.add = files.filter { !known.contains($0) && canOpen($0) }
        for b in books {
            if fileSet.contains(b.path) {
                if b.missing { plan.markPresent.append(b.path) }
            } else if trashedOriginals.contains(where: { b.path == $0 || b.path.hasPrefix($0 + "/") }) {
                if !b.missing { plan.markMissing.append(b.path) }
            } else {
                plan.delete.append(b.path)
            }
        }
        return plan
    }

    /// The new path of `path` after `old` was renamed or moved to `new`, or nil when `path` is not affected.
    public static func rebase(_ path: String, from old: String, to new: String) -> String? {
        if path == old { return new }
        if path.hasPrefix(old + "/") { return new + String(path.dropFirst(old.count)) }
        return nil
    }
}
