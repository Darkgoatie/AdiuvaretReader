import SwiftUI
import SwiftData
import ReaderDesign
import ReaderStore
import ReaderFormats
import ReaderAssistant

struct ReaderSettingsView: View {
    @Bindable private var prefs = ReaderPreferences.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Page") {
                    Picker("Theme", selection: $prefs.theme) {
                        ForEach(ReadingTheme.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if prefs.bookScope != nil {
                    Section {
                        Toggle("Only for this book", isOn: Binding(get: { prefs.isScoped }, set: { prefs.setScoped($0) }))
                    } footer: { Text("Keeps this size, font and theme for this book. Other books keep the shared settings.") }
                }
                Section("Text") {
                    Picker("Font", selection: $prefs.font) {
                        ForEach(ReadingFont.allCases) { Text($0.title).tag($0) }
                    }
                    slider("Size", value: $prefs.fontSize, range: ReaderLimits.fontSize, label: "\(Int(prefs.fontSize)) pt")
                    slider("Line spacing", value: $prefs.lineSpacing, range: ReaderLimits.lineSpacing, label: String(format: "%.1f", prefs.lineSpacing))
                    slider("Margins", value: $prefs.margin, range: ReaderLimits.margin, label: String(Int(prefs.margin.rounded())))
                }
                Section {
                    Toggle("Keep screen on while reading", isOn: $prefs.keepScreenOn)
                }
                Section("Preview") {
                    Text("The quick brown fox jumps over the lazy dog.")
                        .font(prefs.font.font(size: prefs.fontSize))
                        .lineSpacing(prefs.fontSize * (prefs.lineSpacing - 1))
                        .foregroundStyle(prefs.theme.textColor)
                        .padding(Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(prefs.theme.groundColor)
                }
            }
            .navigationTitle("Appearance")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text(label).foregroundStyle(DS.Colors.textSecondary) }
            Slider(value: value, in: range)
        }
    }
}

struct ContentsView: View {
    let session: ReaderSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(session.toc) { item in
                Button {
                    session.go(to: item.position)
                    dismiss()
                } label: {
                    Text(item.title).foregroundStyle(DS.Colors.textPrimary)
                }
            }
            .navigationTitle("Contents")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct SearchView: View {
    let session: ReaderSession
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var searched = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if hits.isEmpty {
                    if searched { Text("No matches").foregroundStyle(DS.Colors.textSecondary) }
                } else {
                    Section("\(hits.count) \(hits.count == 1 ? "match" : "matches")") {
                        ForEach(hits) { hit in
                            Button {
                                if let pos = session.hitPosition?(hit) { session.go(to: pos, find: query) }
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(session.hitPosition?(hit).label(isCode: session.isCode) ?? "").font(DS.Typography.caption).foregroundStyle(DS.Colors.accentText)
                                    Text(hit.snippet).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary).lineLimit(3)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search this book")
            .onAppear { if let q = session.pendingQuery { query = q; session.pendingQuery = nil } }
            .onChange(of: query) { _, q in
                task?.cancel()
                task = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    hits = await session.searchProvider?(q) ?? []
                    searched = q.trimmingCharacters(in: .whitespaces).count >= 2
                }
            }
            .navigationTitle("Search")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct AnnotationsView: View {
    let session: ReaderSession
    let annotations: [BookAnnotation]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if annotations.isEmpty {
                    ContentUnavailableView("Nothing saved yet", systemImage: "highlighter", description: Text("Select text to highlight it or add a note. Bookmark a page from the menu."))
                } else {
                    List {
                        ForEach(annotations) { a in
                            Button {
                                if let p = ReadingPosition(encoded: a.locator) { session.go(to: p) }
                                dismiss()
                            } label: { row(a) }
                            .contextMenu {
                                if a.kind == .highlight {
                                    ForEach(HighlightColor.allCases) { c in
                                        Button(c.title) { a.colorRaw = c.rawValue; try? context.save() }
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(annotations[$0]) }
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("Highlights and notes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func row(_ a: BookAnnotation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: icon(a.kind)).foregroundStyle(a.kind == .highlight ? tint(a.color) : DS.Colors.accentText)
                Text(ReadingPosition(encoded: a.locator)?.label(isCode: session.isCode) ?? "").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            if !a.quote.isEmpty { Text(a.quote).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary).lineLimit(4) }
            if !a.note.isEmpty { Text(a.note).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary) }
        }
    }

    private func tint(_ c: HighlightColor) -> Color {
        switch c {
        case .green: DS.Colors.accentText
        case .yellow: Color(red: 0.94, green: 0.78, blue: 0.24)
        case .blue: Color(red: 0.27, green: 0.55, blue: 0.9)
        case .pink: Color(red: 0.9, green: 0.39, blue: 0.59)
        }
    }

    private func icon(_ k: AnnotationKind) -> String {
        switch k {
        case .highlight: "highlighter"
        case .note: "note.text"
        case .bookmark: "bookmark"
        }
    }
}

struct NoteEditor: View {
    let session: ReaderSession
    let onSave: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !session.selection.isEmpty {
                    Section("Passage") { Text(session.selection).font(DS.Typography.subheadline).lineLimit(6) }
                }
                Section("Note") { TextField("Write a note", text: $text, axis: .vertical).lineLimit(3...10) }
            }
            .navigationTitle("New note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { session.noteDraft = nil; dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(text) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
        .presentationDetents([.medium])
    }
}

struct AssistantSheet: View {
    let session: ReaderSession
    @State private var model = AssistantModel()
    @State private var passage: Passage?
    @State private var question = ""
    @State private var provider = AssistantProviders.make()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if case .unavailable(let reason) = provider.availability {
                        Text(reason).font(DS.Typography.callout).foregroundStyle(DS.Colors.textSecondary)
                    }
                    quote
                    actions
                    if let f = model.failure { Text(message(f)).font(DS.Typography.callout).foregroundStyle(DS.Colors.danger) }
                    if !model.answer.isEmpty || model.isRunning { answerView }
                    ask
                    Label("Runs on this device. Nothing is sent anywhere.", systemImage: "lock")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.privacyLocal)
                }
                .padding(Spacing.l)
            }
            .background(DS.Colors.background)
            .navigationTitle("Assistant")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.cancel(); dismiss() } } }
            .task { passage = await session.makePassage() }
        }
    }

    private var quote: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let p = passage {
                Text(p.isSelection ? "Selected passage, \(p.source)" : "Around where you are, \(p.source)")
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                Text(p.text).font(DS.Typography.footnote).lineLimit(5).foregroundStyle(DS.Colors.textPrimary)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
                if p.wasTrimmed { Text("Shortened to fit.").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
            } else {
                Text("There is no text on this page to ask about.").font(DS.Typography.callout).foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }

    private var actions: some View {
        HStack {
            ForEach(AssistantAction.quickActions, id: \.title) { action in
                Button(action.title) { run(action) }
                    .buttonStyle(.bordered)
                    .font(DS.Typography.caption)
                    .disabled(!canRun)
            }
        }
    }

    private var answerView: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(model.lastAction?.title ?? "Answer").font(DS.Typography.caption).foregroundStyle(DS.Colors.accentText)
                if model.isRunning { ProgressView().controlSize(.small) }
            }
            Text(model.answer.isEmpty ? " " : model.answer)
                .font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
            if !model.isRunning, !model.answer.isEmpty, let p = passage {
                Text("Based on: \(p.source)").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
        .accessibilityElement(children: .combine)
    }

    private var ask: some View {
        HStack {
            TextField("Ask about this passage", text: $question, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .onSubmit(send)
            Button("Ask", action: send)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DS.Colors.onAccent)
                .disabled(!canRun || question.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var canRun: Bool {
        if case .available = provider.availability { return passage != nil && !model.isRunning }
        return false
    }

    private func send() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, canRun else { return }
        run(.ask(q))
        question = ""
    }

    private func run(_ action: AssistantAction) {
        guard let passage else { return }
        model.run(action, on: passage, with: provider)
    }

    private func message(_ e: AssistantError) -> String {
        switch e {
        case .contextTooLong: "That passage is too long for the on-device model. Select a shorter part."
        case .refused: "The model declined to answer this passage."
        case .busy: "The model is busy. Try again in a moment."
        case .other: "Something went wrong. Try again."
        }
    }
}
