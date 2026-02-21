#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/VoiceFlow.app"

echo "Building with xcodebuild..."
cd "$PROJECT_DIR/VoiceFlow"
xcodebuild -scheme VoiceFlow -destination 'platform=macOS,arch=arm64' build > /dev/null

DERIVED_DATA_DIR=$(ls -td ~/Library/Developer/Xcode/DerivedData/VoiceFlow-*/Build/Products/Debug | head -1)

echo "Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$DERIVED_DATA_DIR/VoiceFlow" "$APP_DIR/Contents/MacOS/VoiceFlow"

# Copy MLX metal bundle if it exists
if [ -d "$DERIVED_DATA_DIR/mlx-swift_Cmlx.bundle" ]; then
    cp -R "$DERIVED_DATA_DIR/mlx-swift_Cmlx.bundle" "$APP_DIR/Contents/Resources/"
fi

# Also copy Resources/Info.plist if necessary?
# We construct a minimalist Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.voiceflow.app</string>
    <key>CFBundleName</key>
    <string>VoiceFlow</string>
    <key>CFBundleExecutable</key>
    <string>VoiceFlow</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>VoiceFlow needs microphone access for speech recognition.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>VoiceFlow needs accessibility access to type text and detect hotkeys.</string>
</dict>
</plist>
PLIST

echo "Done! App bundle at: $APP_DIR"
echo "Run with: open $APP_DIR"
