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
    cp -f "$SCRIPT_DIR/hooks/hooks.unix.json" "$PLUGIN_DIR/hooks/hooks.json"
    chmod +x "$PLUGIN_DIR/events/"*.sh "$PLUGIN_DIR/players/"*.sh "$PLUGIN_DIR/preview/"*.sh 2>/dev/null || true
fi

# Copy register-hooks.ps1 (always, for both install and uninstall)
cp -f "$SCRIPT_DIR/hooks/register-hooks.ps1" "$PLUGIN_DIR/hooks/"

# Register hooks in settings.json
if [ -f "$HOME/.claude/settings.json" ]; then
    echo "Registering hooks..."
    if powershell -NoProfile -ExecutionPolicy Bypass -File "$PLUGIN_DIR/hooks/register-hooks.ps1" 2>&1 | grep -q OK; then
        echo "  DingDong hooks registered in settings.json"
    else
        echo "  Warning: Could not auto-register hooks."
        echo "  Manual: See $PLUGIN_DIR/hooks/hooks.json"
    fi
else
    echo "settings.json not found. Run Claude Code once to create it, then reinstall."
fi

echo ""
echo "DingDong installed to $PLUGIN_DIR"
echo "Run '/hooks' in Claude Code to reload, or restart."
