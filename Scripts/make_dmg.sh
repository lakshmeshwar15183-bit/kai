#!/usr/bin/env bash
#
# Packages dist/Kai.app into a distributable dist/Kai.dmg with an
# /Applications drop link. Run on macOS after build_app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Kai"
APP_DIR="dist/${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}.dmg"
STAGING="$(mktemp -d)"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing $APP_DIR — run ./Scripts/build_app.sh first." >&2
  exit 1
fi

echo "==> Staging…"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating ${DMG_PATH}…"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"

echo "Built ${DMG_PATH}"
echo "Distribute after notarization:  xcrun notarytool submit \"$DMG_PATH\" …"
