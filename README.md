# DingDong

Customizable audio feedback for Claude Code events on Windows. Know when Claude finishes a task, needs permission, or a sub-agent gets stuck — without watching the terminal.

## Features

- **5 events** with independent sound assignments
- **Native Windows GUI** to configure everything
- **10 generated WAV chimes** (no copyrighted audio)
- **Windows System Sounds** (Hand, Question, Exclamation, Asterisk, Beep)
- **Master volume** control
- **Per-event mute**
- **Zero external dependencies** — pure PowerShell + WinForms

## Requirements

- Windows 10 / 11
- Claude Code

## Quick Install

```powershell
git clone https://github.com/WhoKnowsNothing/claude-code-dingdong
cd claude-code-dingdong
.\install.ps1
```

This will:
1. Generate WAV chime files
2. Install hook scripts to `~/.claude/hooks/dingdong/`
3. Register hooks in `~/.claude/settings.json`
4. Launch the configuration UI

After install, run `/hooks` in Claude Code or restart.

## Manual Install

If the installer can't update settings.json, add these hook entries manually:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Stop",
        "timeout": 10,
        "async": true
      }]
    }],
    "Notification": [{
      "matcher": "(?i)task.?complet|done|finished|completed",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Notification",
        "timeout": 10,
        "async": true
      }]
    }],
    "PermissionRequest": [{
      "matcher": "Bash|Write|Edit|Read",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event PermissionRequest",
        "timeout": 10,
        "async": true
      }]
    }],
    "Elicitation": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Elicitation",
        "timeout": 10,
        "async": true
      }]
    }],
    "TeammateIdle": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event TeammateIdle",
        "timeout": 10,
        "async": true
      }]
    }],
    "PreToolUse": [{
      "matcher": "AskUserQuestion",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Elicitation",
        "timeout": 10,
        "async": true
      }]
    }],
    "SubagentStop": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Notification",
        "timeout": 10,
        "async": true
      }]
    }]
  }
}

> **Note:** Due to Claude Code event limitations, `Elicitation` and `Notification` events may not fire reliably. The hooks above use `PreToolUse` (for elicitation sounds) and `SubagentStop` (for notification sounds) as workarounds.
```

## Configuration UI

Launch anytime:

```powershell
powershell -File "$env:USERPROFILE\.claude\hooks\dingdong\config-ui.ps1"
```

The GUI shows all 5 events with dropdown selectors, preview buttons, and a master volume slider.

<!-- Screenshot: add docs/screenshot.png before publishing -->

## Sound Options

### System Sounds
| Name | Type |
|------|------|
| Hand | Critical stop / alert |
| Question | Question prompt |
| Exclamation | Warning |
| Asterisk | Information |
| Beep | Simple beep |

### Generated WAV Chimes
| File | Sound | Best For |
|------|-------|----------|
| done-classic.wav | Ascending C5→E5 chime | Task complete |
| done-soft.wav | Gentle A4 tone | Task complete (subtle) |
| done-fanfare.wav | C5→E5→G5 triad | Celebratory finish |
| ding.wav | High clear 1046Hz | Notifications |
| pop.wav | Short 800Hz burst | Quick feedback |
| beep-soft.wav | Gentle 880Hz beep | Subtle alert |
| notify-descend.wav | G5→E5 two-tone | Notifications |
| alert.wav | Medium 660Hz tone | Permission requests |
| warning.wav | Descending 440→349Hz | Sub-agent idle |
| error.wav | Staccato low tones | Error attention |
| question-rising.wav | 400→1200Hz sweep | Elicitation |
| question-double.wav | 660→880Hz double | Clarifications |

## Custom Sounds

You can add your own WAV files to the `sounds/` folder and they'll appear in the configuration dropdown. Any WAV file works — 44100Hz 16-bit mono recommended.

## Uninstall

1. Remove the `dingdong` hook entries from `~/.claude/settings.json`
2. Delete `~/.claude/hooks/dingdong/`
3. Run `/hooks` or restart Claude Code

## License

MIT