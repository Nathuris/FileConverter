#!/bin/bash
# FileConverter 构建与运行脚本
# 用法：
#   ./build_app.sh          构建并创建 .app Bundle
#   ./build_app.sh --run    构建并直接运行

set -e
cd "$(dirname "$0")"

echo "🔨 正在编译 FileConverter..."
swift build -c release 2>&1 | tail -2

echo "📦 创建 App Bundle..."
APP="FileConverter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/release/FileConverter "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

echo "✅ 完成！App: $APP"

if [[ "$1" == "--run" ]]; then
    echo "🚀 正在启动..."
    open "$APP"
fi
