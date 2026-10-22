import Foundation

/// One page of ink: PencilKit's drawing data and the key it was saved under.
public struct InkPage: Codable, Equatable, Sendable {
    public var layout: String
    public var drawing: Data
    public var updatedAt: Date

    public init(layout: String, drawing: Data, updatedAt: Date = Date()) {
        self.layout = layout
        self.drawing = drawing
        self.updatedAt = updatedAt
    }
}

public enum InkStoreError: Error, Equatable { case badKey }

/// Ink lives in files of its own, one folder per book and one file per page or chapter, and not in the library database.
/// A change to the database schema can reset a library, and drawings must never be put at that risk.
public struct InkStore: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public static func standard() -> InkStore {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return InkStore(root: base.appendingPathComponent("Ink", isDirectory: true))
    }

    /// Keys are short names such as `p12` (PDF page 12) or `c3-9f2a61bc` (chapter 3 at one text layout). Anything else is refused,
    /// so a key can never point outside the book's folder.
    public static func isValid(key: String) -> Bool {
        !key.isEmpty && key.count <= 40 && key.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" || $0 == "_" }
    }

    private func folder(_ bookID: UUID) -> URL { root.appendingPathComponent(bookID.uuidString, isDirectory: true) }

    private func file(_ bookID: UUID, _ key: String) -> URL? {
        InkStore.isValid(key: key) ? folder(bookID).appendingPathComponent(key + ".ink") : nil
    }

    public func load(bookID: UUID, key: String) -> InkPage? {
        guard let url = file(bookID, key), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(InkPage.self, from: data)
    }

    public func save(_ page: InkPage, bookID: UUID, key: String) throws {
        guard let url = file(bookID, key) else { throw InkStoreError.badKey }
        try FileManager.default.createDirectory(at: folder(bookID), withIntermediateDirectories: true)
        try JSONEncoder().encode(page).write(to: url, options: .atomic)
    }

    public func remove(bookID: UUID, key: String) {
        guard let url = file(bookID, key) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public func removeAll(bookID: UUID) {
        try? FileManager.default.removeItem(at: folder(bookID))
    }

    /// The pages and chapters that have ink, sorted.
    public func keys(bookID: UUID) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder(bookID).path)) ?? []
        return names.filter { $0.hasSuffix(".ink") }.map { String($0.dropLast(4)) }.sorted()
    }

    public func hasInk(bookID: UUID) -> Bool { !keys(bookID: bookID).isEmpty }
}

/// Ink on reflowing text is drawn at fixed positions, so it only lines up with the text it was drawn on. Each text layout gets its own
/// file: changing the font size shows the ink drawn at that size, and the ink drawn at the other sizes is kept.
public enum InkLayout {
    public static func signature(font: String, fontSize: Double, lineSpacing: Double, margin: Double, width: Double) -> String {
        "v1|\(font)|\(String(format: "%.1f", fontSize))|\(String(format: "%.2f", lineSpacing))|\(String(format: "%.2f", margin))|\(Int(width.rounded()))"
    }

    /// `c3` plus a short stable hash of the layout: `c3-9f2a61bc`.
    public static func key(page: String, signature: String) -> String {
        var h: UInt32 = 2_166_136_261
        for b in signature.utf8 { h ^= UInt32(b); h = h &* 16_777_619 }
        return page + "-" + String(format: "%08x", h)
    }
}
