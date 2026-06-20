# DingDong Configuration GUI - Windows WinForms
# Zero external dependencies: uses built-in System.Windows.Forms + System.Drawing

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System.Runtime.InteropServices;
public class DD {
    [DllImport("winmm.dll", SetLastError=true)]
    public static extern bool PlaySound(string pszSound, System.IntPtr hmod, uint fdwSound);
}
'@

# paths
$scriptDir = Split-Path -Parent $PSCommandPath
$soundsDir = Join-Path $scriptDir "sounds"
$configPath = Join-Path $scriptDir "config.json"

function Get-Config {
    if (-not (Test-Path $configPath)) {
        return @{ version = 2; volume = 80; events = @{} }
    }
    $raw = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $events = @{}
    if ($raw.PSObject.Properties.Name -contains "Stop" -and $raw.Stop -is [string]) {
        foreach ($evt in @("Stop","Notification","PermissionRequest","Elicitation","TeammateIdle")) {
            $val = $raw.$evt
            if ($val -and $val -is [string]) {
                $events[$evt] = @{ type = "wav"; file = $val }
            } else {
                $events[$evt] = @{ type = "none" }
            }
        }
        return @{ version = 2; volume = 80; events = $events }
    }
    foreach ($prop in $raw.events.PSObject.Properties) {
        $e = @{}
        $prop.Value.PSObject.Properties | ForEach-Object { $e[$_.Name] = $_.Value }
        $events[$prop.Name] = $e
    }
    return @{ version = 2; volume = if ($raw.volume -ne $null) { $raw.volume } else { 80 }; events = $events }
}

function Save-Config($cfg) {
    $out = @{ version = 2; volume = [int]$cfg.volume; events = @{} }
    foreach ($kv in $cfg.events.GetEnumerator()) {
        $out.events[$kv.Key] = $kv.Value
    }
    $json = $out | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
}

function Get-SoundList {
    $list = @()
    if (Test-Path $soundsDir) {
        Get-ChildItem "$soundsDir\*.wav" | Sort-Object Name | ForEach-Object {
            $list += $_.Name
        }
    }
    return $list
}

function Get-EventDisplayName($key) {
    switch ($key) {
        "Stop"              { return "Stop - " + [char]0x5BF9 + [char]0x8BDD + [char]0x7ED3 + [char]0x675F }
        "Notification"      { return "Notification - " + [char]0x4EFB + [char]0x52A1 + [char]0x901A + [char]0x77E5 }
        "PermissionRequest" { return "PermissionRequest - " + [char]0x6743 + [char]0x9650 + [char]0x8BF7 + [char]0x6C42 }
        "Elicitation"       { return "Elicitation - " + [char]0x63D0 + [char]0x95EE + [char]0x6F84 + [char]0x6E05 }
        "TeammateIdle"      { return "TeammateIdle - " + [char]0x7A7A + [char]0x95F2 + [char]0x7B49 + [char]0x5F85 }
        default             { return $key }
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "DingDong " + [char]0x53EE + [char]0x549A + " " + [char]0x914D + [char]0x7F6E
$form.Size = New-Object System.Drawing.Size(620, 460)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Source)

$eventGroup = New-Object System.Windows.Forms.GroupBox
$eventGroup.Text = [char]0x4E8B + [char]0x4EF6 + [char]0x5217 + [char]0x8868
$eventGroup.Location = New-Object System.Drawing.Point(12, 12)
$eventGroup.Size = New-Object System.Drawing.Size(240, 180)

$eventList = New-Object System.Windows.Forms.ListBox
$eventList.Location = New-Object System.Drawing.Point(8, 20)
$eventList.Size = New-Object System.Drawing.Size(224, 150)
$eventList.SelectionMode = "One"

$cfg = Get-Config
$eventKeys = @("Stop", "Notification", "PermissionRequest", "Elicitation", "TeammateIdle")
foreach ($key in $eventKeys) {
    $display = Get-EventDisplayName $key
    $evt = $cfg.events[$key]
    if ($evt -and $evt.type -eq "wav" -and $evt.file) {
        $fileName = [System.IO.Path]::GetFileName($evt.file)
        $display += "  [$fileName]"
    } elseif ($evt -and $evt.type -eq "none") {
        $display += "  [" + [char]0x9759 + [char]0x97F3 + "]"
    } elseif ($evt -and $evt.type -eq "system") {
        $display += "  [system: $($evt.sound)]"
    }
    $item = [PSCustomObject]@{ Key = $key; Display = $display }
    [void]$eventList.Items.Add($item)
}
$eventList.DisplayMember = "Display"
$eventGroup.Controls.Add($eventList)

$detailGroup = New-Object System.Windows.Forms.GroupBox
$detailGroup.Text = [char]0x97F3 + [char]0x6548 + [char]0x8BE6 + [char]0x60C5
$detailGroup.Location = New-Object System.Drawing.Point(260, 12)
$detailGroup.Size = New-Object System.Drawing.Size(340, 180)

$lblSound = New-Object System.Windows.Forms.Label
$lblSound.Text = [char]0x97F3 + [char]0x6548 + ":"
$lblSound.Location = New-Object System.Drawing.Point(8, 20)
$lblSound.Size = New-Object System.Drawing.Size(50, 23)

$cboSound = New-Object System.Windows.Forms.ComboBox
$cboSound.Location = New-Object System.Drawing.Point(58, 18)
$cboSound.Size = New-Object System.Drawing.Size(190, 23)
$cboSound.DropDownStyle = "DropDownList"

$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Text = "WAV " + [char]0x4E13 + [char]0x7528
$hintLabel.Location = New-Object System.Drawing.Point(250, 20)
$hintLabel.Size = New-Object System.Drawing.Size(80, 20)
$hintLabel.ForeColor = [System.Drawing.Color]::Gray
$hintLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei", 8)

$lblVolume = New-Object System.Windows.Forms.Label
$lblVolume.Text = [char]0x97F3 + [char]0x91CF + ":"
$lblVolume.Location = New-Object System.Drawing.Point(8, 55)
$lblVolume.Size = New-Object System.Drawing.Size(50, 23)

$trackVolume = New-Object System.Windows.Forms.TrackBar
$trackVolume.Location = New-Object System.Drawing.Point(58, 52)
$trackVolume.Size = New-Object System.Drawing.Size(160, 30)
$trackVolume.Minimum = 0
$trackVolume.Maximum = 100
$trackVolume.TickFrequency = 10
$trackVolume.Value = 80

$lblVolVal = New-Object System.Windows.Forms.Label
$lblVolVal.Text = "80"
$lblVolVal.Location = New-Object System.Drawing.Point(222, 55)
$lblVolVal.Size = New-Object System.Drawing.Size(30, 20)

$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = [char]0x25B6 + " " + [char]0x8BD5 + [char]0x542C
$btnPreview.Location = New-Object System.Drawing.Point(8, 90)
$btnPreview.Size = New-Object System.Drawing.Size(80, 28)

$btnImport = New-Object System.Windows.Forms.Button
$btnImport.Text = [char]0x5BFC + [char]0x5165 + " WAV"
$btnImport.Location = New-Object System.Drawing.Point(94, 90)
$btnImport.Size = New-Object System.Drawing.Size(90, 28)

$detailGroup.Controls.AddRange(@($lblSound, $cboSound, $hintLabel, $lblVolume, $trackVolume, $lblVolVal, $btnPreview, $btnImport))

$soundGroup = New-Object System.Windows.Forms.GroupBox
$soundGroup.Text = [char]0x97F3 + [char]0x6548 + [char]0x5E93
$soundGroup.Location = New-Object System.Drawing.Point(12, 200)
$soundGroup.Size = New-Object System.Drawing.Size(588, 180)

$soundList = New-Object System.Windows.Forms.ListBox
$soundList.Location = New-Object System.Drawing.Point(8, 20)
$soundList.Size = New-Object System.Drawing.Size(570, 148)

function Refresh-SoundList {
    $soundList.Items.Clear()
    $cboSound.Items.Clear()
    [void]$cboSound.Items.Add("(" + [char]0x9759 + [char]0x97F3 + ")")
    Get-SoundList | ForEach-Object {
        [void]$soundList.Items.Add($_)
        $name = [System.IO.Path]::GetFileNameWithoutExtension($_)
        [void]$cboSound.Items.Add($name)
    }
}
Refresh-SoundList

$soundGroup.Controls.Add($soundList)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = [char]0x4FDD + [char]0x5B58
$btnSave.Location = New-Object System.Drawing.Point(12, 392)
$btnSave.Size = New-Object System.Drawing.Size(100, 30)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = [char]0x53D6 + [char]0x6D88
$btnCancel.Location = New-Object System.Drawing.Point(120, 392)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)

$modified = $false

$eventList.Add_SelectedIndexChanged({
    $selItem = $eventList.SelectedItem
    if (-not $selItem) { return }
    $evt = $cfg.events[$selItem.Key]
    if ($evt -and $evt.type -eq "wav" -and $evt.file) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($evt.file)
        $idx = $cboSound.Items.IndexOf($name)
        if ($idx -ge 0) { $cboSound.SelectedIndex = $idx }
        else { $cboSound.SelectedIndex = 0 }
    } else {
        $cboSound.SelectedIndex = 0
    }
    $trackVolume.Value = if ($evt.volume -ne $null) { [int]$evt.volume } else { [int]$cfg.volume }
    $lblVolVal.Text = $trackVolume.Value
})

$cboSound.Add_SelectedIndexChanged({
    if ($eventList.SelectedItem) { $script:modified = $true }
})

$trackVolume.Add_Scroll({
    $lblVolVal.Text = $trackVolume.Value
    if ($eventList.SelectedItem) { $script:modified = $true }
})

$btnPreview.Add_Click({
    $sel = $cboSound.SelectedItem
    if (-not $sel -or $sel -eq "(" + [char]0x9759 + [char]0x97F3 + ")") { return }
    $wavPath = Join-Path $soundsDir "$sel.wav"
    if (Test-Path $wavPath) {
        [DD]::PlaySound($wavPath, [System.IntPtr]::Zero, 0x00020000) | Out-Null
    }
})

$btnImport.Add_Click({
    $openDlg = New-Object System.Windows.Forms.OpenFileDialog
    $openDlg.Filter = "WAV Audio (*.wav)|*.wav"
    $openDlg.Title = [char]0x5BFC + [char]0x5165 + " WAV " + [char]0x97F3 + [char]0x6548
    if ($openDlg.ShowDialog() -eq "OK") {
        if (-not (Test-Path $soundsDir)) { New-Item -ItemType Directory -Path $soundsDir -Force | Out-Null }
        $dest = Join-Path $soundsDir (Split-Path -Leaf $openDlg.FileName)
        Copy-Item $openDlg.FileName $dest -Force
        Refresh-SoundList
        $name = [System.IO.Path]::GetFileNameWithoutExtension($openDlg.FileName)
        $idx = $cboSound.Items.IndexOf($name)
        if ($idx -ge 0) { $cboSound.SelectedIndex = $idx }
        $script:modified = $true
    }
})

$soundList.Add_DoubleClick({
    $sel = $soundList.SelectedItem
    if (-not $sel) { return }
    $wavPath = Join-Path $soundsDir $sel
    if (Test-Path $wavPath) {
        [DD]::PlaySound($wavPath, [System.IntPtr]::Zero, 0x00020000) | Out-Null
    }
})

$btnSave.Add_Click({
    $selItem = $eventList.SelectedItem
    if (-not $selItem) { return }
    $selSound = $cboSound.SelectedItem
    if ($selSound -and $selSound -ne "(" + [char]0x9759 + [char]0x97F3 + ")") {
        $cfg.events[$selItem.Key] = @{ type = "wav"; file = "sounds/$selSound.wav" }
    } else {
        $cfg.events[$selItem.Key] = @{ type = "none" }
    }
    $cfg.events[$selItem.Key].volume = [int]$trackVolume.Value
    Save-Config $cfg
    $script:modified = $false
    [System.Windows.Forms.MessageBox]::Show([char]0x914D + [char]0x7F6E + [char]0x5DF2 + [char]0x4FDD + [char]0x5B58, "DingDong", "OK", "Information")
})

$btnCancel.Add_Click({
    if ($modified) {
        $r = [System.Windows.Forms.MessageBox]::Show([char]0x6709 + [char]0x672A + [char]0x4FDD + [char]0x5B58 + [char]0x7684 + [char]0x66F4 + [char]0x6539 + [char]0xFF0C + [char]0x786E + [char]0x5B9A + [char]0x9000 + [char]0x51FA + [char]0xFF1F, "DingDong", "YesNo", "Warning")
        if ($r -ne "Yes") { return }
    }
    $form.Close()
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($modified) {
        $r = [System.Windows.Forms.MessageBox]::Show([char]0x6709 + [char]0x672A + [char]0x4FDD + [char]0x5B58 + [char]0x7684 + [char]0x66F4 + [char]0x6539 + [char]0xFF0C + [char]0x786E + [char]0x5B9A + [char]0x9000 + [char]0x51FA + [char]0xFF1F, "DingDong", "YesNo", "Warning")
        if ($r -ne "Yes") { $e.Cancel = $true }
    }
})

$form.Controls.AddRange(@($eventGroup, $detailGroup, $soundGroup, $btnSave, $btnCancel))

if ($eventList.Items.Count -gt 0) { $eventList.SelectedIndex = 0 }

[void]$form.ShowDialog()