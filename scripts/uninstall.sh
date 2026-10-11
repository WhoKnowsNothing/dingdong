#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -s)" in
  CYGWIN*|MINGW*|MSYS*)
    [ "${2:-false}" != true ] || { echo 'Use uninstall.ps1 -RemoveFiles on Windows.' >&2; exit 1; }
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$SCRIPT_DIR/uninstall.ps1")"
    ;;
esac
python3 "$SCRIPT_DIR/claude-settings.py" uninstall "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
if [ "${2:-false}" = true ]; then
  PLUGIN_DIR="${1:-$HOME/.claude/plugins/dingdong}"
  if [ "$PLUGIN_DIR" != "$HOME/.claude/plugins/dingdong" ] || [ -L "$PLUGIN_DIR" ]; then
    echo 'Only the default, unlinked plugin directory can be removed automatically.' >&2
    exit 1
  fi
  rm -rf -- "$PLUGIN_DIR"
fi
echo 'DingDong Claude Code hooks removed. Shared settings and sounds are retained for Codex.'
