import SwiftUI
import ReaderDesign
import ReaderStore
import ReaderFormats

/// Source is read once into lines; only the lines on screen are tokenized and drawn.
@MainActor
@Observable
final class CodeBookModel {
    let session: ReaderSession
    var lines: [String] = []
    var language = CodeLanguage.detect(fileName: "")
    var failure: String?
    var loaded = false
    var wrap = false
    var matches: [Int] = []
    var currentMatch = 0
    var query = ""
    var topLine = 0
    var scrollTarget: Int?

    @ObservationIgnored private var cache: [Int: [CodeToken]] = [:]

    init(session: ReaderSession) { self.session = session }

    func load() async {
        guard !loaded, let url = Services.url(for: session.book) else { if !loaded { failure = "This file could not be found." }; return }
        let name = url.lastPathComponent
        do {
            let result = try await Task.detached { () throws -> ([String], CodeLanguage) in
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
                return (lines, CodeLanguage.detect(fileName: name, firstLine: lines.first))
            }.value
            lines = result.0
            language = result.1
        } catch {
            failure = "This file could not be opened."
            return
        }
        loaded = true
        session.contextProvider = { [weak self] in
            guard let self else { return nil }
            let start = max(0, self.topLine - 5)
            let end = min(self.lines.count, start + 120)
            return PassageContext(text: self.lines[start..<end].joined(separator: "\n"), fraction: 0, source: ReadingPosition.block(self.topLine).label(isCode: true))
        }
        session.searchProvider = { [weak self] q in
            guard let self else { return [] }
            return BookSearch.lineMatches(self.lines, query: q).prefix(200).enumerated().map {
                SearchHit(id: $0.offset, chapter: $0.element, offset: 0, length: q.count, snippet: String(self.lines[$0.element].trimmingCharacters(in: .whitespaces).prefix(120)))
            }
        }
        session.hitPosition = { .block($0.chapter) }
        if let saved = session.book.locator, case .block(let b)? = ReadingPosition(encoded: saved) { scrollTarget = min(b, max(lines.count - 1, 0)) }
        report(line: scrollTarget ?? 0)
    }

    func tokens(_ i: Int) -> [CodeToken] {
        if let c = cache[i] { return c }
        let t = CodeTokenizer.tokenize(lines[i], language: language).first ?? []
        if cache.count > 800 { cache.removeAll(keepingCapacity: true) }
        cache[i] = t
        return t
    }

    func report(line: Int) {
        topLine = line
        session.record(.block(line), progress: lines.isEmpty ? 0 : Double(line + 1) / Double(lines.count))
    }

    func find(_ q: String) {
        query = q
        matches = BookSearch.lineMatches(lines, query: q)
        currentMatch = 0
        if let first = matches.first { scrollTarget = first }
    }

    func nextMatch(_ delta: Int) {
        guard !matches.isEmpty else { return }
        currentMatch = (currentMatch + delta + matches.count) % matches.count
        scrollTarget = matches[currentMatch]
    }

    func handle(_ jump: Jump) {
        if case .block(let b) = jump.position { scrollTarget = b }
    }
}

struct CodeViewerView: View {
    let model: CodeBookModel
    private let prefs = ReaderPreferences.shared
    @State private var findText = ""

    var body: some View {
        let palette = CodePalette.for(prefs.theme)
        let size = max(11, prefs.fontSize - 5)
        VStack(spacing: 0) {
            if model.session.showSearch { findBar }
            if let failure = model.failure {
                ContentUnavailableView("Cannot open this file", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else if !model.loaded {
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(model.wrap ? .vertical : [.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(model.lines.indices, id: \.self) { i in
                                row(i, palette: palette, size: size).id(i)
                                    .onAppear { if i % 5 == 0 { model.report(line: i) } }
                            }
                        }
                        .padding(.vertical, Spacing.l)
                        .textSelection(.enabled)
                    }
                    .onChange(of: model.scrollTarget) { _, target in
                        if let target { proxy.scrollTo(target, anchor: .top); model.scrollTarget = nil }
                    }
                    .task(id: model.loaded) {
                        if let target = model.scrollTarget { try? await Task.sleep(nanoseconds: 100_000_000); proxy.scrollTo(target, anchor: .top); model.scrollTarget = nil }
                    }
                }
            }
        }
        .background(prefs.theme.groundColor)
        .task { await model.load() }
    }

    private func row(_ i: Int, palette: CodePalette, size: Double) -> some View {
        let isMatch = model.matches.contains(i)
        let digits = String(model.lines.count).count
        return HStack(alignment: .top, spacing: Spacing.m) {
            Text(String(i + 1))
                .font(.system(size: size - 2, design: .monospaced))
                .foregroundStyle(Color(red: palette.comment.r, green: palette.comment.g, blue: palette.comment.b))
                .frame(width: CGFloat(digits) * (size * 0.62) + 4, alignment: .trailing)
                .accessibilityHidden(true)
            colored(model.tokens(i), palette: palette, size: size)
                .lineLimit(model.wrap ? nil : 1)
                .fixedSize(horizontal: !model.wrap, vertical: true)
        }
        .padding(.horizontal, Spacing.m)
        .background(isMatch ? Color(red: 0.94, green: 0.69, blue: 0.29).opacity(0.25) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Line \(i + 1): " + model.lines[i]))
    }

    private func colored(_ tokens: [CodeToken], palette: CodePalette, size: Double) -> Text {
        if tokens.isEmpty { return Text(" ").font(.system(size: size, design: .monospaced)) }
        var out = Text("")
        for t in tokens {
            let c: RGB
            switch t.kind {
            case .keyword: c = palette.keyword
            case .string: c = palette.string
            case .comment: c = palette.comment
            case .number: c = palette.number
            case .plain: c = palette.text
            }
            out = out + Text(t.text).foregroundColor(Color(red: c.r, green: c.g, blue: c.b))
        }
        return out.font(.system(size: size, design: .monospaced))
    }

    private var findBar: some View {
        HStack(spacing: Spacing.s) {
            TextField("Find in file", text: $findText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit { model.find(findText) }
                .onChange(of: findText) { _, v in model.find(v) }
            Text(model.matches.isEmpty ? "0" : "\(model.currentMatch + 1)/\(model.matches.count)")
                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            Button { model.nextMatch(-1) } label: { Image(systemName: "chevron.up") }
                .accessibilityLabel("Previous match")
            Button { model.nextMatch(1) } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Next match")
        }
        .padding(Spacing.m)
        .background(DS.Colors.surface)
    }
}
