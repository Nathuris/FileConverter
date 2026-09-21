#!/bin/bash
# 统一的 release 编译入口，其它脚本都调用它。
#
# 为什么不直接写 `swift build -c release`：
#   装上 Xcode 之后，SwiftPM 默认换成 Xcode 的编译引擎，而那个引擎会强制
#   使用最新的 macOS 开发套件（27.0）——比本机系统（26.x）还新一代。
#   用比系统更新的套件编译出来的 App，界面控件外观会变样、下拉菜单点不开。
#   所以这里指定 SwiftPM 自带的编译引擎，并把套件锁定到与本机系统匹配的 26.5。
set -e
cd "$(dirname "$0")"

SDK_ROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk

if [ -d "$SDK_ROOT" ]; then
    SDKROOT="$SDK_ROOT" swift build -c release --build-system native
else
    echo "⚠️  找不到 26.5 套件，退回默认设置编译（界面可能会异常）"
    swift build -c release
fi
