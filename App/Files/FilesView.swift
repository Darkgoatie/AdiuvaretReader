import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLook
import ReaderDesign
import ReaderStore
import ReaderFiles

enum FileSource: Hashable {
    case library, shared
}

struct FolderRoute: Hashable {
    let source: FileSource
    let path: String
}

struct ExternalRoute: Hashable {
    let id: UUID
    let path: String
}

struct FilesView: View {
    let open: (Book) -> Void
    @Environment(\.modelContext) private var context
    @State private var externals = Services.externals.folders
    @State private var pickingFolder = false
    @State private var trashCount = Services.files.recentlyDeleted().count

    var body: some View {
        ZStack {
            WallpaperBackground()
            List {
                Section("On this device") {
                    NavigationLink(value: FolderRoute(source: .library, path: "")) { Label("Library", systemImage: "books.vertical") }
                    if Services.shared != nil {
                        NavigationLink(value: FolderRoute(source: .shared, path: "")) { Label("Shared with my apps", systemImage: "square.on.square") }
                    }
                    NavigationLink(value: TrashRoute()) {
                        Label(trashCount == 0 ? "Recently Deleted" : "Recently Deleted (\(trashCount))", systemImage: "trash")
                    }
                }
                Section {
                    ForEach(externals) { f in
                        NavigationLink(value: ExternalRoute(id: f.id, path: "")) { Label(f.name, systemImage: "externaldrive") }
                            .swipeActions { Button("Remove", role: .destructive) { Services.externals.remove(f.id); externals = Services.externals.folders } }
                    }
                    Button { pickingFolder = true } label: { Label("Add a folder", systemImage: "plus") }
                } header: {
                    Text("Other folders")
                } footer: {
                    Text("Folders you add are only read. Copy files in to keep them in the library.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Files")
        .navigationDestination(for: FolderRoute.self) { FolderView(route: $0, open: open) }
        .navigationDestination(for: ExternalRoute.self) { ExternalFolderView(route: $0) }
        .navigationDestination(for: TrashRoute.self) { _ in TrashView() }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { _ = try? Services.externals.add(url); externals = Services.externals.folders }
        }
        .onAppear { trashCount = Services.files.recentlyDeleted().count }
    }
}

struct TrashRoute: Hashable {}

struct FolderView: View {
    let route: FolderRoute
    let open: (Book) -> Void
    @Environment(\.modelContext) private var context
    @State private var items: [FileItem] = []
    @State private var sort = FileSort.name
    @State private var query = ""
    @State private var results: [FileItem] = []
    @State private var selection = Set<String>()
    @State private var importing = false
    @State private var newFolder = false
    @State private var newName = ""
    @State private var renaming: FileItem?
    @State private var renameText = ""
    @State private var moving: [FileItem] = []
    @State private var copying = false
    @State private var preview: URL?
    @State private var error: String?
    @State private var usage = ""
    @State private var selecting = false

    private var store: FileStore? { route.source == .library ? Services.files : Services.shared }
    private var title: String {
        route.path.isEmpty ? (route.source == .library ? "Library" : "Shared with my apps") : (route.path as NSString).lastPathComponent
    }
    private var shown: [FileItem] { query.isEmpty ? items : results }

    var body: some View {
        ZStack {
            WallpaperBackground()
            if shown.isEmpty { emptyState } else { list }
        }
        .navigationTitle(title)
        .searchable(text: $query, prompt: "Search by name")
        .onChange(of: query) { _, q in results = store?.search(q) ?? [] }
        .onChange(of: sort) { _, _ in reload() }
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { if selecting && !selection.isEmpty { selectionBar } }
        .onAppear(perform: reload)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, let store else { return }
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { try store.addCopy(of: url, toFolder: route.path) } catch { self.error = "\(url.lastPathComponent) could not be copied." }
            }
            changed()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let store else { return false }
            var any = false
            for url in urls where url.isFileURL {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if (try? store.addCopy(of: url, toFolder: route.path)) != nil { any = true }
            }
            if any { changed() }
            return any
        }
        .alert("New folder", isPresented: $newFolder) {
            TextField("Name", text: $newName)
            Button("Create") { perform { try $0.createFolder(named: newName, in: route.path) } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let item = renaming {
                    perform { s in
                        let new = try s.rename(item.relativePath, to: renameText)
                        if route.source == .library { LibraryService.rebase(context, from: item.relativePath, to: new) }
                    }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .alert("Something went wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .sheet(isPresented: Binding(get: { !moving.isEmpty }, set: { if !$0 { moving = [] } })) {
            if let store { FolderPicker(store: store, excluding: moving.map(\.relativePath), title: copying ? "Copy to" : "Move to") { dest in
                let list = moving
                moving = []
                perform { s in
                    for item in list {
                        if copying { try s.copy(item.relativePath, toFolder: dest) }
                        else {
                            let new = try s.move(item.relativePath, toFolder: dest)
                            if route.source == .library { LibraryService.rebase(context, from: item.relativePath, to: new) }
                        }
                    }
                }
            } }
        }
        .quickLookPreview($preview)
    }

    // MARK: Pieces

    private var list: some View {
        List(selection: $selection) {
            ForEach(shown) { item in
                row(item)
                    .tag(item.relativePath)
                    .listRowBackground(DS.Colors.surface.opacity(0.92))
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { trash([item]) }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Rename") { renameText = item.name; renaming = item }.tint(DS.Colors.accent)
                    }
                    .contextMenu { menu(item) }
            }
            if query.isEmpty, !usage.isEmpty {
                Text(usage).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        #if os(iOS)
        .environment(\.editMode, .constant(selecting ? .active : .inactive))
        #endif
    }

    @ViewBuilder private func row(_ item: FileItem) -> some View {
        if item.isDirectory {
            NavigationLink(value: FolderRoute(source: route.source, path: item.relativePath)) {
                Label {
                    VStack(alignment: .leading) {
                        Text(item.name).foregroundStyle(DS.Colors.textPrimary)
                        if !query.isEmpty { Text(item.relativePath).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
                    }
                } icon: { Image(systemName: "folder").foregroundStyle(DS.Colors.accentText) }
            }
        } else {
            Button { openFile(item) } label: {
                HStack {
                    Image(systemName: BookFormat.detect(fileName: item.name)?.symbol ?? "doc").foregroundStyle(DS.Colors.accentText).frame(width: 28)
                    VStack(alignment: .leading) {
                        Text(item.name).foregroundStyle(DS.Colors.textPrimary).lineLimit(2)
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file) + (query.isEmpty ? "" : "  \(item.relativePath)"))
                            .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private func menu(_ item: FileItem) -> some View {
        Button("Rename") { renameText = item.name; renaming = item }
        Button("Move") { copying = false; moving = [item] }
        Button("Copy") { copying = true; moving = [item] }
        if !item.isDirectory, let url = try? store?.resolve(item.relativePath) { ShareLink(item: url) }
        Button("Delete", role: .destructive) { trash([item]) }
    }

    private var selectionBar: some View {
        HStack {
            Button("Move") { copying = false; moving = pickedItems }
            Button("Copy") { copying = true; moving = pickedItems }
            Spacer()
            Text("\(selection.count) selected").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Button("Delete", role: .destructive) { trash(pickedItems) }
        }
        .buttonStyle(.bordered)
        .padding(Spacing.m)
        .background(.bar)
    }

    private var pickedItems: [FileItem] { shown.filter { selection.contains($0.relativePath) } }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(query.isEmpty ? "This folder is empty" : "No matches", systemImage: query.isEmpty ? "folder" : "magnifyingglass")
        } description: {
            Text(query.isEmpty ? "Add files, or create a folder." : "No file or folder name contains that.")
        } actions: {
            if query.isEmpty { Button("Add files") { importing = true }.buttonStyle(.borderedProminent).foregroundStyle(DS.Colors.onAccent) }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { selecting.toggle(); selection = [] } label: { Text(selecting ? "Done" : "Select") }
            Menu {
                Button { importing = true } label: { Label("Add files", systemImage: "doc.badge.plus") }
                Button { newName = ""; newFolder = true } label: { Label("New folder", systemImage: "folder.badge.plus") }
                Picker("Sort by", selection: $sort) { ForEach(FileSort.allCases) { Text($0.title).tag($0) } }
            } label: { Label("More", systemImage: "ellipsis.circle") }
        }
    }

    // MARK: Actions

    private func reload() {
        guard let store else { items = []; return }
        items = (try? store.list(route.path, sort: sort)) ?? []
        let total = store.size(of: route.path)
        let count = items.count
        usage = count == 0 ? "" : "\(count) \(count == 1 ? "item" : "items"), \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
    }

    private func changed() {
        if route.source == .library { LibraryService.sync(context) }
        reload()
        if !query.isEmpty { results = store?.search(query) ?? [] }
        selection = []
    }

    private func perform(_ action: (FileStore) throws -> Void) {
        guard let store else { return }
        do { try action(store) } catch FileStoreError.nameCollision { self.error = "An item with that name already exists." }
        catch FileStoreError.invalidName { self.error = "That name is not allowed." }
        catch FileStoreError.moveIntoSelf { self.error = "A folder cannot go inside itself." }
        catch { self.error = "The change could not be made." }
        changed()
    }

    private func trash(_ list: [FileItem]) {
        guard let store else { return }
        for i in list { try? store.trash(i.relativePath) }
        selecting = false
        changed()
    }

    private func openFile(_ item: FileItem) {
        guard let store, let url = try? store.resolve(item.relativePath) else { return }
        if BookFormat.detect(fileName: item.name) != nil,
           let book = LibraryService.book(at: item.relativePath, shared: route.source == .shared, in: context) {
            open(book)
        } else {
            preview = url
        }
    }
}

struct FolderPicker: View {
    let store: FileStore
    let excluding: [String]
    let title: String
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button { onPick(""); dismiss() } label: { Label("Top level", systemImage: "tray") }
                ForEach(allowed, id: \.self) { path in
                    Button { onPick(path); dismiss() } label: {
                        Label(path, systemImage: "folder").foregroundStyle(DS.Colors.textPrimary)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var allowed: [String] {
        store.allFolders().filter { folder in !excluding.contains { folder == $0 || folder.hasPrefix($0 + "/") } }
    }
}

struct TrashView: View {
    @Environment(\.modelContext) private var context
    @State private var items = Services.files.recentlyDeleted()
    @State private var confirmEmpty = false

    var body: some View {
        ZStack {
            WallpaperBackground()
            if items.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "trash", description: Text("Deleted files stay here for \(FileStore.retentionDays) days."))
            } else {
                List {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label(item.name, systemImage: item.isDirectory ? "folder" : "doc")
                            Text("Deleted \(item.deletedAt.formatted(date: .abbreviated, time: .omitted)), \(daysLeft(item)) days left")
                                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                        }
                        .listRowBackground(DS.Colors.surface.opacity(0.92))
                        .swipeActions(edge: .leading) { Button("Restore") { restore(item) }.tint(DS.Colors.accent) }
                        .swipeActions(edge: .trailing) { Button("Delete now", role: .destructive) { Services.files.deletePermanently(item.id); refresh() } }
                        .contextMenu { Button("Restore") { restore(item) }; Button("Delete now", role: .destructive) { Services.files.deletePermanently(item.id); refresh() } }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !items.isEmpty { ToolbarItem(placement: .primaryAction) { Button("Empty") { confirmEmpty = true } } }
        }
        .confirmationDialog("Delete everything here permanently?", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("Empty Recently Deleted", role: .destructive) {
                Services.files.emptyTrash()
                LibraryService.sync(context)
                refresh()
            }
        }
        .onAppear(perform: refresh)
    }

    private func daysLeft(_ i: TrashedItem) -> Int {
        max(0, FileStore.retentionDays - Int(Date().timeIntervalSince(i.deletedAt) / 86_400))
    }

    private func restore(_ i: TrashedItem) {
        _ = try? Services.files.restore(i.id)
        LibraryService.sync(context)
        refresh()
    }

    private func refresh() {
        Services.files.purgeExpired()
        LibraryService.sync(context)
        items = Services.files.recentlyDeleted()
    }
}

struct ExternalFolderView: View {
    let route: ExternalRoute
    @Environment(\.modelContext) private var context
    @State private var entries: [ExternalEntry] = []
    @State private var message: String?

    private var folder: ExternalFolder? { Services.externals.folders.first { $0.id == route.id } }

    var body: some View {
        ZStack {
            WallpaperBackground()
            if entries.isEmpty {
                ContentUnavailableView("Nothing to show", systemImage: "folder", description: Text("This folder is empty, or it can no longer be reached."))
            } else {
                List(entries) { e in
                    if e.isDirectory {
                        NavigationLink(value: ExternalRoute(id: route.id, path: e.relativePath)) { Label(e.name, systemImage: "folder") }
                            .listRowBackground(DS.Colors.surface.opacity(0.92))
                    } else {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(e.name).lineLimit(2)
                                Text(ByteCountFormatter.string(fromByteCount: e.size, countStyle: .file)).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                            }
                            Spacer()
                            Button("Copy in") { copy(e) }.buttonStyle(.bordered)
                        }
                        .listRowBackground(DS.Colors.surface.opacity(0.92))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(route.path.isEmpty ? (folder?.name ?? "Folder") : (route.path as NSString).lastPathComponent)
        .onAppear { if let folder { entries = Services.externals.list(folder, subpath: route.path) } }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} }
    }

    private func copy(_ e: ExternalEntry) {
        guard let folder else { return }
        do {
            try Services.externals.copy(folder, subpath: e.relativePath, into: Services.files)
            LibraryService.sync(context)
            message = "Copied to the library."
        } catch { message = "\(e.name) could not be copied." }
    }
}
