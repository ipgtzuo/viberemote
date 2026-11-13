# 发布检查清单

## 前置条件

- Apple Developer Program 账号
- 钥匙串里有 `Developer ID Application: ... (TEAMID)` 证书
- App 专用密码（用于 `notarytool`）

## 本地构建

```sh
./build.sh
```

`build.sh` 会分别编译 `arm64` 和 `x86_64`，再用 `lipo` 合并为 Universal Binary。当前最低系统版本为 macOS 13。

检查：

```sh
lipo -info dist/VibeRemote.app/Contents/MacOS/VibeRemote
```

## 签名与公证

```sh
export VIBEREMOTE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export VIBEREMOTE_APPLE_ID='you@example.com'
export VIBEREMOTE_TEAM_ID='TEAMID'
export VIBEREMOTE_APP_PASSWORD='app-specific-password'
./scripts/release.sh
```

脚本会重新签名、打包 DMG、提交 `notarytool`、`stapler` 装订，并输出 SHA-256。

如果没有 Developer ID，只能生成 Apple Development 或 ad-hoc 签名；此时用户首次打开可能需要右键 → 打开。

## 干净机器验收

- [ ] 全新 macOS 用户下挂载 DMG，拖入 Applications
- [ ] 首次启动出现向导
- [ ] 输入监控和辅助功能授权后，权限状态变绿
- [ ] Siri Remote 与 RC003-MS 都能连接
- [ ] 语音自检能开始/结束听写并显示诊断
- [ ] DSH / WorkBuddy / 豆包 各完成一次“说话 → 发送 → 停止”
- [ ] 合盖 / 无麦克风 / 权限撤销时有明确提示
- [ ] 卸载重装后 TCC 授权仍可恢复
- [ ] Intel Mac 与 Apple Silicon 各启动一次（Universal）

## GitHub Release

```sh
gh release create "v$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" \
  dist/VibeRemote-*.dmg \
  --title "VibeRemote $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" \
  --notes-file /tmp/release-notes.md
```
