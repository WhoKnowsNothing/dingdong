param(
    [string]$SettingsPath = "$env:USERPROFILE\.claude\settings.json",
    [string]$PluginDir = "$env:USERPROFILE\.claude\plugins\dingdong",
    [switch]$Uninstall
)

$eventBusPs1 = Join-Path (Join-Path $PluginDir "events") "event-bus.ps1"
$busCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $eventBusPs1 + '" -Event'

# Build hook definitions as PowerShell objects (no string-to-JSON conversion needed)
function New-HookMatcher($matcher, $cmd, $eventName) {
    return [PSCustomObject]@{
        matcher = $matcher
        hooks = @(
            [PSCustomObject]@{
                type = "command"
                command = "$cmd $eventName"
                timeout = 10
                async = $true
            }
        )
    }
}

$hookDefs = @(
    @{ Name = "Stop";             Matcher = "*";                                        Event = "Stop" }
    @{ Name = "Notification";     Matcher = "(?i)task.?complet|done|finished|completed"; Event = "Notification" }
    @{ Name = "PermissionRequest"; Matcher = "Bash|Write|Edit|Read";                      Event = "PermissionRequest" }
    @{ Name = "Elicitation";      Matcher = ".*";                                        Event = "Elicitation" }
    @{ Name = "TeammateIdle";     Matcher = ".*";                                        Event = "TeammateIdle" }
    @{ Name = "PreToolUse";       Matcher = "AskUserQuestion";                           Event = "Elicitation" }
    @{ Name = "SubagentStop";     Matcher = ".*";                                        Event = "Notification" }
)

if (-not (Test-Path $SettingsPath)) {
    Write-Error "settings.json not found at $SettingsPath"
    exit 1
}

$config = Get-Content $SettingsPath -Raw | ConvertFrom-Json
if (-not $config.hooks) {
    $config | Add-Member -MemberType NoteProperty -Name 'hooks' -Value (New-Object PSObject)
}
$hooks = $config.hooks

# Normalize: ensure all hooks entries are arrays (Claude Code requires array format)
foreach ($prop in $hooks.PSObject.Properties) {
    $matchers = $prop.Value
    for ($i = 0; $i -lt $matchers.Count; $i++) {
        if ($null -ne $matchers[$i].hooks -and $matchers[$i].hooks.GetType().Name -eq 'PSCustomObject') {
            $matchers[$i].hooks = @($matchers[$i].hooks)
        }
    }
}

if ($Uninstall) {
    # Remove dingdong hooks, keep everything else
    $eventsToRemove = @()
    foreach ($prop in $hooks.PSObject.Properties) {
        $eventName = $prop.Name
        $matchers = $prop.Value
        $keepers = @()
        foreach ($matcher in $matchers) {
            if ($null -eq $matcher) { continue }
            if ($matcher.hooks) {
                $keptHooks = $matcher.hooks | Where-Object {
                    $cmd = "$($_.command)"
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
    # Install: merge dingdong hooks, preserve existing
    $existingEvents = @{}
    foreach ($prop in $hooks.PSObject.Properties) {
        $existingEvents[$prop.Name] = $true
    }

    foreach ($def in $hookDefs) {
        $eventName = $def.Name
        $newMatcher = New-HookMatcher -matcher $def.Matcher -cmd $busCmd -eventName $def.Event

        if (-not $existingEvents.ContainsKey($eventName)) {
            $hooks | Add-Member -MemberType NoteProperty -Name $eventName -Value @($newMatcher)
        } else {
            # Event already exists - check if dingdong hook is already there
            $hasDingDong = $false
            $matchers = $hooks.$eventName
            foreach ($matcher in $matchers) {
                if ($null -eq $matcher) { continue }
                foreach ($h in $matcher.hooks) {
                    if ("$($h.command)" -match 'event-bus') { $hasDingDong = $true; break }
                }
                if ($hasDingDong) { break }
            }
            if (-not $hasDingDong) {
                $hooks.$eventName = @($matchers + $newMatcher)
            }
        }
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath
Write-Output "OK"
