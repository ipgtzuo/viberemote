#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/VibeRemote.app"
BIN="$ROOT/.build/VibeRemote"

mkdir -p "$ROOT/.build"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling VibeRemote…"
xcrun swiftc \
  -swift-version 5 \
  -Onone \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  "$ROOT/Sources/RemoteManager.swift" \
  "$ROOT/Sources/Appearance.swift" \
  "$ROOT/Sources/AppMode.swift" \
  "$ROOT/Sources/ButtonBindings.swift" \
  "$ROOT/Sources/ActionExecutor.swift" \
  "$ROOT/Sources/ActionHUD.swift" \
  "$ROOT/Sources/BluetoothBatteryReader.swift" \
  "$ROOT/Sources/TouchpadManager.swift" \
  "$ROOT/Sources/MappingSettingsView.swift" \
  "$ROOT/Sources/VibeRemoteModel.swift" \
  "$ROOT/Sources/VibeRemoteView.swift" \
  "$ROOT/Sources/VibeRemoteApp.swift" \
  -o "$BIN"

cp "$BIN" "$APP/Contents/MacOS/VibeRemote"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
find "$APP" -exec xattr -c {} \; 2>/dev/null || true
dot_clean -m "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null
echo "Built $APP"
