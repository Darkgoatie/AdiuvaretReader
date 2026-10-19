# Tasks

Status: pending | in progress | done | needs-fix | reverted

| # | Task | Module | Files | Depends | Acceptance check | Status |
|---|---|---|---|---|---|---|
| 1 | Scaffold: project.yml, multiplatform target, compile-only GitHub workflow | app | project.yml, App/, .github/ | - | Actions run compiles iOS and macOS | written, not compiled; run waits for "build" |
| 2 | Spike: EPUB in WKWebView with injected CSS, selection callback | ReaderFormats | spikes/ | 1 | Selecting text delivers the string | pending |
| 3 | ReaderDesign: copy tokens, fonts, theme; contrast tests incl. sepia | ReaderDesign | Packages/ReaderDesign | 1 | ContrastTests pass 4.5:1 in 3 themes | pending |
| 4 | SwiftData models and import of EPUB, PDF, txt | ReaderStore | Packages/ReaderStore | 1 | Unit test imports 3 sample files | pending |
| 5 | Library screen (list iPhone, grid iPad and Mac) with progress | app | App/Library | 3,4 | Shows sample library | pending |
| 6 | Thin slice: open EPUB, read, resume position | ReaderFormats | Packages/ReaderFormats | 2,4 | Close and reopen resumes same Locator (test) | pending |
| 7 | PDF reader via PDFKit with the same Locator | ReaderFormats | Packages/ReaderFormats | 6 | Locator round trip test | pending |
| 8 | Reader settings: theme, font, size, spacing, margins | app | App/Reader | 3,6 | Change re-renders and persists | pending |
| 9 | Highlights, notes, bookmarks, markdown export | ReaderStore | Packages/ReaderStore, App/Reader | 6 | Export contains created highlight (test) | pending |
| 10 | Assistant sheet/inspector: explain, summarise, define on selection, quoted answer | ReaderAssistant | Packages/ReaderAssistant | 6 | Passage builder test; manual on device | pending |
| 11 | In-book search and assistant "find where" | ReaderFormats | Packages/ReaderFormats | 6,10 | Search test on sample EPUB | pending |
| 12 | iPad and Mac layouts: split view, inspector, shortcuts | app | App/ | 5,10 | Compiles for macOS; user checks layout | pending |
| 13 | Accessibility pass and impeccable polish | app | App/ | 8-12 | VoiceOver label audit clean | pending |
| 14 | Wallpapers: copy WallpaperKind (none, scenery, gradient, pattern, solid, own photo), the 13 bundled Pexels scenes with thumbnails, WALLPAPER_CREDITS.md, dim slider, random first-launch scene; Settings > Theme > Wallpaper with Scenery picker and photographer credit. Shown behind library, file browser and assistant, never behind reading text | ReaderDesign, app | Packages/ReaderDesign, App/Wallpapers, App/Settings, docs/spec/WALLPAPER_CREDITS.md | 3 | Package tests: dim maths, stored value falls back to none; first launch shows a scene; choosing None stays None | pending |
| 15 | File store: app Documents/Library folder tree with create folder, rename, move, copy, delete (to a Recently Deleted area, 30 days), sort, search by name, storage usage per folder | ReaderFiles | Packages/ReaderFiles | 4 | Unit tests on a temp directory cover every operation incl. name collisions and move into own subfolder rejected | pending |
| 16 | Files screen: browse folders, multi-select, swipe and context actions, drag and drop on iPad and Mac, open book in reader, quick look for other files, share and export | app | App/Files | 5,15 | Compiles on iOS and macOS; user checks flows | pending |
| 17 | Import from outside: system Files picker, Open In and share extension target, drop onto window, security-scoped bookmarks for user-chosen external folders (read-only browse, copy in to keep) | ReaderFiles, app | Packages/ReaderFiles, App/Files | 15 | Unit test resolves a stored bookmark; user imports from iCloud Drive on device | pending |
| 18 | Expose the library folder in the system Files app (UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace) and rescan on foreground so outside changes appear | ReaderFiles, app | project.yml, Packages/ReaderFiles | 15 | Test: file added outside the app is indexed on rescan; user sees folder in Files | pending |
| 19 | Shared space between own apps: App Group group.com.halit.shared on Reader and Adiuvaret (entitlement + provisioning on both), a "Shared" root in Files listing a Shared/ folder in the group container, copy or move files in and out, open a shared file in the other app via URL scheme. Only apps in the group can read it | ReaderFiles, app | Packages/ReaderFiles, project.yml, App/Files, Config/ | 15,16 | Test: ReaderFiles resolves the group root and a file written by one process is listed by another (two test hosts); user drops a PDF in Adiuvaret and sees it in Reader | pending |

STOP
