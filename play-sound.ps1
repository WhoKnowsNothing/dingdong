param([string]$Event)

$scriptDir = Split-Path -Parent $PSCommandPath
$configPath = Join-Path $scriptDir "config.json"

if (-not (Test-Path $configPath)) { exit 0 }

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$soundFile = $config.$Event
if (-not $soundFile) { exit 0 }

$soundPath = Join-Path $scriptDir $soundFile
if (-not (Test-Path $soundPath)) { exit 0 }

# Start a fresh PowerShell process with its own audio context
# This ensures WAV playback works even from hook background processes
Start-Process powershell -WindowStyle Hidden -ArgumentList @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-Command", "& { (New-Object Media.SoundPlayer '$soundPath').PlaySync(); exit 0 }"
) | Out-Null
