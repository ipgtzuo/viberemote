#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/VibeRemote.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/dist/VibeRemote-${VERSION}.dmg"
IDENTITY="${VIBEREMOTE_SIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  echo "缺少 Developer ID 签名身份。"
  echo "请先安装 Developer ID Application 证书，然后："
  echo "  VIBEREMOTE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/release.sh"
  exit 1
fi

cd "$ROOT"
./build.sh

echo "签名 $APP"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

./package.sh

if [[ -n "${VIBEREMOTE_APPLE_ID:-}" && -n "${VIBEREMOTE_TEAM_ID:-}" && -n "${VIBEREMOTE_APP_PASSWORD:-}" ]]; then
  echo "提交 Apple 公证…"
  xcrun notarytool submit "$DMG" \
    --apple-id "$VIBEREMOTE_APPLE_ID" \
    --team-id "$VIBEREMOTE_TEAM_ID" \
    --password "$VIBEREMOTE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "已公证并装订：$DMG"
else
  echo "未提供公证凭据，已生成未公证 DMG：$DMG"
  echo "设置 VIBEREMOTE_APPLE_ID / VIBEREMOTE_TEAM_ID / VIBEREMOTE_APP_PASSWORD 后可自动公证。"
fi

shasum -a 256 "$DMG"
