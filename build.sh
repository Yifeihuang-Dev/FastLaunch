#!/bin/bash
# 构建并打包 RightMenuHelper.app
set -euo pipefail
cd "$(dirname "$0")"

APP="FastLaunch.app"

echo "==> swift build (release)"
swift build -c release

echo "==> 组装 .app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/RightMenuHelper "$APP/Contents/MacOS/RightMenuHelper"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> ad-hoc 签名（本地运行）"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "（签名跳过）"

echo "==> 完成: $(pwd)/$APP"
echo "运行: open \"$(pwd)/$APP\""
