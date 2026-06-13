#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$HOME/.claude/plugins/dingdong"

echo "Uninstalling DingDong..."
if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    echo "Removed $PLUGIN_DIR"
else
    echo "DingDong not found at $PLUGIN_DIR"
fi

echo ""
echo "Manual cleanup: Remove dingdong hook entries from ~/.claude/settings.json"
echo "Then run: claude /hooks"
