param(
    [string]$File,
    [int]$Volume = 80
)

if (-not (Test-Path $File)) {
    Write-Error "WAV file not found: $File"
    exit 1
}

try {
    $player = New-Object System.Media.SoundPlayer($File)
    $player.PlaySync()
}
catch {
    Write-Error "Failed to play: $File - $_"
    exit 1
}
