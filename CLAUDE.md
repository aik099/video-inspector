# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Video Inspector — small macOS (14+) SwiftUI app: drop a video file, see its `ffprobe` info (per-stream tabs) and a thumbnail. Modeled on the Inspector pane of iSedora Media Server 2.2.2. Built without Xcode (Command Line Tools only), no package manager; snapshot tests for the non-UI code. Public repo `aik099/video-inspector`, BSD-3-Clause.

## Commands

- Build: `./build.sh` (arm64) or `./build.sh --universal` (arm64 + x86_64, compiled in parallel, joined with `lipo`) → `build/Video Inspector.app`. `VERSION=1.2.0 ./build.sh` sets `CFBundleShortVersionString` (default `1.0`). Any failure prints `error: …` to stderr and exits 1. Also forgets remembered window frames/state, so each build starts at the default window size. `Info.plist` is written inline by `build.sh` — edit metadata there.
- Run: `open "build/Video Inspector.app"` or `open -a "build/Video Inspector.app" <files>`.
- Relaunch for testing: quit, then wait for the process to exit before opening files — opening during shutdown hands the files to the dying instance and no window appears:
  `osascript -e 'quit app "Video Inspector"'; while pgrep -f "Video Inspector.app" >/dev/null; do sleep 0.2; done`
- Debug log: `defaults write aik099.video-inspector DebugLogging -bool YES` (read at launch), then `tail -f ~/Library/Logs/Video\ Inspector.log`. Window creation (placement, tab count) and file routing are logged via `Log.debug`.
- Tests: `tests/test.sh` compiles `tests/main.swift` with the non-UI sources (`Probe`, `Format`, `Shell`, `Log`, `ReportLayout`) and compares a text snapshot per fixture (tabs, cards, rows, thumbnail plan/size, cover previews) with `tests/expected/<fixture>.txt`, plus unit checks; exit 1 on mismatch. Needs ffprobe + ffmpeg. After an intended output change: `tests/test.sh --update`, review `git diff tests/expected`. Fixtures in `tests/fixtures/` are committed (regenerated output varies by ffmpeg version); `tests/fixtures/make.sh` documents/rebuilds them.
- Icon: `Tools/make_icon.sh` renders `Resources/icon.png` (`Tools/make_icon.swift`, pure CoreGraphics) and packs `Resources/AppIcon.icns`.
- CI: `.github/workflows/build.yml` runs `./build.sh --universal` and `tests/test.sh` (ffmpeg via Homebrew) on `macos-latest` per push/PR and uploads `Video-Inspector.zip` as an artifact (`upload-artifact` with `archive: false`, no zip-in-zip). Keep actions on current major versions. `.github/workflows/release.yml` on a published release builds with `VERSION=<tag without v>` and attaches `Video-Inspector-<tag>.zip` (`gh release upload`). Built apps are never committed (`build/` is gitignored); zip with `ditto -c -k --keepParent`, not `zip`.

## Constraints

- Only Command Line Tools are assumed locally — the SwiftUI macro plugin is missing, so no `@State`/`@Observable`/`#Preview`. Use `ObservableObject` + `@StateObject`/`@ObservedObject`. CI has full Xcode, so it won't catch macro use.
- `Text` renders Markdown only for literals; runtime strings need `AttributedString(markdown:)`.
- Controls are `.focusable(false)` — no initial focus rings.
- Runtime dependency: `ffprobe` (required) and `ffmpeg` (thumbnails/cover previews only), looked up in `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`, `/usr/bin` (`Shell.searchPaths`; GUI apps don't inherit shell `PATH`). Not bundled on purpose (size). User-facing text stays install-method neutral; download links in `Shell.downloadLinks`.

## Architecture (`src/`)

- `App.swift` — no window scene: an empty `Settings` scene only carries the menu commands (New Window ⌘N, New Tab ⌘T, Open… ⌘O; Settings item removed). `AppDelegate` routes Dock/"Open With" files to `Windows.open`, makes the launch window, handles the tab bar "+" (`newWindowForTab`) and Dock reopen, quits after the last window.
- `Windows.swift` — windows are AppKit `NSWindow`s with an `NSHostingView` (`sizingOptions = []`) holding `ContentView`. Sizing: the hosting view resizes the window to the view's *ideal* size on first layout, so `ContentView` declares `idealSize` (= default window content). Minimum (enforced in `windowWillResize`, since AppKit resets `contentMinSize` for SwiftUI content): small height (360) like native apps — start screen and report scroll instead, so the tab bar can take its 36 pt from the content without the window growing; width = report tab picker + margins. The start screen is one `ScrollView` filling the window (`GeometryReader` min height); a squeezed `ContentUnavailableView` would otherwise scroll on its own and cut its icon. A tab is attached with `addTabbedWindow` *before* it's shown — the reason for not using SwiftUI `WindowGroup`, which shows windows itself so tabs could only be merged afterwards (visible cascade/flash). Placement: first window restored via frame autosave name, tabs share the host frame, ⌘N cascades 24 pt from the front window. Multi-file opens/drops: first file into the front (or target) window, the rest one tab each. Titles: app name when alone, file name / "No Video File" when tabbed, refreshed on key-window change and close.
- `Inspector.swift` — per-window state; `load` → background `Probe.inspect` + `Probe.thumbnail` + `Probe.coverImage` per cover stream. Guards: ffprobe present (else every open path beeps and the error screen stays), `URL.isVideoFile`; rejections beep. `tabBarWidth` feeds the window's min width (`Windows`).
- `Probe.swift` — `VideoTypes`: video = built-in extension list (a clean macOS has no movie type for mkv, vob, …; media players register them) or `UTType.movie`; also used by open panels, plus a MIME fallback for those extensions. ffprobe JSON → flat `[Row]` (`Row.Kind`: file name / section video·audio·text·cover·other / labeled field; section rows carry the stream index). `attached_pic` streams = cover art. Thumbnail follows iSedora: with several video streams the first mjpeg/png wins (no seek), else frame at min(10 %, 120 s); `scale=-2:320,crop='min(iw,320)':320`.
- `ReportLayout.swift` — rows → tabs/cards (`Tab`, `RowGroup`, labels like "Audio (2)"); used by `ReportView` and the tests.
- `Views.swift` — start screen (`ContentUnavailableView` + `TVGuideView`; replaced by an error when ffprobe is missing), report: segmented tabs (only kinds present, counts like "Audio (2)") over `ScrollView` + `GroupBox` cards with a two-column `Grid`. `Form(.grouped)` was dropped: its inner inset scrolls with content. `FfmpegMissingView` sits in place of the thumbnail; covers show "No preview".
- `Format.swift` — duration/bitrate/size/ratio; `tvFit` = bars on a 1920×1080 screen (±2 % of 16:9 counts as full screen).
- `Shell.swift` — tool lookup and `run` (returns empty `Data` on any failure). `Log.swift` — opt-in file log.

## Docs and media

- `README.md` — user-facing; GitHub-docs shortcut style (`Command`+`O`), build badge, `docs/demo.gif` and two screenshots.
- `docs/README.md` — how the README media are made (re-recording steps, why GIF over WebP/MP4).
- `docs/demo/make-video.sh` → `docs/demo/demo.mkv`: the file inspected in the recording (every tab, mixed codecs, two video streams so the Video tab scrolls).
- `docs/demo/make-gif.sh <recording.mp4> [seconds]` → `docs/demo.gif`: places a 540×688 window recording into `docs/demo/backdrop.png` (CleanShot gradient + shadow with a window-shaped hole, 1 px inset to hide the recording's gray window border), then palette GIF with `stats_mode=full`. Check with a few seconds first.
- `CHANGELOG.md` (Keep a Changelog): add entries under `[Unreleased]`; on release rename it to `[x.y.z] - date`. `release.yml` copies that section into the GitHub release notes when the release was published without a description.
- `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/` (bug form asks for macOS/ffprobe versions and the file's ffprobe JSON), `.editorconfig` (tabs for Swift/shell, 2 spaces for YAML).
- GitHub: topics set; ruleset on `main` requires a pull request with passing `build` check (admin bypasses, so direct pushes work), no force-push or deletion for others.
- `handoffs/` — local session handoff notes (`YYYYMMDD_NN_slug.md`), gitignored.

## Conventions

- Public repo: files get neutral names (`demo.mkv`, "Demo Video"), never release-style names; scan new files for personal paths before committing.
- Commit and push only after the change is approved; amend + force-push only when explicitly agreed.
- Shell scripts: `set -euo pipefail`, `error: …` on stderr + exit 1; macOS `/bin/bash` is 3.2 (empty arrays under `set -u` need `${A[@]+"${A[@]}"}`).
- Previews of animated images: wrap in a small HTML page and `open` it (default browser); opening a GIF directly lands in Preview.
