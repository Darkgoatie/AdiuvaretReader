import Foundation

/// The link other apps use to open a file or folder of the shared folder in the Reader:
/// `adiuvaretreader://open?path=Notes/Chapter.md&fragment=Heading`.
public enum ReaderLink {
    public static let scheme = "adiuvaretreader"
    public static let maxPath = 500

    static func valid(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        return !parts.isEmpty && path.count <= maxPath && !path.hasPrefix("/") && !parts.contains("..") && !path.contains("\0")
    }

    public static func url(path: String, fragment: String? = nil) -> URL? {
        guard valid(path) else { return nil }
        var c = URLComponents()
        c.scheme = scheme
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "path", value: path)] + (fragment.flatMap { $0.isEmpty ? nil : URLQueryItem(name: "fragment", value: $0) }.map { [$0] } ?? [])
        return c.url
    }

    /// The shared-folder path and optional heading or page fragment in a link, or nil when it is not a valid Reader link.
    public static func parse(_ url: URL) -> (path: String, fragment: String?)? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == "open",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let path = items.first(where: { $0.name == "path" })?.value, valid(path)
        else { return nil }
        let fragment = items.first(where: { $0.name == "fragment" })?.value
        return (path, fragment?.isEmpty == false ? fragment : nil)
    }
}
