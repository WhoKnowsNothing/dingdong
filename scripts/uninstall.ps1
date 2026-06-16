param([switch]$RemoveFiles)

$pluginRoot = "$env:USERPROFILE\.claude\plugins\dingdong"

Write-Host "DingDong Uninstaller (Windows)"
Write-Host "=============================="

function ConvertTo-Ht($obj) {
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = ConvertTo-Ht $_.Value }
        $ht
    } elseif ($obj -is [array]) {
        ,@($obj | ForEach-Object { ConvertTo-Ht $_ })
    } else { $obj }
}

$settingsPaths = @(
    "$env:APPDATA\Claude Code\settings.json",
    "$env:USERPROFILE\.claude\settings.json"
)

$modified = $false
foreach ($settingsPath in $settingsPaths) {
    if (-not (Test-Path $settingsPath)) { continue }

    $content = Get-Content $settingsPath -Raw -Encoding UTF8
    if (-not $content) { continue }

    $settings = ConvertTo-Ht ($content | ConvertFrom-Json)
    if (-not $settings.ContainsKey("hooks")) { continue }

    $hooks = $settings["hooks"]
    $dingdongEvents = @()

    # Scan each event for DingDong entries
    # Snapshot keys to avoid "collection was modified" enumeration error
    $hookKeys = @($hooks.Keys)
    $hookKeys | ForEach-Object {
        $eventName = $_
        $entries = $hooks[$eventName]
        $filtered = @()
        $found = $false

        foreach ($entry in $entries) {
            $isDingdong = $false
            foreach ($hook in $entry["hooks"]) {
                $cmd = $hook["command"]
                if ($cmd -match "dingdong") { $isDingdong = $true; break }
            }
            if (-not $isDingdong) { $filtered += $entry }
            else { $found = $true }
        }

        if ($found) {
            $dingdongEvents += $eventName
            if ($filtered.Count -gt 0) {
                $hooks[$eventName] = $filtered
            } else {
                $hooks.Remove($eventName)
            }
        }
    }

    if ($dingdongEvents.Count -gt 0) {
        if ($hooks.Count -eq 0) { $settings.Remove("hooks") }
        else { $settings["hooks"] = $hooks }

        $json = $settings | ConvertTo-Json -Depth 10
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)
        Write-Host "Removed DingDong hooks from: $settingsPath"
        Write-Host "  Events affected: $($dingdongEvents -join ', ')"
        $modified = $true
    }
}

if (-not $modified) { Write-Host "No DingDong hooks found in settings.json" }

if ($RemoveFiles -and (Test-Path $pluginRoot)) {
    Remove-Item -Path $pluginRoot -Recurse -Force
    Write-Host "Plugin files removed from: $pluginRoot"
}

Write-Host ""
Write-Host "Done. Run '/hooks' or restart Claude Code."
