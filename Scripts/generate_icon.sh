#!/usr/bin/env bash
#
# Generates AppIcon.icns (and the .appiconset PNGs) from App/AppIcon.svg.
# Run on macOS. Requires `iconutil` and `sips` (both ship with macOS) plus an
# SVG rasterizer: `rsvg-convert` (brew install librsvg) or Inkscape, with a
# fallback to `qlmanage`.
set -euo pipefail
cd "$(dirname "$0")/.."

SVG="App/AppIcon.svg"
WORK="$(mktemp -d)"
MASTER="$WORK/master.png"
ICONSET="$WORK/AppIcon.iconset"
OUT_ICNS="App/AppIcon.icns"
APPICONSET="App/Assets.xcassets/AppIcon.appiconset"

echo "Rasterizing $SVG -> 1024px master…"
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 1024 -h 1024 "$SVG" -o "$MASTER"
elif command -v inkscape >/dev/null 2>&1; then
  inkscape "$SVG" --export-type=png --export-filename="$MASTER" -w 1024 -h 1024
else
  echo "No SVG rasterizer found. Install librsvg:  brew install librsvg" >&2
  echo "Falling back to qlmanage (lower fidelity)…" >&2
  qlmanage -t -s 1024 -o "$WORK" "$SVG" >/dev/null 2>&1
  mv "$WORK"/AppIcon.svg.png "$MASTER"
fi

mkdir -p "$ICONSET"
declare -a SIZES=(16 32 128 256 512)
for s in "${SIZES[@]}"; do
  sips -z "$s" "$s" "$MASTER" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z "$d" "$d" "$MASTER" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

echo "Building $OUT_ICNS…"
iconutil -c icns "$ICONSET" -o "$OUT_ICNS"

echo "Copying PNGs into asset catalog…"
cp "$ICONSET"/*.png "$APPICONSET"/

echo "Done: $OUT_ICNS"
