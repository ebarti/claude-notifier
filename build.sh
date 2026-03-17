#!/bin/bash
# build.sh — Compile and bundle ClaudeNotifier as a macOS .app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="ClaudeNotifier"
BINARY_NAME="claude-notifier"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME..."

# -------------------------------------------------------------------
# 1. Prepare the build directory
# -------------------------------------------------------------------
mkdir -p "$BUILD_DIR"

# -------------------------------------------------------------------
# 2. Compile the Swift source
# -------------------------------------------------------------------
echo "==> Compiling Sources/main.swift..."
swiftc -O -o "$BUILD_DIR/$BINARY_NAME" "$SCRIPT_DIR/Sources/main.swift"
echo "    Binary: $BUILD_DIR/$BINARY_NAME"

# -------------------------------------------------------------------
# 3. Create the .app bundle structure
#
#    ClaudeNotifier.app/
#    └── Contents/
#        ├── Info.plist
#        ├── MacOS/
#        │   └── claude-notifier
#        └── Resources/
#            └── AppIcon.icns
# -------------------------------------------------------------------
echo "==> Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the compiled binary
cp "$BUILD_DIR/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# -------------------------------------------------------------------
# 4. Handle the app icon
# -------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "    Icon copied from Resources/AppIcon.icns"
elif [ -x "$SCRIPT_DIR/generate-icon.sh" ]; then
    echo "==> AppIcon.icns not found — running generate-icon.sh..."
    "$SCRIPT_DIR/generate-icon.sh"
    if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
        cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
        echo "    Icon generated and copied."
    else
        echo "    WARNING: generate-icon.sh ran but Resources/AppIcon.icns still missing."
    fi
else
    echo "    WARNING: No AppIcon.icns found and no generate-icon.sh available."
    echo "             The app will use the default macOS icon."
fi

# -------------------------------------------------------------------
# 5. Ad-hoc code sign
# -------------------------------------------------------------------
echo "==> Signing app bundle (ad-hoc)..."
codesign --force --sign - "$APP_BUNDLE"

# -------------------------------------------------------------------
# 6. Done
# -------------------------------------------------------------------
echo ""
echo "==> Build complete!"
echo "    $APP_BUNDLE"
