import SwiftUI
import ReaderDesign

struct RootView: View {
    var body: some View {
        LibraryView()
            .tint(DS.Colors.accent)
            .font(DS.Typography.body)
    }
}
