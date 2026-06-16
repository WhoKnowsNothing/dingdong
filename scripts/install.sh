#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect OS
case "$(uname -s)" in
    Darwin*)  OS="darwin" ;;
    Linux*)   OS="linux" ;;
    CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
    *)        echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

PLUGIN_DIR="${1:-$HOME/.claude/plugins/dingdong}"

echo "DingDong Installer"
echo "=================="
echo "OS: $OS"
echo "Target: $PLUGIN_DIR"

# Create directories
mkdir -p "$PLUGIN_DIR/sounds"

# Copy files
cp -f "$PROJECT_ROOT/play-sound.sh" "$PLUGIN_DIR/"
cp -f "$PROJECT_ROOT/config.json" "$PLUGIN_DIR/"
cp -f "$PROJECT_ROOT/sounds/"*.wav "$PLUGIN_DIR/sounds/" 2>/dev/null || true
chmod +x "$PLUGIN_DIR/play-sound.sh" 2>/dev/null || true

# Select hooks file
HOOKS_SRC="$PROJECT_ROOT/hooks.unix.json"
if [ "$OS" = "windows" ]; then
    HOOKS_SRC="$PROJECT_ROOT/hooks.json"
fi

# Register hooks in settings.json
SETTINGS_DIR="$HOME/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys

# Read existing settings
settings = {}
try:
    with open('$SETTINGS_FILE') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

# Read hooks definition
with open('$HOOKS_SRC') as f:
    hooks_def = json.load(f)

settings['hooks'] = hooks_def['hooks']

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
print('OK')
"
    echo "Done! Hooks registered in $SETTINGS_FILE"
else
    echo "Warning: python3 not found. Cannot auto-register hooks."
    echo "Manual: merge $HOOKS_SRC into $SETTINGS_FILE"
fi

echo "Run '/hooks' in Claude Code or restart to apply."
