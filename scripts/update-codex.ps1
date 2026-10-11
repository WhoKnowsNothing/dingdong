# Update the existing local marketplace entry from this repository.
param([string]$Marketplace)
$ErrorActionPreference = 'Stop'
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' }
$inventoryArgs = @('plugin', 'list', '--available', '--json')
if ($Marketplace) { $inventoryArgs += @('--marketplace', $Marketplace) }
$inventoryJson = & codex @inventoryArgs
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Codex plugins.' }
$inventory = ($inventoryJson -join "`n") | ConvertFrom-Json
$entries = @(@($inventory.installed) + @($inventory.available) | Where-Object {
    $_.name -eq 'dingdong' -and (-not $Marketplace -or $_.marketplaceName -eq $Marketplace)
})
if ($entries.Count -ne 1 -or $entries[0].source.source -ne 'local') {
    throw 'Register the generated DingDong package in a local Codex marketplace first. Use -Marketplace if more than one DingDong entry exists.'
}
$marketplaceName = $entries[0].marketplaceName
$pluginRoot = $entries[0].source.path
if (-not [System.IO.Path]::IsPathRooted($pluginRoot)) { throw 'The local plugin source must be an absolute path.' }
$backupRoot = Join-Path $codexHome ('backups/dingdong-update-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
[void][System.IO.Directory]::CreateDirectory($backupRoot)
Copy-Item -LiteralPath $pluginRoot -Destination (Join-Path $backupRoot 'plugin') -Recurse
if (Test-Path -LiteralPath (Join-Path $codexHome 'config.toml')) {
    Copy-Item -LiteralPath (Join-Path $codexHome 'config.toml') -Destination (Join-Path $backupRoot 'config.toml.before')
}
. (Join-Path $PSScriptRoot 'data-paths.ps1')
$seedRoot = if (Test-Path -LiteralPath (Join-Path $pluginRoot 'config.json')) { $pluginRoot } else { Split-Path -Parent $PSScriptRoot }
[void](Initialize-DingDongData -SourceRoot $seedRoot)
& (Join-Path $PSScriptRoot 'build-codex.ps1') -OutputDir $pluginRoot
$manifestPath = Join-Path $pluginRoot '.codex-plugin/plugin.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.name -ne 'dingdong') { throw 'The generated package is not DingDong.' }
$manifest.version = $manifest.version.Split('+')[0] + '+codex.' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding $false))
[void](Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
& codex plugin add "dingdong@$marketplaceName" --json
if ($LASTEXITCODE -ne 0) { throw "Codex installation failed. Backup: $backupRoot" }
Write-Host "Backup: $backupRoot"
Write-Host 'Review changed DingDong hooks in /hooks, then start a new Codex task.'
