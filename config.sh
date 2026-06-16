#!/usr/bin/env bash
# DingDong — Interactive configuration terminal UI (zero dependencies)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_CONFIG="$SCRIPT_DIR/config.json"
CONFIG_FILE="$PROJECT_CONFIG"
SOUNDS_DIR="$SCRIPT_DIR/sounds"

# Detect plugin installation (hooks use this path)
PLUGIN_DIR="$HOME/.claude/plugins/dingdong"
[ -d "$PLUGIN_DIR" ] && PLUGIN_CONFIG="$PLUGIN_DIR/config.json" || PLUGIN_CONFIG=""

EVENTS=("Stop" "Notification" "PermissionRequest" "Elicitation" "TeammateIdle")
DESCRIPTIONS=(
  "Task complete / conversation end"
  "System notification popup"
  "Permission prompt shown"
  "Claude asks you a question"
  "Agent idle / waiting"
)

# ── helpers ──────────────────────────────────────────────────────────

clear_screen() { printf "\033c" >&2; }

list_sounds() {
  for f in "$SOUNDS_DIR"/*.wav; do
    [ -f "$f" ] && basename "$f"
  done 2>/dev/null || true
}

# Read current config value for an event key
get_config() {
  local key="$1"
  grep -o "\"$key\":\s*\(null\|\"[^\"]*\"\)" "$CONFIG_FILE" 2>/dev/null \
    | sed 's/.*:\s*//' | sed 's/^"//;s/"$//'
}

# Strip sounds/ prefix and .wav for cleaner display
friendly_name() {
  local val="$1"
  val="${val#sounds/}"
  val="${val%.wav}"
  echo "$val"
}

# Display current value as human-friendly label
display_value() {
  local val="$1"
  if [ "$val" = "null" ] || [ -z "$val" ]; then
    echo "Silent"
  else
    friendly_name "$val"
  fi
}

# Preview a sound file (cross-platform)
preview_sound() {
  local file="$1"
  [ ! -f "$file" ] && return
  case "$(uname -s)" in
    Darwin)  afplay "$file" 2>/dev/null ;;
    Linux)   (paplay "$file" 2>/dev/null || aplay "$file" 2>/dev/null) ;;
    *)       powershell -c "(New-Object Media.SoundPlayer '$file').PlaySync()" 2>/dev/null ;;
  esac || true
}

# ── picker menu (all display goes to stderr, only result to stdout) ──

pick_sound() {
  local event="$1" current_val="$2"
  local sounds=()
  while IFS= read -r s; do sounds+=("$s"); done < <(list_sounds)
  local current_label
  current_label="$(display_value "$current_val")"

  while true; do
    clear_screen
    echo "==========================================" >&2
    echo "  $event  (B = back, P = preview)" >&2
    echo "==========================================" >&2
    echo "" >&2
    echo "   [0] Silent $( [ "$current_label" = "Silent" ] && echo '<--')" >&2
    local i=1
    for s in "${sounds[@]}"; do
      label="${s%.wav}"
      printf "   [%d] %s %s\n" $i "$label" "$( [ "$label" = "$current_label" ] && echo '<--')" >&2
      i=$((i+1))
    done
    echo "" >&2
    printf "  > " >&2
    read -r ch

    case "$ch" in
      [Bb]) return 1 ;;
      [Pp])
        [ "$current_label" != "Silent" ] && preview_sound "$SOUNDS_DIR/$current_label.wav"
        continue
        ;;
      *)
        local total=$((1 + ${#sounds[@]}))
        if [[ "$ch" =~ ^[0-9]+$ ]] && [ "$ch" -ge 0 ] && [ "$ch" -lt "$total" ]; then
          if [ "$ch" -eq 0 ]; then
            echo "null"
            return 0
          else
            local picked="${sounds[$((ch-1))]}"
            preview_sound "$SOUNDS_DIR/$picked"
            echo "sounds/$picked"
            return 0
          fi
        fi
        ;;
    esac
  done
}

# ── save ─────────────────────────────────────────────────────────────

save_config() {
  local -n pairs=$1
  local json="{"
  local first=true
  for evt in "${EVENTS[@]}"; do
    $first && first=false || json+=", "
    local val="${pairs[$evt]}"
    if [ "$val" = "null" ] || [ -z "$val" ]; then
      json+="\"$evt\": null"
    else
      json+="\"$evt\": \"$val\""
    fi
  done
  json+="}"
  printf "%s\n" "$json" > "$CONFIG_FILE"
  # Also sync to project config if we were reading from plugin
  if [ "$CONFIG_FILE" != "$PROJECT_CONFIG" ]; then
    printf "%s\n" "$json" > "$PROJECT_CONFIG"
  fi
}

# ── main ─────────────────────────────────────────────────────────────

# Read current values (prefer plugin config if installed)
if [ -n "$PLUGIN_CONFIG" ]; then
  CONFIG_FILE="$PLUGIN_CONFIG"
fi
declare -A VALUES
for evt in "${EVENTS[@]}"; do
  VALUES["$evt"]="$(get_config "$evt")"
done

while true; do
  clear_screen
  echo "==========================================" >&2
  echo "  DingDong — Sound Configuration" >&2
  echo "==========================================" >&2
  echo "" >&2
  for i in "${!EVENTS[@]}"; do
    evt="${EVENTS[$i]}"
    val="${VALUES[$evt]}"
    printf "  [%d]  %-20s  →  %s\n" $((i+1)) "$evt" "$(display_value "$val")" >&2
    printf "       (%s)\n" "${DESCRIPTIONS[$i]}" >&2
    echo "" >&2
  done
  echo "  [S]  Save & exit" >&2
  echo "  [Q]  Quit without saving" >&2
  echo "" >&2
  printf "  > " >&2
  read -r choice

  case "$choice" in
    [Qq]) exit 0 ;;
    [Ss])
      save_config VALUES
      echo "" >&2
      echo "  Configuration saved to config.json" >&2
      echo "  Restart Claude Code or run '/hooks' to apply." >&2
      exit 0
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#EVENTS[@]}" ]; then
        idx=$((choice-1))
        evt="${EVENTS[$idx]}"
        old_val="${VALUES[$evt]}"
        result="$(pick_sound "$evt" "$old_val")" || continue
        VALUES["$evt"]="$result"
      fi
      ;;
  esac
done
