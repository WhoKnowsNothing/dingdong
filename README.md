# DingDong 叮咚

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Zero-dependency audio feedback for Claude Code — customizable WAV sounds triggered by hook events. Cross-platform (Windows / macOS / Linux).

---

[**English**](#english) · [**中文**](#chinese)

---

<h1 id="english">English</h1>

DingDong plays customizable WAV sounds when Claude Code fires hook events — Stop, Notification, PermissionRequest, Elicitation, TeammateIdle. No dependencies, no background services, one async process hop.

## Quick Start

### Install

```powershell
# Windows
git clone https://github.com/WhoKnowsNothing/dingdong.git
cd dingdong
powershell -File scripts/install.ps1

# macOS / Linux
git clone https://github.com/WhoKnowsNothing/dingdong.git
cd dingdong
bash scripts/install.sh
```

The installer copies scripts and sounds to `~/.claude/plugins/dingdong/` and merges hook definitions into `settings.json`. Unix requires `jq` or `python3` for auto-registration.

After install, run `/hooks` in Claude Code or restart to apply.

### Configure

```powershell
# Terminal TUI (cross-platform)
bash config.sh

# WinForms GUI (Windows only)
powershell -File config-ui.ps1
```

Or edit `config.json` directly:

```json
{ "Stop": "sounds/denielcz-done_01.wav", "Notification": "sounds/pop.wav" }
```

Set an event to `null` to mute it. Paths are relative to plugin root.

### Uninstall

```powershell
powershell -File scripts/uninstall.ps1        # Windows
bash scripts/uninstall.sh                      # Unix
```

## Features

- **7 event types** with independent sound assignments
- **Cross-platform**: Windows, macOS, Linux
- **13 built-in WAV chimes** (no copyrighted audio)
- **Terminal TUI** configurator (cross-platform)
- **WinForms GUI** configurator (Windows only)
- **Per-event mute** (set to `null`)
- **Async hooks** — never blocks Claude Code
- **Zero dependencies** — pure shell + PowerShell
- **Custom WAV import** — drop files into `sounds/`

## Events

| Event | Trigger | Default Sound |
|-------|---------|---------------|
| **Stop** | Claude finishes a response | `denielcz-done_01.wav` |
| **Notification** | Task completion notification | `pop.wav` |
| **PermissionRequest** | Claude needs tool permission | `notify-descend.wav` |
| **Elicitation** | Claude asks a clarifying question | `question-double.wav` |
| **TeammateIdle** | Sub-agent is idle / stuck | *(silent)* |
| **PreToolUse** → Elicitation | Alternative elicitation trigger | *(inherits Elicitation)* |
| **SubagentStop** → Notification | Alternative notification trigger | *(inherits Notification)* |

## Sounds

| File | Tone | Best For |
|------|------|----------|
| `done-classic.wav` | Ascending C5→E5 chord | Task complete |
| `done-soft.wav` | Soft A4 tone | Subtle completion |
| `done-fanfare.wav` | C5→E5→G5 triad | Celebration |
| `ding.wav` | Bright 1046Hz | Notification |
| `pop.wav` | Short 800Hz burst | Quick feedback |
| `beep-soft.wav` | Gentle 880Hz | Soft prompt |
| `notify-descend.wav` | G5→E5 descending | Notification |
| `alert.wav` | Mid 660Hz | Permission request |
| `warning.wav` | Descending 440→349Hz | Agent idle |
| `error.wav` | Staccato low tone | Error |
| `question-rising.wav` | 400→1200Hz sweep | Clarification |
| `question-double.wav` | 660→880Hz dual tone | Confirmation |
| `denielcz-done_01.wav` | Classic chime | Default stop |

Drop `.wav` files into the `sounds/` folder — they appear in the config UI automatically. 44100Hz 16-bit mono recommended.

## Architecture

```
Event → settings.json hooks → play-sound.ps1/.sh → config.json lookup → WAV playback
```

One async process hop. No fallbacks. No state. No pub-sub.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full dependency graph and data flow.

## Technical Notes

- **Async**: All hooks use `"async": true` — sound never blocks Claude Code
- **Silent exit**: Missing config, unknown event, or missing file → clean exit 0, no error noise
- **Portable paths**: Config uses relative paths; plugin root resolved at runtime by each script
- **Windows audio**: Uses `Start-Process` → `Media.SoundPlayer.PlaySync()` for isolated audio context
- **Unix audio**: Uses `afplay` (macOS), `paplay` (Linux), `aplay` (fallback)
- **Install dir**: `~/.claude/plugins/dingdong/`
- **Zero deps**: No npm, pip, gem, or brew — just shell and built-in OS tools

---

<h1 id="chinese">中文</h1>

DingDing（叮咚）是 Claude Code 的音频反馈插件。当 Claude Code 触发 Hook 事件时（Stop、Notification、PermissionRequest、Elicitation、TeammateIdle），播放可自定义的 WAV 音效。零依赖，无后台进程，一次异步调用即完成。

## 快速开始

### 安装

```powershell
# Windows
git clone https://github.com/WhoKnowsNothing/dingdong.git
cd dingdong
powershell -File scripts/install.ps1

# macOS / Linux
git clone https://github.com/WhoKnowsNothing/dingdong.git
cd dingdong
bash scripts/install.sh
```

安装程序会自动：复制脚本和音效到 `~/.claude/plugins/dingdong/`，并将 Hook 配置合并到 `settings.json`。Unix 系统需要 `jq` 或 `python3` 用于自动注册。

安装后在 Claude Code 中执行 `/hooks` 或重启生效。

### 配置

```powershell
# 终端 TUI 界面（跨平台）
bash config.sh

# WinForms 图形界面（仅 Windows）
powershell -File config-ui.ps1
```

或直接编辑 `config.json`：

```json
{ "Stop": "sounds/denielcz-done_01.wav", "Notification": "sounds/pop.wav" }
```

将事件值设为 `null` 可静音。路径相对于插件根目录。

### 卸载

```powershell
powershell -File scripts/uninstall.ps1        # Windows
bash scripts/uninstall.sh                      # Unix
```

## 功能特性

- **7 种事件**独立配置音效
- **跨平台**：Windows、macOS、Linux
- **13 个内置 WAV 音效**（纯代码生成，无版权问题）
- **终端 TUI 配置界面**（跨平台）
- **WinForms 图形配置界面**（仅 Windows）
- **每事件单独静音**（设为 `null`）
- **异步 Hook** — 不阻塞 Claude Code
- **零依赖** — 纯 shell + PowerShell
- **支持导入自定义 WAV**

## 事件对照

| 事件 | 触发条件 | 默认音效 |
|------|----------|----------|
| **Stop** | Claude 结束回复 | `denielcz-done_01.wav` |
| **Notification** | 任务完成通知 | `pop.wav` |
| **PermissionRequest** | Claude 请求工具权限 | `notify-descend.wav` |
| **Elicitation** | Claude 提问澄清 | `question-double.wav` |
| **TeammateIdle** | 子 agent 空闲/卡住 | *（静音）* |
| **PreToolUse** → Elicitation | 替代提问触发 | *（沿用 Elicitation）* |
| **SubagentStop** → Notification | 替代通知触发 | *（沿用 Notification）* |

## 音效列表

| 文件 | 音色 | 推荐用途 |
|------|------|----------|
| `done-classic.wav` | 上行 C5→E5 和弦 | 任务完成 |
| `done-soft.wav` | 柔和 A4 音 | 低调完成 |
| `done-fanfare.wav` | C5→E5→G5 三和弦 | 庆祝 |
| `ding.wav` | 清脆 1046Hz | 通知 |
| `pop.wav` | 短促 800Hz | 快速反馈 |
| `beep-soft.wav` | 轻柔 880Hz | 柔和提示 |
| `notify-descend.wav` | G5→E5 下行双音 | 通知提醒 |
| `alert.wav` | 中频 660Hz | 权限请求 |
| `warning.wav` | 下行 440→349Hz | 空闲警告 |
| `error.wav` | 断奏低音 | 错误提示 |
| `question-rising.wav` | 400→1200Hz 上升扫频 | 提问 |
| `question-double.wav` | 660→880Hz 双音 | 确认 |
| `denielcz-done_01.wav` | 经典提示音 | 默认完成音 |

将 `.wav` 文件放入 `sounds/` 文件夹，配置界面会自动列出。推荐 44100Hz 16-bit 单声道。

## 架构

```
Event → settings.json hooks → play-sound.ps1/.sh → config.json 查表 → WAV 播放
```

一次异步调用，无中间状态。

完整依赖图和数据流见 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 技术说明

- **异步**：所有 Hook 使用 `"async": true`，音效不阻塞 Claude Code
- **静默退出**：配置缺失、事件未知或文件不存在 → 干净退出，无报错
- **路径可迁移**：配置使用相对路径，插件根目录在运行时由脚本解析
- **Windows 音频**：`Start-Process` → `Media.SoundPlayer.PlaySync()`，独立音频上下文
- **Unix 音频**：`afplay`（macOS）、`paplay`（Linux）、`aplay`（降级）
- **安装目录**：`~/.claude/plugins/dingdong/`
- **零依赖**：无需 npm、pip、gem、brew

---

## License

MIT © [WhoKnowsNothing](https://github.com/WhoKnowsNothing)
