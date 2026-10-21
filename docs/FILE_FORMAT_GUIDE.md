# Adiuvaret Reader: file format guide

Audience: AI models and people who write files that Adiuvaret Reader opens.
Scope: exactly what the Reader's renderers accept. Anything not listed here is not supported and is shown as plain text or ignored.
Source of truth: `Packages/ReaderFormats/Sources/ReaderFormats/` (Obsidian/*, LatexConverter, ProseHTML, ProseParser, CodeTokenizer, CodeLanguage, EpubCSS) and `Packages/ReaderFiles/Sources/ReaderFiles/ReaderLink.swift`. If this guide and the code disagree, the code wins; fix the guide.

## 1. Rules for writing files (read this first)

1. Write UTF-8 text. LF or CRLF line endings both work.
2. Use Markdown (`.md`) for notes. It is the richest format and renders the way Obsidian's reading view does.
3. Use only the syntax listed in this guide. Do not use HTML tags in notes: they are escaped and shown as text.
4. Never use `https://` images or remote assets. The Reader has no network access; online images show "Online image not loaded". Put images beside the note and embed them with `![[name.png]]`.
5. Math goes in `$...$` (inline) and `$$...$$` (block). Do not use `\usepackage`, `\newcommand` or other preamble commands in math.
6. Put each molecule in a fenced code block tagged `smiles` or `mol`. Do not describe a molecule as an image.
7. Leave a blank line between blocks (paragraph, list, table, quote, fence, math block).
8. File names: no `/`, no `:`, must not start with `.`, at most 255 bytes. Spaces and Unicode are fine.
9. Links to other notes use `[[Note name]]`. Do not use absolute paths.
10. If unsure whether a feature exists, leave it out. Unknown syntax degrades to visible plain text, never to an error.

## 2. File types

| Extension | Format | Renderer | Notes |
|---|---|---|---|
| `.md`, `.markdown` | Markdown | Obsidian-style renderer | Full feature set in sections 3 to 9 |
| `.txt`, `.text` | Plain text | Paragraph renderer | Blank line = new paragraph; single line breaks are kept. No Markdown, no math, no molecules |
| `.tex`, `.latex` | LaTeX | Converted to Markdown, then a simple renderer | Section 10. No molecules, no wikilinks |
| `.epub` | EPUB | Chapter viewer | Not authored here; math and molecules are not processed |
| `.pdf` | PDF | PDFKit | Not authored here |
| code: `swift py js ts tsx jsx json yaml yml toml html htm css c h cpp hpp m rs go sh rb java kt php sql xml lua cs` | Code | Syntax-highlighted viewer | Section 11. Read-only |

Any other extension is not opened by the Reader.

## 3. Markdown: document structure

### 3.1 Properties (front matter)

A note may start with a YAML block. It must be the very first thing in the file.

```
---
title: Chemistry week 3
tags: [chemistry, exam]
aliases:
  - Week 3
chem-style: bw
---
```

Rules:
- First line is exactly `---` (spaces around allowed). The block ends at the next line that is `---` or `...`.
- The block is accepted only if at least one line contains `:` (otherwise the file is treated as having no properties and the `---` is shown as a rule).
- Each property is `key: value` at column 0. Keys keep their case when shown.
- Lists: either `key: [a, b, c]` or a following run of `- item` lines.
- `tags` / `tag` may also be `tags: a, b` or `tags: a b` (comma or space separated). A leading `#` on a tag is removed.
- Surrounding single or double quotes on a value are removed.
- Nested YAML maps and multi-line strings are not supported; those lines are skipped.
- `cssclasses` and `cssclass` are read but not displayed.
- All other properties are shown in a rounded panel at the top of the note: tags as tag pills, lists as chips, other values as text.
- Reader-specific property: `chem-style` (section 8.4).

### 3.2 Headings

`#` to `######` followed by a space: `## Title`. Trailing `#` characters are removed. The heading text becomes an anchor id: lower-case letters and digits joined by single dashes (`## Rate law (k)` -> `h-rate-law-k`). Setext headings (`Title` over `====`) are not supported.

### 3.3 Paragraphs and line breaks

Consecutive lines form one paragraph. A single newline inside a paragraph is kept as a line break. A blank line ends the paragraph.

### 3.4 Horizontal rule

A line of three or more `-`, `*` or `_` (spaces allowed between), alone on the line: `---`.
Note: `---` directly under a text line is a rule, not a heading.

### 3.5 Lists

```
- bullet            * also bullet       + also bullet
1. numbered         1) also numbered
- [ ] open task
- [x] done task
    - nested (indent by 4 spaces or a tab; more than the parent is enough)
```

- Bullet markers: `-`, `*`, `+` followed by a space.
- Numbered: digits (up to 9) followed by `.` or `)` and a space. The first number sets the start value.
- Tasks: `- [ ] text` or `- [x] text` (capital `X` works). A task item shows a box, ticked when done, dimmed when done.
- Nesting is by indentation; a nested block (paragraph, quote, fence) under an item must be indented more than the marker.
- A line indented more than the marker and not starting a list continues the item's text.

### 3.6 Block quotes

Lines starting with `>`. Quotes can contain any block. For callouts see 5.

### 3.7 Tables

```
| Name   | Value |  Unit |
|:-------|:-----:|------:|
| Mass   |   12  |    g  |
```

- A header row, then a divider row, then body rows. The divider must have the same number of cells as the header.
- Divider cells contain only `-` and `:`. `:--` left, `:-:` centre, `--:` right, `---` default.
- Escape a literal pipe as `\|`. Pipes inside `[[...]]` are not treated as separators.
- A row with fewer cells is padded; extra cells are cut. Cells render inline Markdown.

### 3.8 Code

- Fenced: a line of three or more backticks (or `~~~`), optional language word, content, then a closing fence of the same character. Language word is kept as a class only; no highlighting inside notes.
- Indented code: 4+ spaces or a tab at the start of a block, when no paragraph is open.
- `mermaid` fences are shown as source with a note that diagrams are not drawn.
- Fences tagged `smiles`, `smi`, `mol`, `molfile` draw molecules (section 8).
- Inside a fence nothing else is processed (no links, no math, no comments).

### 3.9 Comments

`%%text%%` is removed before rendering, inline or across lines. Not applied inside fences. Use it for notes to yourself.

### 3.10 Escapes

A backslash before one of `` \ ` * _ { } [ ] ( ) # + - . ! | ~ = % ^ < > $ `` shows the character literally: `\*not italic\*`, `\$5`.

## 4. Markdown: inline syntax

| Write | Result |
|---|---|
| `**bold**`, `__bold__` | bold |
| `*italic*`, `_italic_` | italic |
| `***both***` | bold italic |
| `~~gone~~` | strikethrough |
| `==marked==` | highlight (amber) |
| `` `code` `` | inline code (double backticks allowed: ``` ``a`b`` ```) |
| `[text](https://example.com)` | external link (opens in the browser; only `http`, `https`, `mailto`) |
| `[text](Other note.md)` or `[text](Other%20note.md#Heading)` | link to a file in the same folder tree |
| `<https://example.com>` | autolink |
| `#tag`, `#nested/tag` | tag pill; tapping it searches the note for the tag |
| `[^id]` plus a definition line `[^id]: text` | footnote |
| `^[inline footnote text]` | inline footnote mark with the text as tooltip |
| `text ^block-id` at the end of a paragraph | block id for linking (section 6.3) |

Details:
- Emphasis does not cross line breaks.
- A tag must not be preceded by a letter, digit, `_`, `&`, `#` or `/`, and must contain at least one non-digit character (`#2024` is not a tag; `#plan-2024` is). Allowed characters: letters, digits, `_`, `-`, `/`.
- Footnote definitions: `[^id]: text` at column 0; continuation lines are indented 4 spaces or a tab. The reference must have a definition, otherwise it is shown as plain `[^id]`. Footnotes are listed at the end of the note, in order of definition.
- Online images `![alt](https://...)` are not loaded.

## 5. Callouts

```
> [!warning] Heads up
> Body text, **inline syntax** and other blocks work here.

> [!faq]- Collapsed by default
> Hidden until tapped.

> [!tip]+ Open by default, can be folded
> Visible.
```

- Syntax: first quote line `[!type]`, optional `-` (folded) or `+` (foldable, open), then an optional title. No title shows the type name capitalised.
- Types and aliases (alias -> type): `note`, `abstract` (`summary`, `tldr`), `info`, `todo`, `tip` (`hint`, `important`), `success` (`check`, `done`), `question` (`help`, `faq`), `warning` (`caution`, `attention`), `failure` (`fail`, `missing`), `danger` (`error`), `bug`, `example`, `quote` (`cite`).
- Any other type name is drawn as `note`.
- Colour groups: tip/success green; warning/example/question amber; danger/failure/bug red; quote grey; abstract/todo teal; others blue.

## 6. Links, embeds and the vault

A folder tree of notes is a vault. Links resolve across the whole library folder the note lives in (the app Library, or the "Shared with my apps" folder).

### 6.1 Wikilinks

| Write | Meaning |
|---|---|
| `[[Note]]` | note named Note.md anywhere in the vault |
| `[[Folder/Note]]` | narrows by folder path |
| `[[Note\|shown text]]` | alias (pipe) |
| `[[Note#Heading]]` | opens the note at that heading |
| `[[Note#^block-id]]` | opens the note at that block |
| `[[#Heading]]`, `[[#^block-id]]` | same note |
| `[[./Sibling]]`, `[[../Up/Note]]` | relative to the current note |

- Extension is optional; `.md` is assumed. A name that exists twice resolves to the closest (same folder first, then fewer folders).
- A link that does not resolve is drawn dotted and dimmed; tapping it says the note does not exist. Do not link to notes that are not in the vault.
- Heading text matching is on the anchor form (see 3.2), so punctuation and case are ignored.

### 6.2 Embeds `![[...]]`

| Write | Result |
|---|---|
| `![[Note]]` | the whole note inlined (frontmatter dropped), with its title |
| `![[Note#Heading]]` | that heading's section (until the next heading of the same or higher level) |
| `![[Note#^id]]` | that block |
| `![[pic.png]]`, `![[pic.png\|300]]`, `![[pic.png\|300x200]]` | image, optional width or width x height in px |
| `![[clip.mp3]]` | audio player (mp3 m4a wav ogg flac) |
| `![[clip.mp4]]` | video player (mp4 mov m4v webm) |
| `![[Paper.pdf]]`, `![[Paper.pdf#page=7]]` | link to the PDF, optionally at page 7 |

- Image extensions: png jpg jpeg gif svg webp bmp avif.
- Markdown images `![alt](path/pic.png)` work for local files; `![alt\|300](pic.png)` sets the width.
- Embeds nest at most 3 deep. A missing target shows "Image not found", "Note not found" or "Section not found" in italics.
- A line that contains only an embed is a block of its own.

### 6.3 Block ids

End a paragraph or list item line with ` ^some-id` (space, caret, letters/digits/dashes). It is invisible and can be targeted by `[[Note#^some-id]]` and `![[Note#^some-id]]`. An id on its own line after a block refers to the block above it.

## 7. Math

Rendered by KaTeX 0.16.11, offline.

- Inline: `$a^2 + b^2 = c^2$` or `\( ... \)`.
- Block: `$$ ... $$` on its own lines, or one line `$$ ... $$`, or `\[ ... \]`.
- Inline `$` rules: no space after the opening `$` or before the closing `$`; the closing `$` must not be followed by a letter or digit. So `costs $5 and $6` is not math, `$x$` is. Write `\$` for a literal dollar sign.
- Math is not processed inside code spans or fences.
- Multi-line environments go inside `$$`:

```
$$
\begin{aligned}
f(x) &= (x+1)^2 \\
     &= x^2 + 2x + 1
\end{aligned}
$$
```

Supported: everything in KaTeX's function list (fractions, roots, sums, integrals, matrices `pmatrix` `bmatrix` `vmatrix`, `cases`, `aligned`, `array`, accents `\vec \hat \bar \overrightarrow \widehat`, `\underbrace`, `\xrightarrow`, `\mathbb \mathcal \mathbf`, `\text{}`, `\color{}`, Greek letters, AMS symbols). Not supported: `\usepackage`, `\newcommand` / `\def` across blocks, `tikz`, `\label`/`\ref`, `align`/`equation` environments directly (wrap in `aligned`; `equation` and `align` are only converted in `.tex` files).
An unsupported command is drawn in red in place; it does not break the rest of the note.

### 7.1 Chemical formulas (mhchem)

Use `\ce{...}` inside math:

| Write | Shows |
|---|---|
| `$\ce{H2O}$` | H2O with subscript |
| `$\ce{2H2 + O2 -> 2H2O}$` | reaction with arrow |
| `$\ce{SO4^2-}$`, `$\ce{Fe^{3+}}$` | ions and charges |
| `$\ce{A <=> B}$` | equilibrium |
| `$\ce{CaCO3 v}$`, `$\ce{CO2 ^}$` | precipitate, gas |
| `$\ce{^{14}C}$` | isotope |
| `$\ce{Zn^2+ + 2e- -> Zn}$` | electrons |
| `$\ce{A ->[\ce{H2O}] B}$` | text above the arrow, `->[above][below]` |

Write plain "H2O" in running text only when you do not want formatting. Never rely on automatic conversion.

## 8. Molecules (2D drawings)

Drawn offline with RDKit. Only in Markdown notes.

### 8.1 Block syntax

````
```smiles
style: color
title: Caffeine
Cn1cnc2c1c(=O)n(C)c(=O)n2C
```
````

- Fence language: `smiles` or `smi` (SMILES text), `mol` or `molfile` (an MDL molfile).
- Header: zero or more `key: value` lines at the very top of the block, then the molecule. The header ends at the first line that is not a recognised `key: value`.
- SMILES blocks: one molecule per line. Anything after the first whitespace on a line is a caption shown under that molecule (`CCO ethanol`). Several lines draw several molecules side by side. Blank lines are ignored.
- SMILES must not contain spaces. A header line is recognised only when it looks like `word: value` (a plain word, a colon, then a space or the end of the line) and, in molfile blocks, the word is one of the keys in 8.2. A real SMILES such as `[nH:1]` never matches, because it contains brackets.
- Molfile blocks: put the full molfile (header lines, counts line, atom block, bond block, `M  END`). A molfile's first line is its own name line and is never parsed as an option; only recognised option keys above it are read.
- A molecule that cannot be parsed shows a red line under the block: "Could not read C1CC. Check the notation." The other molecules still draw.

### 8.2 Options

| Key | Values | Default | Effect |
|---|---|---|---|
| `style` | see 8.3 | note default, else `skeletal` | drawing style |
| `hydrogens` | `explicit` (also `show`, `true`, `yes`, `all`, `on`) / `implicit` (also `hide`, `false`, `no`, `none`, `off`) | per style | force all H atoms shown or hidden |
| `numbers` (alias `atom-numbers`) | `true` / `false` | false | show atom indices (0-based, the numbers `highlight` uses). Indices count atoms in the order written in the SMILES, before any hydrogens are added |
| `stereo` (alias `cip`) | `true` / `false` | false | show R/S and E/Z labels |
| `size` | `small` (200), `medium` (300), `large` (420) or a number | 300 | image width in px |
| `width` | integer, `px` allowed | 300 | width in px; clamped to 120..700. Height is 75% of width |
| `title` (aliases `caption`, `name`) | text | none | heading above the drawing |
| `highlight` | atom indices separated by commas or spaces | none | highlights those atoms; use `numbers: true` first to learn the indices |

Unknown keys end the header (for SMILES the line is then treated as a molecule). Booleans accept `true yes on 1 show`; anything else is false.

### 8.3 Styles

| Style | Look | Aliases |
|---|---|---|
| `skeletal` | standard textbook skeletal formula, implicit H | `standard`, `default`, `textbook`, `line` |
| `explicit` | every hydrogen drawn, all methyl groups labelled | `kekule`, `kekulé`, `full`, `hydrogens` |
| `color` | atoms coloured by element | `colour`, `colored`, `coloured` |
| `bw` | black and white, for print | `mono`, `blackwhite`, `print` |
| `comic` | hand-drawn look | `sketch`, `hand` |
| `compact` | thin bonds, small labels, tight padding | `small` |
| `bold` | thick bonds, black and white | `thick` |

An unknown style falls back to `skeletal` and the block shows "Unknown style ..., drawn as skeletal. Styles: ...". There is no 3D, ball-and-stick or space-filling style.
Drawings use the page text colour, so they stay readable in paper, sepia and dark themes.

### 8.4 Note default style

Add `chem-style: bw` to the note's properties. Every molecule block without its own `style:` uses it. A block's `style:` always wins. An unknown value is ignored (falls back to `skeletal`).

### 8.5 Examples

Several molecules with captions:

````
```smiles
size: small
CCO ethanol
CC(=O)O acetic acid
c1ccccc1 benzene
```
````

Stereo and atom numbers for choosing a highlight:

````
```smiles
style: bw
stereo: true
numbers: true
highlight: 0 1
C[C@H](N)C(=O)O L-alanine
```
````

A molfile:

````
```mol
style: comic
name: ethanal

  Tool

  3  2  0  0  0  0  0  0  0  0999 V2000
    0.0000    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    1.2000    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    2.4000    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  1  0
  2  3  2  0
M  END
```
````

(There is a blank line between the option lines and the molfile's own name line. The molfile starts with its name line, then program line, then comment line.)

### 8.6 Rules of thumb for generated files

- Prefer SMILES. Check ring-closure digits are paired and parentheses balance.
- Use aromatic lowercase (`c1ccccc1`) or Kekule (`C1=CC=CC=C1`); both work.
- Do not put a name where only a molecule is allowed (`aspirin` is not a SMILES). Put names after a space as captions.
- One idea per block. Use `title:` for a heading.

## 9. Reader links (from other apps)

URL form: `adiuvaretreader://open?path=<relative path>&fragment=<optional>`

- `path`: file or folder inside the shared folder ("Shared with my apps"), relative, no leading `/`, no `..`, at most 500 characters. Must be percent-encoded.
- `fragment` (optional): for Markdown, a heading text or `^block-id`; for PDF, `page=N` (1-based).
- A folder path opens that folder. A file path opens the file, at the fragment for single-page text formats and PDFs.
- A path that does not exist leaves the Reader on the Files screen at its top level.

Inside notes, use `[[wikilinks]]` (section 6), not this URL.

## 10. LaTeX files (`.tex`)

The Reader converts a LaTeX document to Markdown, then renders it as a simple article (no wikilinks, no molecules, no Obsidian features).

Kept:
- `\title{}`, `\author{}` shown at the top.
- `\chapter`, `\section`, `\subsection`, `\subsubsection` (starred forms too) -> headings 1 to 4.
- `\begin{abstract}`.
- `itemize` / `enumerate` with `\item` -> bullet list (numbering is not preserved).
- `\textbf`, `\mathbf` -> bold; `\emph`, `\textit` -> italic; `\texttt` -> code.
- Math: `equation`, `equation*`, `displaymath`, `\[ \]`, `$$ $$`, `align`, `align*`, `aligned`, `gather`, `multline`, `eqnarray` (all become display math), and inline `$ $` and `\( \)`.
- Comments `% ...` removed. Quote marks ``` `` ``` and `''` become curly quotes. `~` becomes a space, `\\` a line break.

Dropped: everything before `\begin{document}`, `\label \cite \ref \eqref \usepackage \documentclass \maketitle \tableofcontents \newpage \clearpage \centering \noindent \vspace \hspace`.
Not supported (shown as raw text or lost): `tabular`, `figure`, `includegraphics`, bibliography, custom macros, `\input`.
If the file has no `\begin{document}`, the whole file is converted.

## 11. Code files

Open read-only with syntax colours (keywords, strings, comments, numbers) and optional line wrapping. Language comes from the extension, or from a `#!` first line for scripts.

| Extension(s) | Highlighted as |
|---|---|
| swift | Swift |
| py | Python |
| js ts tsx jsx | JavaScript |
| json | JSON |
| yaml yml | YAML |
| toml | TOML |
| html htm | HTML |
| css | CSS |
| c h cpp hpp m | C and C++ |
| java cs kt | Java and C# |
| rs | Rust |
| go | Go |
| sh | Shell |
| rb | Ruby |
| php | PHP |
| sql | SQL |
| lua | Lua |
| xml | XML |

Lines longer than 2000 characters are cut. Position is tracked by line.

## 12. Plain text files (`.txt`)

Paragraphs separated by blank lines; line breaks inside a paragraph are kept. No Markdown, math or molecules are processed. Use `.md` instead if you need any of those.

## 13. Limits and failure behaviour

| Situation | What the reader does |
|---|---|
| Unknown syntax | shown as plain text |
| Unresolved `[[link]]` | dotted dimmed link; tap shows "That note does not exist in this library." |
| Missing image / audio / video / PDF / note / section | italic "... not found: name" line in place |
| Online image | "Online image not loaded" line |
| Embed deeper than 3 | "Embeds are nested too deeply." |
| Bad SMILES / molfile | red "Could not read ..." under the block; other molecules unaffected |
| Unknown molecule style | falls back to skeletal and prints the list of valid styles |
| Unsupported LaTeX command in math | that command is drawn in red; the rest renders |
| Mermaid fence | source shown, with a note that diagrams are not drawn |
| HTML in a note | escaped and shown as text |
| Anything over the molecule width limits | clamped to 120..700 px |

Safety: pages run with the network blocked. Scripts inside notes do not run. File paths in links and Reader URLs cannot leave the library.

## 14. Complete example note

````
---
title: Esterification
tags: [chemistry, organic]
chem-style: skeletal
---

# Esterification

An acid and an alcohol give an ester and water. See also [[Reaction rates#Catalysts]].

$$\ce{CH3COOH + C2H5OH <=> CH3COOC2H5 + H2O}$$

> [!note] Conditions
> Heat under reflux with a few drops of conc. $\ce{H2SO4}$ as catalyst. ==Remove water== to push the equilibrium right.

```smiles
title: Reactants and product
size: small
CC(=O)O acetic acid
CCO ethanol
CC(=O)OCC ethyl acetate
```

| Compound | M (g/mol) | bp (C) |
|:---------|----------:|-------:|
| Ethanol  | 46.07     | 78     |
| Ethyl acetate | 88.11 | 77   |

## Checklist

- [x] Write the equation
- [ ] Draw the mechanism[^1]

[^1]: Use `style: explicit` to show every hydrogen.
````

## 15. Pre-flight checklist for AI authors

1. File ends in `.md` (or `.tex` for LaTeX). UTF-8.
2. Front matter, if present, is first, starts and ends with `---`, and contains `key: value` lines.
3. Every `[[link]]` points to a note that exists in the same vault, or you accept a dimmed link.
4. Every math delimiter is closed; no `\usepackage`; `$` followed by a number is escaped as `\$`.
5. Chemical formulas use `$\ce{...}$`; structures use a `smiles` or `mol` fence.
6. Fenced blocks are closed with the same fence character.
7. Table dividers match the header's cell count.
8. No HTML tags, no remote images, no Mermaid diagrams you need drawn.
9. Molecule options are in the list in 8.2; style is one of 8.3.
10. Footnote references each have a `[^id]: text` definition.

Version: matches Reader build 10 (branch chem-on-math). Update this file whenever a renderer changes.
