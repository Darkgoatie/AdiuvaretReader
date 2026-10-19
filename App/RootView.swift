import SwiftUI
import SwiftData
import ReaderDesign
import ReaderStore

enum SidebarSection: String, CaseIterable, Identifiable {
    case library, files
    var id: String { rawValue }
    var title: String { self == .library ? "Library" : "Files" }
    var symbol: String { self == .library ? "books.vertical" : "folder" }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @State private var section: SidebarSection? = .library
    @State private var openBook: Book?
    @State private var openFragment: String?
    @State private var stackPath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $section) { s in
                Label(s.title, systemImage: s.symbol).tag(s)
            }
            .navigationTitle("Reader")
            .scrollContentBackground(.hidden)
            .background(WallpaperBackground())
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
            #endif
        } detail: {
            NavigationStack(path: $stackPath) {
                Group {
                    switch section ?? .library {
                    case .library: LibraryView(open: { openBook = $0 })
                    case .files: FilesView(open: { openBook = $0 })
                    }
                }
                .navigationDestination(item: $openBook) { ReaderView(book: $0, fragment: openFragment).id($0.id) }
            }
            .id(section)
        }
        .tint(DS.Colors.accent)
        .font(DS.Typography.body)
        .task { LibraryService.sync(context) }
        .onChange(of: phase) { _, p in if p == .active { LibraryService.sync(context) } }
        .onOpenURL { url in importExternal(url) }
    }

    private func importExternal(_ url: URL) {
        if url.scheme?.lowercased() == ReaderLink.scheme {
            if let target = ReaderLink.parse(url) { openShared(target.path, fragment: target.fragment) }
            return
        }
        guard let item = try? Services.library.importFile(at: url) else { return }
        LibraryService.sync(context)
        if let b = LibraryService.book(at: item.relativePath, shared: false, in: context) { openBook = b }
    }

    /// Opens a file or folder of the shared folder, as asked by a link from another app.
    private func openShared(_ path: String, fragment: String?) {
        openBook = nil
        openFragment = nil
        section = .files
        stackPath = NavigationPath()
        guard let store = Services.shared, let url = try? store.resolve(path), FileManager.default.fileExists(atPath: url.path) else { return }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let book = isDirectory.boolValue ? nil : LibraryService.book(at: path, shared: true, in: context)
        let folder = isDirectory.boolValue ? path : (path as NSString).deletingLastPathComponent
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            var next = NavigationPath()
            next.append(FolderRoute(source: .shared, path: ""))
            var walked = ""
            for part in folder.split(separator: "/") {
                walked = walked.isEmpty ? String(part) : walked + "/" + part
                next.append(FolderRoute(source: .shared, path: walked))
            }
            stackPath = next
            if let book {
                try? await Task.sleep(nanoseconds: 250_000_000)
                openFragment = fragment
                openBook = book
            }
        }
    }
}
