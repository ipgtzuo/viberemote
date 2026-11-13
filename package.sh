#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/dist/VibeRemote-${VERSION}.dmg"
STAGE="$ROOT/.build/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$ROOT/dist/VibeRemote.app" "$STAGE/VibeRemote.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "VibeRemote" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Packaged $DMG"
