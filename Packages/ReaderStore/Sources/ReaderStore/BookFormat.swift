import Foundation

public enum BookFormat: String, Codable, CaseIterable, Sendable {
    case epub, pdf, text, markdown, code

    private static let codeExtensions: Set<String> = [
        "swift", "py", "js", "ts", "tsx", "jsx", "json", "yaml", "yml", "toml", "html", "css", "c", "h", "cpp", "hpp",
        "m", "rs", "go", "sh", "rb", "java", "kt", "php", "sql", "xml", "lua", "cs",
    ]

    /// The format for a file name, or nil when the reader cannot open it.
    public static func detect(fileName: String) -> BookFormat? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "epub": return .epub
        case "pdf": return .pdf
        case "txt", "text": return .text
        case "md", "markdown": return .markdown
        default: return codeExtensions.contains(ext) ? .code : nil
        }
    }

    public var title: String {
        switch self {
        case .epub: "EPUB"
        case .pdf: "PDF"
        case .text: "Text"
        case .markdown: "Markdown"
        case .code: "Code"
        }
    }

    public var symbol: String {
        switch self {
        case .epub: "book.closed"
        case .pdf: "doc.richtext"
        case .text, .markdown: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }
}
