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
DERIVED_DATA="/Users/brucechoe/Library/Developer/Xcode/DerivedData/VoiceFlow-gducekvflkibbkbmejqcbmdzqfzz/Build/Products/Debug/VoiceFlow.app"
DEST="$PROJECT_DIR/VoiceFlow.app"

echo "🔨 Building VoiceFlow..."
xcodebuild -project "$PROJECT_DIR/VoiceFlow.xcodeproj" \
  -scheme VoiceFlow \
  -configuration Debug \
  build \
  -quiet

echo "✅ Build succeeded"

# 기존 앱 삭제
if [ -d "$DEST" ]; then
  echo "🗑️  Removing old VoiceFlow.app..."
  rm -rf "$DEST"
fi

# ditto로 복사 (코드사인 보존 - cp -R 사용 금지!)
echo "📦 Copying VoiceFlow.app (ditto, preserving codesign)..."
ditto "$DERIVED_DATA" "$DEST"

echo ""
echo "✅ Build & deploy complete!"
echo "   → $DEST"
echo ""
echo "⚠️  빌드 후 접근성 권한 재승인 필요:"
echo "   시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용"
echo "   → VoiceFlow 토글 off → on"
