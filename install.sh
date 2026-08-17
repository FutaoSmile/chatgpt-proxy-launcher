#!/bin/bash
# 一键安装：构建 "ChatGPT Proxy.app" 到 ~/Applications
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Applications/ChatGPT Proxy.app"

mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
cp "$HERE/Info.plist" "$DEST/Contents/Info.plist"
cp "$HERE/launcher.sh" "$DEST/Contents/MacOS/launcher"
chmod +x "$DEST/Contents/MacOS/launcher"

# 复用原版 ChatGPT 图标（若存在）
if [ -f "/Applications/ChatGPT.app/Contents/Resources/electron.icns" ]; then
  cp "/Applications/ChatGPT.app/Contents/Resources/electron.icns" "$DEST/Contents/Resources/electron.icns"
fi

echo "已安装到 $DEST"
echo "使用方法：先 Cmd+Q 完全退出原版 ChatGPT，再从该 App 启动（可拖入 Dock）。"
