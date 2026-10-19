import Foundation

public struct CodeLanguage: Sendable {
    public let name: String
    let lineComments: [String]
    let blockComment: (String, String)?
    let quotes: [Character]
    let keywords: Set<String>

    static let plain = CodeLanguage(name: "Plain", lineComments: [], blockComment: nil, quotes: [], keywords: [])

    private static func set(_ s: String) -> Set<String> { Set(s.split(separator: " ").map(String.init)) }

    private static let cLike = "if else for while do switch case break continue return default struct class enum union typedef static const void int long short char float double unsigned signed sizeof new delete this null nullptr true false try catch throw throws public private protected import package interface extends implements final abstract namespace using template typename virtual override bool string var let func fn def"
    static let table: [String: CodeLanguage] = [
        "swift": CodeLanguage(name: "Swift", lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\""], keywords: set("let var func class struct enum protocol extension import return if else guard switch case default for while in do try catch throw throws async await actor init self Self nil true false static private public internal fileprivate final override some any where as is break continue defer typealias associatedtype inout mutating")),
        "python": CodeLanguage(name: "Python", lineComments: ["#"], blockComment: ("\"\"\"", "\"\"\""), quotes: ["\"", "'"], keywords: set("def class return if elif else for while in import from as with try except finally raise pass break continue lambda yield None True False and or not is global nonlocal async await assert del")),
        "javascript": CodeLanguage(name: "JavaScript", lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'", "`"], keywords: set("function const let var return if else for while do switch case break continue default class extends new this super import export from async await try catch finally throw typeof instanceof null undefined true false in of interface type enum implements readonly public private protected")),
        "json": CodeLanguage(name: "JSON", lineComments: [], blockComment: nil, quotes: ["\""], keywords: set("true false null")),
        "yaml": CodeLanguage(name: "YAML", lineComments: ["#"], blockComment: nil, quotes: ["\"", "'"], keywords: set("true false null yes no")),
        "toml": CodeLanguage(name: "TOML", lineComments: ["#"], blockComment: nil, quotes: ["\"", "'"], keywords: set("true false")),
        "html": CodeLanguage(name: "HTML", lineComments: [], blockComment: ("<!--", "-->"), quotes: ["\"", "'"], keywords: []),
        "css": CodeLanguage(name: "CSS", lineComments: [], blockComment: ("/*", "*/"), quotes: ["\"", "'"], keywords: set("important inherit initial none auto")),
        "c": CodeLanguage(name: "C and C++", lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'"], keywords: set(cLike)),
        "java": CodeLanguage(name: "Java and C#", lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "'"], keywords: set(cLike + " fun val object")),
        "rust": CodeLanguage(name: "Rust", lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\""], keywords: set("fn let mut const static struct enum impl trait pub use mod crate self Self super match if else for while loop in return break continue where as ref move async await dyn type unsafe true false")),
        "go": CodeLanguage(name: "Go", lineComments: ["//"], blockComment: ("/*", "*/"), quotes: ["\"", "`"], keywords: set("func var const type struct interface package import return if else for range switch case default break continue go defer select chan map nil true false")),
        "shell": CodeLanguage(name: "Shell", lineComments: ["#"], blockComment: nil, quotes: ["\"", "'"], keywords: set("if then else elif fi for while do done case esac function in return exit export local echo cd set unset")),
        "ruby": CodeLanguage(name: "Ruby", lineComments: ["#"], blockComment: nil, quotes: ["\"", "'"], keywords: set("def end class module if elsif else unless while until for in do return yield begin rescue ensure require nil true false self")),
        "php": CodeLanguage(name: "PHP", lineComments: ["//", "#"], blockComment: ("/*", "*/"), quotes: ["\"", "'"], keywords: set(cLike + " function echo foreach as array")),
        "sql": CodeLanguage(name: "SQL", lineComments: ["--"], blockComment: ("/*", "*/"), quotes: ["'"], keywords: set("select from where insert into values update set delete create table drop alter join left right inner outer on group by order having limit and or not null as distinct union primary key index SELECT FROM WHERE INSERT INTO VALUES UPDATE SET DELETE CREATE TABLE DROP ALTER JOIN LEFT RIGHT INNER OUTER ON GROUP BY ORDER HAVING LIMIT AND OR NOT NULL AS DISTINCT UNION PRIMARY KEY INDEX")),
        "lua": CodeLanguage(name: "Lua", lineComments: ["--"], blockComment: ("--[[", "]]"), quotes: ["\"", "'"], keywords: set("function end if then else elseif for while do repeat until return local nil true false and or not in break")),
        "xml": CodeLanguage(name: "XML", lineComments: [], blockComment: ("<!--", "-->"), quotes: ["\"", "'"], keywords: []),
    ]

    private static let extensions: [String: String] = [
        "swift": "swift", "py": "python", "js": "javascript", "ts": "javascript", "tsx": "javascript", "jsx": "javascript",
        "json": "json", "yaml": "yaml", "yml": "yaml", "toml": "toml", "html": "html", "htm": "html", "css": "css",
        "c": "c", "h": "c", "cpp": "c", "hpp": "c", "m": "c", "java": "java", "cs": "java", "kt": "java",
        "rs": "rust", "go": "go", "sh": "shell", "rb": "ruby", "php": "php", "sql": "sql", "lua": "lua", "xml": "xml",
    ]

    public static func detect(fileName: String, firstLine: String? = nil) -> CodeLanguage {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if let key = extensions[ext], let lang = table[key] { return lang }
        if let line = firstLine, line.hasPrefix("#!") {
            let l = line.lowercased()
            if l.contains("python") { return table["python"]! }
            if l.contains("node") { return table["javascript"]! }
            if l.contains("ruby") { return table["ruby"]! }
            if l.contains("sh") { return table["shell"]! }
        }
        return plain
    }
}
