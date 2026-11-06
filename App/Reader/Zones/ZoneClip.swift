import SwiftUI
import PDFKit
import ReaderStore

#if canImport(UIKit)
import UIKit
import CoreImage

/// The copied part of a PDF page for the top of a zone's writing page.
@MainActor
enum ZoneClip {
    /// The marked part of the page as an image `width` points wide (the height follows from the zone's shape), sharp for a screen of `scale`.
    /// The page is drawn at the size that makes the part exactly as wide as asked, and the part is cut out of it. A very small part is drawn
    /// as sharp as the limit allows. With `invert` the colours are flipped for a dark reading theme.
    static func image(page: PDFPage, zone: ZoneRect, width: CGFloat, scale: CGFloat, invert: Bool) -> UIImage? {
        let box = page.bounds(for: .cropBox)
        guard box.width > 0, box.height > 0, width > 1, zone.width > 0 else { return nil }
        let aspect = box.height / box.width
        let wantedPixels = width * scale / CGFloat(zone.width)
        let longSide: CGFloat = 3200
        let pagePixels = min(wantedPixels, longSide / max(1, aspect > 1 ? aspect : 1))
        let size = CGSize(width: max(64, pagePixels), height: max(64, pagePixels * aspect))
        let whole = page.thumbnail(of: size, for: .cropBox)
        guard let cg = whole.cgImage else { return nil }
        let cut = CGRect(x: CGFloat(zone.x) * CGFloat(cg.width), y: CGFloat(zone.y) * CGFloat(cg.height),
                         width: CGFloat(zone.width) * CGFloat(cg.width), height: CGFloat(zone.height) * CGFloat(cg.height)).integral
        guard let part = cg.cropping(to: cut) else { return nil }
        var result = UIImage(cgImage: part, scale: CGFloat(part.width) / width, orientation: .up)
        if invert, let flipped = inverted(result) { result = flipped }
        return result
    }

    private static func inverted(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image), let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }
}
#endif
