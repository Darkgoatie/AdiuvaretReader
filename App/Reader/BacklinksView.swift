import SwiftUI
import ReaderDesign
import ReaderFormats
import ReaderFiles

/// The notes of the same vault that link to the open note.
struct BacklinksView: View {
    let session: ReaderSession
    let path: String
    let shared: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var links: [Backlink] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView().controlSize(.large)
                } else if links.isEmpty {
                    ContentUnavailableView("No notes link here", systemImage: "link", description: Text("Other notes in this folder that use [[this note]] will be listed here."))
                } else {
                    List(links) { link in
                        Button {
                            dismiss()
                            session.openNote?(link.path, nil)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(((link.path as NSString).lastPathComponent as NSString).deletingPathExtension)
                                    .font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                                Text(link.snippet).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Linked from")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        let store = shared ? Services.shared : Services.files
        let current = path
        let result: [Backlink] = await Task.detached(priority: .userInitiated) {
            guard let store else { return [] }
            let all = store.allFiles()
            let notes: [(path: String, text: String)] = all
                .filter { $0.lowercased().hasSuffix(".md") }
                .compactMap { p in
                    guard let url = try? store.resolve(p), let data = try? Data(contentsOf: url) else { return nil }
                    return (p, String(decoding: data, as: UTF8.self))
                }
            return Backlinks.find(to: current, notes: notes, index: VaultIndex(paths: all))
        }.value
        links = result
        loaded = true
    }
}
