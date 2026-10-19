# Adiuvaret Reader spec

Core model: a private, on-device reader in which the library, progress and annotations are local data and the assistant is a tool that works only on the passage the user is looking at. (awaiting user confirmation)

## Goal
EPUB, PDF and text reader for iPhone, iPad and Mac with an on-device assistant, visually matching Adiuvaret.

## Non-goals
Cloud AI, accounts, book store, DRM books, audiobooks, iCloud sync (v1).

## Constraints
SwiftUI, Swift 6, iOS 17 / macOS 14 minimum, one multiplatform target. Bundle ID com.halit.adiuvaretreader. Builds only via GitHub Actions on user request. Commit after every change, short subject, no body. No emoji, no pill buttons.

## Glossary
- Passage: the selected text, or the current page or chapter excerpt, handed to the assistant.
- Locator: format-independent position (spine index + offset for EPUB, page + offset for PDF).

## Existing docs
- ../Adiuvaret/DESIGN.md, ../Adiuvaret/PRODUCT.md: source of the design language.
- PRODUCT.md, DESIGN.md in this repo.

## Decisions
- New repo and folder, design tokens copied, not linked: independent releases.
- One multiplatform SwiftUI target (iOS, iPadOS, macOS).
- EPUB parsed in-app (ZIP + XML), rendered in WKWebView with injected CSS; PDF via PDFKit.
- Assistant uses the Adiuvaret provider approach, Apple Foundation Models first.

## Open questions
- [ ] Confirm core model (owner: user)
- [ ] EPUB renderer: WKWebView + CSS (planned) vs a third-party toolkit; decided by spike task 2 (owner: agent)
- [ ] Share ModelLibrary with Adiuvaret as a package later? (owner: user)

## Spikes
| Unknown | Result | Numbers | Date |
|---|---|---|---|
| EPUB render + selection to assistant | pending | | |

## Baseline
Nothing built yet.
