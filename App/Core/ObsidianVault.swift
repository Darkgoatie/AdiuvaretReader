import Foundation
import ReaderFormats
import ReaderFiles

/// Lets a note find the other files of the library folder it lives in, the way an Obsidian vault does.
enum ObsidianVault {
    static func context(for path: String, shared: Bool, files: FileStore?) -> ObsidianContext {
        guard let files else { return ObsidianContext(index: VaultIndex(paths: []), currentPath: path, fileURL: { _ in nil }, readNote: { _ in nil }) }
        let all = files.allFiles()
        return ObsidianContext(
            index: VaultIndex(paths: all),
            currentPath: path,
            fileURL: { rel in (try? files.resolve(rel))?.absoluteString },
            readNote: { rel in
                guard let url = try? files.resolve(rel), let data = try? Data(contentsOf: url) else { return nil }
                return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            })
    }
}
