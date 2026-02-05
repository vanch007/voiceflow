#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="VoiceFlow"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"

echo "🚀 Starting Package Process..."

# 1. Build the App
echo "🔨 Building Application..."
"$SCRIPT_DIR/build.sh"

# 2. Compile Assets (App Icon)
echo "🎨 Compiling Assets..."
if [ -d "$PROJECT_DIR/VoiceFlow/VoiceFlow/Assets.xcassets" ]; then
    mkdir -p "$APP_PATH/Contents/Resources"
    xcrun actool "$PROJECT_DIR/VoiceFlow/VoiceFlow/Assets.xcassets" \
        --compile "$APP_PATH/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 11.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "/tmp/assetcatalog_generated_info.plist"
    echo "✅ Assets compiled."

    # Patch Info.plist to reference the icon
    echo "📝 Updating Info.plist..."
    # Ensure CFBundleIconFile is set to AppIcon
    plutil -replace CFBundleIconFile -string "AppIcon" "$APP_PATH/Contents/Info.plist"
    # Ensure CFBundleIconName is set to AppIcon (for asset catalog usage)
    plutil -replace CFBundleIconName -string "AppIcon" "$APP_PATH/Contents/Info.plist"
    
    # Touch the app to invalidate cache
    touch "$APP_PATH"
else
    echo "⚠️  Assets.xcassets not found, skipping icon compilation."
fi

# 3. Create DMG Layout
echo "📦 Preparing DMG Layout..."
DMG_ROOT="$PROJECT_DIR/dmg_root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"

# Copy App
echo "   Copying $APP_NAME.app..."
ditto "$APP_PATH" "$DMG_ROOT/$APP_NAME.app"

# Create /Applications Symlink
echo "   Creating /Applications shortcut..."
ln -s /Applications "$DMG_ROOT/Applications"

# 4. Create DMG
echo "💿 Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "🧹 Cleaning up..."
rm -rf "$DMG_ROOT"

echo "✅ DMG Creation Complete!"
echo "   → $DMG_PATH"
ls -lh "$DMG_PATH"
