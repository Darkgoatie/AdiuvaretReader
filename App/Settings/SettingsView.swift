import SwiftUI
import PhotosUI
import ReaderDesign

struct SettingsView: View {
    @Bindable private var store = WallpaperStore.shared
    @Bindable private var theme = ThemeStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var hasPhoto = WallpaperPhoto.exists

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Colour", selection: $theme.theme) {
                        ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Wallpaper") {
                    Picker("Style", selection: $store.kind) {
                        ForEach(WallpaperKind.allCases) { Text($0.title).tag($0) }
                    }
                    switch store.kind {
                    case .none: EmptyView()
                    case .scenery:
                        SceneryPicker(selection: $store.sceneID)
                        let scene = WallpaperScene.resolve(store.sceneID)
                        Text("Photo: \(scene.title) by \(scene.photographer), Pexels")
                            .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    case .gradient:
                        Picker("Gradient", selection: $store.gradient) {
                            ForEach(WallpaperGradient.allCases) { Text($0.title).tag($0) }
                        }
                    case .pattern:
                        Picker("Pattern", selection: $store.pattern) {
                            ForEach(WallpaperPattern.allCases) { Text($0.title).tag($0) }
                        }
                    case .solid:
                        ColorPicker("Colour", selection: solidBinding, supportsOpacity: false)
                    case .photo:
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(hasPhoto ? "Choose another photo" : "Choose a photo")
                        }
                        if hasPhoto {
                            Button("Remove photo", role: .destructive) {
                                WallpaperPhoto.remove(); hasPhoto = false
                            }
                        }
                    }
                    if store.kind == .scenery || store.kind == .photo {
                        VStack(alignment: .leading) {
                            Text("Dim")
                            Slider(value: $store.dim, in: 0...WallpaperStore.maxDim)
                        }
                    }
                    Text("Wallpapers show behind the library and files, never behind reading text.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
                Section("About") {
                    LabeledContent("Version", value: Self.version)
                }
                Section("Privacy") {
                    Text("Your books, notes and highlights stay on this device.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), WallpaperPhoto.save(data) {
                        hasPhoto = true
                        store.kind = .photo
                    }
                }
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private var solidBinding: Binding<Color> {
        Binding(
            get: { WallpaperColor.color(store.solidHex) ?? .gray },
            set: { new in
                #if canImport(UIKit)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(new).getRed(&r, green: &g, blue: &b, alpha: &a)
                store.solidHex = WallpaperColor.hex(red: r, green: g, blue: b)
                #else
                if let c = NSColor(new).usingColorSpace(.sRGB) {
                    store.solidHex = WallpaperColor.hex(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
                }
                #endif
            })
    }
}
