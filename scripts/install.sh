#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
case "$(uname -s)" in
  CYGWIN*|MINGW*|MSYS*)
    args=()
    [ -z "${1:-}" ] || args=(-TargetDir "$(cygpath -w "$1")")
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$SCRIPT_DIR/install.ps1")" "${args[@]}"
    ;;
esac
command -v python3 >/dev/null || { echo 'python3 is required to register Claude Code hooks.' >&2; exit 1; }
PLUGIN_DIR="${1:-$HOME/.claude/plugins/dingdong}"
source "$SCRIPT_DIR/data-paths.sh"
SEED_ROOT="$PROJECT_ROOT"
[ ! -f "$PLUGIN_DIR/config.json" ] || SEED_ROOT="$PLUGIN_DIR"
DATA_ROOT="$(dingdong_initialize_data "$SEED_ROOT")"
mkdir -p "$PLUGIN_DIR/scripts" "$PLUGIN_DIR/sounds"
if [ "$(cd "$PLUGIN_DIR" && pwd)" != "$PROJECT_ROOT" ]; then
  cp "$PROJECT_ROOT/play-sound.sh" "$PROJECT_ROOT/config.sh" "$PLUGIN_DIR/"
  cp "$SCRIPT_DIR/data-paths.sh" "$PLUGIN_DIR/scripts/"
  cp -n "$PROJECT_ROOT/config.json" "$PLUGIN_DIR/config.json"
  for sound in "$PROJECT_ROOT/sounds/"*.wav; do cp -n "$sound" "$PLUGIN_DIR/sounds/"; done
fi
python3 "$SCRIPT_DIR/claude-settings.py" install "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" "$PROJECT_ROOT/hooks.unix.json" "$PLUGIN_DIR"
echo "Shared Claude Code / Codex settings: $DATA_ROOT/config.json"
echo 'Restart Claude Code to load the updated hooks.'
