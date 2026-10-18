# ScreenCLI

Local Screen Translation & Search CLI Tool for macOS.

Capture the full screen and translate it on-device, or select a region and search the extracted text on Google. Uses Apple's Vision framework for OCR and Translation framework for private, on-device translation.

## Requirements

- **macOS 26 (Tahoe) or later** (required for `TranslationSession(installedSource:target:)`)
- Apple Silicon preferred
- Screen Recording permission (System Settings > Privacy & Security > Screen Recording)
- Translation language packs installed for offline use (System Settings > General > Language & Region > Translation Languages)

No paid Apple Developer account required for local builds and personal use.

## Install / Build

```bash
git clone https://github.com/jiahualihuanahuan/screencli.git
cd screencli
swift build -c release
```

The binary will be at `.build/release/screencli`. Copy it to your PATH (e.g. `/usr/local/bin`) or run via `swift run`.

## Usage

### Full-screen translation (always full screen)

```bash
screencli translate --to zh
screencli translate --to ja --copy
screencli translate --to fr --json
```

### Select region and search on Google

```bash
screencli search
screencli search --copy          # OCR and copy only
screencli search --no-open       # OCR and print, no browser
```

## Features

- Full-screen OCR + on-device translation
- Interactive region selection (`screencapture -i`) + OCR + Google search in default browser
- Clipboard support
- JSON output
- Clear error messages for missing permissions or language packs

## Development

Built with Swift Package Manager and ArgumentParser.

```bash
swift run screencli translate --to en
```

## Notes

- Translation defaults to English source detection in this initial version; improve with NaturalLanguage later.
- Multi-monitor support is basic (captures primary/full available).
- Grant Screen Recording permission on first run.
- The direct `TranslationSession` initializer used here requires macOS 26+. On older systems the SwiftUI `.translationTask` path is required.

See the product requirements in the conversation history or expand this README as the project evolves.
