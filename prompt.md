# DingDong: Claude Code Audio Feedback Plugin

Provides customizable sound effects for Claude Code events on Windows via native WinForms UI.

## Events with Sound Support

| Event | Trigger | Default Sound |
|-------|---------|------|
| Stop | Claude finishes a response | Classic Chime |
| Notification | Task completion notification | Ding |
| PermissionRequest | Claude needs tool permission | System Hand |
| Elicitation | Claude asks a clarifying question | System Question |
| TeammateIdle | Sub-agent is idle/stuck | System Exclamation |

## Sound Options

- **System Sounds**: Windows built-in (Hand, Question, Exclamation, Asterisk, Beep)
- **Custom WAVs**: Generated chimes (classic, soft, fanfare, ding, pop, alert, warning, error, question-rising, question-double)
- **Silent**: Mute any event
- **Master Volume**: Global volume control

## Quick Start (Windows)

```powershell
# Install and launch config UI
.\install.ps1

# Silent install (no UI)
.\install.ps1 -NoUI

# Open config UI later
powershell -File "$env:USERPROFILE\.claude\hooks\dingdong\config-ui.ps1"
```

After install, restart Claude Code or run `/hooks` to reload.