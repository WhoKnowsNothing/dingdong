param([switch]$RemoveFiles, [string]$SettingsPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'claude-settings.ps1')
$userRoot = [Environment]::GetFolderPath('UserProfile')
if (-not $SettingsPath) {
    $claudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $userRoot '.claude' }
    $SettingsPath = Join-Path $claudeRoot 'settings.json'
}
$SettingsPath = [System.IO.Path]::GetFullPath($SettingsPath)
if (Test-Path -LiteralPath $SettingsPath) { Update-DingDongClaudeHooks -SettingsPath $SettingsPath }
if ($RemoveFiles) {
    $allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $userRoot '.claude\plugins'))
    $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $allowedRoot 'dingdong'))
    if (-not $pluginRoot.StartsWith($allowedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe plugin path.' }
    if (Test-Path -LiteralPath $pluginRoot) {
        $item = Get-Item -LiteralPath $pluginRoot -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'Refusing to remove a linked plugin directory.' }
        Remove-Item -LiteralPath $pluginRoot -Recurse -Force
    }
}
Write-Host 'DingDong Claude Code hooks removed. Shared settings and sounds are retained for Codex.'
