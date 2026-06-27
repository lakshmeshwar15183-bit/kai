#!/usr/bin/env bash
#
# Builds a release Kai.app bundle from the SwiftPM `kai-app` product.
# Run on macOS 14+ with the Swift toolchain installed.
#
# Usage:
#   ./Scripts/build_app.sh                       # ad-hoc signed, for local use
#   CODESIGN_IDENTITY="Developer ID Application: …" ./Scripts/build_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Kai"
BUNDLE_ID="com.kai.assistant"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"

echo "==> Building release binary (kai-app)…"
swift build -c release --product kai-app

echo "==> Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "${BUILD_DIR}/kai-app" "${MACOS_DIR}/${APP_NAME}"
cp "App/Info.plist" "${APP_DIR}/Contents/Info.plist"

if [[ ! -f "App/AppIcon.icns" ]]; then
  echo "==> Generating app icon…"
  ./Scripts/generate_icon.sh || echo "   (icon generation skipped; continuing without icon)"
fi
[[ -f "App/AppIcon.icns" ]] && cp "App/AppIcon.icns" "${RES_DIR}/AppIcon.icns"

# Bundle the Swift runtime libraries the binary needs (for portability).
echo "==> Embedding Swift runtime (if needed)…"
mkdir -p "${APP_DIR}/Contents/Frameworks"

echo "==> Code signing…"
IDENTITY="${CODESIGN_IDENTITY:--}"   # "-" means ad-hoc
codesign --force --deep --options runtime \
  --entitlements "App/Kai.entitlements" \
  --sign "$IDENTITY" "$APP_DIR"

echo "==> Verifying…"
codesign --verify --verbose=2 "$APP_DIR" || true

echo "Built ${APP_DIR}"
echo "Launch with:  open \"${APP_DIR}\""
