import Foundation
import SwiftData

public enum AnnotationKind: String, Codable, CaseIterable, Sendable {
    case highlight, note, bookmark
}

public enum HighlightColor: String, CaseIterable, Identifiable, Sendable {
    case green, yellow, blue, pink

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public static func resolve(_ raw: String) -> HighlightColor { HighlightColor(rawValue: raw) ?? .green }
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
    public var colorRaw: String = HighlightColor.green.rawValue

    public init(bookID: UUID, kind: AnnotationKind, locator: String, quote: String = "", note: String = "", color: HighlightColor = .green) {
        self.bookID = bookID
        self.kindRaw = kind.rawValue
        self.locator = locator
        self.quote = quote
        self.note = note
        self.colorRaw = color.rawValue
    }

    public var kind: AnnotationKind { AnnotationKind(rawValue: kindRaw) ?? .highlight }
    public var color: HighlightColor { HighlightColor.resolve(colorRaw) }
}
