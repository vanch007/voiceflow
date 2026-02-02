#!/bin/bash
# Run VoiceFlow using xcodebuild

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
XCODE_PROJECT="$PROJECT_ROOT/VoiceFlow/VoiceFlow.xcodeproj"
DERIVED_DATA="$PROJECT_ROOT/VoiceFlow/build"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/VoiceFlow.app"

echo "🔨 Building VoiceFlow..."
cd "$PROJECT_ROOT/VoiceFlow"
xcodebuild -scheme VoiceFlow -configuration Debug -derivedDataPath "$DERIVED_DATA" build 2>&1 | grep -E "(error:|warning:|BUILD|Compiling)" || true

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed - app not found at $APP_PATH"
    exit 1
fi

echo "✅ Build succeeded!"
echo "🚀 Starting VoiceFlow..."

# Set environment variable for Python path
export VOICEFLOW_PYTHON="$PROJECT_ROOT/.venv/bin/python3"

# Run the app (直接运行可执行文件以显示日志)
"$APP_PATH/Contents/MacOS/VoiceFlow"
