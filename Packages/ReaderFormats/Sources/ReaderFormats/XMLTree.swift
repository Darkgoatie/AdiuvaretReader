import Foundation

/// A small in-memory XML tree, enough to read EPUB container, package and NCX files.
public final class XNode {
    public let name: String
    public let attrs: [String: String]
    public var text = ""
    public var children: [XNode] = []

    init(name: String, attrs: [String: String]) {
        self.name = name
        self.attrs = attrs
    }

    public func descendants(named n: String) -> [XNode] {
        var out: [XNode] = []
        for c in children {
            if c.name == n { out.append(c) }
            out.append(contentsOf: c.descendants(named: n))
        }
        return out
    }

    public func first(named n: String) -> XNode? { descendants(named: n).first }
    public func child(named n: String) -> XNode? { children.first { $0.name == n } }
}

public enum XMLTree {
    public static func parse(_ data: Data) -> XNode? {
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        guard parser.parse() else { return nil }
        return builder.root
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: XNode?
        var stack: [XNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
            let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
            let node = XNode(name: local, attrs: attributeDict)
            if let top = stack.last { top.children.append(node) } else { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            _ = stack.popLast()
        }
    }
}
