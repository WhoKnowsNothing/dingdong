param(
    [string]$SettingsPath = "$env:USERPROFILE\.claude\settings.json",
    [string]$PluginDir = "$env:USERPROFILE\.claude\plugins\dingdong",
    [switch]$Uninstall
)

$busCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File \"$PluginDir\events\event-bus.ps1\" -Event"

$hookDefs = @{
    Stop             = '[{"matcher":"*","hooks":[{"type":"command","command":"' + $busCmd + ' Stop","timeout":10,"async":true}]}]'
    Notification     = '[{"matcher":"(?i)task.?complet|done|finished|completed","hooks":[{"type":"command","command":"' + $busCmd + ' Notification","timeout":10,"async":true}]}]'
    PermissionRequest = '[{"matcher":"Bash|Write|Edit|Read","hooks":[{"type":"command","command":"' + $busCmd + ' PermissionRequest","timeout":10,"async":true}]}]'
    Elicitation      = '[{"matcher":".*","hooks":[{"type":"command","command":"' + $busCmd + ' Elicitation","timeout":10,"async":true}]}]'
    TeammateIdle     = '[{"matcher":".*","hooks":[{"type":"command","command":"' + $busCmd + ' TeammateIdle","timeout":10,"async":true}]}]'
    PreToolUse       = '[{"matcher":"AskUserQuestion","hooks":[{"type":"command","command":"' + $busCmd + ' Elicitation","timeout":10,"async":true}]}]'
    SubagentStop     = '[{"matcher":".*","hooks":[{"type":"command","command":"' + $busCmd + ' Notification","timeout":10,"async":true}]}]'
}

if (-not (Test-Path $SettingsPath)) {
    Write-Error "settings.json not found at $SettingsPath"
    exit 1
}

$json = Get-Content $SettingsPath -Raw
$config = $json | ConvertFrom-Json

if (-not $config.hooks) {
    $config | Add-Member -MemberType NoteProperty -Name 'hooks' -Value (New-Object PSObject)
}

$hooks = $config.hooks

if ($Uninstall) {
    # Remove only dingdong hooks, keep everything else
    $eventsToRemove = @()
    foreach ($prop in $hooks.PSObject.Properties) {
        $eventName = $prop.Name
        $matchers = $prop.Value
        $keepers = @()
        foreach ($matcher in $matchers) {
            if ($matcher.hooks) {
                $keptHooks = $matcher.hooks | Where-Object {
                    $cmd = $_.command
                    $cmd -notmatch 'dingdong' -and $cmd -notmatch 'event-bus\.ps1' -and $cmd -notmatch 'play-sound\.ps1'
                }
                if ($keptHooks) {
                    $matcher.hooks = $keptHooks
                    $keepers += $matcher
                }
            }
        }
        if ($keepers.Count -gt 0) {
            $hooks.$eventName = $keepers
        } else {
            $eventsToRemove += $eventName
        }
    }
    foreach ($e in $eventsToRemove) {
        $hooks.PSObject.Properties.Remove($e)
    }
    if ($hooks.PSObject.Properties.Name.Count -eq 0) {
        $config.PSObject.Properties.Remove('hooks')
    }
} else {
    # Install: add new hooks, preserve existing non-dingdong hooks
    $existingEvents = @{}
    foreach ($prop in $hooks.PSObject.Properties) {
        $existingEvents[$prop.Name] = $true
    }

    foreach ($event in $hookDefs.Keys) {
        if (-not $existingEvents.ContainsKey($event)) {
            $parsed = $hookDefs[$event] | ConvertFrom-Json
            $hooks | Add-Member -MemberType NoteProperty -Name $event -Value $parsed
        } else {
            # Event exists - check if dingdong hook is already registered
            $hasDingDong = $false
            $matchers = $hooks.$event
            foreach ($matcher in $matchers) {
                if ($matcher.hooks) {
                    foreach ($h in $matcher.hooks) {
                        if ($h.command -match 'event-bus') { $hasDingDong = $true; break }
                    }
                }
                if ($hasDingDong) { break }
            }
            if (-not $hasDingDong) {
                $parsed = $hookDefs[$event] | ConvertFrom-Json
                $hooks.$event = @($matchers + $parsed)
            }
        }
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath
Write-Output "OK"
