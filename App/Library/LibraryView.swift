import SwiftUI
import SwiftData
import ReaderDesign
import ReaderStore

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent, title, added
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: "Recently read"
        case .title: "Title"
        case .added: "Date added"
        }
    }
}

struct LibraryView: View {
    let open: (Book) -> Void
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Book> { !$0.isMissing }) private var books: [Book]
    @State private var importing = false
    @State private var showSettings = false
    @State private var importError: String?
    @State private var search = ""
    @State private var sort = LibrarySort.recent
    @State private var filter: BookFormat?
    @State private var favoritesOnly = false
    @State private var renaming: Book?
    @State private var renameText = ""
    @State private var undo: UndoDelete?
    @AppStorage("library.grid") private var grid = true
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            WallpaperBackground()
            if books.isEmpty { empty } else if shown.isEmpty { noResults } else if useGrid { gridView } else { listView }
        }
        .navigationTitle("Library")
        .searchable(text: $search, prompt: "Search titles and authors")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { importing = true } label: { Label("Add files", systemImage: "plus") }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Picker("Sort", selection: $sort) { ForEach(LibrarySort.allCases) { Text($0.title).tag($0) } }
                    Picker("Show", selection: $filter) {
                        Text("All types").tag(BookFormat?.none)
                        ForEach(BookFormat.allCases, id: \.self) { Text($0.title).tag(BookFormat?.some($0)) }
                    }
                    Toggle("Favorites only", isOn: $favoritesOnly)
                    Toggle("Grid", isOn: $grid)
                } label: { Label("View options", systemImage: "line.3.horizontal.decrease.circle") }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { handle($0) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .overlay(alignment: .bottom) { undoBanner }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") { if let b = renaming { rename(b, to: renameText) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .alert("Could not add file", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
    }

    private var useGrid: Bool { grid && sizeClass == .regular }

    private var shown: [Book] {
        var list = books
        if let filter { list = list.filter { $0.format == filter } }
        if favoritesOnly { list = list.filter(\.isFavorite) }
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { list = list.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.author.localizedCaseInsensitiveContains(q) } }
        let order = sorted(list)
        return order.filter(\.isFavorite) + order.filter { !$0.isFavorite }
    }

    private func sorted(_ list: [Book]) -> [Book] {
        switch sort {
        case .recent: return list.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
        case .title: return list.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .added: return list.sorted { $0.addedAt > $1.addedAt }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No books yet", systemImage: "books.vertical")
        } description: {
            Text("Add EPUB, PDF, text or code files. They stay on this device.")
        } actions: {
            Button("Add files") { importing = true }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DS.Colors.onAccent)
        }
    }

    private var noResults: some View {
        ContentUnavailableView.search
    }

    private var listView: some View {
        List {
            ForEach(shown) { book in
                Button { open(book) } label: { BookRow(book: book) }
                    .buttonStyle(.plain)
                    .listRowBackground(DS.Colors.surface.opacity(0.92))
                    .contextMenu { menu(book) }
                    .swipeActions { Button("Delete", role: .destructive) { remove(book) } }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Spacing.l)], spacing: Spacing.l) {
                ForEach(shown) { book in
                    Button { open(book) } label: { BookTile(book: book) }
                        .buttonStyle(.plain)
                        .contextMenu { menu(book) }
                }
            }
            .padding(Spacing.l)
        }
    }

    @ViewBuilder private func menu(_ book: Book) -> some View {
        Button { book.isFavorite.toggle(); try? context.save() } label: {
            Label(book.isFavorite ? "Remove from favorites" : "Add to favorites", systemImage: book.isFavorite ? "star.slash" : "star")
        }
        Button { renameText = (((book.relativePath as NSString).lastPathComponent) as NSString).deletingPathExtension; renaming = book } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            book.progress = book.progress >= 0.98 ? 0 : 1
            if book.progress == 0 { book.locator = nil }
            try? context.save()
        } label: {
            Label(book.progress >= 0.98 ? "Mark as unread" : "Mark as read", systemImage: book.progress >= 0.98 ? "circle" : "checkmark.circle")
        }
        if let url = Services.url(for: book) { ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") } }
        Divider()
        Button("Delete", role: .destructive) { remove(book) }
    }

    private var undoBanner: some View {
        Group {
            if let undo {
                HStack(spacing: Spacing.m) {
                    Text("Moved \(undo.title) to Recently Deleted").font(DS.Typography.footnote).lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Undo") { restore(undo) }.font(DS.Typography.footnote.weight(.semibold))
                }
                .padding(Spacing.m)
                .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
                .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator))
                .padding(Spacing.l)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: undo)
    }

    private func rename(_ book: Book, to text: String) {
        let store = book.isShared ? Services.shared : Services.files
        let ext = (book.relativePath as NSString).pathExtension
        let name = text.trimmingCharacters(in: .whitespaces)
        guard let store, !name.isEmpty else { return }
        let full = ext.isEmpty || name.lowercased().hasSuffix("." + ext.lowercased()) ? name : name + "." + ext
        do {
            let new = try store.rename(book.relativePath, to: full)
            if book.isShared { book.relativePath = new } else { LibraryService.rebase(context, from: book.relativePath, to: new) }
            try? context.save()
        } catch {
            importError = "That name could not be used."
        }
    }

    private func restore(_ item: UndoDelete) {
        let store = item.shared ? Services.shared : Services.files
        undo = nil
        guard let store, (try? store.restore(item.trashID)) != nil else { return }
        if item.shared { item.book.isMissing = false } else { LibraryService.sync(context) }
        try? context.save()
    }

    private func handle(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            do {
                let item = try Services.library.importFile(at: url)
                LibraryService.insert(item.relativePath, into: context)
            } catch LibraryError.unsupported {
                importError = "\(url.lastPathComponent) is not a supported file type."
            } catch {
                importError = "\(url.lastPathComponent) could not be read."
            }
        }
        try? context.save()
    }

    /// Moves the file to Recently Deleted. The record stays, marked missing, so a restore brings back progress and notes.
    private func remove(_ book: Book) {
        let store = book.isShared ? Services.shared : Services.files
        let before = Set(store?.recentlyDeleted().map(\.id) ?? [])
        if (try? store?.trash(book.relativePath)) != nil || !FileManager.default.fileExists(atPath: Services.url(for: book)?.path ?? "") {
            book.isMissing = true
            WebAssets.removeCache(for: book.id)
            try? context.save()
            if let trashed = store?.recentlyDeleted().first(where: { !before.contains($0.id) }) {
                let item = UndoDelete(book: book, title: book.title, trashID: trashed.id, shared: book.isShared)
                undo = item
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    if undo == item { undo = nil }
                }
            }
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: Spacing.m) {
            FilePreview(book: book)
                .frame(width: 46, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(DS.Colors.separator))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    if book.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(DS.Colors.accentText).accessibilityLabel("Favorite") }
                    Text(book.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary).lineLimit(2)
                }
                Text(book.author.isEmpty ? book.format.title : "\(book.author), \(book.format.title)")
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                if book.progress > 0 { ProgressView(value: book.progress).tint(DS.Colors.accent) }
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the book")
    }
}

struct BookTile: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            FilePreview(book: book)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.m))
                .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator))
            HStack(spacing: Spacing.xs) {
                if book.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(DS.Colors.accentText).accessibilityLabel("Favorite") }
                Text(book.title).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(2)
            }
            if book.progress > 0 { ProgressView(value: book.progress).tint(DS.Colors.accent) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the book")
    }
}

struct UndoDelete: Equatable {
    let book: Book
    let title: String
    let trashID: String
    let shared: Bool
    static func == (a: UndoDelete, b: UndoDelete) -> Bool { a.trashID == b.trashID }
}
