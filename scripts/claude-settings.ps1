function ConvertTo-DingDongHashtable($Value) {
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-DingDongHashtable $property.Value
        }
        return $result
    }
    if ($Value -is [array]) {
        return ,@($Value | ForEach-Object { ConvertTo-DingDongHashtable $_ })
    }
    return $Value
}

function Update-DingDongClaudeHooks([string]$SettingsPath, [hashtable]$NewHooks) {
    $settings = @{}
    if (Test-Path -LiteralPath $SettingsPath) {
        # Invalid JSON is an error, never permission to discard existing settings.
        $settings = ConvertTo-DingDongHashtable (Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
        if ($settings -isnot [hashtable]) { throw 'Claude settings must be a JSON object.' }
    }
    $hooks = if ($settings.ContainsKey('hooks')) { $settings.hooks } else { @{} }
    if ($hooks -isnot [hashtable]) { throw 'Claude hooks must be a JSON object.' }
    foreach ($eventName in @($hooks.Keys)) {
        $groups = @()
        foreach ($group in $hooks[$eventName]) {
            # Retain other handlers even when they share a DingDong matcher group.
            $remaining = @($group.hooks | Where-Object { $_.command -notmatch '(?i)dingdong[\\/].*play-sound\.(ps1|sh)' })
            if ($remaining.Count) {
                $group.hooks = $remaining
                $groups += $group
            }
        }
        if ($groups.Count) { $hooks[$eventName] = $groups }
        else { $hooks.Remove($eventName) }
    }
    if ($NewHooks) {
        foreach ($eventName in $NewHooks.Keys) {
            $hooks[$eventName] = @($hooks[$eventName] | Where-Object { $null -ne $_ }) + @($NewHooks[$eventName])
        }
    }
    if ($hooks.Count) { $settings.hooks = $hooks }
    else { $settings.Remove('hooks') }
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $SettingsPath))
    if (Test-Path -LiteralPath $SettingsPath) {
        $backupPath = $SettingsPath + '.dingdong-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        Copy-Item -LiteralPath $SettingsPath -Destination $backupPath
        Write-Host "Settings backup: $backupPath"
    }
    [System.IO.File]::WriteAllText($SettingsPath, ($settings | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding $false))
}
