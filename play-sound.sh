#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/data-paths.sh"
DATA_DIR="$(dingdong_data_root)"
[ ! -f "$DATA_DIR/config.json" ] || SCRIPT_DIR="$DATA_DIR"
CONFIG_FILE="$SCRIPT_DIR/config.json"
[ ! -f "$CONFIG_FILE" ] && exit 0

# Read config: support v1 (flat) and v2 (nested) format
if command -v python3 &>/dev/null && python3 --version &>/dev/null; then
  SOUND_PATH=$(python3 - "$CONFIG_FILE" "$EVENT" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8-sig') as f:
    c = json.load(f)
# Detect v1 flat format
if isinstance(c.get('Stop'), str):
    val = c.get(sys.argv[2])
    print(val if val else '')
    sys.exit(0)
# v2 nested format
events = c.get('events', {})
evt = events.get(sys.argv[2], {})
t = evt.get('type', '')
if t == 'none':
    sys.exit(0)
if t == 'wav':
    print(evt.get('file', ''))
    sys.exit(0)
# fallback: unknown type or system → skip
sys.exit(0)
PY
)
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

case "$SOUND_PATH" in
  /*|[A-Za-z]:[\\/]*) WAV_FILE="$SOUND_PATH" ;;
  *) WAV_FILE="$SCRIPT_DIR/$SOUND_PATH" ;;
esac
[ ! -f "$WAV_FILE" ] && exit 0

if [[ "$OSTYPE" == "darwin"* ]]; then
  afplay "$WAV_FILE"
elif command -v paplay &>/dev/null; then
  paplay "$WAV_FILE"
elif command -v aplay &>/dev/null; then
  aplay "$WAV_FILE"
fi
