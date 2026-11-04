# vRain — Chinese Ancient Book-Style Vertical PDF E-book Generator

[![Version](https://img.shields.io/badge/version-v1.5-blue.svg)](https://github.com/shanleiguang/vRain)
[![Language](https://img.shields.io/badge/language-Perl%205-brightgreen.svg)](https://www.perl.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)]()

vRain is a Perl-based toolchain that converts Chinese text into elegantly typeset vertical-layout PDF e-books in the style of traditional woodblock-printed editions. It supports multiple classic formats (movable type, bamboo slips, game records, etc.), multi-font fallback for rare characters, and automatic font metric adjustment for visual consistency.

[简体中文文档](readme.MD)

## Features

- **Vertical (Top-to-Bottom) Typesetting**: Traditional Chinese reading direction — from top to bottom, right to left
- **Multiple Ancient Book Styles**: Movable type, bamboo slips, game records, and more
- **Multi-Font Fallback**: Up to 5 fonts with priority-based fallback to ensure rare/uncommon characters display correctly
- **Font Metric Adjustment**: Automatically measures glyph heights across fonts and scales fallback characters for consistent visual sizing
- **Fallback Bold Simulation**: Optionally applies stroke overlay to fallback-font characters in body text, simulating bold weight to match the primary font
- **Interlinear Commentary**: Double-row small-text commentary via `【】` markers
- **Rich Annotation System**: Wavy book-title lines, rounded-corner frames, circle frames, circle/dot/line emphasis markers, font scaling
- **Automatic Table of Contents**: Chapter titles automatically extracted as PDF outline bookmarks
- **PDF Compression**: Optional Ghostscript-based output compression

## Download and run

Windows, macOS, and Linux each have a compressed package. Extract it and start the launcher. A browser opens a page bound to this machine. Perl, fonts, and ImageMagick do not need to be installed separately.

Each package carries its own Perl: [relocatable-perl](https://github.com/skaji/relocatable-perl) 5.42 on Linux and macOS, and portable [Strawberry Perl](https://github.com/StrawberryPerl/Perl-Dist-Strawberry) on Windows. `web/server.pl` is a small HTTP server written with Perl core modules. It listens on `127.0.0.1:8787` (and the next 20 ports if that one is busy), collects the book, canvas, fonts, and `book.cfg` settings, then runs the existing `vrain.pl`. The typesetter is unchanged. `Font::FreeType` is linked against a static FreeType 2.13 at package time, so a system libfreetype is unnecessary. Canvas JPGs ship in the package; ImageMagick is needed only when regenerating a background with `canvas/*.pl`. PDF compression needs a system Ghostscript; without it the PDF is still written. The command-line flags are the same as before.

GitHub Actions builds and smoke-tests `books/sample` on `ubuntu-24.04`, `windows-latest`, `macos-15` (Apple silicon), and `macos-15-intel`. Artifacts are on the workflow run. A `v*` tag also attaches the four packages to a GitHub Release. On a fork, enable Actions in the repository settings. If GitHub holds the first run, approve it before it starts.

### Windows

Download `vRain-Web-*-windows-x64.zip`, extract it, and double-click `START.bat`. The binary is unsigned. If SmartScreen blocks it, choose “Run anyway”. From a terminal:

```bat
vrain.bat -b sample -f 1 -t 1 -z 1
```

### macOS

Apple silicon uses `darwin-arm64`. Intel uses `darwin-x64`.

```bash
tar -xzf vRain-Web-*-darwin-arm64.tar.gz
cd vRain-Web-darwin-arm64
xattr -dr com.apple.quarantine .
./start.sh
```

`start.command` does the same thing from Finder. The binary is unsigned, so Gatekeeper blocks a downloaded app until the quarantine flag is cleared or you right-click `start.command` and choose Open.

### Linux

```bash
tar -xzf vRain-Web-*-linux-x64.tar.gz
cd vRain-Web-linux-x64
./start.sh
```

The x64 package needs glibc 2.33 or newer (Ubuntu 22.04, Debian 12, and later). The exact requirement is in `runtime/GLIBC.txt` inside the package. Automated builds are x64 only; on an arm64 machine, `bash packaging/build.sh` produces a package there.

The page defaults to Simplified Chinese and can switch to Traditional Chinese or English. Pick or create a book, upload text, a font, a cover, or a JPEG canvas, then generate, watch the log, and preview or download the PDF. One typesetting job runs at a time. `books/sample` is a short example and `books/01` is the original 虞初新志 book; the page will not delete those two. `vrain_mr.pl` and `books_mr/` stay on the command line.

For development, `./start-web.sh` prefers a previously built `runtime/perl` and otherwise uses system Perl (system Perl needs `PDF::Builder` and `Font::FreeType` before it can typeset). To build a package yourself:

```bash
bash packaging/build.sh
bash packaging/smoke.sh dist/vRain-Web-*.tar.gz
```

## Requirements

- **Perl 5** (with core modules)
- **PDF::Builder** — PDF generation
- **Font::FreeType** — Font glyph detection and metrics
- **Image::Magick** — Background image generation (`canvas/*.pl` scripts)
- **Ghostscript** (`gs`) — PDF compression (`-c` option, macOS only)

### Installing Dependencies

```bash
# macOS (Homebrew)
brew install perl imagemagick ghostscript
cpan install PDF::Builder Font::FreeType

# Linux (Debian/Ubuntu)
sudo apt-get install perl imagemagick ghostscript
cpan install PDF::Builder Font::FreeType
```

## Quick Start

```bash
# Basic usage
perl vrain.pl -b <book-id> [-f <start-text-index>] [-t <end-text-index>] [-z <test-pages>] [-c] [-v]

# Example: generate full PDF for book ID 00, all texts
perl vrain.pl -b 00 -f 1 -t 80

# Test mode: output only 5 pages for parameter tuning (suffix _test)
perl vrain.pl -b 00 -f 1 -t 80 -z 5

# Compress output PDF with Ghostscript (macOS only)
perl vrain.pl -b 00 -f 1 -t 80 -c

# Verbose output showing font selection and scaling details
perl vrain.pl -b 00 -v
```

### Generating Background Images

```bash
# Run from the canvas/ directory using corresponding cfg config files
cd canvas && perl vintage.pl -c vintage
cd canvas && perl bamboo.pl -c bamboo
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-h` | Show help information |
| `-v` | Verbose mode — show font selection, scale factors, etc. |
| `-c` | Compress PDF with Ghostscript (macOS only) |
| `-z <pages>` | Test mode — output only N pages, filename suffixed with `_test` |
| `-b <book-id>` | Book ID, corresponding to `books/<ID>/` directory |
| `-f <index>` | Starting text index (ordinal in sorted file list, not filename number) |
| `-t <index>` | Ending text index |

## Project Structure

```
vRain/
├── vrain.pl                     ← Core PDF typesetting script
├── books/
│   └── <ID>/
│       ├── book.cfg             ← Book-level typesetting config (main entry point)
│       ├── text/                ← Source text files, numerically named (001.txt, 002.txt ...)
│       │   ├── 000.txt           ← Optional: preface/introduction
│       │   └── 999.txt           ← Optional: appendix/postscript
│       ├── cover.jpg             ← Optional: cover image (auto-generated if absent)
│       └── *.pdf                 ← Output PDF files stored here
├── canvas/
│   ├── *.cfg                    ← Canvas config (page size, margins, columns, fish-tail ornaments)
│   ├── *.jpg                    ← Generated background images
│   └── *.pl                     ← Background image generation scripts (Image::Magick)
├── fonts/                       ← TTF font files
└── db/
    └── num2zh_jid.txt           ← Arabic numeral → Chinese numeral mapping (chapters, page numbers)
```

## Two-Tier Configuration System

### Canvas-Level (`canvas/*.cfg`) — The "Paper"

| Parameter | Description |
|-----------|-------------|
| `canvas_width` / `canvas_height` | Page dimensions (px) |
| `margins_top` / `margins_bottom` / `margins_left` / `margins_right` | Page margins |
| `leaf_col` | Number of text columns |
| `leaf_center_width` | Center gutter width (spine) |
| `outline_width` / `outline_color` | Outer border width/color |
| `inline_width` / `inline_color` | Inner border width/color |
| `outline_hmargin` / `outline_vmargin` | Border horizontal/vertical margin |
| `if_multirows` | Enable multi-row (multi-section) mode |
| `multirows_num` | Number of rows/sections |
| `logo_text` | Studio name / Logo text |

### Book-Level (`books/<ID>/book.cfg`) — The "Type"

#### Font Setup (up to 5 fonts)

| Parameter | Description |
|-----------|-------------|
| `font1` ~ `font5` | Font filenames (stored in `fonts/` directory) |
| `font1_rotate` ~ `font5_rotate` | Per-font rotation angle adjustment |
| `text_fonts_array` | Body text font priority array (e.g., `134` = try font1, font3, font4 in order) |
| `text_font1_size` ~ `text_font5_size` | Per-font body text size |
| `text_font_color` | Body text color |
| `comment_fonts_array` | Commentary font priority array |
| `comment_font1_size` ~ `comment_font5_size` | Per-font commentary size |
| `comment_font_color` | Commentary color |
| `if_font_metric_adjust` | Enable font metric-based size adjustment (`1` = on) |
| `if_fallback_bold` | Enable simulated bold for fallback-font body text characters (`1` = on) |
| `fallback_bold_stroke_width` | Stroke width for bold simulation (pt), recommended 0.5 ~ 2.0 |

#### Cover & Header

| Parameter | Description |
|-----------|-------------|
| `cover_title_font_size` / `cover_title_y` | Cover title size/position |
| `cover_author_font_size` / `cover_author_y` | Cover author size/position |
| `cover_font_color` | Cover text color |
| `title_font_size` / `title_font_color` / `title_y` | Page header title size/color/position |
| `title_postfix` | Title suffix (`X` auto-replaced with chapter number) |
| `title_directory` | Generate PDF outline bookmarks |
| `pager_font_size` / `pager_font_color` / `pager_y` | Page number size/color/position |

## Text Markup System

Special symbols within source text control typesetting behavior:

| Symbol | Effect |
|--------|--------|
| `【text】` | Interlinear commentary (double-row small text) |
| `《》` | Book title → wavy line on the left side of characters |
| `〔〕` | Rounded-corner frame around characters |
| `〈〉` | Circle frame around characters |
| `（）` | Font size scaling |
| `｛｝` | Circle emphasis marker (right side of body text) |
| `＜＞` | Dot emphasis marker (right side of body text) |
| `［］` | Line emphasis marker (right side of body text) |
| `%` | Full-page break |
| `$` | Half-page break |
| `&` | Jump to last column of current page |
| `@` | Space character |
| `TNO` | Advance one character position |

## Core Typesetting Mechanism

- **Character Position Counter** (`$pcnt`): Tracks the current standard character position on each page. A page break is triggered when it reaches `page_chars_num` (`col_num × row_num`)
- **Precomputed Coordinates**: `@pos_l` (left side) and `@pos_r` (right side, for double-row commentary) arrays are precomputed before typesetting begins
- **Font Fallback**: `get_font()` iterates through the priority-sorted font list, using Font::FreeType to check glyph existence per character. Characters render as `□` when no font supports them
- **Font Metric Adjustment**: Reference character (「國」) glyph heights are measured and compared across all configured fonts. A per-font scale factor is computed and applied at render time, with all centering and spacing calculations automatically using the adjusted size
- **Commentary Interleaving**: Upon encountering `【`, commentary content is extracted and rendered in double-row format before resuming body text

## Recommended Fonts

For optimal results, consider these font combinations:

- **Primary**: CJK fonts with Bold/Heavy weight (e.g., FZJinLingHK Bold) for body text
- **Secondary**: Light/Regular variants from the same font family for commentary
- **Rare Character Fallback**: Fonts covering CJK Extension planes (e.g., FangSong Plane00/Plane02)
- **Ultra-Rare Characters**: Large character-set fonts (e.g., HanaMin, BabelStone Han)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.5 | 2025-05 | Font metric adjustment, fallback bold simulation |
| v1.4 | 2025-03 | Multi-row layout, font configuration improvements |
| v1.3 | 2025-01 | Wavy book-title lines, rounded frames, markup system |
| v1.2 | 2024-12 | Double-row commentary, punctuation processing enhancements |
| v1.1 | 2024-11 | Multi-font fallback system |
| v1.0 | 2024-10 | Initial release |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Author

- **GitHub**: [@shanleiguang](https://github.com/shanleiguang)
- **Xiaohongshu**: @兀雨書屋
- **Email**: shanleiguang@gmail.com

---

*vRain — Professional ancient Chinese book-style typesetting for the digital age.*
