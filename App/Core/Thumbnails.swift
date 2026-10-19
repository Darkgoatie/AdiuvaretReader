import Foundation
import PDFKit
import ImageIO
import QuickLookThumbnailing
import ReaderStore
import ReaderFormats
#if canImport(UIKit)
import UIKit
#endif

struct Thumb: @unchecked Sendable {
    let image: PlatformImage
}

/// Small previews of files: a PDF's first page, an EPUB's cover, the opening lines of text, or the system thumbnail for anything else.
final class ThumbnailService: @unchecked Sendable {
    static let shared = ThumbnailService()
    private let images = NSCache<NSString, PlatformImage>()
    private let texts = NSCache<NSString, NSString>()

    private init() {
        images.countLimit = 250
        texts.countLimit = 400
    }

    private func key(_ url: URL, _ extra: String) -> NSString {
        let a = try? FileManager.default.attributesOfItem(atPath: url.path)
        let stamp = "\((a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)|\((a?[.size] as? NSNumber)?.intValue ?? 0)"
        return "\(url.path)|\(stamp)|\(extra)" as NSString
    }

    func image(for url: URL, format: BookFormat?) async -> Thumb? {
        let k = key(url, "img")
        if let hit = images.object(forKey: k) { return Thumb(image: hit) }
        let made: Thumb? = await Task.detached(priority: .utility) { await Self.render(url, format) }.value
        if let made { images.setObject(made.image, forKey: k) }
        return made
    }

    func snippet(for url: URL, format: BookFormat) async -> String? {
        let k = key(url, "txt")
        if let hit = texts.object(forKey: k) { return hit as String }
        let made: String? = await Task.detached(priority: .utility) { () -> String? in
            if format == .epub { return EpubBook.previewText(at: url) }
            guard format.isTextual, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            let data = (try? handle.read(upToCount: 6000)) ?? Data()
            let kind: FilePreviewText.Kind
            switch format {
            case .markdown: kind = .markdown
            case .latex: kind = .latex
            case .code: kind = .code
            default: kind = .plain
            }
            let text = FilePreviewText.snippet(data, kind: kind)
            return text.isEmpty ? nil : text
        }.value
        if let made { texts.setObject(made as NSString, forKey: k) }
        return made
    }

    private static func render(_ url: URL, _ format: BookFormat?) async -> Thumb? {
        switch format {
        case .pdf:
            guard let doc = PDFDocument(url: url), !doc.isLocked, let page = doc.page(at: 0) else { return nil }
            let box = page.bounds(for: .mediaBox)
            guard box.width > 0, box.height > 0 else { return nil }
            let width: CGFloat = 360
            return Thumb(image: page.thumbnail(of: CGSize(width: width, height: width * box.height / box.width), for: .mediaBox))
        case .epub:
            guard let data = EpubBook.coverData(at: url) else { return nil }
            return downsample(data, maxSide: 480)
        case .some(let f) where f.isTextual:
            return nil
        default:
            return await systemThumbnail(url)
        }
    }

    private static func downsample(_ data: Data, maxSide: CGFloat) -> Thumb? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return Thumb(image: makeImage(cg))
    }

    private static func systemThumbnail(_ url: URL) async -> Thumb? {
        #if canImport(UIKit)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 240, height: 320), scale: 2, representationTypes: .thumbnail)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else { return nil }
        return Thumb(image: rep.uiImage)
        #else
        return nil
        #endif
    }

    private static func makeImage(_ cg: CGImage) -> PlatformImage {
        #if canImport(UIKit)
        UIImage(cgImage: cg)
        #else
        NSImage(cgImage: cg, size: .zero)
        #endif
    }
}
