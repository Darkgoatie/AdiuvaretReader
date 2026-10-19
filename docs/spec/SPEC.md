# Adiuvaret Reader spec

Core model: a private, on-device reader in which the library, progress and annotations are local data and the assistant is a tool that works only on the passage the user is looking at. (awaiting user confirmation; files are part of "library", the app's own folder tree)

## Goal
EPUB, PDF and text reader for iPhone, iPad and Mac with an on-device assistant, visually matching Adiuvaret. It carries Adiuvaret's wallpaper options (none, 13 bundled scenery photos, gradients, patterns, solid colour, own photo) and acts as a partial file manager for the user's reading files.

## Non-goals
A full file manager: no browsing of other apps' data or the whole device; only the app's own library and folders the user explicitly grants. No cloud AI, accounts, book store, DRM books, audiobooks, iCloud sync (v1).

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
- Wallpapers copied from Adiuvaret as of 2026-10-19 (13 Pexels scenes, 1440x2560, about 5 MB), credits file kept with them.
- Partial file manager = full control of the app library (folders, rename, move, copy, delete with Recently Deleted, search, usage) plus import from and export to the system Files app and user-granted external folders.
- Own apps share files through an App Group (group.com.halit.shared) with the same team: iOS gives no other way to read another app's sandbox. Needs the group added to both apps' App IDs in the Apple developer account; cloud signing key must cover it. Apps not in the group (other developers' apps) stay out of scope.
- One multiplatform SwiftUI target (iOS, iPadOS, macOS).
- EPUB parsed in-app (ZIP + XML), rendered in WKWebView with injected CSS; PDF via PDFKit.
- Assistant uses the Adiuvaret provider approach, Apple Foundation Models first.

## Open questions
- [ ] Should wallpaper show behind reading text? Planned: no, readability; reading uses paper, sepia or dark themes only (owner: user)
- [ ] Which of your apps join the group besides Adiuvaret (Keply, KeyFolio, Arztalep)? (owner: user)
- [ ] Confirm core model (owner: user)
- [ ] EPUB renderer: WKWebView + CSS (planned) vs a third-party toolkit; decided by spike task 2 (owner: agent)
- [ ] Share ModelLibrary with Adiuvaret as a package later? (owner: user)

## Spikes
| Unknown | Result | Numbers | Date |
|---|---|---|---|
| EPUB render + selection to assistant | pending | | |

## Baseline
Nothing built yet.
