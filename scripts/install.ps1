param([string]$TargetDir, [switch]$ToProject, [string]$SettingsPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'data-paths.ps1')
. (Join-Path $PSScriptRoot 'claude-settings.ps1')

$pluginRoot = if ($ToProject) { $projectRoot } elseif ($TargetDir) { [System.IO.Path]::GetFullPath($TargetDir) } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude\plugins\dingdong' }
if (-not $SettingsPath) {
    $claudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude' }
    $SettingsPath = Join-Path $claudeRoot 'settings.json'
}
$SettingsPath = [System.IO.Path]::GetFullPath($SettingsPath)

# Migrate the existing installation before copying updated package files.
$seedRoot = if (Test-Path -LiteralPath (Join-Path $pluginRoot 'config.json')) { $pluginRoot } else { $projectRoot }
$dataRoot = Initialize-DingDongData -SourceRoot $seedRoot
if ($projectRoot -ne $pluginRoot) {
    foreach ($file in @('play-sound.ps1', 'play-sound.sh', 'config-ui.ps1', 'configure.bat', 'config.sh',
        'scripts/data-paths.ps1', 'scripts/data-paths.sh')) {
        $destination = Join-Path $pluginRoot $file
        [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $destination -Force
    }
    if (-not (Test-Path -LiteralPath (Join-Path $pluginRoot 'config.json'))) {
        Copy-Item -LiteralPath (Join-Path $projectRoot 'config.json') -Destination (Join-Path $pluginRoot 'config.json')
    }
    [void][System.IO.Directory]::CreateDirectory((Join-Path $pluginRoot 'sounds'))
    foreach ($sound in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'sounds') -Filter '*.wav' -File) {
        $destination = Join-Path $pluginRoot ('sounds/' + $sound.Name)
        if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $sound.FullName -Destination $destination }
    }
}

$definition = ConvertTo-DingDongHashtable (Get-Content -LiteralPath (Join-Path $projectRoot 'hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
foreach ($groups in $definition.hooks.Values) {
    foreach ($group in $groups) {
        foreach ($hook in $group.hooks) {
            $hook.command = $hook.command.Replace('${CLAUDE_PLUGIN_ROOT}', $pluginRoot)
        }
    }
}
Update-DingDongClaudeHooks -SettingsPath $SettingsPath -NewHooks $definition.hooks
Write-Host "Claude Code hooks: $SettingsPath"
Write-Host "Shared Claude Code / Codex settings: $(Join-Path $dataRoot 'config.json')"
Write-Host 'Restart Claude Code to load the updated hooks.'
