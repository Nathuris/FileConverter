#!/bin/bash
# 打包 FileConverter 为 .dmg 安装镜像

set -e

APP_NAME="FileConverter"
VERSION="1.0.0"
APP_DIR="$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"
TEMP_DMG="temp-$DMG_NAME"
VOLUME_NAME="FileConverter Installer"

echo "📦 开始打包 $APP_NAME v$VERSION..."

# 1. 清理旧文件
rm -rf "$APP_DIR" "$DMG_NAME" "$TEMP_DMG" "dmg-staging"

# 2. 构建 release 版本
echo "🔨 构建 release 版本..."
swift build -c release

# 3. 创建 .app bundle
echo "📱 创建 $APP_DIR..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 复制可执行文件
cp .build/release/$APP_NAME "$APP_DIR/Contents/MacOS/"

# 复制 Info.plist（如果没有就创建）
if [ ! -f "Resources/Info.plist" ]; then
    cat > "Resources/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FileConverter</string>
    <key>CFBundleDisplayName</key>
    <string>文件格式转换器</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.FileConverter</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>FileConverter</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
</dict>
</plist>
EOF
fi

cp Resources/Info.plist "$APP_DIR/Contents/"

# 复制图标文件
if [ -f "Resources/FileConverter.icns" ]; then
    cp Resources/FileConverter.icns "$APP_DIR/Contents/Resources/"
    echo "🎨 已复制应用图标"
fi

# 创建 PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 4. 创建 DMG staging 目录
echo "🎨 准备 DMG 布局..."
mkdir -p dmg-staging

# 复制 .app 到 staging
cp -R "$APP_DIR" dmg-staging/

# 创建到 /Applications 的软链接
ln -s /Applications dmg-staging/Applications

# 5. 创建临时 DMG（可读写）
echo "💿 创建临时 DMG..."
hdiutil create -srcfolder dmg-staging -volname "$VOLUME_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG"

# 6. 挂载并设置窗口布局
echo "🎯 设置窗口布局..."
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG")
DEVICE=$(echo "$MOUNT_OUTPUT" | grep '/dev/' | head -1 | awk '{print $1}')

# 设置窗口位置和布局
sleep 2
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "$APP_NAME.app" of container window to {140, 200}
        set position of item "Applications" of container window to {380, 200}
        update without registering applications
        delay 5
        close
    end tell
end tell
EOF

# 7. 卸载
sync
hdiutil detach "$DEVICE"

# 8. 转换为只读压缩 DMG
echo "🗜️ 压缩为最终 DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# 9. 清理
rm -rf "$TEMP_DMG" dmg-staging "$APP_DIR"

echo ""
echo "✅ 打包完成！"
echo "📦 安装包: $DMG_NAME"
echo "💡 双击 DMG 文件即可打开，拖动 App 到 Applications 文件夹完成安装"
echo ""

# 显示文件大小
ls -lh "$DMG_NAME" | awk '{print "📏 大小: " $5}'
