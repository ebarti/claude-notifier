#!/bin/bash
# install.sh — Install ClaudeNotifier.app into ~/.claude/bin/ and create a CLI symlink
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeNotifier"
BINARY_NAME="claude-notifier"
APP_BUNDLE="$SCRIPT_DIR/build/$APP_NAME.app"
INSTALL_DIR="$HOME/.claude/bin"
SYMLINK_TARGET="/usr/local/bin/$BINARY_NAME"

# -------------------------------------------------------------------
# 1. Verify the .app bundle exists
# -------------------------------------------------------------------
if [ ! -d "$APP_BUNDLE" ]; then
    echo "ERROR: $APP_BUNDLE not found."
    echo "       Run ./build.sh first to compile the app."
    exit 1
fi

# -------------------------------------------------------------------
# 2. Copy .app to the install directory
# -------------------------------------------------------------------
echo "==> Installing $APP_NAME.app to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
# Remove any previous installation to get a clean copy
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
echo "    Installed: $INSTALL_DIR/$APP_NAME.app"

# -------------------------------------------------------------------
# 3. Create a symlink in /usr/local/bin for CLI access
# -------------------------------------------------------------------
INSTALLED_BINARY="$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/$BINARY_NAME"

echo "==> Creating symlink at $SYMLINK_TARGET..."
if [ -w "$(dirname "$SYMLINK_TARGET")" ]; then
    ln -sf "$INSTALLED_BINARY" "$SYMLINK_TARGET"
    echo "    Symlink created: $SYMLINK_TARGET -> $INSTALLED_BINARY"
else
    echo "    /usr/local/bin is not writable — trying with sudo..."
    if sudo ln -sf "$INSTALLED_BINARY" "$SYMLINK_TARGET"; then
        echo "    Symlink created: $SYMLINK_TARGET -> $INSTALLED_BINARY"
    else
        echo "    WARNING: Could not create symlink. You can add it manually:"
        echo "    ln -sf \"$INSTALLED_BINARY\" \"$SYMLINK_TARGET\""
    fi
fi

# -------------------------------------------------------------------
# 4. Send a test notification
# -------------------------------------------------------------------
echo "==> Sending test notification..."
"$INSTALLED_BINARY" -title "Claude Notifier" -message "Installation successful!"

# -------------------------------------------------------------------
# 5. Print Claude Code hook configuration
# -------------------------------------------------------------------
echo ""
echo "==> Installation complete!"
echo ""
echo "To use with Claude Code, add the following to your settings.json hooks config:"
echo ""
cat <<'HOOK_JSON'
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "claude-notifier"
          }
        ]
      }
    ]
  }
}
HOOK_JSON
