import SwiftUI
import ReaderStore
import ReaderDesign

/// Every zone of the PDF, grouped by page, to open or delete.
struct ZoneListView: View {
    let controller: ZoneController

    private var pages: [Int] { Array(Set(controller.list.zones.map(\.page))).sorted() }

    var body: some View {
        NavigationStack {
            Group {
                if controller.hasZones {
                    List {
                        ForEach(pages, id: \.self) { page in
                            Section("Page \(page + 1)") {
                                ForEach(controller.list.zones(onPage: page)) { zone in row(zone) }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No zones yet", systemImage: "rectangle.dashed",
                                           description: Text("Choose Mark a zone, then drag over a question."))
                }
            }
            .navigationTitle("Zones")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { controller.showList = false } } }
        }
    }

    private func row(_ zone: Zone) -> some View {
        let written = controller.written.contains(zone.id)
        return Button {
            controller.showList = false
            // the list sheet has to be gone before the writing page comes up
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                controller.open(zone)
            }
        } label: {
            HStack(spacing: Spacing.m) {
                Text(controller.title(of: zone)).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                if written {
                    Image(systemName: "pencil.line").foregroundStyle(DS.Colors.accentText)
                        .accessibilityLabel("Has writing")
                }
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(DS.Colors.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .swipeActions {
            Button(role: .destructive) { controller.delete(zone) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

/// Shown over the PDF while the user marks a zone.
struct ZoneMarkingBanner: View {
    let controller: ZoneController

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text("Drag over a question to mark it. Two fingers scroll.")
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textPrimary)
            Spacer(minLength: Spacing.s)
            Button("Cancel") { controller.marking = false }
                .font(DS.Typography.footnote.weight(.semibold))
                .foregroundStyle(DS.Colors.accentText)
        }
        .padding(.horizontal, Spacing.l).padding(.vertical, Spacing.m)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator))
        .padding(.horizontal, Spacing.l).padding(.top, Spacing.s)
        .transition(.opacity)
    }
}
