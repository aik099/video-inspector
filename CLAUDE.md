# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Video Inspector — small macOS (14+) SwiftUI app: drop a video file, see its `ffprobe` info (per-stream tabs) and a thumbnail. Modeled on the Inspector pane of iSedora Media Server 2.2.2. Built without Xcode, no tests, no package manager. BSD-3-Clause.

## Commands

- Build: `./build.sh` (arm64) or `./build.sh --universal` (arm64 + x86_64, compiled in parallel, joined with `lipo`) → `build/Video Inspector.app`. `VERSION=1.2.0 ./build.sh` sets `CFBundleShortVersionString` (default `1.0`). Any failure prints `error: …` to stderr and exits 1. `Info.plist` is written inline by `build.sh` — edit metadata there.
- Run: `open "build/Video Inspector.app"` or `open -a "build/Video Inspector.app" <files>`.
- Relaunch for testing: quit, then wait for the process to exit before opening files — opening during shutdown hands the files to the dying instance and no window appears:
  `osascript -e 'quit app "Video Inspector"'; while pgrep -f "Video Inspector.app" >/dev/null; do sleep 0.2; done`
- Debug log: `defaults write aik099.video-inspector DebugLogging -bool YES` (read at launch), then `tail -f ~/Library/Logs/Video\ Inspector.log`. Window creation (placement, tab count) and file routing are logged via `Log.debug`.
- Tests: `./test.sh` compiles `tests/main.swift` with the non-UI sources (`Probe`, `Format`, `Shell`, `Log`, `ReportLayout`) and compares a text snapshot per fixture (tabs, cards, rows, thumbnail plan/size, cover previews) with `tests/expected/<fixture>.txt`, plus unit checks; exit 1 on mismatch. Needs ffprobe + ffmpeg. After an intended output change: `./test.sh --update`, review `git diff tests/expected`. Fixtures in `tests/fixtures/` are committed (regenerated output varies by ffmpeg version); `tests/fixtures/make.sh` documents/rebuilds them.
- Icon: `Tools/make_icon.sh` renders `Resources/icon.png` (`Tools/make_icon.swift`, pure CoreGraphics) and packs `Resources/AppIcon.icns`.
- CI: `.github/workflows/build.yml` runs `./build.sh --universal` and `./test.sh` (ffmpeg via Homebrew) on `macos-latest` per push/PR and uploads the zipped app as an artifact. `.github/workflows/release.yml` on a published release builds with `VERSION=<tag without v>` and attaches `Video-Inspector-<tag>.zip` (`gh release upload`). Built apps are never committed (`build/` is gitignored); zip with `ditto -c -k --keepParent`, not `zip`.

## Constraints

- Only Command Line Tools are assumed locally — the SwiftUI macro plugin is missing, so no `@State`/`@Observable`/`#Preview`. Use `ObservableObject` + `@StateObject`/`@ObservedObject`. CI has full Xcode, so it won't catch macro use.
- `Text` renders Markdown only for literals; runtime strings need `AttributedString(markdown:)`.
- Controls are `.focusable(false)` — no initial focus rings.
- Runtime dependency: `ffprobe` (required) and `ffmpeg` (thumbnails/cover previews only), looked up in `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`, `/usr/bin` (`Shell.searchPaths`; GUI apps don't inherit shell `PATH`). Not bundled on purpose (size). User-facing text stays install-method neutral; download links in `Shell.downloadLinks`.

## Architecture (`src/`)

- `App.swift` — no window scene: an empty `Settings` scene only carries the menu commands (New Window ⌘N, New Tab ⌘T, Open… ⌘O; Settings item removed). `AppDelegate` routes Dock/"Open With" files to `Windows.open`, makes the launch window, handles the tab bar "+" (`newWindowForTab`) and Dock reopen, quits after the last window.
- `Windows.swift` — windows are AppKit `NSWindow`s hosting `ContentView` via `NSHostingController` (`sizingOptions = [.minSize]`: SwiftUI sets only the minimum size). A tab is attached with `addTabbedWindow` *before* it's shown — the reason for not using SwiftUI `WindowGroup`, which shows windows itself so tabs could only be merged afterwards (visible cascade/flash). Placement: first window restored via frame autosave name, tabs share the host frame, ⌘N cascades 24 pt from the front window. Multi-file opens/drops: first file into the front (or target) window, the rest one tab each. Titles: app name when alone, file name / "No Video File" when tabbed, refreshed on key-window change and close.
- `Inspector.swift` — per-window state; `load` → background `Probe.inspect` + `Probe.thumbnail` + `Probe.coverImage` per cover stream. Guards: ffprobe present, `URL.isVideoFile` (extension conforms to `UTType.movie`); rejections beep. `tabBarWidth` feeds the window's min width (via the hosting controller's min size).
- `Probe.swift` — ffprobe JSON → flat `[Row]` (`Row.Kind`: file name / section video·audio·text·cover·other / labeled field; section rows carry the stream index). `attached_pic` streams = cover art. Thumbnail follows iSedora: with several video streams the first mjpeg/png wins (no seek), else frame at min(10 %, 120 s); `scale=-2:320,crop='min(iw,320)':320`.
- `ReportLayout.swift` — rows → tabs/cards (`Tab`, `RowGroup`, labels like "Audio (2)"); used by `ReportView` and the tests.
- `Views.swift` — start screen (`ContentUnavailableView` + `TVGuideView`; replaced by an error when ffprobe is missing), report: segmented tabs (only kinds present, counts like "Audio (2)") over `ScrollView` + `GroupBox` cards with a two-column `Grid`. `Form(.grouped)` was dropped: its inner inset scrolls with content. `FfmpegMissingView` sits in place of the thumbnail; covers show "No preview".
- `Format.swift` — duration/bitrate/size/ratio; `tvFit` = bars on a 1920×1080 screen (±2 % of 16:9 counts as full screen).
- `Shell.swift` — tool lookup and `run` (returns empty `Data` on any failure). `Log.swift` — opt-in file log.

## Docs

- `README.md` — user-facing; GitHub-docs shortcut style (`Command`+`O`), build badge.
- `handoffs/` — local session handoff notes (`YYYYMMDD_NN_slug.md`), gitignored.
