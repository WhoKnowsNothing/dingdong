# DingDong for Claude Code

## Project Structure

```
claude-code-dingdong/
├── .claude-plugin/
│   ├── plugin.json           # Plugin metadata for marketplace
│   └── marketplace.json      # Marketplace listing definition
├── hooks/
│   ├── hooks.json            # Hook definitions (CLAUDE_PLUGIN_ROOT resolved)
│   ├── play-sound.ps1        # Event → sound mapper, reads config.json
│   ├── config.json           # User preferences (event → sound mapping)
│   ├── config-ui.ps1         # PowerShell WinForms GUI for configuration
│   └── sound-generator.ps1   # Generates WAV files from sine waves
├── sounds/                   # Generated WAV files
├── install.ps1               # Windows installer
├── install.sh                # Unix/macOS installer
├── prompt.md                 # Claude Skill prompt
├── CLAUDE.md                 # This file
└── README.md                 # User documentation
```

## Architecture

```
Claude Code Event (Stop, Notification, PermissionRequest, Elicitation, TeammateIdle)
    │
    ▼
settings.json hook entry
    │
    ▼
play-sound.ps1 -Event <name>
    │
    ├── reads config.json (event → {type, file/sound, label})
    │
    ├── type=system  → Windows.SystemSounds::X.Play()
    ├── type=wav     → SoundPlayer(wav).PlaySync()
    └── type=none    → silent return
```

## Key Design Decisions

1. **Wrapper script pattern**: hooks.json points to play-sound.ps1, which reads config.json — users change sounds by editing config, not settings.json
2. **${CLAUDE_PLUGIN_ROOT}**: resolved at runtime by play-sound.ps1, so config.json is portable across installs
3. **WinForms GUI**: config-ui.ps1 uses native Windows Forms (no external dependencies)
4. **Generated WAVs**: sine wave synthesis in pure PowerShell — no audio samples to license
5. **Async hooks**: all sound hooks use `"async": true` so sound never blocks Claude Code

## Marketplace Publishing

To publish to a marketplace:

1. Fork or create a GitHub repo with this structure
2. Create a marketplace.json that references this plugin
3. Add the repo URL to user's `extraKnownMarketplaces` in settings.json
4. Users install via: `claude install <marketplace-repo-url>`

Or submit to an existing marketplace like superpowers-marketplace.