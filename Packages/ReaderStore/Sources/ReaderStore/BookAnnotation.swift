import Foundation
import SwiftData

public enum AnnotationKind: String, Codable, CaseIterable, Sendable {
    case highlight, note, bookmark
}

@Model
public final class BookAnnotation {
    public var id: UUID = UUID()
    public var bookID: UUID = UUID()
    public var kindRaw: String = AnnotationKind.highlight.rawValue
    /// Position text, see ReadingPosition.
    public var locator: String = ""
    public var quote: String = ""
    public var note: String = ""
    public var createdAt: Date = Date()

    public init(bookID: UUID, kind: AnnotationKind, locator: String, quote: String = "", note: String = "") {
        self.bookID = bookID
        self.kindRaw = kind.rawValue
        self.locator = locator
        self.quote = quote
        self.note = note
    }

    public var kind: AnnotationKind { AnnotationKind(rawValue: kindRaw) ?? .highlight }
}
