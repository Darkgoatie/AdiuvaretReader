import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ReaderDesign
import ReaderStore

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    @State private var importing = false
    @State private var showSettings = false
    @State private var importError: String?

    private let folder = LibraryFolder.standard()

    var body: some View {
        NavigationStack {
            ZStack {
                WallpaperBackground()
                if books.isEmpty { empty } else { list }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { importing = true } label: { Label("Add", systemImage: "plus") }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                handle(result)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("Could not add file", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "") }
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

    private var list: some View {
        List {
            ForEach(books) { book in
                BookRow(book: book)
                    .listRowBackground(DS.Colors.surface.opacity(0.9))
            }
            .onDelete(perform: delete)
        }
        .scrollContentBackground(.hidden)
    }

    private func handle(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            do {
                let item = try folder.importFile(at: url)
                let title = LibraryFolder.title(fromFileName: url.lastPathComponent)
                context.insert(Book(title: title, format: item.format, relativePath: item.relativePath))
            } catch LibraryError.unsupported {
                importError = "\(url.lastPathComponent) is not a supported file type."
            } catch {
                importError = "\(url.lastPathComponent) could not be read."
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            try? FileManager.default.removeItem(at: folder.url(for: book.relativePath))
            context.delete(book)
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: book.format.symbol)
                .font(.title2)
                .foregroundStyle(DS.Colors.accentText)
                .frame(width: 44, height: 44)
                .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.s))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(book.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary).lineLimit(2)
                Text(book.format.title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                if book.progress > 0 {
                    ProgressView(value: book.progress).tint(DS.Colors.accent)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
