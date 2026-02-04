#!/bin/bash
# Run VoiceFlow directly (no build)

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$PROJECT_ROOT/VoiceFlow.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Run ./scripts/build.sh first"
    exit 1
fi

echo "🚀 Starting VoiceFlow..."

# Set environment variable for Python path
export VOICEFLOW_PYTHON="$PROJECT_ROOT/.venv/bin/python3"

# Run the app (直接运行可执行文件以显示日志)
"$APP_PATH/Contents/MacOS/VoiceFlow"
