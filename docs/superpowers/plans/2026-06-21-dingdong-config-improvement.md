# DingDong 配置体验改善 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 升级 DingDong 配置系统：v2 JSON 格式、Windows WinForms GUI、跨平台 TUI、播放脚本适配

**Architecture:** 6 个独立任务。先更新 config.json v2 格式，然后并行或串行实现 play-sound.ps1、play-sound.sh、config-ui.ps1、config.sh，最后更新文档。

**Tech Stack:** PowerShell 5.1+ (WinForms + winmm.dll)、bash 4+ (ANSI TUI)、jq/python3 (config 读写)

## 全局约束

- 零外部依赖：仅用 OS 内置工具（PowerShell、bash、WinForms、winmm.dll）
- 向后兼容：v1 格式自动升级到 v2
- 不合并 `claude-code-dingdong` build 版本代码
- 不修改 hooks.json / hooks.unix.json / install/uninstall 脚本
- 所有路径相对于插件根目录

---

### Task 1: 更新 config.json 为 v2 格式

**Files:**
- Modify: `dingdong/config.json`

**Interfaces:**
- Produces: v2 config.json 格式，所有后续任务以此为输入

- [ ] **Step 1: 将 config.json 更新为 v2 格式**

```json
{
  "version": 2,
  "volume": 80,
  "events": {
    "Stop":              { "type": "wav",    "file": "sounds/denielcz-done_01.wav" },
    "Notification":      { "type": "wav",    "file": "sounds/pop.wav" },
    "PermissionRequest": { "type": "wav",    "file": "sounds/notify-descend.wav" },
    "Elicitation":       { "type": "wav",    "file": "sounds/question-double.wav" },
    "TeammateIdle":      { "type": "none" }
  }
}
```

- [ ] **Step 2: 验证 JSON 合法**

Run: `jq . config.json` (or `python3 -m json.tool config.json`)
Expected: 输出格式化后的 JSON，无错误

---

### Task 2: 重写 play-sound.ps1 (winmm.dll + v2 格式 + type: system)

**Files:**
- Modify: `dingdong/play-sound.ps1`

**Interfaces:**
- Consumes: config.json v2 格式（兼容 v1 自动升级）
- Entry point: `play-sound.ps1 -Event <name>` (param string, 无 ValidateSet，保持灵活)
- Produces: 播放对应音效/系统声音/静音，exit 0

- [ ] **Step 1: 写入完整 play-sound.ps1**

```powershell
param([string]$Event)

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
    $config = $v2 | ConvertFrom-Json
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
    # winmm.dll PlaySound — no process hop, no flash window
    Add-Type @'
using System.Runtime.InteropServices;
public class DD {
    [DllImport("winmm.dll", SetLastError=true)]
    public static extern bool PlaySound(string pszSound, System.IntPtr hmod, uint fdwSound);
}
'@
    [DD]::PlaySound($wavPath, [System.IntPtr]::Zero, 0x00020000) | Out-Null
    exit 0
}
```

- [ ] **Step 2: 验证脚本语法正确**

Run: `powershell -NoProfile -Command "& .\play-sound.ps1 -Event Stop; exit 0"`
Expected: 播放 denielcz-done_01.wav，无报错，无闪窗

- [ ] **Step 3: 验证 v1 自动升级**

- 临时将 config.json 改为旧格式 `{"Stop": "sounds/pop.wav", "Notification": null}`
- Run: `powershell -NoProfile -Command "& .\play-sound.ps1 -Event Stop; exit 0"`
- 验证 config.json 已自动升级为 v2 格式
- 恢复 config.json 为 v2

Run: `powershell -NoProfile -Command "& .\play-sound.ps1 -Event UnknownEvent; exit 0"`
Expected: 无输出，exit 0

---

### Task 3: 更新 play-sound.sh (v2 格式 + type: none)

**Files:**
- Modify: `dingdong/play-sound.sh`

**Interfaces:**
- Consumes: config.json v2 格式（兼容 v1）
- Entry point: `play-sound.sh <EventName>`
- Produces: 播放 WAV 或静默退出

- [ ] **Step 1: 写入完整 play-sound.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
[ ! -f "$CONFIG_FILE" ] && exit 0

# Read config: support v1 (flat) and v2 (nested) format
if command -v python3 &>/dev/null; then
  SOUND_PATH=$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    c = json.load(f)
# Detect v1 flat format
if isinstance(c.get('Stop'), str):
    val = c.get('$EVENT')
    print(val if val else '')
    sys.exit(0)
# v2 nested format
events = c.get('events', {})
evt = events.get('$EVENT', {})
t = evt.get('type', '')
if t == 'none':
    sys.exit(0)
if t == 'wav':
    print(evt.get('file', ''))
    sys.exit(0)
# fallback: unknown type or system → skip
sys.exit(0)
")
elif command -v jq &>/dev/null; then
  SOUND_PATH=$(jq -r --arg e "$EVENT" '
    if .Stop | type == "string" then
      .[$e] // ""
    else
      .events[$e] // {} | if .type == "none" then "" elif .type == "wav" then .file // "" else "" end
    end' "$CONFIG_FILE")
else
  exit 0
fi

[ -z "$SOUND_PATH" ] && exit 0

WAV_FILE="$SCRIPT_DIR/$SOUND_PATH"
[ ! -f "$WAV_FILE" ] && exit 0

if [[ "$OSTYPE" == "darwin"* ]]; then
  afplay "$WAV_FILE"
elif command -v paplay &>/dev/null; then
  paplay "$WAV_FILE"
elif command -v aplay &>/dev/null; then
  aplay "$WAV_FILE"
fi
```

- [ ] **Step 2: 验证脚本语法正确**

Run: `bash -n play-sound.sh`
Expected: 无输出（语法正确）

---

### Task 4: 新建 config-ui.ps1 (Windows WinForms GUI)

**Files:**
- Create: `dingdong/config-ui.ps1`

**Interfaces:**
- Reads: config.json v2 格式
- Writes: config.json v2 格式
- Scans: `dingdong/sounds/*.wav`
- Produces: 可视化配置界面，可保存配置

- [ ] **Step 1: 写入完整 config-ui.ps1**

```powershell
# DingDong Configuration GUI — Windows WinForms
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

# ── paths ──────────────────────────────────────────────────────────
$scriptDir = Split-Path -Parent $PSCommandPath
$soundsDir = Join-Path $scriptDir "sounds"
$configPath = Join-Path $scriptDir "config.json"

# ── load config ────────────────────────────────────────────────────
function Get-Config {
    if (-not (Test-Path $configPath)) {
        return @{ version = 2; volume = 80; events = @{} }
    }
    $raw = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $events = @{}
    # v1 flat format → convert to v2
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
    # v2 nested format
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

# ── scan sounds ────────────────────────────────────────────────────
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
        "Stop"              { return "Stop — 对话结束" }
        "Notification"      { return "Notification — 任务通知" }
        "PermissionRequest" { return "PermissionRequest — 权限请求" }
        "Elicitation"       { return "Elicitation — 提问澄清" }
        "TeammateIdle"      { return "TeammateIdle — 空闲等待" }
        default             { return $key }
    }
}

# ── build form ─────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text = "DingDong 叮咚 · 配置"
$form.Size = New-Object System.Drawing.Size(620, 460)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Source)

# Event list (left panel)
$eventGroup = New-Object System.Windows.Forms.GroupBox
$eventGroup.Text = "事件列表"
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
        $display += "  [静音]"
    } elseif ($evt -and $evt.type -eq "system") {
        $display += "  [系统: $($evt.sound)]"
    }
    [void]$eventList.Items.Add($key)
}
$eventGroup.Controls.Add($eventList)

# Detail panel (right side)
$detailGroup = New-Object System.Windows.Forms.GroupBox
$detailGroup.Text = "音效详情"
$detailGroup.Location = New-Object System.Drawing.Point(260, 12)
$detailGroup.Size = New-Object System.Drawing.Size(340, 180)

$lblSound = New-Object System.Windows.Forms.Label
$lblSound.Text = "音效:"
$lblSound.Location = New-Object System.Drawing.Point(8, 20)
$lblSound.Size = New-Object System.Drawing.Size(40, 23)

$cboSound = New-Object System.Windows.Forms.ComboBox
$cboSound.Location = New-Object System.Drawing.Point(48, 18)
$cboSound.Size = New-Object System.Drawing.Size(200, 23)
$cboSound.DropDownStyle = "DropDownList"

$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Text = "仅支持 WAV 格式"
$hintLabel.Location = New-Object System.Drawing.Point(250, 20)
$hintLabel.Size = New-Object System.Drawing.Size(80, 20)
$hintLabel.ForeColor = [System.Drawing.Color]::Gray
$hintLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei", 8)

$lblVolume = New-Object System.Windows.Forms.Label
$lblVolume.Text = "音量:"
$lblVolume.Location = New-Object System.Drawing.Point(8, 55)
$lblVolume.Size = New-Object System.Drawing.Size(40, 23)

$trackVolume = New-Object System.Windows.Forms.TrackBar
$trackVolume.Location = New-Object System.Drawing.Point(48, 52)
$trackVolume.Size = New-Object System.Drawing.Size(160, 30)
$trackVolume.Minimum = 0
$trackVolume.Maximum = 100
$trackVolume.TickFrequency = 10
$trackVolume.Value = 80

$lblVolVal = New-Object System.Windows.Forms.Label
$lblVolVal.Text = "80"
$lblVolVal.Location = New-Object System.Drawing.Point(212, 55)
$lblVolVal.Size = New-Object System.Drawing.Size(30, 20)

$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = "▶ 试听"
$btnPreview.Location = New-Object System.Drawing.Point(8, 90)
$btnPreview.Size = New-Object System.Drawing.Size(80, 28)

$btnImport = New-Object System.Windows.Forms.Button
$btnImport.Text = "导入 WAV"
$btnImport.Location = New-Object System.Drawing.Point(94, 90)
$btnImport.Size = New-Object System.Drawing.Size(90, 28)

$detailGroup.Controls.AddRange(@($lblSound, $cboSound, $hintLabel, $lblVolume, $trackVolume, $lblVolVal, $btnPreview, $btnImport))

# Sound list (bottom)
$soundGroup = New-Object System.Windows.Forms.GroupBox
$soundGroup.Text = "音效库"
$soundGroup.Location = New-Object System.Drawing.Point(12, 200)
$soundGroup.Size = New-Object System.Drawing.Size(588, 180)

$soundList = New-Object System.Windows.Forms.ListBox
$soundList.Location = New-Object System.Drawing.Point(8, 20)
$soundList.Size = New-Object System.Drawing.Size(570, 148)
$soundList.SelectionMode = "One"

function Refresh-SoundList {
    $soundList.Items.Clear()
    $cboSound.Items.Clear()
    [void]$cboSound.Items.Add("(静音)")
    Get-SoundList | ForEach-Object {
        [void]$soundList.Items.Add($_)
        $name = [System.IO.Path]::GetFileNameWithoutExtension($_)
        [void]$cboSound.Items.Add($name)
    }
}
Refresh-SoundList

$soundGroup.Controls.Add($soundList)

# Save/Cancel buttons
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "保存"
$btnSave.Location = New-Object System.Drawing.Point(12, 392)
$btnSave.Size = New-Object System.Drawing.Size(100, 30)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取消"
$btnCancel.Location = New-Object System.Drawing.Point(120, 392)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)

# ── events ──────────────────────────────────────────────────────────
$modified = $false
$selectedEvent = $null

$eventList.Add_SelectedIndexChanged({
    $selectedEvent = $eventList.SelectedItem
    if (-not $selectedEvent) { return }
    $evt = $cfg.events[$selectedEvent]
    # Select sound in dropdown
    if ($evt -and $evt.type -eq "wav" -and $evt.file) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($evt.file)
        $idx = $cboSound.Items.IndexOf($name)
        if ($idx -ge 0) { $cboSound.SelectedIndex = $idx }
        else { $cboSound.SelectedIndex = 0 }
    } else {
        $cboSound.SelectedIndex = 0  # (静音)
    }
    $trackVolume.Value = if ($evt.volume -ne $null) { [int]$evt.volume } else { [int]$cfg.volume }
    $lblVolVal.Text = $trackVolume.Value
})

$cboSound.Add_SelectedIndexChanged({
    if (-not $selectedEvent) { return }
    $modified = $true
})

$trackVolume.Add_Scroll({
    $lblVolVal.Text = $trackVolume.Value
    if ($selectedEvent) { $modified = $true }
})

$btnPreview.Add_Click({
    $sel = $cboSound.SelectedItem
    if (-not $sel -or $sel -eq "(静音)") { return }
    $wavPath = Join-Path $soundsDir "$sel.wav"
    if (Test-Path $wavPath) {
        [DD]::PlaySound($wavPath, [System.IntPtr]::Zero, 0x00020000) | Out-Null
    }
})

$btnImport.Add_Click({
    $openDlg = New-Object System.Windows.Forms.OpenFileDialog
    $openDlg.Filter = "WAV 音频 (*.wav)|*.wav"
    $openDlg.Title = "导入 WAV 音效"
    if ($openDlg.ShowDialog() -eq "OK") {
        $dest = Join-Path $soundsDir (Split-Path -Leaf $openDlg.FileName)
        Copy-Item $openDlg.FileName $dest -Force
        Refresh-SoundList
        # Auto-select the imported sound
        $name = [System.IO.Path]::GetFileNameWithoutExtension($openDlg.FileName)
        $idx = $cboSound.Items.IndexOf($name)
        if ($idx -ge 0) { $cboSound.SelectedIndex = $idx }
        $modified = $true
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
    if (-not $selectedEvent) { return }
    # Save current selection
    $selSound = $cboSound.SelectedItem
    if ($selSound -and $selSound -ne "(静音)") {
        $cfg.events[$selectedEvent] = @{ type = "wav"; file = "sounds/$selSound.wav" }
    } else {
        $cfg.events[$selectedEvent] = @{ type = "none" }
    }
    $cfg.events[$selectedEvent].volume = [int]$trackVolume.Value
    Save-Config $cfg
    $modified = $false
    [System.Windows.Forms.MessageBox]::Show("配置已保存", "DingDong", "OK", "Information")
})

$btnCancel.Add_Click({
    if ($modified) {
        $r = [System.Windows.Forms.MessageBox]::Show("有未保存的更改，确定退出？", "DingDong", "YesNo", "Warning")
        if ($r -ne "Yes") { return }
    }
    $form.Close()
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($modified) {
        $r = [System.Windows.Forms.MessageBox]::Show("有未保存的更改，确定退出？", "DingDong", "YesNo", "Warning")
        if ($r -ne "Yes") { $e.Cancel = $true }
    }
})

$form.Controls.AddRange(@($eventGroup, $detailGroup, $soundGroup, $btnSave, $btnCancel))

# Select first event by default
if ($eventList.Items.Count -gt 0) { $eventList.SelectedIndex = 0 }

[void]$form.ShowDialog()
```

- [ ] **Step 2: 验证 GUI 启动**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\config-ui.ps1`
Expected: 窗口正常显示，事件列表有 5 项，音效下拉列出 13 个 WAV + (静音)

- [ ] **Step 3: 验证 GUI 功能**

- 点击不同事件 → 音效下拉切换
- 选择新的音效 → 点击试听 → 播放对应 WAV
- 拖动音量滑块 → 显示数值变化
- 导入 WAV → 选择任意 .wav 文件 → 文件复制到 sounds/ → 下拉和列表刷新
- 保存 → config.json 更新 → 弹出确认消息

---

### Task 5: 重写 config.sh (交互终端 TUI)

**Files:**
- Modify: `dingdong/config.sh`

**Interfaces:**
- Reads: config.json v2 格式
- Writes: config.json v2 格式
- Scans: `dingdong/sounds/*.wav`
- Produces: 终端交互式配置界面

- [ ] **Step 1: 写入完整 config.sh**

```bash
#!/usr/bin/env bash
# DingDong — 交互终端配置工具 (跨平台)
# 零依赖: bash 4+ + ANSI escape codes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
SOUNDS_DIR="$SCRIPT_DIR/sounds"

EVENTS=("Stop" "Notification" "PermissionRequest" "Elicitation" "TeammateIdle")
DESCRIPTIONS=(
  "对话结束"
  "任务通知"
  "权限请求"
  "提问澄清"
  "空闲等待"
)

# ── helpers ──────────────────────────────────────────────────────────

clear_screen() { printf "\033c" >&2; }

list_sounds() {
  local files=()
  for f in "$SOUNDS_DIR"/*.wav; do
    [ -f "$f" ] && files+=("$(basename "$f")")
  done
  printf "%s\n" "${files[@]}" | sort
}

# Read current event config from v1 or v2 format
read_config() {
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    c = json.load(f)
# v1 flat
if isinstance(c.get('Stop'), str):
    for evt in ['Stop','Notification','PermissionRequest','Elicitation','TeammateIdle']:
        v = c.get(evt)
        if v and isinstance(v, str):
            print(f'{evt}|wav|{v}')
        else:
            print(f'{evt}|none|')
    sys.exit(0)
# v2 nested
events = c.get('events', {})
for evt in ['Stop','Notification','PermissionRequest','Elicitation','TeammateIdle']:
    e = events.get(evt, {})
    t = e.get('type', 'none')
    if t == 'wav':
        print(f'{evt}|wav|{e.get(\"file\", \"\")}')
    elif t == 'system':
        print(f'{evt}|system|{e.get(\"sound\", \"\")}')
    else:
        print(f'{evt}|none|')
"
  elif command -v jq &>/dev/null; then
    jq -r --argjson evts '["Stop","Notification","PermissionRequest","Elicitation","TeammateIdle"]' '
      if .Stop | type == "string" then
        $evts[] | "\(.)|\(if . as $e | .[$e] | type == "string" then "wav|\(.[$e])" else "none|" end)"
      else
        $evts[] | "\(.)|\(if .events[.].type == "wav" then "wav|\(.events[.].file)" elif .events[.].type == "system" then "system|\(.events[.].sound)" else "none|" end)"
      end
    ' "$CONFIG_FILE"
  else
    return 1
  fi
}

write_config() {
  local -n data=$1
  local json="{"
  local first=true
  for evt in "${EVENTS[@]}"; do
    $first && first=false || json+=", "
    local line="${data[$evt]}"
    local type="${line%%|*}"
    local rest="${line#*|}"
    local val="${rest#*|}"
    if [ "$type" = "none" ]; then
      json+="\"$evt\": {\"type\": \"none\"}"
    elif [ "$type" = "system" ]; then
      json+="\"$evt\": {\"type\": \"system\", \"sound\": \"$val\"}"
    else
      json+="\"$evt\": {\"type\": \"wav\", \"file\": \"$val\"}"
    fi
  done
  json+="}"
  local full="{\"version\": 2, \"volume\": 80, \"events\": $json}"
  printf "%s\n" "$full" > "$CONFIG_FILE"
}

friendly_name() {
  local val="$1"
  val="${val#sounds/}"
  val="${val%.wav}"
  echo "$val"
}

preview_sound() {
  local file="$1"
  [ ! -f "$file" ] && return
  case "$(uname -s)" in
    Darwin)  afplay "$file" 2>/dev/null ;;
    Linux)   (paplay "$file" 2>/dev/null || aplay "$file" 2>/dev/null) ;;
    *)       powershell -c "
Add-Type @'
using System.Runtime.InteropServices;
public class DD {
    [DllImport(\"winmm.dll\", SetLastError=true)]
    public static extern bool PlaySound(string p, System.IntPtr h, uint f);
}
'@
[DD]::PlaySound('$file', [System.IntPtr]::Zero, 0x00020000)" 2>/dev/null ;;
  esac || true
}

import_sound() {
  echo "" >&2
  printf "  请输入 WAV 文件的绝对路径: " >&2
  read -r import_path
  import_path="${import_path/#\~/$HOME}"
  if [ ! -f "$import_path" ]; then
    echo "  文件不存在" >&2
    sleep 1
    return 1
  fi
  if [[ "$import_path" != *.wav && "$import_path" != *.WAV ]]; then
    echo "  仅支持 WAV 格式" >&2
    sleep 1
    return 1
  fi
  cp "$import_path" "$SOUNDS_DIR/"
  echo "  已导入: $(basename "$import_path")" >&2
  sleep 1
}

# ── main ────────────────────────────────────────────────────────────

mkdir -p "$SOUNDS_DIR"

# Read current config
declare -A CURRENT
if ! read_config > /dev/null 2>&1; then
  echo "Warning: jq or python3 required for config reading" >&2
fi

while IFS='|' read -r evt type val; do
  CURRENT["$evt"]="${type}|${val}"
done < <(read_config 2>/dev/null || true)

while true; do
  clear_screen
  echo "╔══════════════════════════════════════╗" >&2
  echo "║     DingDong 叮咚 · 配置            ║" >&2
  echo "╠══════════════════════════════════════╣" >&2
  echo "║  仅支持 WAV 格式                    ║" >&2
  echo "╚══════════════════════════════════════╝" >&2
  echo "" >&2

  for i in "${!EVENTS[@]}"; do
    evt="${EVENTS[$i]}"
    desc="${DESCRIPTIONS[$i]}"
    line="${CURRENT[$evt]:-none|}"
    type="${line%%|*}"
    rest="${line#*|}"
    val="${rest#*|}"
    case "$type" in
      none)   display="静音" ;;
      system) display="系统: $val" ;;
      wav)    display="$(friendly_name "$val")" ;;
      *)      display="???" ;;
    esac
    printf "  [%d]  %-20s  →  %s\n" $((i+1)) "$evt ($desc)" "$display" >&2
  done

  echo "" >&2
  echo "  [I] 导入音频" >&2
  echo "  [S] 保存配置" >&2
  echo "  [Q] 退出" >&2
  echo "" >&2
  printf "  > " >&2
  read -r choice

  case "$choice" in
    [Qq]) exit 0 ;;
    [Ss])
      write_config CURRENT
      echo "" >&2
      echo "  ✓ 配置已保存到 config.json" >&2
      echo "  重启 Claude Code 或执行 /hooks 以生效。" >&2
      sleep 1
      ;;
    [Ii])
      import_sound || true
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#EVENTS[@]}" ]; then
        idx=$((choice-1))
        evt="${EVENTS[$idx]}"

        # ── secondary selection page ──
        local_sounds=()
        while IFS= read -r s; do local_sounds+=("$s"); done < <(list_sounds)
        current_line="${CURRENT[$evt]:-none|}"
        current_type="${current_line%%|*}"
        rest="${current_line#*|}"
        current_val="${rest#*|}"

        while true; do
          clear_screen
          echo "╔══════════════════════════════════════╗" >&2
          printf "║  %-36s ║\n" "$evt" >&2
          echo "╚══════════════════════════════════════╝" >&2
          echo "" >&2
          echo "  0) 静音 $([ "$current_type" = "none" ] && echo '← 当前')" >&2
          local i=1
          for s in "${local_sounds[@]}"; do
            label="$(friendly_name "$s")"
            marker=""
            [ "$label" = "$(friendly_name "$current_val")" ] && [ "$current_type" = "wav" ] && marker="← 当前"
            printf "  %d) %s %s\n" $i "$label" "$marker" >&2
            i=$((i+1))
          done
          echo "" >&2
          echo "  [B] 返回  [/] 搜索" >&2
          echo "  仅支持 WAV 格式" >&2
          echo "" >&2
          printf "  > " >&2
          read -r sub_choice

          case "$sub_choice" in
            [Bb]) break ;;
            *)
              if [ "$sub_choice" = "0" ]; then
                CURRENT["$evt"]="none|"
                break
              elif [[ "$sub_choice" =~ ^[0-9]+$ ]] && [ "$sub_choice" -ge 1 ] && [ "$sub_choice" -le "${#local_sounds[@]}" ]; then
                picked="${local_sounds[$((sub_choice-1))]}"
                CURRENT["$evt"]="wav|sounds/$picked"
                preview_sound "$SOUNDS_DIR/$picked"
                break
              fi
              ;;
          esac
        done
      fi
      ;;
  esac
done
```

- [ ] **Step 2: 验证 TUI 启动**

Run: `bash config.sh`
Expected: TUI 界面正常显示，5 个事件带当前音效

- [ ] **Step 3: 验证 TUI 功能**

- 按数字键进入二级页面 → 显示音效列表和静音选项
- 选择音效 → 返回主界面 → 显示新值
- 按 I → 输入路径导入 WAV
- 按 S → 写入 config.json
- 验证 config.json 格式为 v2

---

### Task 6: 更新文档

**Files:**
- Modify: `dingdong/README.md`
- Modify: `dingdong/CLAUDE.md`

- [ ] **Step 1: 更新 README.md 的 Configure 章节**

README.md 第 37-51 行区域：

将旧格式 JSON 示例：
```json
{ "Stop": "sounds/denielcz-done_01.wav", "Notification": "sounds/pop.wav" }
```
替换为新格式：
```json
{
  "version": 2,
  "volume": 80,
  "events": {
    "Stop":              { "type": "wav", "file": "sounds/denielcz-done_01.wav" },
    "Notification":      { "type": "wav", "file": "sounds/pop.wav" },
    "PermissionRequest": { "type": "wav", "file": "sounds/notify-descend.wav" },
    "Elicitation":       { "type": "wav", "file": "sounds/question-double.wav" },
    "TeammateIdle":      { "type": "none" }
  }
}
```

在 Windows 配置说明后增加：
```powershell
# Windows 图形界面 (WinForms)
powershell -File config-ui.ps1
```

在 "Custom WAV import" 功能项说明中明确描述：
> **Custom WAV import** — drop `.wav` files into `sounds/`, or use the config UI's import button / TUI's `[I]` command to import from any path. 44100Hz 16-bit mono recommended.

- [ ] **Step 2: 更新 CLAUDE.md 结构说明**

CLAUDE.md 第 8-21 行文件树区域，将 `config-ui.ps1` 加入树并更新 config.json 示例为 v2 格式：

```
dingdong/
├── play-sound.ps1        # Windows entry point (winmm.dll PlaySound)
├── play-sound.sh          # Unix entry point (afplay/paplay/aplay)
├── config-ui.ps1          # Windows WinForms configuration GUI
├── config.json            # Event → sound mapping (v2 format)
├── hooks.json             # Windows hook definitions (for install)
├── hooks.unix.json        # Unix hook definitions (for install)
├── scripts/
│   ├── install.ps1        # Windows installer
│   ├── install.sh         # Unix installer
│   ├── uninstall.ps1      # Windows uninstaller
│   └── uninstall.sh       # Unix uninstaller
├── sounds/                # WAV files
└── .claude-plugin/
    └── plugin.json
```

CLAUDE.md 第 34-41 行 Config 章节，将 JSON 示例更新为 v2 格式（同上 Step 1）并在说明中增加 `config-ui.ps1`。
