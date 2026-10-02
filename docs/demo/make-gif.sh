#!/bin/bash
# Turns a window recording into docs/demo.gif, framed with the CleanShot backdrop.
# Usage: docs/demo/make-gif.sh <recording.mp4> [seconds]
#   seconds: encode only the first N seconds, to check the result quickly
set -euo pipefail

fail() {
	echo "error: $*" >&2
	exit 1
}

[ $# -ge 1 ] || fail "usage: docs/demo/make-gif.sh <recording.mp4> [seconds]"
[ -f "$1" ] || fail "recording not found: $1"
# Absolute before changing directory, so relative paths work
RECORDING=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(dirname "$0")"
command -v ffmpeg >/dev/null || fail "ffmpeg not found"

# backdrop.png: gradient + shadow with a window-shaped hole for a 540×688 window at 10,10
SIZE=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$RECORDING")
[ "$SIZE" = "540x688" ] || fail "recording is $SIZE, backdrop.png fits 540x688"

LIMIT=()
OUTPUT=../demo.gif
if [ $# -ge 2 ]; then
	LIMIT=(-t "$2")
	OUTPUT=$(mktemp -d)/demo-test.gif
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. Recording into the backdrop's hole. Lossless intermediate keeps the backdrop static (small GIF);
#    bt709: the recording's color convention (otherwise colors shift)
# ${LIMIT[@]+...}: empty array under set -u in macOS bash 3.2
ffmpeg -v error -y ${LIMIT[@]+"${LIMIT[@]}"} -i "$RECORDING" -i backdrop.png -filter_complex \
	"[0:v]scale=in_color_matrix=bt709:in_range=tv:out_range=pc,format=rgb24,pad=560:708:10:10[v];[v][1:v]overlay=format=rgb,format=rgb24" \
	-c:v libx264rgb -qp 0 -preset ultrafast "$TMP/framed.mkv"

# 2. GIF: palette from all pixels (stats_mode=full) so the static gradient isn't dithered
ffmpeg -v error -y -i "$TMP/framed.mkv" -vf \
	"fps=10,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
	"$OUTPUT"

# Real path for the message (relative to the script folder otherwise)
echo "Wrote $(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT") ($(du -h "$OUTPUT" | cut -f1))"
