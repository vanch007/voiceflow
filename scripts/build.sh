#!/bin/bash
# VoiceFlow 编译 + 部署脚本
#
# IMPORTANT: 复制 app 时必须使用 ditto。
# cp -R 不会保留 macOS 代码签名(code signature)，
# 辅助功能(Accessibility)权限会失效。
# ditto 会保留代码签名、扩展属性和 ACL。
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEST="$PROJECT_DIR/VoiceFlow.app"

echo "🔨 Building VoiceFlow..."
xcodebuild -project "$PROJECT_DIR/VoiceFlow/VoiceFlow.xcodeproj" \
  -scheme VoiceFlow \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -quiet

# 从 DerivedData 动态获取编译后的 app 路径
DERIVED_DATA=$(xcodebuild -project "$PROJECT_DIR/VoiceFlow/VoiceFlow.xcodeproj" \
  -scheme VoiceFlow \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -showBuildSettings 2>/dev/null \
  | grep -m1 "BUILT_PRODUCTS_DIR" \
  | awk '{print $3}')

if [ -z "$DERIVED_DATA" ] || [ ! -d "$DERIVED_DATA/VoiceFlow.app" ]; then
  echo "❌ Build product not found at: $DERIVED_DATA/VoiceFlow.app"
  exit 1
fi

echo "✅ Build succeeded"

# 删除旧 app
if [ -d "$DEST" ]; then
  echo "🗑️  Removing old VoiceFlow.app..."
  rm -rf "$DEST"
fi

# 使用 ditto 复制 (保留代码签名 - 禁止使用 cp -R!)
echo "📦 Copying VoiceFlow.app (ditto, preserving codesign)..."
ditto "$DERIVED_DATA/VoiceFlow.app" "$DEST"

echo ""
echo "✅ Build & deploy complete!"
echo "   → $DEST"
echo ""
echo "⚠️  编译后需重新授权辅助功能权限:"
echo "   系统设置 → 隐私与安全性 → 辅助功能"
echo "   → VoiceFlow 开关 off → on"
