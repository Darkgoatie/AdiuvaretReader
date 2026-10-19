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

    @Test func keepScreenOnDefaultsToOnAndPersists() {
        let d = defaults()
        let p = ReaderPreferences(defaults: d)
        #expect(p.keepScreenOn)
        p.keepScreenOn = false
        #expect(!ReaderPreferences(defaults: d).keepScreenOn)
    }

    @Test func aBookCanKeepItsOwnSettings() {
        let d = defaults()
        let p = ReaderPreferences(defaults: d)
        let book = UUID()
        p.fontSize = 20
        p.enter(book: book)
        #expect(!p.isScoped)
        p.setScoped(true)
        p.fontSize = 30
        p.theme = .sepia
        #expect(ReaderPreferences(defaults: d).fontSize == 20)
        p.leave()
        #expect(p.fontSize == 20 && p.theme == .paper)
        p.enter(book: book)
        #expect(p.isScoped && p.fontSize == 30 && p.theme == .sepia)
        let other = UUID()
        p.leave()
        p.enter(book: other)
        #expect(!p.isScoped && p.fontSize == 20)
    }

    @Test func changesWithoutABookOverrideStayGlobal() {
        let d = defaults()
        let p = ReaderPreferences(defaults: d)
        p.enter(book: UUID())
        p.fontSize = 26
        p.leave()
        #expect(ReaderPreferences(defaults: d).fontSize == 26)
    }

    @Test func turningTheOverrideOffReturnsToGlobal() {
        let d = defaults()
        let p = ReaderPreferences(defaults: d)
        let book = UUID()
        p.fontSize = 18
        p.enter(book: book)
        p.setScoped(true)
        p.fontSize = 32
        p.setScoped(false)
        #expect(p.fontSize == 18 && !p.isScoped)
        p.leave()
        p.enter(book: book)
        #expect(!p.isScoped && p.fontSize == 18)
    }
}
