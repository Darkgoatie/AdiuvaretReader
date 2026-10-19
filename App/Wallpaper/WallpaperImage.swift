import SwiftUI
import ReaderDesign
import ImageIO
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
extension Image { init(platform i: PlatformImage) { self.init(uiImage: i) } }
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
extension Image { init(platform i: PlatformImage) { self.init(nsImage: i) } }
#endif

/// The user's own photo for the wallpaper, downscaled and kept on this device only.
enum WallpaperPhoto {
    static let maxSide: CGFloat = 1600

    private static var url: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("wallpaper.jpg")
    }

    static func save(_ data: Data) -> Bool {
        guard let jpeg = downscaledJPEG(data, maxSide: maxSide) else { return false }
        do { try jpeg.write(to: url, options: .atomic); return true } catch { return false }
    }

    static func load() -> PlatformImage? { PlatformImage(contentsOfFile: url.path) }
    static func remove() { try? FileManager.default.removeItem(at: url) }
    static var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    private static func downscaledJPEG(_ data: Data, maxSide: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}

/// The photos that ship inside the app.
enum WallpaperScenery {
    static func image(named name: String) -> PlatformImage? {
        Bundle.main.path(forResource: name, ofType: "jpg").flatMap { PlatformImage(contentsOfFile: $0) }
    }
}
