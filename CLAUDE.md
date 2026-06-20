# DingDong for Claude Code

Zero-dependency audio feedback for Claude Code — plays WAV sounds on hook events.

## Structure

```
dingdong/
├── play-sound.ps1        # Windows entry point (winmm.dll PlaySound)
├── play-sound.sh          # Unix entry point (afplay/paplay/aplay)
├── config.json            # Event → sound file mapping
├── hooks.json             # Windows hook definitions (for install)
├── hooks.unix.json        # Unix hook definitions (for install)
├── scripts/
│   ├── install.ps1        # Windows installer
│   ├── install.sh         # Unix installer
│   ├── uninstall.ps1      # Windows uninstaller
│   └── uninstall.sh       # Unix uninstaller
├── sounds/                # WAV files
└── .claude-plugin/
    └── plugin.json
```

## Data Flow

```
Event → hooks in settings.json → play-sound.ps1/.sh → config.json lookup → WAV playback
```

One process hop. No fallbacks. No volume control. No pub-sub.

## Config (v2)

```json
{
  "version": 2,
  "volume": 80,
  "events": {
    "Stop":              { "type": "wav",    "file": "sounds/denielcz-done_01.wav" },
    "Notification":      { "type": "wav",    "file": "sounds/pop.wav" },
    "PermissionRequest": { "type": "wav",    "file": "sounds/notify-descend.wav" },
    "Elicitation":       { "type": "wav",    "file": "sounds/question-double.wav" },
    "TeammateIdle":      { "type": "none" }
  }
}
```

Set `"type": "none"` for silent events. Paths are relative to the plugin root. `volume` is a percentage (0-100).

## Install

```sh
# Windows (recommended: install to APPDATA)
powershell -File scripts/install.ps1

# Windows (install alongside project for development)
powershell -File scripts/install.ps1 -ToProject

# Unix
bash scripts/install.sh

# Uninstall
powershell -File scripts/uninstall.ps1       # Windows
bash scripts/uninstall.sh                     # Unix
```
