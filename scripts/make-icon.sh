#!/bin/bash
# Renders the app icon from the clock itself, then packs it into an .icns.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
mkdir -p build
./.build/release/ClockPreview --icon build/icon-1024.png

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512; do
  sips -z $size $size build/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double build/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
cp build/icon-1024.png Resources/AppIcon.png
echo "ICONSET_OK Resources/AppIcon.icns"
