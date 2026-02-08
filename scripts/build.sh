#!/bin/bash
# VoiceFlow 编译脚本
# 编译后复制到 /Applications/，方便权限管理和测试

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_PATH="/Applications/VoiceFlow.app"

echo "🔨 Building VoiceFlow..."
xcodebuild -project "$PROJECT_DIR/VoiceFlow/VoiceFlow.xcodeproj" \
  -scheme VoiceFlow \
  -configuration Debug \
  build \
  -quiet

echo "✅ Build succeeded"
echo ""

# 找到 DerivedData 中的 app
APP_PATH=$(ls -d ~/Library/Developer/Xcode/DerivedData/VoiceFlow-*/Build/Products/Debug/VoiceFlow.app 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found in DerivedData"
    exit 1
fi

# 关闭正在运行的 VoiceFlow
if pgrep -x "VoiceFlow" > /dev/null 2>&1; then
    echo "🛑 正在关闭运行中的 VoiceFlow..."
    killall VoiceFlow 2>/dev/null || true
    sleep 1
fi

# 复制到 /Applications/（使用 ditto 保留签名和属性）
echo "📦 复制到 $INSTALL_PATH ..."
rm -rf "$INSTALL_PATH"
ditto "$APP_PATH" "$INSTALL_PATH"

echo "✅ 已安装到 $INSTALL_PATH"
echo ""
echo "⚠️  代码签名已变更，辅助功能权限需要重新授权："
echo "   系统设置 → 隐私与安全性 → 辅助功能 → 先删除 VoiceFlow（-按钮）→ 再重新添加（+按钮）"
echo ""
echo "🚀 运行方式: ./run.sh"
