import Foundation
import SwiftData
import ReaderStore
import ReaderFiles
import ReaderFormats

enum Services {
    static let library = LibraryFolder.standard()
    static let files = FileStore(root: LibraryFolder.standard().root)
    static let externals = ExternalFolderStore()
    static let shared: FileStore? = SharedSpace.store()

    static func url(for book: Book) -> URL? {
        if book.isShared { return try? shared?.resolve(book.relativePath) }
        return try? files.resolve(book.relativePath)
    }
}

@MainActor
enum LibraryService {
    /// Makes the book records match the files in the library folder.
    static func sync(_ context: ModelContext) {
        let store = Services.files
        store.purgeExpired()
        let books = ((try? context.fetch(FetchDescriptor<Book>())) ?? []).filter { !$0.isShared }
        let plan = LibrarySync.plan(
            files: store.allFiles(),
            books: books.map { BookRef(path: $0.relativePath, missing: $0.isMissing) },
            trashedOriginals: store.recentlyDeleted().map(\.originalPath),
            canOpen: { BookFormat.detect(fileName: $0) != nil })
        for path in plan.add { insert(path, into: context) }
        for b in books {
            if plan.markMissing.contains(b.relativePath) { b.isMissing = true }
            if plan.markPresent.contains(b.relativePath) { b.isMissing = false }
            if plan.delete.contains(b.relativePath) {
                let id = b.id
                let notes = (try? context.fetch(FetchDescriptor<BookAnnotation>(predicate: #Predicate { $0.bookID == id }))) ?? []
                notes.forEach { context.delete($0) }
                context.delete(b)
            }
        }
        try? context.save()
    }

    static func insert(_ path: String, into context: ModelContext) {
        guard let format = BookFormat.detect(fileName: path) else { return }
        var title = LibraryFolder.title(fromFileName: (path as NSString).lastPathComponent)
        var author = ""
        if format == .epub, let url = try? Services.files.resolve(path), let md = EpubBook.metadata(at: url) {
            if !md.title.isEmpty { title = md.title }
            author = md.author
        }
        context.insert(Book(title: title, author: author, format: format, relativePath: path))
    }

    /// Follows a rename or move so progress and notes stay with the file.
    static func rebase(_ context: ModelContext, from old: String, to new: String) {
        let books = ((try? context.fetch(FetchDescriptor<Book>())) ?? []).filter { !$0.isShared }
        for b in books {
            if let p = LibrarySync.rebase(b.relativePath, from: old, to: new) { b.relativePath = p }
        }
        try? context.save()
    }

    /// The record for a file, made if it does not exist yet. Shared files get a record of their own so progress and notes are kept.
    static func book(at path: String, shared: Bool, in context: ModelContext) -> Book? {
        let all = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        if let b = all.first(where: { $0.relativePath == path && $0.isShared == shared }) { return b }
        guard let format = BookFormat.detect(fileName: path) else { return nil }
        let title = LibraryFolder.title(fromFileName: (path as NSString).lastPathComponent)
        let b = Book(title: title, format: format, relativePath: path)
        b.storage = shared ? "shared" : "library"
        context.insert(b)
        return b
    }
}
