param([string]$TargetDir, [switch]$ToProject)

if ($ToProject) {
    $pluginRoot = Split-Path -Parent $PSScriptRoot
} elseif ($TargetDir) {
    $pluginRoot = $TargetDir
} else {
    $pluginRoot = "$env:USERPROFILE\.claude\plugins\dingdong"
}

Write-Host "DingDong Installer (Windows)"
Write-Host "============================"
Write-Host "Target: $pluginRoot"
$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Copy files only if source != destination
if ($projectRoot -ne $pluginRoot) {
    New-Item -ItemType Directory -Path "$pluginRoot\sounds" -Force | Out-Null
    Copy-Item -Path "$projectRoot\play-sound.ps1" -Destination "$pluginRoot\" -Force
    Copy-Item -Path "$projectRoot\config.json" -Destination "$pluginRoot\" -Force
    Copy-Item -Path "$projectRoot\sounds\*.wav" -Destination "$pluginRoot\sounds\" -Force
} else {
    Write-Host "In-place install — skipping file copy"
}

# Helper: convert PSCustomObject to hashtable (PS5.1 compatible)
function ConvertTo-Ht($obj) {
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = ConvertTo-Ht $_.Value }
        $ht
    } elseif ($obj -is [array]) {
        ,@($obj | ForEach-Object { ConvertTo-Ht $_ })
    } else { $obj }
}

# Resolve settings.json path
$settingsPaths = @(
    "$env:APPDATA\Claude Code\settings.json",
    "$env:USERPROFILE\.claude\settings.json"
)
$settingsPath = $null
foreach ($p in $settingsPaths) {
    if (Test-Path $p) { $settingsPath = $p; break }
}
if (-not $settingsPath) {
    $settingsDir = "$env:APPDATA\Claude Code"
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    $settingsPath = "$settingsDir\settings.json"
}

# Read or create settings (as hashtable for easy manipulation)
$settings = @{}
if (Test-Path $settingsPath) {
    $content = Get-Content $settingsPath -Raw -Encoding UTF8
    if ($content) { $settings = ConvertTo-Ht ($content | ConvertFrom-Json) }
}

# Read hooks definition and merge
$hooksDef = ConvertTo-Ht (Get-Content "$PSScriptRoot\..\hooks.json" -Raw -Encoding UTF8 | ConvertFrom-Json)

# Resolve ${CLAUDE_PLUGIN_ROOT} to actual path (hooks system doesn't auto-resolve it)
function Resolve-HookPaths($obj) {
    if ($obj -is [hashtable]) {
        $result = @{}
        $obj.Keys | ForEach-Object {
            $result[$_] = Resolve-HookPaths $obj[$_]
        }
        $result
    } elseif ($obj -is [array]) {
        ,@($obj | ForEach-Object { Resolve-HookPaths $_ })
    } elseif ($obj -is [string]) {
        $obj -replace '\$\{CLAUDE_PLUGIN_ROOT\}', $pluginRoot
    } else { $obj }
}
$resolvedHooks = Resolve-HookPaths $hooksDef["hooks"]
$settings["hooks"] = $resolvedHooks

# Write with UTF8 No BOM (PS5.1 compatible)
$json = $settings | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)

Write-Host "Done! Hooks registered in: $settingsPath"
Write-Host "Run '/hooks' in Claude Code or restart to apply."
