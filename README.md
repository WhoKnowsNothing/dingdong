# DingDong

> Zero-dependency audio feedback for Claude Code — Pub-Sub architecture.
> Hear events without watching the terminal. Cross-platform.

## Quick Install

```bash
claude install dingdong
# or from source:
# curl -fsSL https://raw.githubusercontent.com/WhoKnowsNothing/dingdong/main/install.sh | bash
```

## Architecture

```
Hook Event     →    Event Bus    →    Config (Subscription Registry)    →    Sound Players
  (pub)              (router)                   (subscriptions)                 (subscribers)
```

The pub-sub architecture uses `config.json` as the subscription registry. Each event type maps to an array of subscribers. Adding/removing entries = subscribing/unsubscribing.

## Events

| Event | Triggered When | Default Sound |
|-------|---------------|---------------|
| Stop | Response complete | Done chord |
| Notification | Task finished | Pop |
| PermissionRequest | Tool execution | Alert |
| Elicitation | Question to user | Question chime |
| TeammateIdle | Sub-agent idle | System Asterisk |

## Sound Preview

Browse and preview all available sounds interactively:

```powershell
# Windows
powershell -File "%USERPROFILE%\.claude\plugins\dingdong\preview\preview.ps1"
```

```bash
# Unix
~/.claude/plugins/dingdong/preview/preview.sh
```

Or run directly from the project directory:
```bash
# Windows
.\preview\preview.ps1
```

## Configuration

Edit `~/.claude/plugins/dingdong/config.json` to customize sound assignments.

Each event supports **multiple subscribers** (play multiple sounds at once):

```json
{
  "subscriptions": {
    "Stop": [
      { "type": "wav", "file": "${CLAUDE_PLUGIN_ROOT}/sounds/done-classic.wav", "label": "Done" }
    ]
  }
}
```

### Subscriber Types

| Type | Description | Platform |
|------|-------------|----------|
| `wav` | Play a WAV file | All |
| `system` | Windows system sound (Asterisk/Question/Exclamation/Hand/Beep) | Windows only |
| `none` | Silent (disable event) | All |

## Available Sounds

### WAV Files (13)

| File | Character |
|------|-----------|
| alert.wav | Medium 660Hz alert |
| beep-soft.wav | Gentle 880Hz beep |
| denielcz-done_01.wav | Extended completion sound |
| ding.wav | Clean 1046Hz ding |
| done-classic.wav | Ascending C5→E5 chord |
| done-fanfare.wav | C5→E5→G5 triad fanfare |
| done-soft.wav | Soft A4 tone |
| error.wav | Staccato low tone |
| notify-descend.wav | G5→E5 descending pair |
| pop.wav | Short 800Hz pop |
| question-double.wav | 660→880Hz double tone |
| question-rising.wav | 400→1200Hz rising sweep |
| warning.wav | Descending 440→349Hz |

### Windows System Sounds (5)

Asterisk, Question, Exclamation, Hand, Beep

## Project Structure

```
dingdong/
├── .claude-plugin/plugin.json   # Marketplace metadata
├── hooks/hooks.json             # Claude Code hook definitions
├── events/
│   ├── event-bus.ps1            # Windows event bus (pub-sub dispatcher)
│   └── event-bus.sh             # Unix event bus
├── players/
│   ├── play-wav.ps1 / .sh       # WAV file players
│   └── play-system.ps1 / .sh    # System sound players
├── preview/
│   ├── preview.ps1              # Windows preview CLI
│   └── preview.sh               # Unix preview CLI
├── sounds/                      # 13 WAV sound files
├── config.json                  # Subscription registry (pub-sub config)
├── install.sh                   # Cross-platform installer
├── uninstall.sh                 # Cross-platform uninstaller
└── README.md
```

## License

MIT
