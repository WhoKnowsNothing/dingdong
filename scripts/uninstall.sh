#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${1:-$HOME/.claude/plugins/dingdong}"
REMOVE_FILES="${2:-false}"

echo "DingDong Uninstaller"
echo "===================="

# Remove hooks from settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json
try:
    with open('$SETTINGS_FILE') as f:
        settings = json.load(f)
    if 'hooks' in settings:
        del settings['hooks']
        with open('$SETTINGS_FILE', 'w') as f:
            json.dump(settings, f, indent=2)
        print('Hooks removed')
    else:
        print('No hooks found')
except (FileNotFoundError, json.JSONDecodeError):
    print('No settings file')
"
elif [ ! -f "$SETTINGS_FILE" ]; then
    echo "settings.json not found."
fi

if [ "$REMOVE_FILES" = "true" ] && [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    echo "Plugin files removed from: $PLUGIN_DIR"
fi

echo "Done. Run '/hooks' or restart Claude Code."
