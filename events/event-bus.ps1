param(
    [string]$Event,
    [switch]$DryRun
)

$scriptDir = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptDir
$configPath = Join-Path $projectRoot "config.json"

if (-not (Test-Path $configPath)) {
    throw "config.json not found at: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$subs = $config.subscriptions.$Event
if (-not $subs) { return }

$results = @()
foreach ($sub in $subs) {
    $entry = @{
        Type = $sub.type
        Label = $sub.label
    }

    if ($sub.type -eq "wav") {
        $filePath = $sub.file -replace '\$\{CLAUDE_PLUGIN_ROOT\}', $projectRoot
        $entry.File = $filePath
        if (-not $DryRun) {
            & "$scriptDir/../players/play-wav.ps1" -File $filePath -Volume $config.volume
        }
    }
    elseif ($sub.type -eq "system") {
        $entry.Sound = $sub.sound
        if (-not $DryRun) {
            & "$scriptDir/../players/play-system.ps1" -Sound $sub.sound
        }
    }

    $results += [PSCustomObject]$entry
}

if ($DryRun) { return $results }
else { $results | Out-Null }
