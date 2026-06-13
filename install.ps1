# ============================================================
# DingDong — Claude Code Audio Feedback Plugin
# Windows Installer
# ============================================================
param(
    [switch]$NoUI,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ScriptName = "DingDong"

if ($Help) {
    Write-Host @"
DingDong — Installer
=========================
Installs sound hook scripts and configuration UI for Claude Code.

Usage:
  .\install.ps1              Install and launch config UI
  .\install.ps1 -NoUI        Install silently (generates sounds, registers hooks)
  .\install.ps1 -Help        Show this help

What it does:
  1. Generates WAV sound files
  2. Copies hook scripts to ~/.claude/hooks/dingdong/
  3. Registers hooks in ~/.claude/settings.json
  4. Optionally launches the configuration UI
"@
    return
}

$ClaudeDir = "$env:USERPROFILE\.claude"
$HooksDir = "$ClaudeDir\hooks"
$TargetDir = "$HooksDir\dingdong"
$PluginsDir = "$ClaudeDir\plugins"
$SettingsPath = "$ClaudeDir\settings.json"

Write-Host "=== DingDong Installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Generate sounds
Write-Host "[1/4] Generating WAV sound files..." -ForegroundColor Yellow
$soundGen = Join-Path $PSScriptRoot "hooks\sound-generator.ps1"
$soundsOut = Join-Path $PSScriptRoot "sounds"
if (-not (Test-Path $soundsOut) -or -not (Get-ChildItem $soundsOut -Filter "*.wav" | Select-Object -First 1)) {
    & powershell -NoProfile -File $soundGen -OutputDir $soundsOut
    Write-Host "  -> Sounds generated in: $soundsOut" -ForegroundColor Green
} else {
    Write-Host "  -> Sounds already exist, skipping generation" -ForegroundColor DarkGray
}

# 2. Create target directory
Write-Host "[2/4] Installing files..." -ForegroundColor Yellow
$null = New-Item -ItemType Directory -Path $TargetDir -Force
$null = New-Item -ItemType Directory -Path "$TargetDir\sounds" -Force

# Copy hook scripts from hooks/ (skip config.json — it's at root now)
Get-ChildItem (Join-Path $PSScriptRoot "hooks") -File | Where-Object { $_.Name -ne "config.json" } | ForEach-Object {
    Copy-Item $_.FullName "$TargetDir\" -Force
    Write-Host "  -> Copied: $($_.Name)" -ForegroundColor DarkGray
}

# Copy config.json from repo root
if (Test-Path (Join-Path $PSScriptRoot "config.json")) {
    Copy-Item (Join-Path $PSScriptRoot "config.json") "$TargetDir\" -Force
    Write-Host "  -> Copied: config.json" -ForegroundColor DarkGray
}

# Copy WAV sounds
Get-ChildItem $soundsOut -Filter "*.wav" | ForEach-Object {
    Copy-Item $_.FullName "$TargetDir\sounds\" -Force
    Write-Host "  -> Copied sound: $($_.Name)" -ForegroundColor DarkGray
}

# 3. Config.json stays portable — keep ${CLAUDE_PLUGIN_ROOT} placeholder
# (Resolve-WavPath in config-ui.ps1 and play-sound.ps1 resolve it at runtime)

# 4. Register hooks in settings.json
Write-Host "[3/4] Registering hooks in settings.json..." -ForegroundColor Yellow
if (-not (Test-Path $SettingsPath)) {
    Write-Host "  -> Creating new settings.json" -ForegroundColor DarkGray
    @{ "hooks" = @{} } | ConvertTo-Json | Set-Content $SettingsPath -Encoding UTF8
}

try {
    $settings = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Helper to ensure hook array for an event
    function Ensure-HookArray($settings, $eventName) {
        if (-not $settings.hooks) {
            $settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value @{} -Force
        }
        if (-not $settings.hooks.$eventName) {
            $settings.hooks.$eventName = @()
        }
    }

    $soundPackSettings = @{
        "Stop" = @(
            @{
                matcher = "*"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event Stop"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
        "Notification" = @(
            @{
                matcher = "(?i)task.?complet|done|finished|completed"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event Notification"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
        "PermissionRequest" = @(
            @{
                matcher = "Bash|Write|Edit|Read"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event PermissionRequest"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
        "Elicitation" = @(
            @{
                matcher = ".*"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event Elicitation"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
        "TeammateIdle" = @(
            @{
                matcher = ".*"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event TeammateIdle"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
        "PreToolUse" = @(
            @{
                matcher = "AskUserQuestion"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event Elicitation"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
        "SubagentStop" = @(
            @{
                matcher = ".*"
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\play-sound.ps1`" -Event Notification"
                        timeout = 10
                        async = $true
                    }
                )
            }
        )
    }

    foreach ($evt in $soundPackSettings.Keys) {
        Ensure-HookArray $settings $evt
        # Add dingdong hooks before existing ones (so our sound plays)
        $settings.hooks.$evt = $soundPackSettings[$evt] + $settings.hooks.$evt
        Write-Host "  -> Registered hook: $evt" -ForegroundColor DarkGray
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
    Write-Host "  -> settings.json updated" -ForegroundColor Green
} catch {
    Write-Host "  -> WARNING: Could not update settings.json automatically." -ForegroundColor Yellow
    Write-Host "     Add hooks manually — see README.md for instructions." -ForegroundColor Yellow
    Write-Host "     Error: $_" -ForegroundColor Red
}

# 5. Done
Write-Host ""
Write-Host "[4/4] Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "DingDong installed to: $TargetDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart Claude Code (or run '/hooks' to reload)" -ForegroundColor White
Write-Host "  2. Configure your sounds:" -ForegroundColor White

if (-not $NoUI) {
    Write-Host "     -> Launching configuration UI..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File "$TargetDir\config-ui.ps1"
    } catch {
        Write-Host "     -> Could not launch UI. Run manually:" -ForegroundColor Yellow
        Write-Host "        powershell -File `"$TargetDir\config-ui.ps1`"" -ForegroundColor Cyan
    }
} else {
    Write-Host "     -> Run: powershell -File `"$TargetDir\config-ui.ps1`"" -ForegroundColor Cyan
    Write-Host "     Or edit: $TargetDir\config.json" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "To uninstall: remove the dingdong hooks from settings.json and delete $TargetDir" -ForegroundColor DarkGray