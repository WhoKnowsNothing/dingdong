# Both clients keep user data outside their versioned plugin directories.
function Get-DingDongDataRoot {
    if ($env:DINGDONG_HOME) {
        if (-not [System.IO.Path]::IsPathRooted($env:DINGDONG_HOME)) {
            throw 'DINGDONG_HOME must be an absolute path.'
        }
        return [System.IO.Path]::GetFullPath($env:DINGDONG_HOME)
    }
    return Join-Path ([Environment]::GetFolderPath('UserProfile')) '.config\dingdong'
}

function Initialize-DingDongData([string]$SourceRoot) {
    $dataRoot = Get-DingDongDataRoot
    $soundDir = Join-Path $dataRoot 'sounds'
    [void][System.IO.Directory]::CreateDirectory($soundDir)
    foreach ($sound in Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'sounds') -File -Filter '*.wav') {
        $destination = Join-Path $soundDir $sound.Name
        if (-not [System.IO.File]::Exists($destination)) {
            try { [System.IO.File]::Copy($sound.FullName, $destination, $false) }
            catch { if (-not [System.IO.File]::Exists($destination)) { throw } }
        }
    }
    $configPath = Join-Path $dataRoot 'config.json'
    if (-not [System.IO.File]::Exists($configPath)) {
        # Publish a complete JSON file; concurrent installers never overwrite it.
        $tempPath = Join-Path $dataRoot ([guid]::NewGuid().ToString() + '.tmp')
        try {
            [System.IO.File]::Copy((Join-Path $SourceRoot 'config.json'), $tempPath)
            try { [System.IO.File]::Move($tempPath, $configPath) }
            catch { if (-not [System.IO.File]::Exists($configPath)) { throw } }
        } finally {
            if ([System.IO.File]::Exists($tempPath)) { [System.IO.File]::Delete($tempPath) }
        }
    }
    return $dataRoot
}

function Get-DingDongConfigRoot([string]$PluginRoot) {
    $dataRoot = Get-DingDongDataRoot
    if (Test-Path -LiteralPath (Join-Path $dataRoot 'config.json') -PathType Leaf) {
        return $dataRoot
    }
    # An unpacked plugin still works before the first install/configuration.
    return $PluginRoot
}
