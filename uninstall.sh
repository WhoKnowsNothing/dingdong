#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$HOME/.claude/plugins/dingdong"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTER_SCRIPT="$SCRIPT_DIR/hooks/register-hooks.ps1"

echo "DingDong Uninstaller"
echo "===================="
echo ""

# Step 1: Remove DingDong hooks from settings.json (BEFORE deleting files)
if [ -f "$SETTINGS_FILE" ]; then
    if command -v powershell &>/dev/null; then
        # Use register-hooks.ps1 from source project (survives plugin dir deletion)
        if [ -f "$REGISTER_SCRIPT" ] && powershell -NoProfile -ExecutionPolicy Bypass -File "$REGISTER_SCRIPT" -Uninstall > /dev/null 2>&1; then
            echo "[1/2] Removed DingDong hooks from settings.json"
        else
            echo "[1/2] Warning: Could not auto-clean settings.json"
        fi
    else
        echo "[1/2] PowerShell not found. Manual cleanup required."
    fi
else
    echo "[1/2] settings.json not found, nothing to clean"
fi

# Step 2: Remove plugin files
if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    echo "[2/2] Removed $PLUGIN_DIR"
else
    echo "[2/2] DingDong plugin directory not found"
fi

echo ""
echo "DingDong uninstalled."
echo "Run 'claude /hooks' in Claude Code to reload."
