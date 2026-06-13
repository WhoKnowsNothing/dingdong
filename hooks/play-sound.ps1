param(
    [Parameter(Mandatory)]
    [ValidateSet("Stop", "Notification", "PermissionRequest", "Elicitation", "TeammateIdle")]
    [string]$Event,

    [string]$ConfigPath
)

# $PSScriptRoot is unreliable in param default values when called from Claude Code hook,
# so it's resolved here in the script body
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $ScriptDir "config.json" }

# ============================================================
# play-sound.ps1 — Hook entry point for all sound events
# Reads config.json and plays the configured sound for $Event
# ============================================================

# Resolve CLAUDE_PLUGIN_ROOT — the plugin root is the script's own directory
$Script:PluginRoot = $ScriptDir

function Resolve-PluginPath([string]$Path) {
    if ($Path -and $Path.Contains('${CLAUDE_PLUGIN_ROOT}')) {
        return $Path.Replace('${CLAUDE_PLUGIN_ROOT}', $Script:PluginRoot)
    }
    return $Path
}

function Get-WaveDuration([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        $reader = [System.IO.BinaryReader]::new($fs)
        try {
            $null = $reader.ReadBytes(40)  # skip headers
            $dataSize = $reader.ReadInt32()
            $sampleRate = 44100
            $channels = 1
            $bitsPerSample = 16
            return [math]::Round($dataSize / ($sampleRate * $channels * ($bitsPerSample / 8)), 1)
        }
        finally {
            $reader.Close()
            $fs.Close()
        }
    } catch { return 0 }
}

# ---- Load config ----
$config = @{}
$eventsDefault = @{
    "Stop"              = @{ "type" = "wav"; "file" = "${CLAUDE_PLUGIN_ROOT}\sounds\done-classic.wav"; "label" = "Classic Chime" }
    "Notification"      = @{ "type" = "wav"; "file" = "${CLAUDE_PLUGIN_ROOT}\sounds\ding.wav";          "label" = "Ding" }
    "PermissionRequest" = @{ "type" = "system"; "sound" = "Hand";        "label" = "System Hand" }
    "Elicitation"       = @{ "type" = "system"; "sound" = "Question";    "label" = "System Question" }
    "TeammateIdle"      = @{ "type" = "system"; "sound" = "Exclamation"; "label" = "System Exclamation" }
}

if (Test-Path $ConfigPath) {
    try {
        $config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        # Convert PSCustomObject to hashtable (PS5.1 compatible)
        function ConvertTo-Ht($obj) {
            if ($obj -is [System.Management.Automation.PSCustomObject]) {
                $ht = @{}
                $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = ConvertTo-Ht $_.Value }
                $ht
            } elseif ($obj -is [array]) {
                ,@($obj | ForEach-Object { ConvertTo-Ht $_ })
            } else { $obj }
        }
        $config = ConvertTo-Ht $config
    } catch {
        Write-Warning "DingDong: failed to read config, using defaults"
    }
}

$events = if ($config.ContainsKey("events")) { $config.events } else { $eventsDefault }
$eventCfg = $events[$Event]
if (-not $eventCfg) {
    Write-Debug "DingDong: no config for event '$Event', skipping"
    return
}

$type = $eventCfg["type"]
$volume = if ($config.ContainsKey("volume")) { $config.volume } else { 80 }

# ---- Play the sound ----
# Hook sessions lack a Windows message pump, so SoundPlayer.PlaySync() silently fails.
# Strategy: try WAV playback with a message pump (hidden WinForms form), fall back to
# SystemSounds mapping if that fails (which always works in hook contexts).

$wavToSystemMap = @{
    "done-classic.wav"    = "Asterisk"
    "done-soft.wav"       = "Asterisk"
    "done-fanfare.wav"    = "Asterisk"
    "ding.wav"            = "Asterisk"
    "pop.wav"             = "Beep"
    "beep-soft.wav"       = "Beep"
    "notify-descend.wav"  = "Asterisk"
    "alert.wav"           = "Hand"
    "warning.wav"         = "Exclamation"
    "error.wav"           = "Hand"
    "question-rising.wav" = "Question"
    "question-double.wav" = "Question"
}

function Play-SystemSound([string]$Name) {
    switch ($Name) {
        "Hand"        { [System.Media.SystemSounds]::Hand.Play() }
        "Question"    { [System.Media.SystemSounds]::Question.Play() }
        "Exclamation" { [System.Media.SystemSounds]::Exclamation.Play() }
        "Asterisk"    { [System.Media.SystemSounds]::Asterisk.Play() }
        "Beep"        { [System.Media.SystemSounds]::Beep.Play() }
        default       { [System.Media.SystemSounds]::Beep.Play() }
    }
}

function Play-WavAsync([string]$Path) {
    # SoundPlayer.Play() uses a background thread — no message pump needed
    $player = New-Object System.Media.SoundPlayer $Path
    $player.Play()
    Start-Sleep -Milliseconds 3000  # keep process alive for playback
    $player.Stop()
}

try {
    if ($type -eq "none") {
        return  # Silent
    }
    elseif ($type -eq "system") {
        Play-SystemSound $eventCfg["sound"]
    }
    elseif ($type -eq "wav") {
        $wavPath = Resolve-PluginPath $eventCfg["file"]
        $wavFile = [System.IO.Path]::GetFileName($eventCfg["file"])
        $played = $false
        # Try async WAV playback (works without message pump)
        if (Test-Path $wavPath) {
            try {
                Play-WavAsync $wavPath
                $played = $true
            } catch {
                # Fall through to SystemSounds fallback
            }
        }
        # Fallback: map to SystemSound
        if (-not $played) {
            $soundName = if ($wavToSystemMap.ContainsKey($wavFile)) { $wavToSystemMap[$wavFile] } else { "Beep" }
            Play-SystemSound $soundName
        }
    }
} catch {
    # Silently fail — don't let sound errors affect Claude Code
    Write-Debug "DingDong: playback error for $Event : $_"
}
