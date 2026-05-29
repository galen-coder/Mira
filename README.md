# Mira

Mira is a quiet Markdown editor for macOS, inspired by Typora's focused writing experience.

It is built with SwiftUI and a small AppKit text-editor bridge so it can keep native macOS editing behavior while rendering a live Markdown preview.

## Features

- Source, split, and preview modes
- Markdown outline sidebar
- Focus mode for distraction-light writing
- Native `NSTextView` editing with undo and find support
- Toolbar and menu commands for common Markdown formatting
- Preview rendering for headings, paragraphs, quotes, lists, task lists, tables, code blocks, and local images
- Word, character, heading, and reading-time stats

## Requirements

- macOS 14 or later
- Xcode 15 or later
- Swift 5.9 or later

## Build

Open `Package.swift` in Xcode, or build from Terminal:

```bash
swift build
```

To build and launch the app bundle locally:

```bash
./script/build_and_run.sh
```

## License

Mira is released under the MIT License.
