#!/bin/bash
# Regenerates the committed test fixtures. Run only when adding/changing fixtures,
# then refresh snapshots with ./test.sh --update and review the diff.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Tiny, short, single-threaded: small files, stable output for a given ffmpeg
FF=(ffmpeg -v error -y -threads 1)
VIDEO=(-c:v libx264 -preset veryslow -crf 40 -pix_fmt yuv420p -g 25)

# Cover art images: portrait poster + wide banner
"${FF[@]}" -f lavfi -i "color=c=steelblue:s=100x150" -frames:v 1 "$TMP/cover.jpg"
"${FF[@]}" -f lavfi -i "color=c=darkorange:s=120x52" -frames:v 1 "$TMP/small_cover.jpg"

# Subtitles
printf '1\n00:00:00,000 --> 00:00:00,900\nПривет\n' > "$TMP/rus.srt"
printf '1\n00:00:00,000 --> 00:00:00,900\nHello\n' > "$TMP/eng.srt"

# multi-stream.mkv: 2.39 cinema video, 2 audio (rus default, eng), 2 subtitles (rus forced, eng),
# 2 cover-art attachments (poster first → becomes the thumbnail)
"${FF[@]}" \
	-f lavfi -i "testsrc2=size=320x134:rate=25:duration=1" \
	-f lavfi -i "sine=frequency=440:duration=1" \
	-f lavfi -i "sine=frequency=660:duration=1" \
	-i "$TMP/rus.srt" -i "$TMP/eng.srt" \
	-map 0 -map 1 -map 2 -map 3 -map 4 \
	"${VIDEO[@]}" -c:a aac -b:a 32k -ac 1 -c:s srt \
	-metadata title="Multi Stream Test" \
	-metadata:s:a:0 language=rus -metadata:s:a:0 title="Dubbing" -disposition:a:0 default \
	-metadata:s:a:1 language=eng -metadata:s:a:1 title="Original" -disposition:a:1 0 \
	-metadata:s:s:0 language=rus -metadata:s:s:0 title="Forced" -disposition:s:0 forced \
	-metadata:s:s:1 language=eng -disposition:s:1 0 \
	-attach "$TMP/cover.jpg" -metadata:s:t:0 mimetype=image/jpeg -metadata:s:t:0 filename=cover.jpg \
	-attach "$TMP/small_cover.jpg" -metadata:s:t:1 mimetype=image/jpeg -metadata:s:t:1 filename=small_cover.jpg \
	multi-stream.mkv

# four-three.avi: 4:3 → bars left/right; MPEG-4 Part 2 + AC-3 like old DivX rips; no tags
"${FF[@]}" \
	-f lavfi -i "testsrc2=size=320x240:rate=25:duration=1" \
	-f lavfi -i "sine=frequency=440:duration=1" \
	-c:v mpeg4 -q:v 31 -c:a ac3 -b:a 64k -ac 1 -fflags +bitexact \
	four-three.avi

# anamorphic.mkv: 720x576 stored, SAR 16:15 → displays as 4:3 (DVD-style non-square pixels)
"${FF[@]}" \
	-f lavfi -i "testsrc2=size=720x576:rate=25:duration=1" \
	-vf setsar=16/15 "${VIDEO[@]}" -an \
	anamorphic.mkv

# tags.mkv: 16:9 video (fills the screen) with file-level tags
"${FF[@]}" \
	-f lavfi -i "testsrc2=size=320x180:rate=25:duration=1" \
	"${VIDEO[@]}" -an \
	-metadata title="Tag Test" -metadata artist="Test Artist" -metadata composer="Test Composer" \
	-metadata album="Test Album" -metadata track="3/12" -metadata genre="Documentary" -metadata date="2026" \
	tags.mkv

# audio-only.mkv: video extension, no video stream → no thumbnail
"${FF[@]}" \
	-f lavfi -i "sine=frequency=440:duration=1" \
	-c:a aac -b:a 32k -ac 1 \
	audio-only.mkv

ls -la ./*.mkv ./*.avi
