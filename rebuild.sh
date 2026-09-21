#!/bin/bash
# 一键重建：编译 → xcodeproj → DMG
set -e
cd "$(dirname "$0")"

echo "🔨 swift build..."
bash build_release.sh
echo "📱 xcodeproj..."
python3 gen_xcode.py
echo "📦 DMG..."
bash package_dmg.sh
