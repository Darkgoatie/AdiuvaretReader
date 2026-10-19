import Foundation
import CoreText

public enum DesignSystemFonts {
    /// File URL of a bundled font, for use in web content.
    public static func fileURL(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
    }

    /// Registers the bundled TTFs for this process. Call once at app launch.
    public static func register() {
        guard let root = Bundle.module.resourceURL,
              let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in walk where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
