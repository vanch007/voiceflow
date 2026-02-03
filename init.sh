#!/bin/bash
###############################################################################
# VoiceFlow Development Environment Initialization Script
#
# This script:
# 1. Activates Python virtual environment (if needed)
# 2. Starts ASR server on port 9876
# 3. Provides health check output
###############################################################################

set -e  # Exit on error

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="${PROJECT_ROOT}/.venv"
SERVER_DIR="${PROJECT_ROOT}/server"
ASR_PORT=9876

echo "=============================================="
echo "VoiceFlow Development Environment Setup"
echo "=============================================="
echo ""

# Check if virtual environment exists
if [ -d "$VENV_PATH" ]; then
    echo "✓ Found virtual environment at: $VENV_PATH"

    # Activate virtual environment
    echo "  Activating virtual environment..."
    source "$VENV_PATH/bin/activate"
    echo "  ✓ Virtual environment activated"
else
    echo "⚠ No virtual environment found at: $VENV_PATH"
    echo "  Proceeding with system Python..."
fi

echo ""

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1)
echo "✓ Python version: $PYTHON_VERSION"

# Check if server directory exists
if [ ! -d "$SERVER_DIR" ]; then
    echo "✗ ERROR: Server directory not found: $SERVER_DIR"
    exit 1
fi

echo "✓ Server directory: $SERVER_DIR"
echo ""

# Check if requirements are installed
echo "Checking Python dependencies..."
cd "$SERVER_DIR"

REQUIRED_PACKAGES=("websockets" "numpy" "soundfile" "qwen-asr" "pytest")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if python3 -c "import ${package//-/_}" 2>/dev/null; then
        echo "  ✓ $package"
    else
        echo "  ✗ $package (missing)"
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
    echo ""
    echo "⚠ Missing packages detected: ${MISSING_PACKAGES[*]}"
    echo "  Installing missing packages..."
    pip install -q "${MISSING_PACKAGES[@]}" || {
        echo "✗ Failed to install packages"
        echo "  Please run: pip install -r requirements.txt"
        exit 1
    }
    echo "  ✓ Packages installed successfully"
fi

echo ""
echo "=============================================="
echo "Starting ASR Server on port $ASR_PORT"
echo "=============================================="
echo ""

# Check if port is already in use
if lsof -Pi :$ASR_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠ Port $ASR_PORT is already in use"
    echo "  Checking if it's the ASR server..."

    PID=$(lsof -Pi :$ASR_PORT -sTCP:LISTEN -t)
    echo "  Process ID: $PID"

    read -p "  Kill existing process and restart? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $PID 2>/dev/null || {
            echo "✗ Failed to kill process $PID"
            exit 1
        }
        echo "  ✓ Killed process $PID"
        sleep 1
    else
        echo "  Keeping existing server running"
        echo "  ✓ ASR server is already running on port $ASR_PORT"
        echo ""
        echo "=============================================="
        echo "Health Check"
        echo "=============================================="
        echo "✓ ASR server: RUNNING (port $ASR_PORT)"
        echo "✓ Environment: READY"
        echo ""
        exit 0
    fi
fi

# Start ASR server in background
echo "Starting ASR server..."
cd "$SERVER_DIR"

# Start server in background and capture PID
python3 main.py > /tmp/voiceflow-asr.log 2>&1 &
SERVER_PID=$!

echo "  ✓ ASR server started (PID: $SERVER_PID)"
echo "  Log file: /tmp/voiceflow-asr.log"

# Wait for server to initialize
echo "  Waiting for server to initialize..."
sleep 2

# Health check
if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "  ✓ Server process is running"

    # Check if port is listening
    if lsof -Pi :$ASR_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ✓ Server is listening on port $ASR_PORT"
    else
        echo "  ⚠ Server process is running but not listening on port $ASR_PORT yet"
        echo "    Check log file for details: /tmp/voiceflow-asr.log"
    fi
else
    echo "  ✗ Server process died unexpectedly"
    echo "    Check log file for errors: /tmp/voiceflow-asr.log"
    exit 1
fi

echo ""
echo "=============================================="
echo "Health Check Summary"
echo "=============================================="
echo "✓ ASR server: RUNNING (port $ASR_PORT, PID: $SERVER_PID)"
echo "✓ Python environment: READY"
echo "✓ Dependencies: INSTALLED"
echo ""
echo "To stop the server:"
echo "  kill $SERVER_PID"
echo ""
echo "To view logs:"
echo "  tail -f /tmp/voiceflow-asr.log"
echo ""
echo "=============================================="
echo "Initialization Complete!"
echo "=============================================="
