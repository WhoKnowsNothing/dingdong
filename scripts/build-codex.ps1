param([Parameter(Mandatory = $true)][string]$OutputDir)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = [System.IO.Path]::GetFullPath($OutputDir).TrimEnd('\', '/')
if ($projectRoot -eq $outputRoot -or $projectRoot.StartsWith($outputRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The output must not be the source repository or one of its parents.'
}

# The Codex package is generated from the same players and UI as Claude Code.
# Keep its hook file out of Claude's auto-discovered hooks/hooks.json location.
$files = @('play-sound.ps1', 'play-sound.sh', 'config-ui.ps1', 'configure.bat',
    'config.sh', 'config.json', 'LICENSE', 'COMMERCIAL_LICENSE.md', 'README.md',
    'scripts/data-paths.ps1', 'scripts/data-paths.sh', 'scripts/on-event.ps1', 'scripts/on-event.sh')
foreach ($file in $files) {
    $destination = Join-Path $outputRoot $file
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $destination -Force
}
[void][System.IO.Directory]::CreateDirectory((Join-Path $outputRoot 'sounds'))
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'sounds') -Filter '*.wav' -File |
    Copy-Item -Destination (Join-Path $outputRoot 'sounds') -Force
[void][System.IO.Directory]::CreateDirectory((Join-Path $outputRoot '.codex-plugin'))
[void][System.IO.Directory]::CreateDirectory((Join-Path $outputRoot 'hooks'))
Copy-Item -LiteralPath (Join-Path $projectRoot 'integrations/codex/.codex-plugin/plugin.json') -Destination (Join-Path $outputRoot '.codex-plugin/plugin.json') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'integrations/codex/hooks.json') -Destination (Join-Path $outputRoot 'hooks/hooks.json') -Force
Write-Host "Codex package: $outputRoot"
