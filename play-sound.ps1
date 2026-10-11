param([string]$Event, [switch]$DryRun)

# winmm.dll P/Invoke — defined once at script scope to avoid Add-Type duplicate errors
if (-not $DryRun -and -not ([System.Management.Automation.PSTypeName]'DD').Type) {
Add-Type @'
using System.Runtime.InteropServices;
public class DD {
    [DllImport("winmm.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool PlaySound(string pszSound, System.IntPtr hmod, uint fdwSound);
}
'@
}

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'scripts/data-paths.ps1')
$scriptDir = Get-DingDongConfigRoot -PluginRoot $scriptDir
$configPath = Join-Path $scriptDir "config.json"
if (-not (Test-Path -LiteralPath $configPath)) { return }

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

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
    # Interpret legacy data without rewriting a shared file during a hook.
    $config = $v2
    $events = $config.events
} else {
    $events = $config.events
}

# Look up event
$eventCfg = $events.$Event
if ($DryRun) {
    $file = $null
    if ($eventCfg.type -eq 'wav') {
        $file = if ([System.IO.Path]::IsPathRooted($eventCfg.file)) { $eventCfg.file } else { Join-Path $scriptDir $eventCfg.file }
    }
    [pscustomobject]@{ event = $Event; config = $configPath; type = $(if ($eventCfg) { $eventCfg.type } else { 'none' }); file = $file } | ConvertTo-Json -Compress
    return
}
if (-not $eventCfg) { return }

$type = $eventCfg.type
if ($type -eq "none") { return }

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
    return
}

if ($type -eq "wav") {
    $wavPath = if ([System.IO.Path]::IsPathRooted($eventCfg.file)) { $eventCfg.file } else { Join-Path $scriptDir $eventCfg.file }
    if (-not (Test-Path -LiteralPath $wavPath)) { return }
    if (-not [DD]::PlaySound($wavPath, [System.IntPtr]::Zero, 0x00020002)) {
        throw 'DingDong: Windows could not play the configured WAV.'
    }
    return
}
