param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Stop', 'PermissionRequest', 'Elicitation', 'Notification')]
    [string]$Event
)

# Codex requires JSON even for a muted event. Never persist hook input.
$ErrorActionPreference = 'Stop'

function Test-DingDongNewCompletion([string]$Payload) {
    try { $completion = $Payload | ConvertFrom-Json -ErrorAction Stop }
    catch { return $true }
    if ($completion.session_id -isnot [string] -or [string]::IsNullOrWhiteSpace($completion.session_id) -or
        $completion.turn_id -isnot [string] -or [string]::IsNullOrWhiteSpace($completion.turn_id)) {
        # Older clients/manual invocations without an identity must still notify.
        return $true
    }

    . (Join-Path $PSScriptRoot 'data-paths.ps1')
    $stateDir = Join-Path (Get-DingDongDataRoot) 'state/codex-stop'
    [void][System.IO.Directory]::CreateDirectory($stateDir)
    $identity = ConvertTo-Json -InputObject @($completion.session_id, $completion.turn_id) -Compress
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digest = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
    $markerPath = Join-Path $stateDir ($digest + '.done')

    # Atomic creation also prevents two concurrently dispatched hooks from playing.
    # Only an empty hash-named marker is retained, never IDs or conversation text.
    try {
        $marker = [System.IO.File]::Open($markerPath, [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $marker.Dispose()
    } catch [System.IO.IOException] {
        if ([System.IO.File]::Exists($markerPath)) { return $false }
        throw
    }

    # Bound runtime state; delayed callbacks remain deduplicated for seven days.
    $cutoff = [DateTime]::UtcNow.AddDays(-7)
    foreach ($path in [System.IO.Directory]::EnumerateFiles($stateDir, '*.done')) {
        if ([System.IO.Path]::GetFileName($path) -cmatch '^[0-9a-f]{64}\.done$') {
            try {
                if ([System.IO.File]::GetLastWriteTimeUtc($path) -lt $cutoff) { [System.IO.File]::Delete($path) }
            } catch { }
        }
    }
    return $true
}

try {
    $payload = [Console]::In.ReadToEnd()
    $play = $true
    if ($Event -eq 'Stop') {
        try { $play = Test-DingDongNewCompletion -Payload $payload }
        catch { [Console]::Error.WriteLine('DingDong: completion deduplication unavailable.') }
    }
    if ($play) {
        & (Join-Path (Split-Path -Parent $PSScriptRoot) 'play-sound.ps1') -Event $Event | Out-Null
    }
} catch {
    [Console]::Error.WriteLine('DingDong: unable to play the configured sound.')
} finally {
    [Console]::Out.WriteLine('{}')
}
exit 0
