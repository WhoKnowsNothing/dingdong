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

## Config

```json
{
  "Stop": "sounds/denielcz-done_01.wav",
  "Notification": "sounds/pop.wav",
  "PermissionRequest": "sounds/alert.wav",
  "Elicitation": "sounds/question-double.wav",
  "TeammateIdle": null
}
```

Set an event to `null` for silent. Paths are relative to the plugin root.

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
