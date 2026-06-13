param([string]$Sound)

$validSounds = @("Asterisk", "Question", "Exclamation", "Hand", "Beep")
if ($Sound -notin $validSounds) {
    Write-Error "Invalid system sound. Valid: $($validSounds -join ', ')"
    exit 1
}

$sp = New-Object System.Media.SoundPlayer
$sp.Stream = ([System.Media.SystemSounds]::$Sound).Stream
$sp.PlaySync()
