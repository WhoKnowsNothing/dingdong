#!/usr/bin/env bash
# Drain the event payload without storing it. Audio never decides approvals.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat >/dev/null
bash "$SCRIPT_DIR/../play-sound.sh" "${1:-}" >/dev/null 2>&1 || true
printf '{}\n'
