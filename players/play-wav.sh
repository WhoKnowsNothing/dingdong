#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-}"

if [ ! -f "$FILE" ]; then
    echo "WAV file not found: $FILE" >&2
    exit 1
fi

if command -v afplay &>/dev/null; then
    afplay "$FILE"
elif command -v paplay &>/dev/null; then
    paplay "$FILE"
elif command -v aplay &>/dev/null; then
    aplay "$FILE"
else
    echo "No audio player found (tried afplay, paplay, aplay)" >&2
    exit 1
fi
