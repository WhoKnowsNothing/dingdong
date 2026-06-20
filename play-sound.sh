#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
[ ! -f "$CONFIG_FILE" ] && exit 0

# Read config: support v1 (flat) and v2 (nested) format
if command -v python3 &>/dev/null; then
  SOUND_PATH=$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    c = json.load(f)
# Detect v1 flat format
if isinstance(c.get('Stop'), str):
    val = c.get('$EVENT')
    print(val if val else '')
    sys.exit(0)
# v2 nested format
events = c.get('events', {})
evt = events.get('$EVENT', {})
t = evt.get('type', '')
if t == 'none':
    sys.exit(0)
if t == 'wav':
    print(evt.get('file', ''))
    sys.exit(0)
# fallback: unknown type or system → skip
sys.exit(0)
")
elif command -v jq &>/dev/null; then
  SOUND_PATH=$(jq -r --arg e "$EVENT" '
    if .Stop | type == "string" then
      .[$e] // ""
    else
      .events[$e] // {} | if .type == "none" then "" elif .type == "wav" then .file // "" else "" end
    end' "$CONFIG_FILE")
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
