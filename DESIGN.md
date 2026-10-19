# Design

Direction: inherited from Adiuvaret (plain native Apple UI, warm neutral ground, single green accent). The Reader reuses its tokens so both apps read as one family.

## Principles
- System structure first: NavigationSplitView on iPad and Mac, NavigationStack on iPhone, sheets, SF Symbols, system materials.
- Green #2AB985 is the single accent and marks what the user can act on. Labels on green fills are dark. Green as text uses the darker accentText token.
- Ground #FAF7F2 light, #171512 dark; surfaces white and #221F1B. Reading themes add sepia (#F1E7D0 ground, #3B3226 text) without new accents.
- Rounded rectangles, never pills. Radii 8, 12, 20. Spacing 4, 8, 12, 16, 24.
- No emoji. Settled states are calm ("Saved", "Removed") instead of vanishing.

## Wallpapers
Same options as Adiuvaret Settings > Theme > Wallpaper: None (default), Scenery (13 bundled photos with previews and photographer, one random on first launch), Gradient, Pattern, Solid colour, Your photo, plus a dim slider. They sit behind the library, file browser and assistant. The reading surface never has one; it uses its paper, sepia or dark ground so text contrast holds. Settings screens stay solid.

## Files
Files is a top-level section next to Library: folder list with sizes, breadcrumb, multi-select, swipe and context actions (rename, move, copy, delete, share), search by name, Recently Deleted. System grouped lists, no custom chrome; book files show a progress ring and open in the reader.

## Code viewer
Read-only. Monospaced (system mono), line numbers in a quiet gutter, syntax colours drawn from the app palette (green accent for keywords, warm neutrals elsewhere) with 4.5:1 contrast on paper and dark grounds, wrap toggle, find bar. No editing chrome.

## Typography
UI: Google Sans Flex for headings, buttons, captions; Google Sans for body. Archivo Black only for the library title. Reading text: user choice among Google Sans, a system serif (New York) and system sans, with size, line spacing and margin controls. All via Font.custom relativeTo text styles so Dynamic Type scales.

## Layout
- Library: grid of covers on iPad and Mac, list on iPhone, with progress under each.
- Reader: full-bleed text, tap centre to toggle chrome, assistant as a bottom sheet on iPhone and a trailing inspector on iPad and Mac.
- Assistant answers always quote the passage they used.

## Tokens
Copied from Adiuvaret Packages/DesignSystem (Tokens.swift, Theme.swift, fonts) into ReaderDesign; changes to shared tokens are made in both.
