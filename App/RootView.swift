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
            NavigationStack {
                Group {
                    switch section ?? .library {
                    case .library: LibraryView(open: { openBook = $0 })
                    case .files: FilesView(open: { openBook = $0 })
                    }
                }
                .navigationDestination(item: $openBook) { ReaderView(book: $0).id($0.id) }
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
        guard let item = try? Services.library.importFile(at: url) else { return }
        LibraryService.sync(context)
        if let b = LibraryService.book(at: item.relativePath, shared: false, in: context) { openBook = b }
    }
}
