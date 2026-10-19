# Tasks

Status: pending | in progress | done | needs-fix | reverted

| # | Task | Module | Files | Depends | Acceptance check | Status |
|---|---|---|---|---|---|---|
| 1 | Scaffold: project.yml, multiplatform target, compile-only GitHub workflow | app | project.yml, App/, .github/ | - | Actions run compiles iOS and macOS | pending |
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

STOP
