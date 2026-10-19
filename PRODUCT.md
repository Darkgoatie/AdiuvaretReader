# Product

<!-- impeccable:product-schema 1 -->

## Platform
adaptive (iPhone, iPad, Mac)

## Users
People who read books, PDFs and long articles on their own devices and want help understanding what they read without sending it anywhere. Not developers.

## Product Purpose
Adiuvaret Reader is a private reading app. The user imports EPUB, PDF and text files, reads them in a calm layout, and asks the on-device assistant about the passage in front of them: explain, summarise, define, find where something was said. Success: the user finishes more of what they start and never wonders where their text went.

## Positioning
Reading first, assistant second. The assistant never covers the text unless asked, and everything it uses stays on the device.

## Operating Context
Long sessions on iPhone and iPad, short ones on the phone in a queue, desktop reading on Mac. Context is limited (4096-token design floor), so the assistant works on the selection, the current chapter, or search hits, never the whole book.

## Capabilities and Constraints
- Formats v1: EPUB, PDF, plain text, markdown and source code (read-only, syntax highlighted). Library, progress, highlights, notes, bookmarks.
- Assistant: on-device models only (Apple Intelligence where available, same approach as Adiuvaret). No cloud.
- Files: the app is a partial file manager. Full control of its own library folders (create, rename, move, copy, delete with Recently Deleted, search, storage usage), plus import and export through the system Files app and folders the user grants. It does not browse the rest of the device.
- Wallpapers: Adiuvaret's set (none, bundled scenery, gradient, pattern, solid, own photo) behind the library and files, not behind text.
- Storage: SwiftData, local. iCloud sync is not in v1.
- Book content is never logged.

## Brand Commitments
- Same as Adiuvaret: Google Sans and Google Sans Flex app-wide, accent #2AB985, warm neutral ground (#FAF7F2 / #171512), no emoji, no pill buttons, radii 8/12/20.
- Reading surface: user-selectable paper, sepia and dark themes; typography adjustable.
- Voice: warm and personal, brief.

## Product Principles
1. The text is the interface; chrome gets out of the way.
2. Nothing leaves the device, and the app says so plainly.
3. The assistant answers about what is on the page, with the quote shown.
4. Fast to the page: opening a book resumes exactly where the user stopped.
5. Highlights and notes belong to the user and export as plain files.

## Accessibility & Inclusion
Dynamic Type through the largest sizes, VoiceOver for every control, 4.5:1 contrast in every reading theme, Reduce Motion respected, 44 pt targets, keyboard and pointer support on iPad and Mac.
