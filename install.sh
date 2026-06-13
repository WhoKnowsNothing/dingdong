#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DingDong — Claude Code Audio Feedback Plugin
# Unix/macOS Installer (partial)
# NOTE: This plugin is primarily designed for Windows.
# On macOS/Linux only task-complete events are supported
# via afplay (macOS) or paplay/aplay (Linux).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks/dingdong"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "=== DingDong Installer (Unix) ==="
echo ""

# Detect platform
if [[ "$(uname)" == "Darwin" ]]; then
    PLAY_CMD="afplay"
    echo "[INFO] macOS detected — will use 'afplay' for audio"
elif command -v paplay &>/dev/null; then
    PLAY_CMD="paplay"
    echo "[INFO] Linux (PulseAudio) detected — will use 'paplay'"
elif command -v aplay &>/dev/null; then
    PLAY_CMD="aplay"
    echo "[INFO] Linux (ALSA) detected — will use 'aplay'"
else
    echo "[WARN] No audio player found (afplay/paplay/aplay)."
    echo "       Sounds will not play on this system."
    PLAY_CMD=""
fi

# Create target directories
mkdir -p "$HOOKS_DIR"
mkdir -p "$CLAUDE_DIR"

# Generate a simple notification sound using shell
if [[ -n "$PLAY_CMD" ]]; then
    echo "[1/3] Generating sounds..."

    # Create simple WAV using ffmpeg or python if available
    SOUNDS_DIR="$HOOKS_DIR/sounds"
    mkdir -p "$SOUNDS_DIR"

    if command -v python3 &>/dev/null; then
        python3 "$SCRIPT_DIR/hooks/sound_generator_unix.py" "$SOUNDS_DIR" 2>/dev/null || true
    elif command -v sox &>/dev/null; then
        sox -n -r 44100 -b 16 "$SOUNDS_DIR/done-classic.wav" synth 0.2 sine 523.25 fade 0.01 0 0.05 2>/dev/null || true
        sox -n -r 44100 -b 16 "$SOUNDS_DIR/ding.wav" synth 0.2 sine 1046.5 fade 0.01 0 0.08 2>/dev/null || true
    fi

    # Count what we got
    WAV_COUNT=$(find "$SOUNDS_DIR" -name "*.wav" 2>/dev/null | wc -l)
    if [[ "$WAV_COUNT" -gt 0 ]]; then
        echo "  -> Generated $WAV_COUNT sound file(s)"
    else
        echo "  -> No sounds generated (install python3 or sox for sound generation)"
    fi
fi

# Copy hook scripts
echo "[2/3] Installing hook scripts..."
cp "$SCRIPT_DIR/hooks/play-sound.ps1" "$HOOKS_DIR/" 2>/dev/null || true
# Create a Unix-compatible version of play-sound
cat > "$HOOKS_DIR/play-sound.sh" << 'SHEOF'
#!/usr/bin/env bash
EVENT="${1:-}"
CONFIG_FILE="$HOME/.claude/hooks/dingdong/config.json"
SOUNDS_DIR="$HOME/.claude/hooks/dingdong/sounds"

if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Parse event sound from config (simple grep, no jq dependency)
if command -v python3 &>/dev/null; then
    SOUND=$(python3 -c "
import json,sys
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
ev = cfg.get('events', {}).get('$EVENT', {})
if ev.get('type') == 'wav':
    f = ev.get('file','')
    f = f.replace('\${CLAUDE_PLUGIN_ROOT}', '$HOME/.claude/hooks/dingdong')
    print(f)
elif ev.get('type') == 'system':
    print('system:' + ev.get('sound','Beep'))
" 2>/dev/null) || SOUND=""
else
    SOUND=""
fi

if [[ -z "$SOUND" ]]; then
    exit 0
fi

if [[ "$SOUND" == system:* ]]; then
    # System sounds via terminal bell
    echo -ne '\a'
elif [[ -f "$SOUND" ]]; then
    if command -v afplay &>/dev/null; then
        afplay "$SOUND" &
    elif command -v paplay &>/dev/null; then
        paplay "$SOUND" &
    elif command -v aplay &>/dev/null; then
        aplay "$SOUND" &
    fi
fi
SHEOF
chmod +x "$HOOKS_DIR/play-sound.sh"
echo "  -> Installed play-sound.sh"

# Try to register in settings.json
echo "[3/3] Registering hooks..."
if [[ -f "$SETTINGS_FILE" ]]; then
    echo "  -> settings.json exists — please add hooks manually."
    echo "     See README.md for instructions."
else
    echo "  -> No settings.json found. Create it or skip this step."
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "To add hooks to your settings.json, add entries like this:"
echo ""
echo '"hooks": {'
echo '  "Stop": [{'
echo '    "matcher": "*",'
echo '    "hooks": [{'
echo '      "type": "command",'
echo '      "command": "'"$HOOKS_DIR"'/play-sound.sh Stop",'
echo '      "timeout": 5,'
echo '      "async": true'
echo '    }]'
echo '  }]'
echo '}'
echo ""
echo "Then restart Claude Code."