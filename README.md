# Metadata Remover

A native macOS app (SwiftUI) that strips identifying metadata from videos and images and saves clean copies under random file names.

## Features
- **Videos:** remove all metadata (GPS, device make/model, dates, encoder tags, chapters, timecode/data tracks, C2PA/AI tags) losslessly with ffmpeg, or re-encode for the most thorough clean. Merge multiple clips into one (lossless join when formats match, otherwise automatic re-encode).
- **Images:** JPEG, HEIC/HEIF, PNG, TIFF, WebP, GIF, AVIF, RAW/DNG. Removes EXIF, GPS, IPTC, XMP, maker notes, thumbnails, Live Photo IDs, depth maps, C2PA and AI prompt data. Crop/rotate/flip editor with aspect presets. Preserves 16-bit/10-bit depth, standard colour spaces and HDR (gain maps, PQ/HLG), with an option to flatten to SDR.
- Random 12-character output names, extended attributes cleared, file dates reset. Originals are never modified.

## Requirements
- macOS 14 or later
- Xcode command-line tools (Swift 6)
- [Homebrew](https://brew.sh) ffmpeg: `brew install ffmpeg`

## Build and install
```sh
./build.sh              # build, sign (ad-hoc) and install to /Applications
./build.sh --no-install # build only, into ./build
```

## Tests
```sh
swift test --scratch-path /tmp/mr-tests
```

## Note on ffmpeg
The app runs Homebrew's ffmpeg as a separate process and does not bundle it.
