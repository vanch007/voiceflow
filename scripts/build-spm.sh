#!/bin/bash
# VoiceFlow 编译脚本 (SPM 版本)
# 编译后复制到 /Applications/
# 注意: swift build 无法编译 Metal 着色器，需要单独用 xcrun metal 编译 metallib

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")/VoiceFlow"
INSTALL_PATH="/Applications/VoiceFlow.app"

cd "$PROJECT_DIR"

echo "🔨 Building VoiceFlow with SPM..."
swift build -c debug

echo "✅ Build succeeded"
echo ""

# 编译 MLX Metal 着色器 (swift build 不会编译 .metal 文件)
METAL_DIR="$PROJECT_DIR/.build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal"
INCLUDE_DIR="$PROJECT_DIR/.build/checkouts/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/kernels"
METALLIB_BUILD_DIR="/tmp/mlx-metallib-build"

if [ -d "$METAL_DIR" ]; then
    # 检查是否已有缓存的 metallib 且 .metal 源文件未变
    METALLIB_CACHE="$PROJECT_DIR/.build/mlx.metallib"
    NEEDS_REBUILD=false

    if [ ! -f "$METALLIB_CACHE" ]; then
        NEEDS_REBUILD=true
    else
        # 检查 .metal 文件是否比缓存新
        for metal_file in $(find "$METAL_DIR" -name "*.metal" -type f); do
            if [ "$metal_file" -nt "$METALLIB_CACHE" ]; then
                NEEDS_REBUILD=true
                break
            fi
        done
    fi

    if [ "$NEEDS_REBUILD" = true ]; then
        echo "🔧 Compiling MLX Metal shaders..."
        rm -rf "$METALLIB_BUILD_DIR"
        mkdir -p "$METALLIB_BUILD_DIR"

        for metal_file in $(find "$METAL_DIR" -name "*.metal" -type f); do
            name=$(basename "$metal_file" .metal)
            xcrun -sdk macosx metal -c -std=metal3.1 -I "$INCLUDE_DIR" "$metal_file" -o "$METALLIB_BUILD_DIR/$name.air" 2>/dev/null
        done

        xcrun -sdk macosx metallib "$METALLIB_BUILD_DIR"/*.air -o "$METALLIB_CACHE" 2>/dev/null
        rm -rf "$METALLIB_BUILD_DIR"
        echo "✅ MLX metallib compiled"
    else
        echo "📦 Using cached MLX metallib"
    fi
fi

# 关闭正在运行的 VoiceFlow
if pgrep -x "VoiceFlow" > /dev/null 2>&1; then
    echo "🛑 正在关闭运行中的 VoiceFlow..."
    killall VoiceFlow 2>/dev/null || true
    sleep 1
fi

# 创建或更新 App Bundle
echo "📦 Updating $INSTALL_PATH ..."

mkdir -p "$INSTALL_PATH/Contents/MacOS"
mkdir -p "$INSTALL_PATH/Contents/Resources"

# 每次都复制 Info.plist（确保始终存在且最新）
cp "$PROJECT_DIR/Resources/Info.plist" "$INSTALL_PATH/Contents/"
cp "$PROJECT_DIR/Resources/VoiceFlow.entitlements" "$INSTALL_PATH/Contents/Resources/" 2>/dev/null || true

# 复制 AppIcon.icns（从 .derivedData 或项目资源中）
DERIVED_DATA_ICON="$PROJECT_DIR/.derivedData/Build/Products/Debug/VoiceFlow.app/Contents/Resources/AppIcon.icns"
if [ -f "$DERIVED_DATA_ICON" ]; then
    cp "$DERIVED_DATA_ICON" "$INSTALL_PATH/Contents/Resources/"
    echo "📦 Installed AppIcon.icns"
else
    echo "⚠️  AppIcon.icns not found!"
fi

# 复制新的可执行文件
cp .build/debug/VoiceFlow "$INSTALL_PATH/Contents/MacOS/"
chmod +x "$INSTALL_PATH/Contents/MacOS/VoiceFlow"

# 复制 MLX metallib（关键！MLX 需要此文件进行 GPU 计算）
METALLIB_CACHE="$PROJECT_DIR/.build/mlx.metallib"
if [ -f "$METALLIB_CACHE" ]; then
    echo "📦 Installing MLX metallib..."
    cp "$METALLIB_CACHE" "$INSTALL_PATH/Contents/MacOS/mlx.metallib"
    cp "$METALLIB_CACHE" "$INSTALL_PATH/Contents/Resources/default.metallib"
else
    echo "⚠️  MLX metallib not found! Native ASR will not work."
    echo "   需要安装 Metal Toolchain: xcodebuild -downloadComponent MetalToolchain"
fi

echo "✅ 已安装到 $INSTALL_PATH"
echo ""

# 修复代码签名（ad-hoc）
codesign --force --deep --sign - "$INSTALL_PATH" 2>/dev/null || true

echo "⚠️  代码签名已变更，辅助功能权限需要重新授权："
echo "   系统设置 → 隐私与安全性 → 辅助功能 → 先删除 VoiceFlow（-按钮）→ 再重新添加（+按钮）"
echo ""

echo "🚀 运行方式: ./run.sh"
