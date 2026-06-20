# DingDong 配置体验改善设计

## 概述

改善 DingDong 的配置体验，包括配置格式升级、Windows WinForms GUI、跨平台 TUI、播放脚本适配。不合并 `claude-code-dingdong` build 版本的代码，独立改善当前 `dingdong/` 项目。

## config.json 格式 v2

```json
{
  "version": 2,
  "volume": 80,
  "events": {
    "Stop":              { "type": "wav",    "file": "sounds/denielcz-done_01.wav" },
    "Notification":      { "type": "wav",    "file": "sounds/pop.wav",          "volume": 90 },
    "PermissionRequest": { "type": "system", "sound": "Hand" },
    "Elicitation":       { "type": "wav",    "file": "sounds/question-double.wav" },
    "TeammateIdle":      { "type": "none" }
  }
}
```

### 字段说明

- **version**：配置版本号，用于后续迁移
- **volume**：全局音量（0-100），每事件可覆盖。本次 Windows 端仅记录字段，不实现实际调音；Unix 端不做
- **events**：事件映射表
  - **type**：`wav` / `system` / `none`。`system` 仅在 Windows 有效（映射到 SystemSounds）；`none` 表示静音
  - **file**：`type=wav` 时生效，WAV 文件路径（相对于插件根目录）
  - **sound**：`type=system` 时生效，系统声音名称（Hand / Question / Exclamation / Asterisk / Beep）
  - **volume**：可选，覆盖全局音量

### 向后兼容

- `play-sound.ps1` / `play-sound.sh` 启动时检测 config.json 格式
- 旧 v1 格式（`{"Stop": "sounds/foo.wav"}`）自动升级为 v2 格式并写回文件
- 升级逻辑：每个事件的值如果是字符串，转为 `{ "type": "wav", "file": "<原值>" }`

## config-ui.ps1 — Windows WinForms GUI

### 依赖

- PowerShell 5.1+（系统自带）
- `System.Windows.Forms` / `System.Drawing`（系统自带）
- 零外部依赖

### 布局

```
┌─────────────────────────────────────────────┐
│  DingDong 叮咚  配置         — □ x │
├─────────────────────────────────────────────┤
│                                             │
│  [事件列表]              [音效详情]          │
│  ┌─────────────────┐   ┌─────────────────┐  │
│  │ ◎ Stop           │   │ 音效:           │  │
│  │ ○ Notification   │   │ ┌──────────────┐│  │
│  │ ○ PermissionReq  │   │ │denielcz-done… ││  │
│  │ ○ Elicitation    │   │ │done-classic   ││  │
│  │ ○ TeammateIdle   │   │ │done-fanfare   ││  │
│  └─────────────────┘   │ │done-soft      ││  │
│                         │ │ding           ││  │
│                         │ │(仅支持 WAV)   ││  │
│                         │ │…              ││  │
│                         │ │[静音]         ││  │
│                         │ └──────────────┘│  │
│                         │                 │  │
│                         │ 音量: ═══●══╗   │  │
│                         │      0     100  │  │
│                         │                 │  │
│                         │ [▶ 试听] [导入] │  │
│                         └─────────────────┘  │
│                                             │
│  [保存] [取消]                              │
└─────────────────────────────────────────────┘
```

### 交互

- **事件列表**（左侧 ListBox）：点击选中事件，右侧显示当前配置
- **音效下拉框**（右侧 ComboBox）：
  - 列出 `dingdong\sounds\` 下所有 `.wav` 文件（文件名校验：仅显示 `.wav` 后缀的合规文件）
  - 末尾固定项「静音」（对应 `type: none`）
  - 提示标签："仅支持 WAV 格式"
- **音量滑块**（TrackBar）：0-100，默认 80。当前仅记录到配置文件中
- **试听按钮**：播放下拉框当前选中的音效文件（使用 `SoundPlayer.PlaySync()` 或 winmm.dll）
- **导入按钮**：打开 OpenFileDialog（过滤 `*.wav`），用户选择后：
  1. 复制文件到 `dingdong\sounds\` 目录
  2. 刷新音效下拉列表
  3. 自动选中新导入的音效
- **保存**：写入 config.json v2 格式，显示成功消息
- **取消**：若有关闭时未保存的变更，弹出确认对话框
- **启动时扫描**：窗体加载时自动扫描 `dingdong\sounds\*.wav` 构建音效列表

### 类型自动判断逻辑

| 用户操作 | 写入 type | 写入 file |
|----------|-----------|-----------|
| 下拉选了某个 `.wav` 文件 | `wav` | `sounds/xxx.wav` |
| 下拉选了「静音」 | `none` | 不写入 |
| 手动编辑 json 写入 `system` | 保留 | GUI 不展示，不覆盖 |

## config.sh — 跨平台 TUI

### 依赖

- bash 4+
- 平台音频工具：`afplay`（macOS）/ `paplay`（Linux，推荐）/ `aplay`（Linux，降级）
- 零外部依赖

### 主界面

```
┌─────────────────────────────────────────────────┐
│  DingDong 叮咚 · 配置                           │
├─────────────────────────────────────────────────┤
│                                                 │
│   1. Stop              → denielcz-done_01  [▶]  │
│   2. Notification      → pop               [▶]  │
│   3. PermissionRequest → notify-descend    [▶]  │
│   4. Elicitation       → question-double   [▶]  │
│   5. TeammateIdle      → 静音                   │
│                                                 │
│   [I] 导入音频  [S] 保存  [Q] 退出              │
│                                                 │
│   提示: 仅支持 WAV 格式                          │
└─────────────────────────────────────────────────┘
```

### 二级选择页

```
┌─────────────────────────────────────────────┐
│  Stop                                       │
├─────────────────────────────────────────────┤
│                                             │
│  [ ] 静音                                   │
│  [●] denielcz-done_01.wav       [⏎ 当前]    │
│  [ ] done-classic.wav                       │
│  [ ] done-fanfare.wav                       │
│  [ ] done-soft.wav                          │
│  [ ] ding.wav                               │
│  ...                                        │
│                                             │
│  方向键移动 | 空格试听 | Enter确认 | B返回    │
│  仅支持 WAV 格式                             │
└─────────────────────────────────────────────┘
```

### Key Bindings

- **主界面**：
  - `1-5` — 选择事件进入二级页
  - `I` — 导入音频：提示用户输入 WAV 文件的绝对路径，校验存在且为 `.wav` 后缀后，复制到 `dingdong/sounds/`，刷新列表，自动选中
  - `S` — 保存当前配置
  - `Q` — 退出（不保存）
- **二级页**：
  - `↑/↓` 或 `j/k` — 移动选择
  - `Space` — 试听当前选中项
  - `Enter` — 确认选择并返回主界面
  - `B` — 返回主界面（不修改）
  - `/` — 搜索过滤（可选功能）

### 实现方式

- 用 ANSI escape codes 实现终端渲染（`\033[c` 清屏、定位）
- 用 `read -n1` 捕获单键输入
- 试听调用 `afplay` / `paplay` / `aplay`
- 读/写 `config.json` 用 `jq`（优先）或 `python3`（降级），不可用时降级为显示配置文件的路径让用户手动编辑

## play-sound.ps1 改造

### 当前问题

- 使用 `Start-Process powershell -Command Media.SoundPlayer` 新开进程 → 闪窗、延迟
- 不支持 v2 配置格式
- 不支持 `system` 类型

### 改造内容

1. **格式检测**：读取 config.json 后检测顶层是否有 `events` 字段；无则视为 v1 格式，自动升级为 v2 并写回
2. **替换音频播放**：用 `winmm.dll PlaySound`（同步）替代 `Start-Process`，消除闪窗和延迟
3. **支持 `type: system`**：映射到 `SystemSounds::X.Play()`
4. **支持 `type: none`**：直接退出
5. **支持 `type: wav` + 文件不存在**：静默退出
6. **音量字段**：从配置读取，仅保留不实现（存储但不消费）

### winmm.dll PlaySound 示例

```powershell
Add-Type @'
using System.Runtime.InteropServices;
public class WinMM {
    [DllImport("winmm.dll", SetLastError=true)]
    public static extern bool PlaySound(string pszSound, System.IntPtr hmod, uint fdwSound);
}
'@
[WinMM]::PlaySound($path, [System.IntPtr]::Zero, 0x00020000)  # SND_FILENAME | SND_SYNC
```

## play-sound.sh 改造

### 改造内容

1. **格式检测**：同 ps1，检测 v1/v2，自动升级
2. **支持 `type: none`**：直接退出
3. **支持 `type: wav`**：现有播放流程不变
4. **`type: system`**：Unix 无此概念，忽略

## 安装包分离（未来方向）

- 本次保持统一目录结构
- Windows 组件：`play-sound.ps1` + `config-ui.ps1` + `hooks.json` + `scripts/install.ps1` + `scripts/uninstall.ps1`
- Unix 组件：`play-sound.sh` + `config.sh` + `hooks.unix.json` + `scripts/install.sh` + `scripts/uninstall.sh`
- 共享组件：`config.json` + `config.sh`（跨平台 TUI）+ `sounds/`
- 后续发布可打包为 `dingdong-windows.zip` 和 `dingdong-unix.tar.gz`

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `config.json` | 修改 | 格式升级为 v2 |
| `play-sound.ps1` | 重写 | winmm.dll 播放 + v2 兼容 + type: system |
| `play-sound.sh` | 修改 | 增加 v2 兼容 + type: none |
| `config-ui.ps1` | 新增 | WinForms GUI |
| `config.sh` | 重写 | 交互式 TUI + 导入功能 |
| `README.md` | 修改 | 更新配置工具说明 |
| `CLAUDE.md` | 修改 | 更新结构描述 |

## 不做的事

- 不实现实际音量控制（保留字段供后续版本）
- 不合并 `claude-code-dingdong` build 版本的代码
- 不拆分安装包（标记为未来方向）
- 不添加 Web UI
- 不改变现有 hook 定义（hooks.json / hooks.unix.json 不变）
- 不修改 install/uninstall 脚本
