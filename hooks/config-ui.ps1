# ============================================================
# Sound Pack Configuration UI (Windows WinForms)
# Native GUI for selecting which sounds play for each event
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- Resolve paths ----
# Script can run from source (repo/hooks/) or from installed dir (sound-pack/)
# In both cases, sounds/ is a sibling of the script's location
$Script:ScriptDir = $PSScriptRoot

# Determine plugin root: if running from hooks/ subdir, parent is root; else script dir itself
if ((Split-Path $Script:ScriptDir -Leaf) -eq "hooks") {
    $Script:PluginRoot = Split-Path $Script:ScriptDir -Parent
} else {
    $Script:PluginRoot = $Script:ScriptDir
}
$Script:SoundsDir = Join-Path $Script:PluginRoot "sounds"
$Script:ConfigPath = Join-Path $Script:PluginRoot "config.json"

# ---- Enumerate available sounds ----
function Get-AvailableWavs {
    $dir = $Script:SoundsDir
    if (-not (Test-Path $dir)) { return @() }
    return Get-ChildItem $dir -Filter "*.wav" | Sort-Object Name
}

function Get-SystemSounds {
    return @(
        @{ "id" = "Hand";        "label" = "System: Hand (critical stop)" }
        @{ "id" = "Question";    "label" = "System: Question" }
        @{ "id" = "Exclamation"; "label" = "System: Exclamation" }
        @{ "id" = "Asterisk";    "label" = "System: Asterisk" }
        @{ "id" = "Beep";        "label" = "System: Beep" }
    )
}

# ---- Load config ----
function Load-Config {
    if (Test-Path $Script:ConfigPath) {
        try {
            $raw = Get-Content $Script:ConfigPath -Raw -Encoding UTF8
            return $raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Save-Config($cfg) {
    $json = $cfg | ConvertTo-Json -Depth 4
    $null = New-Item -ItemType Directory -Path (Split-Path $Script:ConfigPath -Parent) -Force
    [System.IO.File]::WriteAllText($Script:ConfigPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-WavPath([string]$Path) {
    # Handle ${CLAUDE_PLUGIN_ROOT} placeholder
    if ($Path -and $Path.Contains('${CLAUDE_PLUGIN_ROOT}')) {
        return $Path.Replace('${CLAUDE_PLUGIN_ROOT}', $Script:PluginRoot)
    }
    return $Path
}

# ---- Preview sound ----
function Preview-Sound {
    param([string]$Type, [string]$SoundOrFile)

    try {
        if ($Type -eq "system") {
            switch ($SoundOrFile) {
                "Hand"        { [System.Media.SystemSounds]::Hand.Play(); break }
                "Question"    { [System.Media.SystemSounds]::Question.Play(); break }
                "Exclamation" { [System.Media.SystemSounds]::Exclamation.Play(); break }
                "Asterisk"    { [System.Media.SystemSounds]::Asterisk.Play(); break }
                "Beep"        { [System.Media.SystemSounds]::Beep.Play(); break }
            }
        }
        elseif ($Type -eq "wav") {
            $resolved = Resolve-WavPath $SoundOrFile
            if (-not (Test-Path $resolved)) {
                [System.Windows.Forms.MessageBox]::Show("WAV file not found:`n$resolved", "Preview Error", "OK", "Warning")
                return
            }
            $player = New-Object System.Media.SoundPlayer $resolved
            $player.PlaySync()
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Cannot play sound: $_", "DingDong", "OK", "Warning")
    }
}

# ---- Import custom WAV ----
function Import-CustomWav {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select a WAV sound file to import"
    $dialog.Filter = "WAV Audio Files (*.wav)|*.wav|All Files (*.*)|*.*"
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false

    if ($dialog.ShowDialog() -eq "OK") {
        $srcPath = $dialog.FileName
        $fileName = [System.IO.Path]::GetFileName($srcPath)

        # Avoid overwriting built-in sounds
        $builtIns = @("alert.wav","beep-soft.wav","ding.wav","done-classic.wav","done-fanfare.wav","done-soft.wav","error.wav","notify-descend.wav","pop.wav","question-double.wav","question-rising.wav","warning.wav")
        if ($builtIns -contains $fileName.ToLower()) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "'$fileName' is a built-in sound name. Overwrite it?",
                "Overwrite Built-in?",
                "YesNo",
                "Warning"
            )
            if ($result -eq "No") { return $null }
        }

        $null = New-Item -ItemType Directory -Path $Script:SoundsDir -Force
        $dstPath = Join-Path $Script:SoundsDir $fileName

        # If a custom file with same name exists, add a numeric suffix
        if (Test-Path $dstPath) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $ext = [System.IO.Path]::GetExtension($fileName)
            $counter = 1
            do {
                $dstPath = Join-Path $Script:SoundsDir "${baseName}_${counter}${ext}"
                $counter++
            } while (Test-Path $dstPath)
        }

        Copy-Item $srcPath $dstPath -Force
        Write-Host "Imported WAV: $dstPath"
        return $dstPath
    }
    return $null
}

# ---- Refresh dropdown items from current wavs list ----
function Update-DropdownItems {
    param([System.Windows.Forms.ComboBox]$ddl, [int]$keepSelectionIndex)

    $currentSelection = $ddl.SelectedIndex
    $sysSounds = Get-SystemSounds
    $currentWavs = Get-AvailableWavs

    $ddl.Items.Clear()
    $ddl.Items.Add("-- Silent --") | Out-Null
    foreach ($sys in $sysSounds) {
        $ddl.Items.Add($sys.label) | Out-Null
    }
    $ddl.Items.Add("--- Built-in WAV Files ---") | Out-Null
    foreach ($wav in $currentWavs) {
        $sizeKb = [math]::Round($wav.Length / 1KB, 1)
        $ddl.Items.Add("$($wav.Name)  ($sizeKb KB)") | Out-Null
    }
    $ddl.Items.Add("--- Import Custom WAV File... ---") | Out-Null

    if ($keepSelectionIndex -ge 0 -and $keepSelectionIndex -lt $ddl.Items.Count) {
        $ddl.SelectedIndex = $keepSelectionIndex
    }
}

# ---- Add custom wav import handler to dropdown ----
function Attach-ImportHandler {
    param([System.Windows.Forms.ComboBox]$ddl, [scriptblock]$refreshAll)

    $ddl.Add_SelectedIndexChanged({
        $sysSounds = Get-SystemSounds
        $currentWavs = Get-AvailableWavs
        $sysCount = $sysSounds.Count
        $importIdx = 1 + $sysCount + 1 + $currentWavs.Count  # Silent + system sounds + separator + wavs

        if ($this.SelectedIndex -eq $importIdx) {
            # "Import Custom WAV File..." selected — open dialog
            $newPath = Import-CustomWav
            if ($newPath) {
                # Refresh all dropdowns
                Invoke-Command $refreshAll
                # Find and select the new wav in this dropdown
                $newName = [System.IO.Path]::GetFileName($newPath)
                $updatedWavs = Get-AvailableWavs
                for ($i = 0; $i -lt $updatedWavs.Count; $i++) {
                    if ($updatedWavs[$i].Name -eq $newName) {
                        $this.SelectedIndex = 1 + $sysCount + 1 + $i
                        break
                    }
                }
            } else {
                # User cancelled — revert to previous selection
                # Dropdown forces an index, so select the first item (Silent) on cancel
                # Actually, since IndexChanged already fired, we can't block it.
                # The import was cancelled, so revert to index 0 (Silent)
                # But the dropdown is already at importIdx and won't go back automatically.
                # Set to 0 as fallback.
                $prevEvents = $global:eventDdlMap.GetEnumerator() | Where-Object { $_.Value -eq $this }
                # Just set to silent as a safe fallback
                $this.SelectedIndex = 0
            }
        }
    })
}

# ---- Build UI ----
$form = New-Object System.Windows.Forms.Form
$form.Text = "DingDong - Claude Code Sound Plugin"
$form.Size = New-Object System.Drawing.Size(680, 530)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $pid).MainModule.FileName)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

# Load config
$config = Load-Config
if (-not $config) {
    [System.Windows.Forms.MessageBox]::Show("No config found. Defaults will be used.", "DingDong", "OK", "Information")
}

$events = @(
    @{ "key" = "Stop";              "title" = "Task Complete (Stop)";          "desc" = "Plays when Claude finishes a response" }
    @{ "key" = "Notification";      "title" = "Task Notification";            "desc" = "Plays on task completion notifications" }
    @{ "key" = "PermissionRequest"; "title" = "Permission Request";           "desc" = "Plays when Claude needs permission" }
    @{ "key" = "Elicitation";       "title" = "Elicitation / Clarification";  "desc" = "Plays when Claude needs to ask a question" }
    @{ "key" = "TeammateIdle";      "title" = "Sub-agent Idle";               "desc" = "Plays when a sub-agent gets stuck" }
)

# Available WAVs
$wavs = Get-AvailableWavs
$systemSounds = Get-SystemSounds

# Track dropdowns per event
$global:eventDdlMap = @{}

# Shared refresh-all-dropdowns callback
$global:refreshAllDropdowns = {
    $sysSounds = Get-SystemSounds
    $currentWavs = Get-AvailableWavs
    foreach ($evt in $events) {
        $key = $evt.key
        $ddl = $global:eventDdlMap[$key]
        if (-not $ddl) { continue }
        $prevIdx = $ddl.SelectedIndex
        $ddl.Items.Clear()
        $ddl.Items.Add("-- Silent --") | Out-Null
        foreach ($sys in $sysSounds) {
            $ddl.Items.Add($sys.label) | Out-Null
        }
        $ddl.Items.Add("--- Built-in WAV Files ---") | Out-Null
        foreach ($wav in $currentWavs) {
            $sizeKb = [math]::Round($wav.Length / 1KB, 1)
            $ddl.Items.Add("$($wav.Name)  ($sizeKb KB)") | Out-Null
        }
        $ddl.Items.Add("--- Import Custom WAV File... ---") | Out-Null
        if ($prevIdx -lt $ddl.Items.Count) {
            $ddl.SelectedIndex = $prevIdx
        } else {
            $ddl.SelectedIndex = 0
        }
    }
}

# Volume slider
$volLabel = New-Object System.Windows.Forms.Label
$volLabel.Text = "Master Volume"
$volLabel.Location = New-Object System.Drawing.Point(15, 15)
$volLabel.Size = New-Object System.Drawing.Size(100, 22)

$volTrackbar = New-Object System.Windows.Forms.TrackBar
$volTrackbar.Location = New-Object System.Drawing.Point(120, 12)
$volTrackbar.Size = New-Object System.Drawing.Size(300, 40)
$volTrackbar.Minimum = 0
$volTrackbar.Maximum = 100
$volTrackbar.TickFrequency = 10
$volTrackbar.Value = if ($config) { $config.volume } else { 80 }

$volValueLabel = New-Object System.Windows.Forms.Label
$volValueLabel.Location = New-Object System.Drawing.Point(430, 15)
$volValueLabel.Size = New-Object System.Drawing.Size(40, 22)
$volValueLabel.Text = "$($volTrackbar.Value)%"

$volTrackbar.Add_Scroll({
    $volValueLabel.Text = "$($volTrackbar.Value)%"
})

$form.Controls.AddRange(@($volLabel, $volTrackbar, $volValueLabel))

# Separator line
$sep1 = New-Object System.Windows.Forms.Label
$sep1.Location = New-Object System.Drawing.Point(10, 58)
$sep1.Size = New-Object System.Drawing.Size(645, 2)
$sep1.BorderStyle = "Fixed3D"
$form.Controls.Add($sep1)

# Header
$hdrEvent = New-Object System.Windows.Forms.Label
$hdrEvent.Text = "Event"
$hdrEvent.Location = New-Object System.Drawing.Point(15, 68)
$hdrEvent.Size = New-Object System.Drawing.Size(150, 20)
$hdrEvent.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

$hdrSound = New-Object System.Windows.Forms.Label
$hdrSound.Text = "Sound"
$hdrSound.Location = New-Object System.Drawing.Point(170, 68)
$hdrSound.Size = New-Object System.Drawing.Size(350, 20)
$hdrSound.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

$form.Controls.AddRange(@($hdrEvent, $hdrSound))

# Event rows
$yPos = 92
$rowHeight = 60

foreach ($evt in $events) {
    $key = $evt.key
    $eventCfg = if ($config -and $config.events.$key) { $config.events.$key } else { $null }

    # Background panel for this row
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(10, $yPos)
    $panel.Size = New-Object System.Drawing.Size(645, 52)
    $panel.BorderStyle = "FixedSingle"
    $panel.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)

    # Event name
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $evt.title
    $lbl.Location = New-Object System.Drawing.Point(8, 6)
    $lbl.Size = New-Object System.Drawing.Size(150, 18)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text = $evt.desc
    $lblDesc.Location = New-Object System.Drawing.Point(8, 26)
    $lblDesc.Size = New-Object System.Drawing.Size(150, 18)
    $lblDesc.ForeColor = [System.Drawing.Color]::Gray
    $lblDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)

    # Dropdown
    $ddl = New-Object System.Windows.Forms.ComboBox
    $ddl.Location = New-Object System.Drawing.Point(165, 8)
    $ddl.Size = New-Object System.Drawing.Size(335, 22)
    $ddl.DropDownStyle = "DropDownList"

    # Populate items
    $ddl.Items.Add("-- Silent --") | Out-Null
    foreach ($sys in $systemSounds) {
        $ddl.Items.Add($sys.label) | Out-Null
    }
    $ddl.Items.Add("--- Built-in WAV Files ---") | Out-Null
    foreach ($wav in $wavs) {
        $sizeKb = [math]::Round($wav.Length / 1KB, 1)
        $ddl.Items.Add("$($wav.Name)  ($sizeKb KB)") | Out-Null
    }
    $ddl.Items.Add("--- Import Custom WAV File... ---") | Out-Null

    # Select current
    $selectedIdx = 0  # silent
    if ($eventCfg) {
        if ($eventCfg.type -eq "system") {
            for ($i = 0; $i -lt $systemSounds.Count; $i++) {
                if ($ddl.Items[$i + 1] -like "*$($eventCfg.sound)*") {
                    $selectedIdx = $i + 1
                    break
                }
            }
        }
        elseif ($eventCfg.type -eq "wav") {
            $resolvedFile = Resolve-WavPath $eventCfg.file
            $wavName = [System.IO.Path]::GetFileName($resolvedFile)
            $separatorIdx = 1 + $systemSounds.Count  # skip silent + system sounds
            for ($i = 0; $i -lt $wavs.Count; $i++) {
                if ($wavs[$i].Name -eq $wavName) {
                    $selectedIdx = $separatorIdx + 1 + $i
                    break
                }
            }
        }
    }
    $ddl.SelectedIndex = $selectedIdx

    # Preview button
    $btnPreview = New-Object System.Windows.Forms.Button
    $btnPreview.Text = "Preview"
    $btnPreview.Location = New-Object System.Drawing.Point(508, 6)
    $btnPreview.Size = New-Object System.Drawing.Size(55, 26)
    $btnPreview.UseVisualStyleBackColor = $true
    $btnPreview.Add_Click({
        # Find the dropdown in this button's parent panel (avoid PowerShell closure trap)
        $parentPanel = $this.Parent
        $localDdl = $parentPanel.Controls | Where-Object { $_ -is [System.Windows.Forms.ComboBox] } | Select-Object -First 1
        if (-not $localDdl) { return }

        $idx = $localDdl.SelectedIndex
        $sysCount = $systemSounds.Count
        $currentWavs = Get-AvailableWavs       # fresh at preview time (supports imported WAVs)
        $silentIdx = 0
        $sysEndIdx = $sysCount
        $sep1Idx = $sysCount + 1
        $wavEndIdx = $sysCount + 1 + $currentWavs.Count

        if ($idx -eq $silentIdx) {
            return
        }
        elseif ($idx -ge 1 -and $idx -le $sysEndIdx) {
            $sys = $systemSounds[$idx - 1]
            Preview-Sound -Type "system" -SoundOrFile $sys.id
        }
        elseif ($idx -ge ($sep1Idx + 1) -and $idx -le ($wavEndIdx)) {
            $wavIdx = $idx - ($sep1Idx + 1)
            if ($wavIdx -ge 0 -and $wavIdx -lt $currentWavs.Count) {
                Preview-Sound -Type "wav" -SoundOrFile $currentWavs[$wavIdx].FullName
            }
        }
    })

    # Attach import handler to dropdown
    $importHandler = {
        $sysSounds = Get-SystemSounds
        $currentWavs = Get-AvailableWavs
        $sysCount = $sysSounds.Count
        $importIdx = 1 + $sysCount + 1 + $currentWavs.Count

        if ($this.SelectedIndex -eq $importIdx) {
            $newPath = Import-CustomWav
            if ($newPath) {
                # Refresh all dropdowns
                Invoke-Command $global:refreshAllDropdowns
                # Select the new wav
                $newName = [System.IO.Path]::GetFileName($newPath)
                $updatedWavs = Get-AvailableWavs
                for ($i = 0; $i -lt $updatedWavs.Count; $i++) {
                    if ($updatedWavs[$i].Name -eq $newName) {
                        $this.SelectedIndex = 1 + $sysCount + 1 + $i
                        break
                    }
                }
            } else {
                $this.SelectedIndex = 0
            }
        }
    }
    $ddl.Add_SelectedIndexChanged($importHandler)

    $panel.Controls.AddRange(@($lbl, $lblDesc, $ddl, $btnPreview))
    $form.Controls.Add($panel)

    $global:eventDdlMap[$key] = $ddl
    $yPos += $rowHeight + 2
}

# ---- Bottom: status + buttons ----
$yPos += 5

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(15, $yPos)
$statusLabel.Size = New-Object System.Drawing.Size(500, 20)
$statusLabel.Text = "Ready"
$form.Controls.Add($statusLabel)

$yPos += 28

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Configuration"
$btnSave.Location = New-Object System.Drawing.Point(15, $yPos)
$btnSave.Size = New-Object System.Drawing.Size(165, 32)
$btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = "Flat"
$btnSave.Add_Click({
    $sysCount = $systemSounds.Count
    $newConfig = @{
        volume = $volTrackbar.Value
        events = @{}
    }

    foreach ($evt in $events) {
        $key = $evt.key
        $ddl = $global:eventDdlMap[$key]
        $idx = $ddl.SelectedIndex

        $wavCount = (Get-AvailableWavs).Count
        $sep1Idx = 1 + $sysCount
        $wavEndIdx = $sep1Idx + $wavCount

        if ($idx -eq 0) {
            $newConfig.events[$key] = @{
                type = "none"
                label = "Silent"
            }
        }
        elseif ($idx -ge 1 -and $idx -le $sysCount) {
            $sys = $systemSounds[$idx - 1]
            $newConfig.events[$key] = @{
                type = "system"
                sound = $sys.id
                label = $sys.label
            }
        }
        elseif ($idx -ge ($sep1Idx + 1) -and $idx -le $wavEndIdx) {
            $wavIdx = $idx - ($sep1Idx + 1)
            $currentWavs = Get-AvailableWavs
            if ($wavIdx -ge 0 -and $wavIdx -lt $currentWavs.Count) {
                $wav = $currentWavs[$wavIdx]
                $relPath = '${CLAUDE_PLUGIN_ROOT}\sounds\' + $wav.Name
                $newConfig.events[$key] = @{
                    type = "wav"
                    file = $relPath
                    label = $wav.Name
                }
            }
        }
        # else: import item or separator selected — skip (won't happen at save time)
    }

    Save-Config $newConfig
    $statusLabel.Text = "Saved! Run '/hooks' or restart Claude Code to apply."
    $statusLabel.ForeColor = [System.Drawing.Color]::Green
})

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(195, $yPos)
$btnClose.Size = New-Object System.Drawing.Size(100, 32)
$btnClose.Add_Click({ $form.Close() })

# Generate sounds if missing
$btnGen = New-Object System.Windows.Forms.Button
$btnGen.Text = "Regenerate Sounds"
$btnGen.Location = New-Object System.Drawing.Point(310, $yPos)
$btnGen.Size = New-Object System.Drawing.Size(145, 32)
$btnGen.Add_Click({
    $statusLabel.Text = "Generating sounds..."
    $statusLabel.ForeColor = [System.Drawing.Color]::Blue
    $form.Refresh()
    & "powershell" -NoProfile -File (Join-Path $Script:ScriptDir "sound-generator.ps1") -OutputDir $Script:SoundsDir | Out-Null
    Invoke-Command $global:refreshAllDropdowns
    $statusLabel.Text = "Sounds regenerated!"
    $statusLabel.ForeColor = [System.Drawing.Color]::Green
})

$form.Controls.AddRange(@($statusLabel, $btnSave, $btnClose, $btnGen))

# ---- Show ----
$form.ShowDialog() | Out-Null
