#!/usr/bin/env bash
#
# Package the macOS release build as a DMG.
#
# Signing has three levels and this picks the best one available:
#
#   Developer ID + notarization  →  opens by double-click, no warning
#   ad-hoc (the default here)    →  first launch needs a right-click → Open
#   unsigned                     →  macOS reports the app as "damaged"
#
# Ad-hoc is what a build with no certificate gets. It costs nothing, needs no
# Apple account, and it is the difference between "unidentified developer"
# (which a user can get past) and "damaged" (which reads like a broken
# download). A free Apple ID does not help here: the certificates it issues
# expire in 7 days and are only trusted on machines that already trust them,
# so they are for local device debugging rather than distribution.
#
# Prerequisites: flutter build macos --release
#
# Optional env, all four needed for notarization:
#   MACOS_SIGN_IDENTITY   e.g. "Developer ID Application: Name (TEAMID)"
#   APPLE_ID              Apple ID email for notarytool
#   APPLE_TEAM_ID         10-character team id
#   APPLE_APP_PASSWORD    app-specific password
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Asasfans Next"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
OUT_DIR="build/macos"

VERSION="$(grep '^version:' pubspec.yaml | head -1 |
  sed 's/version:[[:space:]]*//' | cut -d'+' -f1 | tr -d '[:space:]')"
DMG_PATH="${OUT_DIR}/asasfans-next-${VERSION}-macos.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: app bundle not found at $APP_PATH" >&2
  echo "Run 'flutter build macos --release' first." >&2
  exit 1
fi

# Rebuild AppIcon.icns from the PNG set rather than trusting the one Xcode
# compiled from the asset catalogue.
#
# Xcode's asset compilation here produced an icns containing only the 16pt and
# 128pt entries, dropping 32, 256 and 512. Finder then upscaled the 256px image
# for every large slot, which looked blurry and mis-centred even though the
# source PNGs were correct. iconutil takes the same PNGs and writes all ten
# entries, and the result is verifiable by reading it back.
ICON_SRC="macos/packaging/icon"
ICON_DEST="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [[ -d "$ICON_SRC" ]]; then
  ICONSET="$(mktemp -d -t asasfans_iconset)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  cp "$ICON_SRC/icon_16.png" "$ICONSET/icon_16x16.png"
  cp "$ICON_SRC/icon_32.png" "$ICONSET/icon_16x16@2x.png"
  cp "$ICON_SRC/icon_32.png" "$ICONSET/icon_32x32.png"
  cp "$ICON_SRC/icon_64.png" "$ICONSET/icon_32x32@2x.png"
  cp "$ICON_SRC/icon_128.png" "$ICONSET/icon_128x128.png"
  cp "$ICON_SRC/icon_256.png" "$ICONSET/icon_128x128@2x.png"
  cp "$ICON_SRC/icon_256.png" "$ICONSET/icon_256x256.png"
  cp "$ICON_SRC/icon_512.png" "$ICONSET/icon_256x256@2x.png"
  cp "$ICON_SRC/icon_512.png" "$ICONSET/icon_512x512.png"
  cp "$ICON_SRC/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns -o "$ICON_DEST" "$ICONSET"
  rm -rf "$(dirname "$ICONSET")"
  # Signing comes after this, so the replaced icon is inside what gets signed.
  echo "Rebuilt AppIcon.icns from $ICON_SRC"
fi

# Partial signing configuration is a mistake rather than a choice: a release
# pipeline with a typo'd secret would otherwise quietly ship a low-trust build
# that looks the same in the artifact list.
NOTARIZE_READY=0
if [[ -n "${MACOS_SIGN_IDENTITY:-}" && -n "${APPLE_ID:-}" &&
  -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  NOTARIZE_READY=1
fi
SIGN_VARS_PRESENT=0
for value in "${MACOS_SIGN_IDENTITY:-}" "${APPLE_ID:-}" \
  "${APPLE_TEAM_ID:-}" "${APPLE_APP_PASSWORD:-}"; do
  [[ -n "$value" ]] && SIGN_VARS_PRESENT=1
done
if [[ "$SIGN_VARS_PRESENT" == "1" && "$NOTARIZE_READY" == "0" &&
  "${ALLOW_ADHOC_RELEASE:-}" != "1" ]]; then
  echo "ERROR: signing is partially configured." >&2
  echo "Need all of: MACOS_SIGN_IDENTITY, APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD" >&2
  echo "To build ad-hoc on purpose, set ALLOW_ADHOC_RELEASE=1." >&2
  exit 1
fi

if [[ -n "${MACOS_SIGN_IDENTITY:-}" ]]; then
  echo "Signing with Developer ID: $MACOS_SIGN_IDENTITY"
  codesign --deep --force --options runtime --timestamp \
    --sign "$MACOS_SIGN_IDENTITY" "$APP_PATH"
else
  echo "No Developer ID configured; applying an ad-hoc signature."
  codesign --deep --force --sign - "$APP_PATH"
fi
codesign --verify --deep --strict "$APP_PATH"

# hdiutil rather than a packaging dependency: it ships with macOS, and the
# layout this needs is a folder with the app and an Applications symlink.
mkdir -p "$OUT_DIR"
rm -f "$DMG_PATH"
STAGE="$(mktemp -d -t asasfans_dmg)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp macos/packaging/INSTALL_NOTE.md "$STAGE/首次打开说明.md"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG_PATH"
echo "Built: $DMG_PATH"

if [[ "$NOTARIZE_READY" == "1" ]]; then
  echo "Notarizing..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  echo "Notarized and stapled."
else
  echo "Ad-hoc signed, not notarized. First launch needs right-click → Open;"
  echo "see macos/packaging/INSTALL_NOTE.md."
fi
