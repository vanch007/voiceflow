#!/bin/bash
# Run VoiceFlow from /Applications/ using open command
# 使用 open 命令启动，确保 TCC 权限正常工作

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="/Applications/VoiceFlow.app"

# 如果 /Applications/ 中没有，先编译安装
if [ ! -d "$APP_PATH" ]; then
    echo "📦 首次运行，先编译安装..."
    "$PROJECT_ROOT/scripts/build.sh"
fi

echo "🚀 Starting VoiceFlow..."
echo "   → $APP_PATH"
echo ""
echo "📋 查看日志请打开 Console.app，筛选 VoiceFlow"
echo "   或运行: log stream --predicate 'subsystem == \"com.voiceflow.app\"' --level debug"
echo ""

# 设置环境变量（通过 launchctl 传递给应用）
launchctl setenv VOICEFLOW_PYTHON "$PROJECT_ROOT/.venv/bin/python3"
launchctl setenv VOICEFLOW_PROJECT_ROOT "$PROJECT_ROOT"

# 使用 open 命令启动（通过 LaunchServices，TCC 权限正常工作）
open "$APP_PATH"

echo "✅ VoiceFlow 已启动"
echo ""
echo "💡 提示："
echo "   - 双击 Control 键: 系统音频转录"
echo "   - 长按 Option 键: 麦克风录音"
echo "   - 点击菜单栏图标: 更多选项"
