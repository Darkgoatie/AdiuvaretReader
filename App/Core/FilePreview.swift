import SwiftUI
import ReaderDesign
import ReaderStore
import ReaderFiles

/// A small picture of a file's contents, with the type icon shown only until the picture is ready or when there is none.
struct FilePreview: View {
    private let key: String
    private let format: BookFormat?
    private let symbol: String
    private let resolve: () -> URL?
    @State private var image: PlatformImage?
    @State private var text: String?

    init(book: Book) {
        key = book.id.uuidString + book.relativePath
        format = book.format
        symbol = book.format.symbol
        resolve = { Services.url(for: book) }
    }

    init(store: FileStore?, path: String, name: String) {
        key = path
        format = BookFormat.detect(fileName: name)
        symbol = format?.symbol ?? "doc"
        resolve = { try? store?.resolve(path) }
    }

    var body: some View {
        Color.clear
            .overlay { content }
            .clipped()
            .accessibilityHidden(true)
            .task(id: key) { await load() }
    }

    @ViewBuilder private var content: some View {
        ZStack {
            DS.Colors.surface
            if let image {
                Image(platform: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            } else if let text {
                GeometryReader { geo in
                    Text(text)
                        .font(.system(size: max(4, geo.size.width / 13), design: format == .code ? .monospaced : .default))
                        .foregroundStyle(DS.Colors.textPrimary.opacity(0.78))
                        .lineSpacing(1)
                        .frame(width: geo.size.width - 8, height: geo.size.height - 8, alignment: .topLeading)
                        .clipped()
                        .padding(4)
                }
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(DS.Colors.accentText)
            }
        }
    }

    private func load() async {
        image = nil
        text = nil
        guard let url = resolve() else { return }
        if let format, format.isTextual {
            text = await ThumbnailService.shared.snippet(for: url, format: format)
            return
        }
        image = await ThumbnailService.shared.image(for: url, format: format)?.image
        if image == nil, format == .epub { text = await ThumbnailService.shared.snippet(for: url, format: .epub) }
    }
}
