# Mira

Mira is a quiet Markdown editor for macOS, inspired by Typora's focused writing experience.

It is built with SwiftUI and a small AppKit text-editor bridge, keeping native macOS editing behavior while rendering a live Markdown preview.

![welcome](https://github.com/galen-coder/Mira/blob/main/assets/%E6%88%AA%E5%B1%8F2026-05-31%2003.03.07.png)

## Features

- Starts with an untitled empty Markdown document
- Opens the first document window at the largest visible desktop size by default
- Closes the untouched temporary document when opening an existing file
- Source, split, and preview modes
- Synchronized scrolling between editor and preview in split mode
- Markdown outline sidebar
- Focus mode for distraction-light writing
- Runtime language setting for English, Simplified Chinese, or system language
- Settings for pasted/local image insertion behavior
- Native `NSTextView` editing with undo and find support
- Toolbar and menu commands for headings, emphasis, links, lists, tables, and code blocks
- Automatic Markdown code fence completion when typing triple backticks
- Preview rendering for headings, paragraphs, quotes, lists, task lists, tables, code blocks, HTML blocks, local images, and remote images
- Remote image caching to avoid reloading images on every edit
- Clipboard image paste support
- Word, character, heading, and reading-time stats

## Image Handling

Mira supports Markdown images from several sources:

```markdown
![local absolute](/Users/name/Pictures/image.png)
![local relative](assets/image.png)
![remote](https://example.com/image.png)
```

Relative image paths are resolved from the current Markdown file's directory. Save the document first if you want relative image previews to work.

When pasting an image into the editor:

- Images copied from the system clipboard are saved as PNG files.
- Image files copied from Finder are copied into `assets/` using their original bytes and extension.
- Pasted image files are saved beside the current Markdown file in an `assets/` folder.
- If `assets/` does not exist, Mira asks before creating it.
- The image insertion behavior can be changed in Settings.

## Requirements

- macOS 14 or later
- Xcode 15 or later
- Swift 5.9 or later

## Build And Run

Open `Package.swift` in Xcode, or build from Terminal:

```bash
swift build
```

To build and launch a local app bundle:

```bash
./script/build_and_run.sh
```

## Package

To create a movable release app and distributable archive:

```bash
./script/package_app.sh
```

The script builds `Mira.app`, signs it ad-hoc by default, validates the bundle with `codesign`, and tries to create a DMG. If macOS disk image services are unavailable, it falls back to a zip archive.

For a Developer ID signed build, pass a signing identity:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_app.sh
```

Public distribution outside your own Mac generally requires Developer ID signing and notarization.

## Project Layout

```text
Sources/Mira/App        App entry point and commands
Sources/Mira/Models     Document, block, command, and sync models
Sources/Mira/Support    Markdown parsing and asset helpers
Sources/Mira/Views      Editor, preview, toolbar, outline, and status UI
script                  Local run and packaging scripts
```

## License

Mira is released under the MIT License.
