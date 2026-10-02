#!/bin/bash
# Regenerates the README demo video: every tab, mixed codecs, two video streams so the Video tab scrolls.
# Recording the README media: see docs/README.md.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FF=(ffmpeg -v error -y)

# Cover art: portrait poster (becomes the thumbnail) + wide banner
"${FF[@]}" -f lavfi -i "gradients=s=500x750:c0=0x1d3557:c1=0xe63946:x0=0:y0=0:x1=500:y1=750:d=1" -frames:v 1 "$TMP/poster.jpg"
"${FF[@]}" -f lavfi -i "gradients=s=600x263:c0=0xf4a261:c1=0x2a9d8f:d=1" -frames:v 1 "$TMP/banner.jpg"
printf '1\n00:00:01,000 --> 00:00:04,000\nForced subtitle demo\n' > "$TMP/eng.srt"
printf '1\n00:00:01,000 --> 00:00:04,000\nПривет\n' > "$TMP/rus.srt"

# 2 video: H.264 2.39 main + MPEG-4 Part 2 (DivX-style) 16:9 alternate angle
# 3 audio: AC-3 5.1 (rus, default), AAC stereo (eng), AC-3 2.0 commentary (eng)
# 2 subtitles (eng forced, rus optional), 2 cover-art attachments
"${FF[@]}" \
	-f lavfi -i "testsrc2=size=1280x536:rate=24000/1001:duration=10" \
	-f lavfi -i "smptehdbars=size=640x360:rate=25:duration=10" \
	-f lavfi -i "sine=frequency=440:duration=10" \
	-f lavfi -i "sine=frequency=550:duration=10" \
	-f lavfi -i "sine=frequency=660:duration=10" \
	-i "$TMP/eng.srt" -i "$TMP/rus.srt" \
	-map 0 -map 1 -map 2 -map 3 -map 4 -map 5 -map 6 \
	-c:v:0 libx264 -crf 32 -preset fast -pix_fmt yuv420p \
	-c:v:1 mpeg4 -q:v 8 \
	-c:a:0 ac3 -b:a:0 448k -ac:a:0 6 -channel_layout:a:0 5.1 \
	-c:a:1 aac -b:a:1 128k -ac:a:1 2 \
	-c:a:2 ac3 -b:a:2 192k -ac:a:2 2 \
	-c:s srt \
	-metadata title="Demo Video" \
	-metadata:s:v:0 title="Main" -metadata:s:v:1 title="Alternate Angle" -metadata:s:v:1 language=eng \
	-metadata:s:a:0 language=rus -metadata:s:a:0 title="Dubbing" -disposition:a:0 default \
	-metadata:s:a:1 language=eng -metadata:s:a:1 title="Original" -disposition:a:1 0 \
	-metadata:s:a:2 language=eng -metadata:s:a:2 title="Commentary" -disposition:a:2 0 \
	-metadata:s:s:0 language=eng -metadata:s:s:0 title="Forced" -disposition:s:0 forced \
	-metadata:s:s:1 language=rus -disposition:s:1 0 \
	-attach "$TMP/poster.jpg" -metadata:s:t:0 mimetype=image/jpeg -metadata:s:t:0 filename=cover.jpg \
	-attach "$TMP/banner.jpg" -metadata:s:t:1 mimetype=image/jpeg -metadata:s:t:1 filename=small_cover.jpg \
	demo.mkv

ls -la demo.mkv
