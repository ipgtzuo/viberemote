#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DMG="$ROOT/dist/VibeRemote-1.7.dmg"
STAGE="$ROOT/.build/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$ROOT/dist/VibeRemote.app" "$STAGE/VibeRemote.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "VibeRemote" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Packaged $DMG"
