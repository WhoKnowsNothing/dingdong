# DingDong 叮咚

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)

Claude Code 与 Codex 共用的本地提示音。一套播放器、一套音效库、一套用户设置；两端分别接入各自的事件回调，无后台服务。

DingDong provides local audio feedback for Claude Code and Codex. Both clients share the same players, sound library and persistent user settings.

## 共享配置 / Shared settings

默认用户数据目录：

- Windows：`%USERPROFILE%\.config\dingdong\`
- macOS / Linux：`~/.config/dingdong/`

其中 `config.json` 保存设置，`sounds/` 保存音效。设置一次，对两端生效；重装或升级插件保留这些数据。
可用绝对路径环境变量 `DINGDONG_HOME` 指定其他目录，两端必须使用相同的值。

首次安装会迁移已有安装目录中的设置和 WAV；已有共享配置和同名音效不会被覆盖。如果原来两端设置不同，请先用要保留的一端初始化共享目录，并备份另一端。
直接解压运行但尚未初始化共享目录时，播放器读取包内默认配置。

User data lives outside versioned plugin caches. Installers seed it once and preserve it on subsequent installs. Use the same absolute `DINGDONG_HOME` in both clients to override its location.

## 安装 / Install

### Claude Code

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1

# macOS / Linux (python3 required for settings registration)
bash scripts/install.sh
```

安装器只替换 DingDong 的回调，并备份设置文件；同组中的其他回调也会保留。Windows 将运行文件安装到 `~/.claude/plugins/dingdong/`。
重新启动 Claude Code 加载更改。

### Codex

Codex 安装包从本仓库生成，独立插件目录是生成结果；修改代码应在本仓库进行。

已有本地市场中的 DingDong 时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-codex.ps1
```

这个脚本通过 Codex CLI 查找已注册的本地来源，备份旧包、构建并更新缓存版本，再由 CLI 验证和安装，不依赖额外的 plugin-creator 辅助文件。若多个市场都有 DingDong，可用 `-Marketplace personal` 指定市场。
首次安装需先将生成的 Codex 包注册到本地插件市场。在市场根目录的 `.agents/plugins/marketplace.json` 中添加 `dingdong` 条目，`source` 使用 `{"source":"local","path":"./plugins/dingdong"}`，并把生成包放入对应目录；已有市场应保留其他条目。完整结构见 [Codex 官方本地插件安装说明](https://developers.openai.com/plugins/build/plugins#install-a-local-plugin-manually)。然后运行 `codex plugin marketplace add <市场根目录>` 和 `codex plugin add dingdong@<市场名称>`；回调信任仍按 Codex 的正常流程处理。

仅构建可分发包：

```powershell
powershell -File scripts/build-codex.ps1 -OutputDir ./dist/codex/dingdong
```

包内包含 Windows 与 Unix 播放入口；macOS/Linux 运行依赖系统音频工具及 python3 或 jq。
Codex 的回调必须先在 `/hooks` 审核并信任，然后新开任务验证。安装成功不代表回调已获信任。
详见 [Codex 官方回调文档](https://learn.chatgpt.com/docs/hooks)。

For an existing local-marketplace installation, `scripts/update-codex.ps1` rebuilds from this repository and reinstalls through the Codex CLI without external plugin-creator helpers. Review changed hooks in `/hooks` and start a new task.

## 配置 / Configure

```powershell
# Windows：也可以双击 configure.bat
powershell -NoProfile -ExecutionPolicy Bypass -File config-ui.ps1

# 终端配置工具
bash config.sh
```

从仓库、Claude 安装目录或 Codex 包打开配置工具，都编辑同一份用户设置。导入 WAV 也保存到共享音效库。

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

- `type: none` 静音；`type: wav` 播放 WAV。
- Windows 也支持 `type: system` 和 `sound: Hand/Asterisk/Beep/Question/Exclamation`。
- 相对音效路径以配置文件所在目录为基准，也支持绝对文件路径。
- 旧版平铺配置可以读取；事件触发时不改写配置。
- 播放音量由系统控制；现有 `volume` 字段保留兼容，播放器尚不应用此字段。

## 事件映射 / Events

| 共用设置 | Claude Code 入口 | Codex 入口 |
| --- | --- | --- |
| Stop：回复结束 | Stop | Stop |
| PermissionRequest：权限确认 | PermissionRequest | PermissionRequest |
| Elicitation：需要输入 | MCP Elicitation；PreToolUse / AskUserQuestion | PreToolUse / request_user_input、request_user_input_async、send_user_message_async |
| Notification：通知 | Notification；SubagentStop | SubagentStop |
| TeammateIdle：队友空闲 | TeammateIdle | 无对应事件，保留设置 |

Claude 的回调定义位于 `hooks.json` 和 `hooks.unix.json`；Codex 的定义位于 `integrations/codex/`，构建时复制到独立包，避免两端自动加载对方的回调。
具体匹配范围以对应定义为准。两端异步播放，不做权限决策。Codex 包装入口消费但不保存事件输入，并始终返回空 JSON 对象。
Windows 的 Codex 完成回调按会话 ID 和本轮任务 ID 去重：同一轮重复、延迟或并发到达的 `Stop` 只播放一次；其他轮次和会话独立提示。去重状态位于共享目录的 `state/codex-stop/`，仅保留以哈希命名的空标记文件，七天后清理，不保存对话内容。缺少 ID 或状态目录不可写时仍正常尝试播放。
Windows 入口按 UTF-8 读取事件，避免中文回复在旧代码页下导致 JSON 解析失败。`transcript_path` 明确为空的临时会话不播放完成音，避免标题、摘要等后台任务追加响铃；这也包含使用 `--ephemeral` 的临时 CLI 任务。缺少该字段的旧客户端和手动调用保持兼容。
v0.0.8 新增旧代码页下中文输入和临时会话回调的回归测试，本地 15 项检查通过。实际响铃次数仍需在 Codex 中完成真实任务后确认。

## 卸载 / Uninstall

```powershell
# Claude Code
powershell -File scripts/uninstall.ps1
bash scripts/uninstall.sh

# Codex
codex plugin remove dingdong@personal
```

卸载任一端均保留共享配置与音效，另一端仍可使用。

## 验证 / Verify

```powershell
python -m unittest discover -s tests -v

# 查看 Windows 播放器实际读取的配置和音效，不播放声音
powershell -File play-sound.ps1 -Event Stop -DryRun
```

测试覆盖双端共享设置、重装保留数据、旧配置迁移、混合回调保护、无效设置保护、Codex JSON 输出，以及带中文、空格和单引号路径的 Unix 播放入口。
Windows 测试需 Windows PowerShell；Unix 音频检查使用替身，不表示 macOS/Linux 声卡已实机验证。

结构见 [ARCHITECTURE.md](ARCHITECTURE.md)。内置 13 个 WAV；自定义 WAV 可通过配置工具导入。
许可见 [LICENSE](LICENSE) 和 [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md)。
