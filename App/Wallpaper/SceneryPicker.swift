import SwiftUI
import ReaderDesign

/// The bundled landscape photos as small previews, three to a row. Tapping one makes it the wallpaper.
struct SceneryPicker: View {
    @Binding var selection: String
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(WallpaperScene.all) { scene in
                Button { selection = scene.id } label: {
                    Color.clear
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .overlay {
                            if let image = WallpaperScenery.image(named: scene.thumbnail) {
                                Image(platform: image).resizable().scaledToFill()
                            } else {
                                DS.Colors.surface
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.s)
                                .stroke(selection == scene.id ? DS.Colors.accent : Color.clear, lineWidth: 3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: scene.title))
                .accessibilityAddTraits(selection == scene.id ? .isSelected : [])
                .accessibilityIdentifier("wallpaper.scene.\(scene.id)")
            }
        }
        .padding(.vertical, Spacing.s)
    }
}
