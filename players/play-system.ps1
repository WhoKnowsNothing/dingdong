param([string]$Sound)

$validSounds = @("Asterisk", "Question", "Exclamation", "Hand", "Beep")
if ($Sound -notin $validSounds) {
    Write-Error "Invalid system sound. Valid: $($validSounds -join ', ')"
    exit 1
}

[System.Media.SystemSounds]::$Sound.Play()
