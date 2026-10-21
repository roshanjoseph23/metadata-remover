# Changelog

All notable changes to Metadata Remover. Versions follow `CFBundleShortVersionString` (build number in brackets).

## 1.4.2 (8) — 2026-10-22

Security and robustness release. Output files are byte-identical to 1.4.1.

### Fixed
- **Merging clips whose file name contains a line break** no longer fails. Such clips now use the re-encoding join, which passes each file to ffmpeg separately instead of through a line-based list (this also rules out list-entry injection).
- **Malformed HDR gain maps:** a gain map that declares a row length shorter than its width is now rejected instead of being passed to Core Image, preventing a possible out-of-bounds read.

### Quality
- Security scans (trivy, mobsfscan, scancode) with every finding triaged: no vulnerabilities, secrets or real issues found beyond the two fixes above.
- The full video and image regression suites and the app ran cleanly under AddressSanitizer and ThreadSanitizer (no reports).
- New Swift Testing unit tests for crop maths, crop presets, colour-space matching, container sanitising and random file names (`swift test`). The app build is unaffected.

## 1.4.1 (7)

- Fixes from a second full SwiftUI code review: modern SwiftUI/Foundation APIs, accessibility labels, number formatting and smaller view/model clean-ups. No change to how files are cleaned.

## 1.4 (5–6)

- **High bit depth and HDR are preserved:** 16-bit PNG/TIFF, 10-bit HEIC/AVIF, 32-bit float TIFF, PQ and HLG images, and HDR gain maps (Apple and ISO 21496-1 / Ultra HDR) are kept, with the gain map cropped and rotated with the image.
- Wide-gamut colour is kept: Display P3, Adobe RGB, ProPhoto, Rec. 2020 and grey profiles are re-tagged with standard system profiles, so custom profile names (which can identify a device) are dropped without clipping colours.
- New **Keep HDR** option, which can be turned off to flatten HDR to SDR with proper tone-mapping.
- New app icon (build 6: refreshed artwork).

## 1.3 (4)

- **Images:** JPEG, HEIC/HEIF, PNG, TIFF, WebP, GIF (animated), AVIF and RAW/DNG. Removes EXIF, GPS, IPTC, XMP, maker notes, thumbnails, comments, Live Photo identifiers and depth maps.
- Strips **AI-generation and provenance data**: C2PA/Content Credentials manifests, IPTC "digital source type" tags and Stable Diffusion/ComfyUI prompt and workflow text.
- Crop, rotate and flip editor with aspect presets, plus batch crop to an aspect ratio.
- Output as original format or JPEG with adjustable quality.
- Renamed from "Video Metadata Remover" to **Metadata Remover**.

## 1.2 (3)

- Full SwiftUI code review: Swift 6 strict concurrency with no warnings, safer process handling and accessibility improvements.
- **Cancel** running jobs; ffmpeg processes stop cleanly and partial files are removed.
- Native Materials look, standard bordered buttons and a new app icon.

## 1.1 (2)

- **Merge** several clips into one video: a lossless join when the clips match, otherwise an automatic re-encode to a common size, frame rate and codec. The merged file is cleaned like any other.

## 1.0 (1)

- First release. Removes all metadata from videos (GPS/location, device make and model, dates, encoder and software tags, chapters, timecode and data tracks) with ffmpeg, losslessly by default or with an optional re-encode.
- Clean copies are saved under random 12-character names with extended attributes and file dates reset; originals are never modified.
