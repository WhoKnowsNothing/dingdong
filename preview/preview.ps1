function Show-Preview {
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    $configPath = Join-Path $projectRoot "config.json"
    $soundsDir = Join-Path $projectRoot "sounds"

    # Collect sounds
    $sounds = @()
    Get-ChildItem "$soundsDir/*.wav" | Sort-Object Name | ForEach-Object {
        $sounds += @{Type="wav"; Name=$_.Name; Path=$_.FullName}
    }
    $systemSounds = @("Asterisk", "Question", "Exclamation", "Hand", "Beep")
    $systemSounds | ForEach-Object {
        $sounds += @{Type="system"; Name="[System] $_"; Path=$_}
    }

    # Show menu
    Write-Host "`nDingDong Sound Preview" -ForegroundColor Cyan
    Write-Host ("=" * 40) -ForegroundColor Cyan
    for ($i = 0; $i -lt $sounds.Count; $i++) {
        Write-Host ("[{0,2}] {1}" -f ($i + 1), $sounds[$i].Name)
    }

    # Play selection
    $choice = Read-Host "`nEnter number to preview (or q to quit)"
    if ($choice -eq 'q') { return }

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $sounds.Count) {
        Write-Host "Invalid selection" -ForegroundColor Red
        return
    }

    $selected = $sounds[$idx]
    Write-Host ">> Playing: $($selected.Name)" -ForegroundColor Green

    if ($selected.Type -eq "wav") {
        $player = New-Object System.Media.SoundPlayer($selected.Path)
        $player.PlaySync()
    }
    else {
        $systemSoundMap = @{
            "Asterisk"   = [System.Media.SystemSounds]::Asterisk
            "Question"   = [System.Media.SystemSounds]::Question
            "Exclamation"= [System.Media.SystemSounds]::Exclamation
            "Hand"       = [System.Media.SystemSounds]::Hand
            "Beep"       = [System.Media.SystemSounds]::Beep
        }
        $systemSoundMap[$selected.Path].Play()
    }

    # Configure to event
    $assign = Read-Host "`nAssign to event? (Stop/Notification/PermissionRequest/Elicitation/TeammateIdle, or Enter to skip)"
    if ($assign -ne '') {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($selected.Type -eq "wav") {
            $subEntry = @{ type = "wav"; file = '${CLAUDE_PLUGIN_ROOT}/sounds/' + $selected.Name; label = $selected.Name -replace '\.wav$', '' }
        } else {
            $subEntry = @{ type = "system"; sound = $selected.Path; label = "System " + $selected.Path }
        }
        $config.subscriptions | Add-Member -MemberType NoteProperty -Name $assign -Value @($subEntry) -Force
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
        Write-Host "OK $assign -> $($selected.Name)" -ForegroundColor Green
    }
}

Show-Preview
