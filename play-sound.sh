#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

[ ! -f "$CONFIG_FILE" ] && exit 0

# Read sound file path for the event from config.json
if command -v jq &>/dev/null; then
  SOUND_PATH=$(jq -r --arg e "$EVENT" '(.[$e] // "null") | if . == "null" then "" else . end' "$CONFIG_FILE")
elif command -v python3 &>/dev/null; then
  SOUND_PATH=$(python3 -c "
import json, sys
try:
  with open('$CONFIG_FILE') as f:
    c = json.load(f)
  v = c.get('$EVENT')
  print(v if v else '')
except: pass
" 2>/dev/null)
else
  exit 0
fi

[ -z "$SOUND_PATH" ] && exit 0

WAV_FILE="$SCRIPT_DIR/$SOUND_PATH"
[ ! -f "$WAV_FILE" ] && exit 0

if [[ "$OSTYPE" == "darwin"* ]]; then
  afplay "$WAV_FILE"
elif command -v paplay &>/dev/null; then
  paplay "$WAV_FILE"
elif command -v aplay &>/dev/null; then
  aplay "$WAV_FILE"
fi
