import SwiftUI
import ReaderDesign
import ReaderStore
import ReaderFormats

struct WebBookView: View {
    let model: WebBookModel
    let annotations: [BookAnnotation]
    private let prefs = ReaderPreferences.shared
    @Environment(\.colorScheme) private var scheme
    private var surface: ReadingSurface { prefs.surface(dark: scheme == .dark) }

    var body: some View {
        Group {
            if let request = model.request {
                WebReaderView(
                    request: request,
                    readAccess: URL(fileURLWithPath: NSHomeDirectory()),
                    css: css,
                    ground: surface.ground.hex,
                    dark: surface.isDark,
                    highlights: highlights,
                    ink: model.ink,
                    inkPage: "c\(model.chapter)",
                    controller: model.controller,
                    onSelection: { model.session.selection = $0 },
                    onScroll: { model.scrolled($0) },
                    onTap: { _ in model.session.chromeVisible.toggle() },
                    onLink: { model.link($0) })
            } else if let failure = model.failure {
                ContentUnavailableView("Cannot open this book", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .background(surface.groundColor)
        .task { await model.load() }
    }

    private var css: String {
        let t = surface
        return EpubCSS.make(text: t.text.hex, ground: t.ground.hex, link: t.link.hex, fontStack: prefs.font.css,
                            fontSize: prefs.fontSize, lineHeight: prefs.lineSpacing, sidePadding: Double(prefs.sidePadding),
                            fontFileURL: WebAssets.fontFileURL?.absoluteString)
    }

    private var highlights: [WebHighlight] {
        annotations.compactMap { a in
            guard a.kind != .bookmark, !a.quote.isEmpty, case .chapter(let i, _)? = ReadingPosition(encoded: a.locator), i == model.chapter else { return nil }
            return WebHighlight(quote: a.quote, color: a.colorRaw)
        }
    }
}
