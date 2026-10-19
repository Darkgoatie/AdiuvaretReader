import SwiftUI
import SwiftData
import ReaderDesign
import ReaderStore

@main
struct ReaderApp: App {
    private let container: ModelContainer

    init() {
        DesignSystemFonts.register()
        _ = ThemeStore.shared
        _ = WallpaperStore.shared
        do {
            container = try ModelContainer(for: Book.self, BookAnnotation.self,
                                           configurations: ModelConfiguration(url: StoreLocation.defaultStoreURL()))
        } catch {
            fatalError("The library database could not be opened: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
