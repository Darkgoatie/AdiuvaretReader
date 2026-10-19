import Foundation

public enum StoreLocation {
    /// The file the Reader's records have always lived in: `default.store` in the app's own Application Support folder.
    /// It is named on purpose. With an App Group entitlement SwiftData's unnamed default moves into the group container,
    /// which looks like an empty library with no progress, bookmarks or highlights.
    public static func defaultStoreURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("default.store")
    }
}
