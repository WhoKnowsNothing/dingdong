#!/usr/bin/env bash
# DingDong — 交互终端配置工具 (跨平台)
# 零依赖: bash 4+ + ANSI escape codes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
SOUNDS_DIR="$SCRIPT_DIR/sounds"

EVENTS=("Stop" "Notification" "PermissionRequest" "Elicitation" "TeammateIdle")
DESCRIPTIONS=(
  "对话结束"
  "任务通知"
  "权限请求"
  "提问澄清"
  "空闲等待"
)

# ── helpers ──────────────────────────────────────────────────────────

clear_screen() { printf "\033c" >&2; }

list_sounds() {
  local files=()
  for f in "$SOUNDS_DIR"/*.wav; do
    [ -f "$f" ] && files+=("$(basename "$f")")
  done
  printf "%s\n" "${files[@]}" | sort
}

# Read current event config from v1 or v2 format
read_config() {
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    c = json.load(f)
# v1 flat
if isinstance(c.get('Stop'), str):
    for evt in ['Stop','Notification','PermissionRequest','Elicitation','TeammateIdle']:
        v = c.get(evt)
        if v and isinstance(v, str):
            print(f'{evt}|wav|{v}')
        else:
            print(f'{evt}|none|')
    sys.exit(0)
# v2 nested
events = c.get('events', {})
for evt in ['Stop','Notification','PermissionRequest','Elicitation','TeammateIdle']:
    e = events.get(evt, {})
    t = e.get('type', 'none')
    if t == 'wav':
        print(f'{evt}|wav|{e.get(\"file\", \"\")}')
    elif t == 'system':
        print(f'{evt}|system|{e.get(\"sound\", \"\")}')
    else:
        print(f'{evt}|none|')
"
  elif command -v jq &>/dev/null; then
    jq -r --argjson evts '["Stop","Notification","PermissionRequest","Elicitation","TeammateIdle"]' '
      if .Stop | type == "string" then
        $evts[] | "\(.)|\(if . as $e | .[$e] | type == "string" then "wav|\(.[$e])" else "none|" end)"
      else
        $evts[] | "\(.)|\(if .events[.].type == "wav" then "wav|\(.events[.].file)" elif .events[.].type == "system" then "system|\(.events[.].sound)" else "none|" end)"
      end
    ' "$CONFIG_FILE"
  else
    return 1
  fi
}

write_config() {
  local -n data=$1
  local json="{"
  local first=true
  for evt in "${EVENTS[@]}"; do
    $first && first=false || json+=", "
    local line="${data[$evt]}"
    local type="${line%%|*}"
    local rest="${line#*|}"
    local val="${rest#*|}"
    if [ "$type" = "none" ]; then
      json+="\"$evt\": {\"type\": \"none\"}"
    elif [ "$type" = "system" ]; then
      json+="\"$evt\": {\"type\": \"system\", \"sound\": \"$val\"}"
    else
      json+="\"$evt\": {\"type\": \"wav\", \"file\": \"$val\"}"
    fi
  done
  json+="}"
  local full="{\"version\": 2, \"volume\": 80, \"events\": $json}"
  printf "%s\n" "$full" > "$CONFIG_FILE"
}

friendly_name() {
  local val="$1"
  val="${val#sounds/}"
  val="${val%.wav}"
  echo "$val"
}

preview_sound() {
  local file="$1"
  [ ! -f "$file" ] && return
  case "$(uname -s)" in
    Darwin)  afplay "$file" 2>/dev/null ;;
    Linux)   (paplay "$file" 2>/dev/null || aplay "$file" 2>/dev/null) ;;
    *)       powershell -c "
Add-Type @'
using System.Runtime.InteropServices;
public class DD {
    [DllImport(\"winmm.dll\", SetLastError=true)]
    public static extern bool PlaySound(string p, System.IntPtr h, uint f);
}
'@
[DD]::PlaySound('$file', [System.IntPtr]::Zero, 0x00020000)" 2>/dev/null ;;
  esac || true
}

import_sound() {
  echo "" >&2
  printf "  请输入 WAV 文件的绝对路径: " >&2
  read -r import_path
  import_path="${import_path/#\~/$HOME}"
  if [ ! -f "$import_path" ]; then
    echo "  文件不存在" >&2
    sleep 1
    return 1
  fi
  if [[ "$import_path" != *.wav && "$import_path" != *.WAV ]]; then
    echo "  仅支持 WAV 格式" >&2
    sleep 1
    return 1
  fi
  cp "$import_path" "$SOUNDS_DIR/"
  echo "  已导入: $(basename "$import_path")" >&2
  sleep 1
}

# ── main ────────────────────────────────────────────────────────────

mkdir -p "$SOUNDS_DIR"

# Read current config
declare -A CURRENT
if ! read_config > /dev/null 2>&1; then
  echo "Warning: jq or python3 required for config reading" >&2
fi

while IFS='|' read -r evt type val; do
  CURRENT["$evt"]="${type}|${val}"
done < <(read_config 2>/dev/null || true)

while true; do
  clear_screen
  echo "╔══════════════════════════════════════╗" >&2
  echo "║     DingDong 叮咚 · 配置            ║" >&2
  echo "╠══════════════════════════════════════╣" >&2
  echo "║  仅支持 WAV 格式                    ║" >&2
  echo "╚══════════════════════════════════════╝" >&2
  echo "" >&2

  for i in "${!EVENTS[@]}"; do
    evt="${EVENTS[$i]}"
    desc="${DESCRIPTIONS[$i]}"
    line="${CURRENT[$evt]:-none|}"
    type="${line%%|*}"
    rest="${line#*|}"
    val="${rest#*|}"
    case "$type" in
      none)   display="静音" ;;
      system) display="系统: $val" ;;
      wav)    display="$(friendly_name "$val")" ;;
      *)      display="???" ;;
    esac
    printf "  [%d]  %-20s  →  %s\n" $((i+1)) "$evt ($desc)" "$display" >&2
  done

  echo "" >&2
  echo "  [I] 导入音频" >&2
  echo "  [S] 保存配置" >&2
  echo "  [Q] 退出" >&2
  echo "" >&2
  printf "  > " >&2
  read -r choice

  case "$choice" in
    [Qq]) exit 0 ;;
    [Ss])
      write_config CURRENT
      echo "" >&2
      echo "  ✓ 配置已保存到 config.json" >&2
      echo "  重启 Claude Code 或执行 /hooks 以生效。" >&2
      sleep 1
      ;;
    [Ii])
      import_sound || true
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#EVENTS[@]}" ]; then
        idx=$((choice-1))
        evt="${EVENTS[$idx]}"

        # ── secondary selection page ──
        local_sounds=()
        while IFS= read -r s; do local_sounds+=("$s"); done < <(list_sounds)
        current_line="${CURRENT[$evt]:-none|}"
        current_type="${current_line%%|*}"
        rest="${current_line#*|}"
        current_val="${rest#*|}"

        while true; do
          clear_screen
          echo "╔══════════════════════════════════════╗" >&2
          printf "║  %-36s ║\n" "$evt" >&2
          echo "╚══════════════════════════════════════╝" >&2
          echo "" >&2
          echo "  0) 静音 $([ "$current_type" = "none" ] && echo '← 当前')" >&2
          i=1
          for s in "${local_sounds[@]}"; do
            label="$(friendly_name "$s")"
            marker=""
            [ "$label" = "$(friendly_name "$current_val")" ] && [ "$current_type" = "wav" ] && marker="← 当前"
            printf "  %d) %s %s\n" $i "$label" "$marker" >&2
            i=$((i+1))
          done
          echo "" >&2
          echo "  [B] 返回  [/] 搜索" >&2
          echo "  仅支持 WAV 格式" >&2
          echo "" >&2
          printf "  > " >&2
          read -r sub_choice

          case "$sub_choice" in
            [Bb]) break ;;
            *)
              if [ "$sub_choice" = "0" ]; then
                CURRENT["$evt"]="none|"
                break
              elif [[ "$sub_choice" =~ ^[0-9]+$ ]] && [ "$sub_choice" -ge 1 ] && [ "$sub_choice" -le "${#local_sounds[@]}" ]; then
                picked="${local_sounds[$((sub_choice-1))]}"
                CURRENT["$evt"]="wav|sounds/$picked"
                preview_sound "$SOUNDS_DIR/$picked"
                break
              fi
              ;;
          esac
        done
      fi
      ;;
  esac
done
