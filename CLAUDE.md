# DingDong for Claude Code and Codex

Local audio feedback with a shared configuration and sound library.

- Maintain the common players and configuration tools in this repository.
- `hooks.json` / `hooks.unix.json` are Claude Code adapters.
- `integrations/codex/` contains the Codex manifest and hook templates.
- `scripts/build-codex.ps1` creates a separate, self-contained Codex package.
- Do not maintain a second player implementation in an installed plugin/cache directory.
- User settings and imported sounds live in `~/.config/dingdong/`, overridable with an absolute `DINGDONG_HOME`.
- Preserve shared data on reinstall/uninstall and preserve unrelated Claude hook handlers, including handlers in mixed matcher groups.
- Windows code must remain compatible with Windows PowerShell 5.1 and Unicode paths.
- Hook input must not be logged or persisted. Codex hooks return neutral JSON and never decide permissions.
- Keep Codex hook templates out of the repository's `hooks/hooks.json` location to avoid Claude auto-discovery.
- Use normal Codex hook review/trust after installing changed definitions.

See README.md for installation and ARCHITECTURE.md for the data flow.
Run `python -m unittest discover -s tests -v` for integration checks.
