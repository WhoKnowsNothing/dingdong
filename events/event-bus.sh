#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config.json"

[ -f "$CONFIG_FILE" ] || { echo "config.json not found: $CONFIG_FILE" >&2; exit 1; }

# Extract wav file paths for the given event
FILES=$(grep -A10 "\"$EVENT\":" "$CONFIG_FILE" | grep '"file"' | sed 's/.*"file": *"\(.*\)",/\1/')
# Extract system sound names for the given event
SYSTEM_SOUNDS=$(grep -A10 "\"$EVENT\":" "$CONFIG_FILE" | grep '"sound"' | sed 's/.*"sound": *"\(.*\)",/\1/')

# Play wav files
[ -n "$FILES" ] && while IFS= read -r FILE; do
    RESOLVED="${FILE/\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_DIR}"
    "$SCRIPT_DIR/../players/play-wav.sh" "$RESOLVED"
done <<< "$FILES"

# Play system sounds
[ -n "$SYSTEM_SOUNDS" ] && while IFS= read -r SOUND; do
    "$SCRIPT_DIR/../players/play-system.sh" "$SOUND"
done <<< "$SYSTEM_SOUNDS"
