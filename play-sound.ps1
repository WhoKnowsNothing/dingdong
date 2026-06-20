param([string]$Event)

# winmm.dll P/Invoke — defined once at script scope to avoid Add-Type duplicate errors
if (-not ([System.Management.Automation.PSTypeName]'DD').Type) {
Add-Type @'
using System.Runtime.InteropServices;
public class DD {
    [DllImport("winmm.dll", SetLastError=true)]
    public static extern bool PlaySound(string pszSound, System.IntPtr hmod, uint fdwSound);
}
'@
}

$scriptDir = Split-Path -Parent $PSCommandPath
$configPath = Join-Path $scriptDir "config.json"
if (-not (Test-Path $configPath)) { exit 0 }

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# --- v1 → v2 auto-upgrade ---
if ($config.PSObject.Properties.Name -contains "Stop" -and $config.Stop -is [string]) {
    # Flat v1 format: {"Stop": "sounds/foo.wav"}
    $v2 = @{ version = 2; volume = 80; events = @{} }
    $eventNames = @("Stop","Notification","PermissionRequest","Elicitation","TeammateIdle")
    foreach ($evt in $eventNames) {
        $val = $config.$evt
        if ($val -and $val -is [string]) {
            $v2.events[$evt] = @{ type = "wav"; file = $val }
        } else {
            $v2.events[$evt] = @{ type = "none" }
        }
    }
    # Write back v2
    $json = $v2 | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
    $config = $v2
    $events = $config.events
} else {
    $events = $config.events
}

# Look up event
$eventCfg = $events.$Event
if (-not $eventCfg) { exit 0 }

$type = $eventCfg.type
if ($type -eq "none") { exit 0 }

if ($type -eq "system") {
    $soundName = $eventCfg.sound
    switch ($soundName) {
        "Hand"        { [System.Media.SystemSounds]::Hand.Play() }
        "Question"    { [System.Media.SystemSounds]::Question.Play() }
        "Exclamation" { [System.Media.SystemSounds]::Exclamation.Play() }
        "Asterisk"    { [System.Media.SystemSounds]::Asterisk.Play() }
        "Beep"        { [System.Media.SystemSounds]::Beep.Play() }
        default       { [System.Media.SystemSounds]::Beep.Play() }
    }
    exit 0
}

if ($type -eq "wav") {
    $wavPath = Join-Path $scriptDir $eventCfg.file
    if (-not (Test-Path $wavPath)) { exit 0 }
    [DD]::PlaySound($wavPath, [System.IntPtr]::Zero, 0x00020000) | Out-Null
    exit 0
}
