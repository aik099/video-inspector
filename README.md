# Video Inspector
[![Build](https://github.com/aik099/video-inspector/actions/workflows/build.yml/badge.svg)](https://github.com/aik099/video-inspector/actions/workflows/build.yml)

Small macOS app that shows what's inside a video file: container, video, audio, subtitle and cover-art streams, with codecs, resolutions, aspect ratios, languages and tags, plus a thumbnail. Inspired by the Inspector mode of the iSedora Media Server 2.2.2.

Drop a video on the window or the Dock icon, or press `Command`+`O`.

## Features

- Tabs per stream kind (General, Video, Audio, Subtitles, Cover Art), shown only when the file has them
- Thumbnail and cover-art previews
- "On 16:9 TV" row: whether the picture fills a 16:9 screen or gets black bars, and how wide
- Several files at once: each opens in its own window tab (`Command`+`T` for an empty one)
- Native universal app (Apple Silicon and Intel), under 2 MB

## Download

Each GitHub release has the universal app attached (`Video-Inspector-<version>.zip`). The app is ad-hoc signed, not notarized, so macOS blocks the first launch: open System Settings → Privacy & Security and click "Open Anyway" (or run `xattr -d com.apple.quarantine "Video Inspector.app"`).

## Requirements

- macOS 14 or later
- `ffmpeg` - used for thumbnails and cover-art previews (optional)
- `ffprobe` - used for everything else (mandatory)
- `ffprobe` and `ffmpeg` are searched in `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`, `/usr/bin`
- Static builds can be obtained at [osxexperts.net](https://www.osxexperts.net) (Apple Silicon & Intel), [evermeet.cx/ffmpeg](https://evermeet.cx/ffmpeg/) (Intel)
- Homebrew (`brew install ffmpeg`) and MacPorts also work

## Build

Only the Xcode Command Line Tools are needed (`xcode-select --install`):

```
./build.sh               # Apple Silicon only
./build.sh --universal   # Apple Silicon + Intel
open "build/Video Inspector.app"
```

The script exits non-zero if anything fails. `VERSION=1.2.0 ./build.sh` sets the app version (default `1.0`). GitHub Actions builds on every push and attaches the app to each published release.

## Tests

```
tests/test.sh
```

Checks what the app would show for small committed test videos in `tests/fixtures/` (tabs, rows, values, thumbnail choice) against `tests/expected/`. Needs `ffprobe` and `ffmpeg`. After an intended change in the output, run `tests/test.sh --update` and review the diff.

## Debug log

```
defaults write aik099.video-inspector DebugLogging -bool YES
tail -f ~/Library/Logs/Video\ Inspector.log
```

## License

BSD 3-Clause, see [LICENSE](LICENSE).
