# DingDong 叮咚

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Claude Code 音频反馈插件 — 用声音告诉你 Claude 在做什么，无需盯着终端。
>
> Audio feedback plugin for Claude Code — know what Claude is doing without watching the terminal.

---

**English** | [中文](#功能特性)

DingDong plays customizable sounds for Claude Code events on Windows. Hear when a task completes, when Claude needs permission, when it asks a question, or when a sub-agent is idle — all while you work in other windows.

DingDong 为 Claude Code 的各类事件提供可自定义的音效。任务完成、需要授权、提出问题、子 agent 空闲 — 你都能听到，无需一直盯着终端。

---

## 功能 Features

| Feature | 功能 |
|---------|------|
| **7 event types** with independent sound assignments | 7 种事件独立配置音效 |
| **Native Windows GUI** (WinForms) | 原生 Windows 图形界面 |
| **12 generated WAV chimes** (no copyrighted audio) | 12 个纯生成的 WAV 音效（无版权问题） |
| **5 Windows System Sounds** (Hand, Question, Exclamation, Asterisk, Beep) | 5 种 Windows 系统音 |
| **Master volume** control | 全局音量控制 |
| **Per-event mute** | 每事件单独静音 |
| **Custom WAV import** | 支持导入自己的 WAV 文件 |
| **Zero dependencies** — pure PowerShell | 零依赖 — 纯 PowerShell |

---

## 快速开始 Quick Start

### 安装 Install

```powershell
git clone https://github.com/WhoKnowsNothing/claude-code-dingdong
cd claude-code-dingdong
.\install.ps1
```

安装过程：
1. 生成 WAV 音效文件
2. 复制脚本到 `~/.claude/hooks/dingdong/`
3. 注册 Hook 到 `~/.claude/settings.json`
4. 自动打开配置界面

安装后在 Claude Code 中执行 `/hooks` 或重启。

### 配置 Configure

```powershell
powershell -File "$env:USERPROFILE\.claude\hooks\dingdong\config-ui.ps1"
```

图形界面 — 下拉选择音效、预览、调节音量、导入自定义 WAV。

<!-- Screenshot: add docs/screenshot.png before publishing -->

---

## 支持的事件 Events

| Event | 事件 | 说明 |
|-------|------|------|
| Stop | 完成 | Claude 结束回复时 |
| Notification | 通知 | 任务完成通知 |
| PermissionRequest | 权限请求 | Claude 需要执行操作时 |
| Elicitation | 澄清 | Claude 需要提问时 |
| TeammateIdle | 子 agent 空闲 | 子 agent 卡住时 |
| PreToolUse → Elicitation | 工具调用前 | 替代 Elicitation（更可靠） |
| SubagentStop → Notification | 子 agent 完成 | 替代 Notification（更可靠） |

> **Note:** 由于 Claude Code 事件机制限制，`Elicitation` 和 `Notification` 可能不会始终触发。
> `PreToolUse/AskUserQuestion`（Elicitation 音效）和 `SubagentStop`（Notification 音效）是更可靠的替代方案。
>
> Due to Claude Code event limitations, `Elicitation` and `Notification` may not fire consistently.
> `PreToolUse/AskUserQuestion` (Elicitation sound) and `SubagentStop` (Notification sound) serve as more reliable alternatives.

---

## 音效列表 Sounds

### Windows 系统音 System Sounds

| Name | 名称 | 用途 |
|------|------|------|
| Hand | 手掌 | 紧急停止 / 警报 |
| Question | 提问 | 澄清问题 |
| Exclamation | 感叹 | 警告 |
| Asterisk | 星号 | 信息通知 |
| Beep | 哔声 | 简单提示 |

### 内置 WAV 音效 Built-in WAV Chimes

| File | 音色 | Best For |
|------|------|----------|
| done-classic.wav | 上行 C5→E5 和弦 | 任务完成 |
| done-soft.wav | 柔和 A4 音 | 任务完成（低调） |
| done-fanfare.wav | C5→E5→G5 三和弦 | 庆祝完成 |
| ding.wav | 清脆 1046Hz | 通知 |
| pop.wav | 短促 800Hz | 快速反馈 |
| beep-soft.wav | 轻柔 880Hz | 柔和提示 |
| notify-descend.wav | G5→E5 下行双音 | 通知 |
| alert.wav | 中频 660Hz | 权限请求 |
| warning.wav | 下行 440→349Hz | 子 agent 空闲 |
| error.wav | 断奏低音 | 错误提示 |
| question-rising.wav | 400→1200Hz 上升扫频 | 澄清问题 |
| question-double.wav | 660→880Hz 双音 | 提问确认 |

### 导入自定义音效 Custom WAV Import

将 `.wav` 文件放入 `sounds/` 文件夹，重启 UI 后会在下拉菜单中出现。推荐 44100Hz 16-bit 单声道。

Add `.wav` files to the `sounds/` folder — they appear in the dropdown automatically. 44100Hz 16-bit mono recommended.

---

## 手动安装 Manual Install

如果安装脚本无法修改 settings.json，请手动添加以下 Hook 条目：

If the installer can't update settings.json, add these hooks manually:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Stop",
        "timeout": 10, "async": true
      }]
    }],
    "PermissionRequest": [{
      "matcher": "Bash|Write|Edit|Read",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event PermissionRequest",
        "timeout": 10, "async": true
      }]
    }],
    "PreToolUse": [{
      "matcher": "AskUserQuestion",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Elicitation",
        "timeout": 10, "async": true
      }]
    }],
    "SubagentStop": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Notification",
        "timeout": 10, "async": true
      }]
    }],
    "Elicitation": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event Elicitation",
        "timeout": 10, "async": true
      }]
    }],
    "TeammateIdle": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\You\\.claude\\hooks\\dingdong\\play-sound.ps1\" -Event TeammateIdle",
        "timeout": 10, "async": true
      }]
    }]
  }
}
```

---

## 卸载 Uninstall

```powershell
# 一键卸载
.\_uninstall.ps1

# 或手动：
# 1. 从 settings.json 删除 dingdong Hook 条目
# 2. 删除 ~/.claude/hooks/dingdong/
# 3. 在 Claude Code 中执行 /hooks 或重启
```

---

## 技术说明 Technical Notes

- 所有 Hook 使用 `async: true`，音效播放不会阻塞 Claude Code
- 配置文件 `config.json` 使用 `${CLAUDE_PLUGIN_ROOT}` 变量路径，安装位置无关
- 安装目录：`~/.claude/hooks/dingdong/`
- 日志位置：`~/.claude/hooks/dingdong/logs/`

---

## License

MIT
