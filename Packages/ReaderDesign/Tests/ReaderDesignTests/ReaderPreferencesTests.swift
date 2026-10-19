import Testing
import Foundation
@testable import ReaderDesign

@Suite struct ReaderPreferencesTests {
    private func defaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "test." + UUID().uuidString)!
        return d
    }

    @Test func defaultsAndPersistence() {
        let d = defaults()
        let p = ReaderPreferences(defaults: d)
        #expect(p.theme == .paper)
        #expect(p.fontSize == 19)
        p.theme = .sepia
        p.fontSize = 24
        let again = ReaderPreferences(defaults: d)
        #expect(again.theme == .sepia)
        #expect(again.fontSize == 24)
    }

    @Test func storedValuesAreClamped() {
        let d = defaults()
        d.set(500.0, forKey: "reader.size")
        d.set(-3.0, forKey: "reader.margin")
        let p = ReaderPreferences(defaults: d)
        #expect(p.fontSize == 34)
        #expect(p.margin == 0)
    }
}
