#!/usr/bin/env bash
set -euo pipefail

# Detect OS
case "$(uname -s)" in
    Darwin*)  OS="darwin" ;;
    Linux*)   OS="linux" ;;
    CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
    *)        echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

PLUGIN_DIR="$HOME/.claude/plugins/dingdong"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "DingDong Installer"
echo "=================="
echo "OS: $OS"
echo "Target: $PLUGIN_DIR"

# Create target dirs
mkdir -p "$PLUGIN_DIR/sounds"
mkdir -p "$PLUGIN_DIR/events"
mkdir -p "$PLUGIN_DIR/players"
mkdir -p "$PLUGIN_DIR/preview"
mkdir -p "$PLUGIN_DIR/hooks"

# Copy shared files
cp -f "$SCRIPT_DIR/config.json" "$PLUGIN_DIR/"
cp -f "$SCRIPT_DIR/sounds/"*.wav "$PLUGIN_DIR/sounds/" 2>/dev/null || true

# Copy platform-specific files
if [ "$OS" = "windows" ]; then
    cp -f "$SCRIPT_DIR/events/event-bus.ps1" "$PLUGIN_DIR/events/"
    cp -f "$SCRIPT_DIR/players/play-wav.ps1" "$PLUGIN_DIR/players/"
    cp -f "$SCRIPT_DIR/players/play-system.ps1" "$PLUGIN_DIR/players/"
    cp -f "$SCRIPT_DIR/preview/preview.ps1" "$PLUGIN_DIR/preview/"
    cp -f "$SCRIPT_DIR/hooks/hooks.json" "$PLUGIN_DIR/hooks/"
else
    cp -f "$SCRIPT_DIR/events/event-bus.sh" "$PLUGIN_DIR/events/"
    cp -f "$SCRIPT_DIR/players/play-wav.sh" "$PLUGIN_DIR/players/"
    cp -f "$SCRIPT_DIR/players/play-system.sh" "$PLUGIN_DIR/players/"
    cp -f "$SCRIPT_DIR/preview/preview.sh" "$PLUGIN_DIR/preview/"
    cp -f "$SCRIPT_DIR/hooks/hooks.json" "$PLUGIN_DIR/hooks/"
    chmod +x "$PLUGIN_DIR/events/"*.sh "$PLUGIN_DIR/players/"*.sh "$PLUGIN_DIR/preview/"*.sh 2>/dev/null || true
fi

# Register hooks in settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Registering hooks in $SETTINGS_FILE..."
    echo ""
    echo "Manual step: Add the following to your settings.json hooks section:"
    echo "  See $PLUGIN_DIR/hooks/hooks.json for the hook definitions"
    echo "  Then run: claude /hooks  (or restart Claude Code)"
else
    echo "settings.json not found at $SETTINGS_FILE"
    echo "Create it manually, or run Claude Code once to auto-generate it."
fi

echo ""
echo "DingDong installed to $PLUGIN_DIR"
echo ""
echo "Next steps:"
echo "  1. Preview sounds:"
if [ "$OS" = "windows" ]; then
    echo "     powershell -File \"$PLUGIN_DIR/preview/preview.ps1\""
else
    echo "     $PLUGIN_DIR/preview/preview.sh"
fi
echo "  2. Register hooks from $PLUGIN_DIR/hooks/hooks.json in your settings.json"
echo "  3. Run /hooks in Claude Code to reload"
