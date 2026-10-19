import Foundation
import SwiftData

@Model
public final class Book {
    public var id: UUID = UUID()
    public var title: String = ""
    public var author: String = ""
    public var formatRaw: String = BookFormat.text.rawValue
    public var relativePath: String = ""
    public var addedAt: Date = Date()
    public var lastOpenedAt: Date?
    /// 0 to 1.
    public var progress: Double = 0
    /// Format specific position, written by the reader.
    public var locator: String?
    /// True while the file is not in the library folder, for example in Recently Deleted. Progress and notes are kept for a restore.
    public var isMissing: Bool = false
    /// "library" for the app's own folder, "shared" for the App Group folder shared with the user's other apps.
    public var storage: String = "library"
    public var isFavorite: Bool = false

    public init(title: String, author: String = "", format: BookFormat, relativePath: String) {
        self.title = title
        self.author = author
        self.formatRaw = format.rawValue
        self.relativePath = relativePath
    }

    public var isShared: Bool { storage == "shared" }

    public var format: BookFormat { BookFormat(rawValue: formatRaw) ?? .text }
}
