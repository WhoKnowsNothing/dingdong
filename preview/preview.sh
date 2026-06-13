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
    entry="{\"type\":\"$type\",\"file\":\"\${CLAUDE_PLUGIN_ROOT}/sounds/$name\",\"label\":\"${name%.wav}\"}"
    if [ "$type" = system ]; then
        entry="{\"type\":\"system\",\"sound\":\"$name\",\"label\":\"System $name\"}"
    fi
    sed -i "/\"$assign\":/c\\"$assign\": [$entry]," "$CONFIG_FILE"
    echo "OK $assign -> $name"
fi
