#!/bin/bash
# VoiceFlow launcher - run both ASR server and app
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV="/Users/brucechoe/clawd/.venvs/qwen3-asr"
LOG="/tmp/voiceflow.log"

# Kill existing
pkill -f "server/main.py" 2>/dev/null || true
pkill -f "VoiceFlow" 2>/dev/null || true
sleep 1

echo "🚀 Starting VoiceFlow..."
echo ""

# Start ASR server in background
echo "📡 Starting ASR server..."
"$VENV/bin/python3" "$PROJECT_DIR/server/main.py" > /tmp/voiceflow-server.log 2>&1 &
SERVER_PID=$!

# Wait for server to be ready
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w '' --connect-timeout 1 http://localhost:9876 2>/dev/null; then
        break
    fi
    sleep 1
done

echo "✅ ASR server ready (pid: $SERVER_PID)"
echo ""

# Start VoiceFlow app
echo "🎤 Starting VoiceFlow app..."
echo "   Ctrl+Ctrl (더블탭) = 녹음 시작/종료"
echo "   Ctrl+C = 종료"
echo ""

"$PROJECT_DIR/VoiceFlow.app/Contents/MacOS/VoiceFlow" 2>&1 | tee -a "$LOG"

# Cleanup on exit
kill $SERVER_PID 2>/dev/null
echo "👋 VoiceFlow stopped."
