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

# Step 2: Remove only DingDong Hook entries from settings.json
# Only touches hooks whose command contains "dingdong" or "play-sound.ps1"
# Other hooks (model-router, notify-feishu, etc.) are preserved.
if [ -f "$SETTINGS_FILE" ]; then
    CLEANED=0

    # Try PowerShell first (Windows), then python3 (Unix/macOS)
    if command -v powershell &>/dev/null; then
        powershell -NoProfile -Command "
\$config = Get-Content '$SETTINGS_FILE' -Raw | ConvertFrom-Json
\$hooks = \$config.hooks
if (-not \$hooks) { exit 0 }
\$eventsToRemove = @()
foreach (\$event in \$hooks.PSObject.Properties.Name) {
    \$matchers = \$hooks.\$event
    foreach (\$matcher in \$matchers) {
        if (\$matcher.hooks) {
            \$matcher.hooks = \$matcher.hooks | Where-Object {
                \$cmd = \$_.command
                \$cmd -notmatch 'dingdong' -and \$cmd -notmatch 'play-sound\\.ps1'
            }
        }
    }
    # Remove empty matcher entries
    \$hooks.\$event = \$matchers | Where-Object { \$_.hooks -and \$_.hooks.Count -gt 0 }
    if (-not \$hooks.\$event -or \$hooks.\$event.Count -eq 0) {
        \$eventsToRemove += \$event
    }
}
foreach (\$e in \$eventsToRemove) { \$hooks.PSObject.Properties.Remove(\$e) }
if (\$hooks.PSObject.Properties.Name.Count -eq 0) {
    \$config.PSObject.Properties.Remove('hooks')
}
\$config | ConvertTo-Json -Depth 10 | Set-Content '$SETTINGS_FILE'
Write-Output 'CLEANED'
" 2>&1 | grep -q CLEANED && { echo "[2/2] Removed DingDong hooks from settings.json"; CLEANED=1; }

    elif command -v python3 &>/dev/null; then
        python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    config = json.load(f)
hooks = config.get('hooks', {})
for event in list(hooks.keys()):
    matchers = hooks[event]
    for m in matchers:
        m['hooks'] = [h for h in m.get('hooks', [])
            if 'dingdong' not in h.get('command', '').lower()
            and 'play-sound.ps1' not in h.get('command', '')]
    hooks[event] = [m for m in matchers if m.get('hooks')]
    if not hooks[event]:
        del hooks[event]
if not hooks:
    del config['hooks']
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(config, f, indent=2)
" 2>&1 && { echo "[2/2] Removed DingDong hooks from settings.json"; CLEANED=1; }
    fi

    if [ "$CLEANED" -eq 0 ]; then
        echo "[2/2] Could not auto-clean. Manually remove entries with 'dingdong' or 'play-sound.ps1' from:"
        echo "      $SETTINGS_FILE"
    fi
else
    echo "[2/2] settings.json not found, nothing to clean"
fi

echo ""
echo "DingDong uninstalled."
echo "Run 'claude /hooks' in Claude Code to reload."
