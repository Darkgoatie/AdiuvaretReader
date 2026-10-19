import SwiftUI
import SwiftData
import ReaderDesign
import ReaderStore
import ReaderFormats
import ReaderAssistant

struct ReaderView: View {
    let book: Book
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var annotations: [BookAnnotation]
    @State private var session: ReaderSession
    @State private var web: WebBookModel?
    @State private var pdf: PDFBookModel?
    @State private var code: CodeBookModel?
    @State private var toast: String?
    private let prefs = ReaderPreferences.shared

    init(book: Book) {
        self.book = book
        let id = book.id
        _annotations = Query(filter: #Predicate<BookAnnotation> { $0.bookID == id }, sort: \.createdAt)
        _session = State(initialValue: ReaderSession(book: book))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            if session.chromeVisible { bottomBar.transition(.opacity) }
            if let toast {
                Text(toast)
                    .font(DS.Typography.footnote)
                    .padding(.horizontal, Spacing.l).padding(.vertical, Spacing.m)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator))
                    .padding(.bottom, 90)
                    .transition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .background(prefs.theme.groundColor.ignoresSafeArea())
        .navigationTitle(book.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(session.chromeVisible ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .toolbar { toolbar }
        .animation(.easeInOut(duration: 0.2), value: session.chromeVisible)
        .animation(.easeInOut(duration: 0.2), value: toast)
        .onAppear(perform: start)
        .onDisappear { session.flush(); try? context.save() }
        .onChange(of: session.jump) { _, jump in
            guard let jump else { return }
            web?.handle(jump)
            code?.handle(jump)
            pdf?.handle(jump)
        }
        .onChange(of: session.progress) { _, v in book.progress = v }
        .sheet(isPresented: $session.showSettings) { ReaderSettingsView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $session.showContents) { ContentsView(session: session) }
        .sheet(isPresented: $session.showAnnotations) { AnnotationsView(session: session, annotations: annotations) }
        .sheet(isPresented: Binding(get: { session.showSearch && !session.isCode }, set: { session.showSearch = $0 })) { SearchView(session: session) }
        .sheet(isPresented: $session.showAssistant) { AssistantSheet(session: session).presentationDetents([.medium, .large]) }
        .sheet(isPresented: Binding(get: { session.noteDraft != nil }, set: { if !$0 { session.noteDraft = nil } })) {
            NoteEditor(session: session) { text in saveNote(text) }
        }
        .preferredColorScheme(scheme)
    }

    private var scheme: ColorScheme { prefs.theme == .dark ? .dark : .light }

    @ViewBuilder private var content: some View {
        switch book.format {
        case .epub, .text, .markdown:
            if let web { WebBookView(model: web, annotations: annotations) }
        case .pdf:
            if let pdf { PDFBookView(model: pdf) }
        case .code:
            if let code { CodeViewerView(model: code) }
        }
    }

    private func start() {
        guard web == nil, pdf == nil, code == nil else { return }
        book.lastOpenedAt = Date()
        switch book.format {
        case .epub, .text, .markdown: web = WebBookModel(session: session)
        case .pdf: pdf = PDFBookModel(session: session)
        case .code: code = CodeBookModel(session: session)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if !session.toc.isEmpty {
                Button { session.showContents = true } label: { Label("Contents", systemImage: "list.bullet") }
            }
            Button { session.showSearch.toggle() } label: { Label("Search", systemImage: "magnifyingglass") }
            if book.format == .code, let code {
                Button { code.wrap.toggle() } label: { Label("Wrap lines", systemImage: code.wrap ? "text.alignleft" : "arrow.left.and.right.text.vertical") }
            }
            Menu {
                Button { session.showAnnotations = true } label: { Label("Highlights and notes", systemImage: "highlighter") }
                Button { toggleBookmark() } label: { Label(hasBookmark ? "Remove bookmark" : "Add bookmark", systemImage: hasBookmark ? "bookmark.slash" : "bookmark") }
                Button { session.showSettings = true } label: { Label("Appearance", systemImage: "textformat.size") }
                if !annotations.isEmpty { ShareLink(item: exportText, subject: Text(book.title)) { Label("Export notes", systemImage: "square.and.arrow.up") } }
            } label: { Label("More", systemImage: "ellipsis.circle") }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.s) {
            if !session.selection.isEmpty { selectionBar }
            HStack(spacing: Spacing.m) {
                Button { session.stepper?(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(book.format == .pdf ? "Previous page" : "Previous chapter")
                    .disabled(book.format == .code || session.stepper == nil)
                VStack(spacing: Spacing.xs) {
                    ProgressView(value: session.progress).tint(DS.Colors.accent)
                    Text(progressLabel).font(DS.Typography.caption).foregroundStyle(prefs.theme.secondaryText.color)
                }
                Button { session.stepper?(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel(book.format == .pdf ? "Next page" : "Next chapter")
                    .disabled(book.format == .code || session.stepper == nil)
                Button { session.openAssistant() } label: {
                    Label("Assistant", systemImage: "sparkles").labelStyle(.iconOnly).frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DS.Colors.onAccent)
                .accessibilityLabel("Ask the assistant")
            }
            .padding(.horizontal, Spacing.l)
        }
        .padding(.vertical, Spacing.s)
        .background(.bar)
    }

    private var selectionBar: some View {
        HStack(spacing: Spacing.s) {
            Button("Highlight") { addHighlight() }
            Button("Note") { session.noteDraft = "" }
            Button("Ask") { session.openAssistant() }
            Button("Copy") { copy(session.selection) }
            Spacer()
            Button { session.clearSelection() } label: { Image(systemName: "xmark") }.accessibilityLabel("Clear selection")
        }
        .buttonStyle(.bordered)
        .font(DS.Typography.caption)
        .padding(.horizontal, Spacing.l)
    }

    private var progressLabel: String {
        let pct = Int((session.progress * 100).rounded())
        guard let p = session.position else { return "\(pct)%" }
        return "\(p.label(isCode: book.format == .code))  \(pct)%"
    }

    // MARK: Annotations

    private var hasBookmark: Bool {
        guard let p = session.position else { return false }
        return annotations.contains { $0.kind == .bookmark && ReadingPosition(encoded: $0.locator)?.isNear(p) == true }
    }

    private func toggleBookmark() {
        guard let p = session.position else { return }
        if let existing = annotations.first(where: { $0.kind == .bookmark && ReadingPosition(encoded: $0.locator)?.isNear(p) == true }) {
            context.delete(existing)
            say("Bookmark removed")
        } else {
            context.insert(BookAnnotation(bookID: book.id, kind: .bookmark, locator: p.encoded))
            say("Bookmarked")
        }
        try? context.save()
    }

    private func addHighlight() {
        guard let p = session.position, !session.selection.isEmpty else { return }
        context.insert(BookAnnotation(bookID: book.id, kind: .highlight, locator: p.encoded, quote: clip(session.selection)))
        try? context.save()
        session.clearSelection()
        say("Highlight saved")
    }

    private func saveNote(_ text: String) {
        guard let p = session.position else { return }
        context.insert(BookAnnotation(bookID: book.id, kind: .note, locator: p.encoded, quote: clip(session.selection), note: text))
        try? context.save()
        session.clearSelection()
        session.noteDraft = nil
        say("Note saved")
    }

    private func clip(_ s: String) -> String { String(s.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600)) }

    private func copy(_ s: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = s
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
        say("Copied")
    }

    private var exportText: String {
        let isCode = book.format == .code
        let records = annotations.map {
            AnnotationRecord(kind: $0.kind, label: ReadingPosition(encoded: $0.locator)?.label(isCode: isCode) ?? "", quote: $0.quote, note: $0.note, createdAt: $0.createdAt)
        }
        return AnnotationExport.markdown(title: book.title, author: book.author, records: records)
    }

    private func say(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == text { toast = nil }
        }
    }
}

extension RGB {
    var color: Color { Color(red: r, green: g, blue: b) }
}
