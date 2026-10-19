import SwiftUI
import SwiftData
import ReaderDesign
import ReaderStore

@main
struct ReaderApp: App {
    init() {
        DesignSystemFonts.register()
        _ = ThemeStore.shared
        _ = WallpaperStore.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Book.self, BookAnnotation.self])
    }
}
