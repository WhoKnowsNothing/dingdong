#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config.json"

[ -f "$CONFIG_FILE" ] || { echo "config.json not found: $CONFIG_FILE" >&2; exit 1; }

# Extract file paths for the given event using grep/sed (zero deps)
FILES=$(grep -A10 "\"$EVENT\":" "$CONFIG_FILE" | grep '"file"' | sed 's/.*"file": *"\(.*\)",/\1/')

[ -z "$FILES" ] && exit 0

while IFS= read -r FILE; do
    RESOLVED="${FILE/\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_DIR}"
    "$SCRIPT_DIR/../players/play-wav.sh" "$RESOLVED"
done <<< "$FILES"
