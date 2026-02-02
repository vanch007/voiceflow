#!/bin/bash
# VoiceFlow 빌드 + 배포 스크립트
#
# IMPORTANT: 앱 복사 시 반드시 ditto를 사용해야 합니다.
# cp -R은 macOS 코드사인(code signature)을 보존하지 않아서
# 접근성(Accessibility) 권한이 깨집니다.
# ditto는 코드사인, extended attributes, ACL을 모두 보존합니다.
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

# DerivedData에서 빌드된 앱 경로를 동적으로 가져옴
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

# 기존 앱 삭제
if [ -d "$DEST" ]; then
  echo "🗑️  Removing old VoiceFlow.app..."
  rm -rf "$DEST"
fi

# ditto로 복사 (코드사인 보존 - cp -R 사용 금지!)
echo "📦 Copying VoiceFlow.app (ditto, preserving codesign)..."
ditto "$DERIVED_DATA/VoiceFlow.app" "$DEST"

echo ""
echo "✅ Build & deploy complete!"
echo "   → $DEST"
echo ""
echo "⚠️  빌드 후 접근성 권한 재승인 필요:"
echo "   시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용"
echo "   → VoiceFlow 토글 off → on"
