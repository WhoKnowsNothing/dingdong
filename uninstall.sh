#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$HOME/.claude/plugins/dingdong"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "DingDong Uninstaller"
echo "===================="
echo ""

# Step 1: Remove plugin files
if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    echo "[1/2] Removed $PLUGIN_DIR"
else
    echo "[1/2] DingDong not found at $PLUGIN_DIR"
fi

# Step 2: Remove DingDong hooks from settings.json
if [ -f "$SETTINGS_FILE" ]; then
    # Check for lingering dingdong hooks and remove them
    # Use register-hooks.ps1 if it still exists, or inline PowerShell
    REGISTER_SCRIPT="$PLUGIN_DIR/hooks/register-hooks.ps1"
    if [ -f "$REGISTER_SCRIPT" ]; then
        powershell -NoProfile -ExecutionPolicy Bypass -File "$REGISTER_SCRIPT" -Uninstall 2>&1 | grep -q OK && \
            echo "[2/2] Removed DingDong hooks from settings.json" || \
            echo "[2/2] Warning: Could not clean settings.json"
    elif command -v powershell &>/dev/null; then
        # Fallback: inline cleanup for hooks with dingdong/event-bus/play-sound in their command
        powershell -NoProfile -Command "
            \$json = Get-Content '$SETTINGS_FILE' -Raw
            \$config = \$json | ConvertFrom-Json
            if (-not \$config.hooks) { exit 0 }
            \$hooks = \$config.hooks
            \$eventsToRemove = @()
            foreach (\$prop in \$hooks.PSObject.Properties) {
                \$keepers = @()
                foreach (\$matcher in \$prop.Value) {
                    if (\$matcher.hooks) {
                        \$kept = \$matcher.hooks | Where-Object { \$_.command -notmatch 'dingdong|event-bus\\.ps1|play-sound\\.ps1' }
                        if (\$kept) { \$matcher.hooks = \$kept; \$keepers += \$matcher }
                    }
                }
                if (\$keepers.Count -gt 0) { \$hooks.\$(\$prop.Name) = \$keepers }
                else { \$eventsToRemove += \$prop.Name }
            }
            foreach (\$e in \$eventsToRemove) { \$hooks.PSObject.Properties.Remove(\$e) }
            if (-not \$hooks.PSObject.Properties.Name) { \$config.PSObject.Properties.Remove('hooks') }
            \$config | ConvertTo-Json -Depth 10 | Set-Content '$SETTINGS_FILE'
            Write-Output 'OK'
        " 2>&1 | grep -q OK && echo "[2/2] Removed DingDong hooks from settings.json" || \
            echo "[2/2] Manual: Remove dingdong hooks from $SETTINGS_FILE"
    else
        echo "[2/2] Manual: Remove dingdong hooks from $SETTINGS_FILE"
    fi
else
    echo "[2/2] settings.json not found, nothing to clean"
fi

echo ""
echo "DingDong uninstalled."
echo "Run 'claude /hooks' in Claude Code to reload."
