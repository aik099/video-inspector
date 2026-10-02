#!/bin/bash
# Builds and runs the tests (non-UI code against committed fixtures); exits non-zero on failure
# Usage: tests/test.sh            compare with tests/expected
#        tests/test.sh --update   rewrite tests/expected (review the diff before committing)
set -euo pipefail
# Run from the repo root: paths below are relative to it
cd "$(dirname "$0")/.."

fail() {
	echo "error: $*" >&2
	exit 1
}

for tool in swiftc ffprobe ffmpeg; do
	command -v "$tool" >/dev/null || fail "$tool not found"
done

mkdir -p build
# UI files (App, Views, Windows, Inspector) stay out: tests cover the model only
swiftc -O tests/main.swift src/{Probe,Format,Shell,Log,ReportLayout}.swift -o build/tests \
	|| fail "test compilation failed"
echo "ffprobe: $(ffprobe -version | head -1)"
build/tests "$PWD" "$@"
