import SwiftUI
#if canImport(UIKit)
import UIKit

/// iOS's own dictionary sheet for a word or short phrase.
struct DefineView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController { UIReferenceLibraryViewController(term: term) }
    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}

    static func canDefine(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 60, t.split(whereSeparator: \.isWhitespace).count <= 3 else { return false }
        return UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: t)
    }
}
#endif
