import SwiftUI
import ReaderDesign

/// Paints the chosen wallpaper. With none chosen, or a photo that is missing, it is the plain theme background.
struct WallpaperBackground: View {
    @Bindable private var store = WallpaperStore.shared
    @Environment(\.colorScheme) private var scheme
    @State private var photo: PlatformImage?

    var body: some View {
        ZStack {
            DS.Colors.background
            switch store.kind {
            case .none: EmptyView()
            case .gradient:
                LinearGradient(colors: store.gradient.stops(dark: scheme == .dark).compactMap(WallpaperColor.color), startPoint: .topLeading, endPoint: .bottomTrailing)
            case .pattern:
                PatternShape(kind: store.pattern).stroke(DS.Colors.accent.opacity(0.14), lineWidth: 1)
            case .solid:
                (WallpaperColor.color(store.solidHex) ?? DS.Colors.background)
            case .photo, .scenery:
                if let photo {
                    // A filled photo is wider than its frame. Laid out on a clear base and clipped, it cannot spill out of the drawer over the chat.
                    Color.clear.overlay {
                        Image(platform: photo).resizable().scaledToFill()
                            .overlay(DS.Colors.background.opacity(store.dim))
                    }
                    .clipped()
                }
            }
        }
        .clipped()
        .ignoresSafeArea()
        // Clipping does not limit touches, so an oversized photo would still catch taps outside its frame. The wallpaper is only a picture.
        .allowsHitTesting(false)
        .onAppear { if photo == nil { photo = picture() } }
        .onChange(of: store.kind) { _, _ in photo = picture() }
        .onChange(of: store.sceneID) { _, _ in photo = picture() }
        .accessibilityHidden(true)
    }
}

extension WallpaperBackground {
    /// The image for the current choice, or nil when the choice has none.
    fileprivate func picture() -> PlatformImage? {
        switch store.kind {
        case .photo: WallpaperPhoto.load()
        case .scenery: WallpaperScenery.image(named: WallpaperScene.resolve(store.sceneID).file)
        default: nil
        }
    }
}

/// A repeating pattern as one path, so it draws cheaply.
struct PatternShape: Shape {
    let kind: WallpaperPattern

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 28
        switch kind {
        case .dots:
            var y: CGFloat = step / 2
            while y < rect.height { var x: CGFloat = step / 2; while x < rect.width { p.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)); x += step }; y += step }
        case .grid:
            var x: CGFloat = 0; while x <= rect.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height)); x += step }
            var y: CGFloat = 0; while y <= rect.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y)); y += step }
        case .lines:
            var d: CGFloat = -rect.height; while d < rect.width { p.move(to: CGPoint(x: d, y: rect.height)); p.addLine(to: CGPoint(x: d + rect.height, y: 0)); d += step }
        case .waves:
            var y: CGFloat = step
            while y < rect.height + step {
                p.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x < rect.width { p.addQuadCurve(to: CGPoint(x: x + step, y: y), control: CGPoint(x: x + step / 2, y: y - 9)); x += step; p.addQuadCurve(to: CGPoint(x: x + step, y: y), control: CGPoint(x: x + step / 2, y: y + 9)); x += step }
                y += step
            }
        }
        return p
    }
}
