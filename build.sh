#!/bin/bash
# Builds build/Video Inspector.app without Xcode; exits non-zero on any failure
# Usage: ./build.sh              arm64 (Apple Silicon) only
#        ./build.sh --universal  arm64 + x86_64 (Intel)
# VERSION env sets the app version (default 1.0), e.g. VERSION=1.2.0 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Video Inspector.app"
ARCHS=(arm64)
VERSION="${VERSION:-1.0}"

fail() {
	echo "error: $*" >&2
	exit 1
}

case "${1:-}" in
	"") ;;
	--universal) ARCHS=(arm64 x86_64) ;;
	*) fail "unknown option: $1 (usage: ./build.sh [--universal])" ;;
esac

command -v swiftc >/dev/null || fail "swiftc not found (install Xcode Command Line Tools: xcode-select --install)"
[ -f Resources/AppIcon.icns ] || fail "Resources/AppIcon.icns missing (run Tools/make_icon.sh)"
compgen -G "src/*.swift" >/dev/null || fail "no sources in src/"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# One slice per architecture, compiled in parallel, joined with lipo
SLICES=()
PIDS=()
for ARCH in "${ARCHS[@]}"; do
	swiftc -O -parse-as-library -target "$ARCH-apple-macos14" src/*.swift -o "build/VideoInspector-$ARCH" &
	PIDS+=($!)
	SLICES+=("build/VideoInspector-$ARCH")
done
for i in "${!PIDS[@]}"; do
	wait "${PIDS[$i]}" || fail "compilation failed (${ARCHS[$i]})"
done
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/VideoInspector" || fail "lipo failed"
rm -f "${SLICES[@]}"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Video Inspector</string>
<key>CFBundleIdentifier</key><string>aik099.video-inspector</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>VideoInspector</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSItemContentTypes</key><array><string>public.movie</string></array>
</dict></array>
</dict></plist>
PLIST
plutil -lint -s "$APP/Contents/Info.plist" || fail "Info.plist is invalid"

codesign --force -s - "$APP" || fail "codesign failed"
codesign --verify "$APP" || fail "signature verification failed"

echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/VideoInspector"))"
