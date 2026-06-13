# DingDong — Cross-platform Audio Feedback Plugin for Claude Code

## Overview

DingDong is a zero-dependency Claude Code plugin that plays sound effects on hook events using a **Pub-Sub architecture**. Unlike the old `claude-code-dingdong` (procedural PowerShell scripts), this version separates concerns into event publishers, an event bus, and sound-playing subscribers via a subscription registry.

## Architecture

```
Claude Code Hook Event (Publisher)
    │
    ▼
┌──────────────────────────────────┐
│   Event Bus (event-bus.ps1/sh)   │  → reads config.json (subscription registry)
│   1. Receives event name          │
│   2. Looks up subscribers         │
│   3. Dispatches to each           │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────┐
│   Subscriber Registry             │
│   config.json                     │
│   { "subscriptions": {            │
│       "Stop": [{type, file}, ...] │
│   }}                               │
└──────┬───────────┬───────────────┘
       │           │
       ▼           ▼
  play-wav.ps1  play-system.ps1
  (WAV player)  (system sounds)
```

## Design Decisions

### Pub-Sub via Config Registry
- `config.json` IS the subscription registry
- Each event type maps to an array of subscriber entries
- Adding/removing entries = subscribing/unsubscribing
- No background processes, no IPC, no runtime state

### Cross-platform Zero Dependency
- Windows: PowerShell + .NET `System.Media.SoundPlayer` / `SystemSounds`
- macOS: `afplay` (built-in)
- Linux: `paplay` (PulseAudio) or `aplay` (ALSA) — both built-in
- No Python, Node.js, or any package manager required

### Separation of Concerns
- `events/` — Event bus (dispatchers), one per platform
- `players/` — Sound playback implementations (subscribers)
- `preview/` — Sound preview CLI
- `hooks/` — Claude Code hook definitions
- `config.json` — Subscription registry (shared across platforms)

## Project Structure

```
dingdong/
├── .claude-plugin/
│   └── plugin.json              # Marketplace metadata
├── hooks/
│   └── hooks.json               # Hook definitions
├── events/
│   ├── event-bus.ps1            # Windows event bus
│   └── event-bus.sh             # Unix event bus
├── players/
│   ├── play-wav.ps1             # Windows WAV player
│   ├── play-wav.sh              # Unix WAV player
│   ├── play-system.ps1          # Windows system sounds
│   └── play-system.sh           # Unix system sounds fallback
├── preview/
│   ├── preview.ps1              # Windows preview CLI
│   └── preview.sh               # Unix preview CLI
├── sounds/                      # WAV files from original project
│   ├── pop.wav
│   ├── ding.wav
│   ├── done-classic.wav
│   ├── done-fanfare.wav
│   ├── done-soft.wav
│   ├── alert.wav
│   ├── warning.wav
│   ├── error.wav
│   ├── beep-soft.wav
│   ├── notify-descend.wav
│   ├── question-double.wav
│   ├── question-rising.wav
│   └── denielcz-done_01.wav
├── config.json                  # Subscription registry
├── install.sh                   # Cross-platform installer
├── uninstall.sh                 # Uninstaller
└── README.md                    # Documentation
```

### Config Format (Subscription Registry)

```json
{
  "version": 1,
  "subscriptions": {
    "Stop": [
      { "type": "wav", "file": "${CLAUDE_PLUGIN_ROOT}/sounds/done-classic.wav", "label": "Done" }
    ],
    "Notification": [
      { "type": "wav", "file": "${CLAUDE_PLUGIN_ROOT}/sounds/pop.wav", "label": "Pop" }
    ],
    "PermissionRequest": [
      { "type": "wav", "file": "${CLAUDE_PLUGIN_ROOT}/sounds/alert.wav", "label": "Alert" }
    ],
    "Elicitation": [
      { "type": "wav", "file": "${CLAUDE_PLUGIN_ROOT}/sounds/question-double.wav", "label": "Question" }
    ],
    "TeammateIdle": [
      { "type": "system", "sound": "Asterisk", "label": "System Asterisk" }
    ]
  },
  "volume": 80
}
```

`type` values:
- `"wav"` — play WAV file via platform player
- `"system"` — Windows SystemSounds (Asterisk/Question/Exclamation/Hand/Beep); Unix fallbacks to simple beep
- `"none"` — silent (disable event)

### Hook Configuration

`hooks/hooks.json` maps all Claude Code events to the event bus dispatcher:

| Hook Event | Matcher | Description |
|-----------|---------|-------------|
| Stop | * | Response complete |
| Notification | Task completion | Task done |
| PermissionRequest | Bash/Write/Edit/Read | Tool execution |
| Elicitation | * | Question to user |
| TeammateIdle | * | Sub-agent idle |
| PreToolUse | AskUserQuestion | Question (reliable fallback) |
| SubagentStop | * | Sub-agent done |

### Event Bus (Dispatcher)

**Windows (`event-bus.ps1`):**
- Accepts `-Event <name>` parameter from hook
- Reads `config.json`, resolves `${CLAUDE_PLUGIN_ROOT}`
- Iterates subscription array, calls appropriate player for each entry
- Async execution per Claude Code hook config

**Unix (`event-bus.sh`):**
- Accepts `$1` as event name
- Uses grep/sed to parse JSON (zero dependencies)
- Delegates to `play-wav.sh` for each subscriber

### Sound Players

| Platform | WAV Player | System Sounds |
|----------|-----------|---------------|
| Windows | `System.Media.SoundPlayer` | `System.Media.SystemSounds` |
| macOS | `afplay` | Fallback to WAV |
| Linux | `paplay` or `aplay` | Fallback to WAV |

### Preview CLI

An interactive terminal menu that:
1. Lists all available `.wav` files and system sounds
2. Plays the selected sound for preview
3. Optionally configures the sound to an event in `config.json`

### Installation

```bash
# One-line install (from marketplace)
claude install dingdong

# From source
curl -fsSL https://raw.githubusercontent.com/<owner>/dingdong/main/install.sh | bash
```

The installer:
1. Detects OS
2. Copies files to `~/.claude/plugins/dingdong/`
3. Registers hooks in `settings.json`
4. Optionally launches preview

### Marketplace Publishing

- Package as `.claude-plugin/` format
- Submit to superpowers-marketplace or similar
- Users install via `claude install <url>`

## Development Approach

- **BDD-driven**: Gherkin-style behavior specs before implementation
- **Testing**: Pester (Windows), bats (Unix) for integration testing
- **CI**: GitHub Actions for cross-platform testing
