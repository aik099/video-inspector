# Contributing

Bug reports and pull requests are welcome. For bugs, the issue form asks for the macOS and ffprobe versions and the ffprobe output of the file — that's usually all that's needed to reproduce it.

## Setup

- macOS 14 or later with the Xcode Command Line Tools (`xcode-select --install`); Xcode itself isn't used
- `ffprobe` and `ffmpeg` (see [README](README.md#requirements))

## Build and test

```
./build.sh               # build/Video Inspector.app (Apple Silicon)
./build.sh --universal   # + Intel
tests/test.sh            # snapshot tests
```

The tests compare what the app would show for the videos in `tests/fixtures/` with `tests/expected/`. If you change the output on purpose, run `tests/test.sh --update` and include the reviewed diff of `tests/expected/` in your pull request. New fixtures: add them to `tests/fixtures/make.sh`.

## Code

- SwiftUI without macros (no `@State`, `@Observable`, `#Preview`): the build only needs the Command Line Tools, which lack the macro plugin. Use `ObservableObject` with `@StateObject`/`@ObservedObject`.
- Tabs for indentation in Swift and shell scripts (see `.editorconfig`).
- Shell scripts: `set -euo pipefail`, errors as `error: …` on stderr with exit code 1.

Pull requests need the CI build to pass.
