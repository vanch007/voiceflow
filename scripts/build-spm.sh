#!/bin/bash
# VoiceFlow 编译脚本 (SPM 版本)
# 编译后复制到 /Applications/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/VoiceFlow"
INSTALL_PATH="/Applications/VoiceFlow.app"

cd "$PROJECT_DIR"

echo "🔨 Building VoiceFlow with SPM..."
swift build -c debug

echo "✅ Build succeeded"
echo ""

# 关闭正在运行的 VoiceFlow
if pgrep -x "VoiceFlow" > /dev/null 2>&1; then
    echo "🛑 正在关闭运行中的 VoiceFlow..."
    killall VoiceFlow 2>/dev/null || true
    sleep 1
fi

# 创建或更新 App Bundle
echo "📦 Updating $INSTALL_PATH ..."

# 如果 app 不存在，创建一个基本的结构
if [ ! -d "$INSTALL_PATH" ]; then
    mkdir -p "$INSTALL_PATH/Contents/MacOS"
    mkdir -p "$INSTALL_PATH/Contents/Resources"

    # 复制 Info.plist
    cp "$PROJECT_DIR/Resources/Info.plist" "$INSTALL_PATH/Contents/"

    # 复制 entitlements
    cp "$PROJECT_DIR/Resources/VoiceFlow.entitlements" "$INSTALL_PATH/Contents/Resources/" 2>/dev/null || true
fi

# 复制新的可执行文件
cp .build/debug/VoiceFlow "$INSTALL_PATH/Contents/MacOS/"
chmod +x "$INSTALL_PATH/Contents/MacOS/VoiceFlow"

# 复制 MLX metallib 文件（关键！）
METALLIB_SRC="$PROJECT_DIR/.build/arm64-apple-macosx/release/mlx.metallib"
if [ -f "$METALLIB_SRC" ]; then
    echo "📦 Copying MLX metallib..."
    cp "$METALLIB_SRC" "$INSTALL_PATH/Contents/MacOS/mlx.metallib"
    # 创建 default.metallib 符号链接
    ln -sf mlx.metallib "$INSTALL_PATH/Contents/MacOS/default.metallib" 2>/dev/null || true

    # 也复制到 Resources
    cp "$METALLIB_SRC" "$INSTALL_PATH/Contents/Resources/mlx.metallib"
    cp "$INSTALL_PATH/Contents/Resources/mlx.metallib" "$INSTALL_PATH/Contents/Resources/default.metallib"
fi

echo "✅ 已安装到 $INSTALL_PATH"
echo ""

# 修复代码签名（ad-hoc）
codesign --force --deep --sign - "$INSTALL_PATH" 2>/dev/null || true

echo "⚠️  代码签名已变更，辅助功能权限需要重新授权："
echo "   系统设置 → 隐私与安全性 → 辅助功能 → 先删除 VoiceFlow（-按钮）→ 再重新添加（+按钮）"
echo ""

echo "🚀 运行方式: ./run.sh"
