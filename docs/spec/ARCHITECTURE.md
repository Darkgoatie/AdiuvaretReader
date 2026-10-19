# Architecture
Local SwiftPM packages: ReaderDesign, ReaderStore, ReaderFormats, ReaderAssistant. App/ is the SwiftUI target (XcodeGen project.yml).
Flow: importer -> ReaderStore (SwiftData) -> library UI -> reader view (ReaderFormats renders, emits Locator and selection) -> assistant sheet (ReaderAssistant, takes a Passage).
