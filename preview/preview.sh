#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOUNDS_DIR="$PROJECT_DIR/sounds"
CONFIG_FILE="$PROJECT_DIR/config.json"
PLAYERS_DIR="$PROJECT_DIR/players"

sounds=()
while IFS= read -r f; do
    sounds+=("wav:$(basename "$f"):$f")
done < <(find "$SOUNDS_DIR" -name '*.wav' | sort)
for s in Asterisk Question Exclamation Hand Beep; do
    sounds+=("system:$s:")
done

echo ""
echo "DingDong Sound Preview"
echo "======================"
for i in "${!sounds[@]}"; do
    IFS=':' read -r type name path <<< "${sounds[$i]}"
    if [ "$type" = system ]; then
        printf "[%2d] [System] %s\n" $((i+1)) "$name"
    else
        printf "[%2d] %s\n" $((i+1)) "$name"
    fi
done

read -p $'\nNumber to preview (or q): ' choice
[ "$choice" = q ] && exit 0
idx=$((choice - 1))
[ "$idx" -lt 0 ] || [ "$idx" -ge "${#sounds[@]}" ] && { echo "Invalid"; exit 1; }

IFS=':' read -r type name path <<< "${sounds[$idx]}"
echo ">> $name"
if [ "$type" = wav ]; then
    "$PLAYERS_DIR/play-wav.sh" "$path"
else
    echo -e "\a"
fi

read -p $'\nAssign to event? (Stop/Notification/... or Enter to skip): ' assign
if [ -n "$assign" ]; then
    if [ "$type" = wav ]; then
        entry="{\"type\":\"wav\",\"file\":\"\${CLAUDE_PLUGIN_ROOT}/sounds/$name\",\"label\":\"${name%.wav}\"}"
    else
        entry="{\"type\":\"system\",\"sound\":\"$name\",\"label\":\"System $name\"}"
    fi
    # Use Python for safe JSON editing to avoid sed JSON corruption
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
config['subscriptions']['$assign'] = [json.loads('$entry')]
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null && echo "OK $assign -> $name" || {
    echo "Warning: Could not update config.json. Python3 required for safe JSON editing."
    echo "Manual: Add to config.json: \"$assign\": [$entry]"
}
fi
