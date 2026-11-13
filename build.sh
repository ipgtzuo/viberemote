#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/VibeRemote.app"
BIN="$ROOT/.build/VibeRemote"

mkdir -p "$ROOT/.build"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=(
  "$ROOT/Sources/RemoteManager.swift"
  "$ROOT/Sources/Appearance.swift"
  "$ROOT/Sources/AppMode.swift"
  "$ROOT/Sources/ButtonBindings.swift"
  "$ROOT/Sources/ActionExecutor.swift"
  "$ROOT/Sources/ActionHUD.swift"
  "$ROOT/Sources/BluetoothBatteryReader.swift"
  "$ROOT/Sources/TouchpadManager.swift"
  "$ROOT/Sources/MappingSettingsView.swift"
  "$ROOT/Sources/VibeRemoteModel.swift"
  "$ROOT/Sources/OnboardingView.swift"
  "$ROOT/Sources/VibeRemoteView.swift"
  "$ROOT/Sources/VibeRemoteApp.swift"
)

build_arch() {
  local arch="$1"
  local output="$2"
  echo "Compiling VibeRemote ${arch}…"
  xcrun swiftc \
    -swift-version 5 \
    -Onone \
    -parse-as-library \
    -target "${arch}-apple-macos13.0" \
    "${SOURCES[@]}" \
    -o "$output"
}

build_arch arm64 "$ROOT/.build/VibeRemote-arm64"
build_arch x86_64 "$ROOT/.build/VibeRemote-x86_64"
lipo -create \
  "$ROOT/.build/VibeRemote-arm64" \
  "$ROOT/.build/VibeRemote-x86_64" \
  -output "$BIN"

cp "$BIN" "$APP/Contents/MacOS/VibeRemote"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
if [[ -f "$ROOT/Resources/RC003MS.png" ]]; then
  cp "$ROOT/Resources/RC003MS.png" "$APP/Contents/Resources/RC003MS.png"
fi
for asset in BrandDeepSeek.png BrandWorkBuddy.png BrandDoubao.png; do
  if [[ -f "$ROOT/Resources/$asset" ]]; then
    cp "$ROOT/Resources/$asset" "$APP/Contents/Resources/$asset"
  fi
done
xattr -cr "$APP" 2>/dev/null || true
# Sign a fresh copy: xattrs inherited from the workspace can make codesign
# reject the bundle as "resource fork, Finder information, or similar detritus".
SIGN_TMP="$(mktemp -d)/VibeRemote.app"
ditto "$APP" "$SIGN_TMP"
xattr -cr "$SIGN_TMP" 2>/dev/null || true
codesign --force --deep --sign - "$SIGN_TMP" >/dev/null
rm -rf "$APP"
ditto "$SIGN_TMP" "$APP"
rm -rf "$(dirname "$SIGN_TMP")"
echo "Built $APP"
