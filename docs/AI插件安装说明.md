# Godot AI 插件安装说明（v4.3.1 · 2026-11-01）

## 装了什么

| 组件 | 位置 / 版本 | 说明 |
|---|---|---|
| Godot 引擎 | `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` | 4.7.2.stable.official，绿色版（不在 PATH/注册表，只能按路径调用） |
| 编辑器插件 | 本工程 `addons/godot_ai/`（313 文件） | 来自 tag `v4.3.1` 源码，`plugin.cfg version=4.3.1` |
| Python 服务端 | `C:\Users\a\.local\bin\godot-ai.exe`（uv tool） | `godot-ai 4.3.1`，由清华源安装 |
| DSH 侧 MCP 配置包 | 本工程 `.dsh-godot-ai-mcp/` | config-only bundle，已 `install_bundle` 装入 desktop profile |
| 资源库清单 | `docs/资源库清单.md` | 用户整理的开源 Godot 资源，含网络实测 |

## 链路

```
DSH ──(stdio)──> godot-ai attach ──(鉴权 HTTP 127.0.0.1:8000)──> Python 服务端
                                                    │
                                          (鉴权 WS 127.0.0.1:9500)
                                                    ▼
                                          Godot 编辑器插件（本工程）
```

- 凭据：`%LOCALAPPDATA%\godot-ai\capabilities\http-8000.json`
- 工具命名空间：`mcp__godot-ai__*`（47 个工具：场景/节点/脚本/信号/UI/动画/粒子/材质/TileMap/GridMap/音频/相机/物理/测试/运行时输入 等）

## 启动顺序

1. 打开 Godot 编辑器（打开本工程）→ 插件自动加载，日志出现
   `MCP | plugin loaded` → `MCP | adopted external server` 或 `MCP | connected to server`
2. 编辑器侧服务端会自己占 8000/9500；**不要再手动起第二个**实例，否则会
   `HTTP port 8000 is already in use`（插件的 `godot_ai_server_startup.json` 会记录该错误）。
3. DSH 里的 MCP 客户端会 spawn `godot-ai.exe attach --port 8000 --ws-port 9500` 转 stdio。
   编辑器没开时 attach 可能自己拉一个后端；编辑器后开会“采纳（adopt）”它。

## 换一台机器 / 换一个工程怎么装

把 `addons/godot_ai/` 整个目录拷进目标工程的 `addons/`，然后在 `project.godot` 里启用：

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")
```

`addons/godot_ai/runtime/game_helper.gd` 会被插件自动注册为 autoload `_mcp_game_helper`（运行时输入/游戏内 eval 需要它）。

## 本机网络相关的坑（没翻墙）

| 现象 | 处理 |
|---|---|
| GitHub Release 附件下到一半连接被重置 | 改 `git clone --depth 1 --branch v4.3.1 https://github.com/hi-godot/godot-ai.git` 取源码（11 秒） |
| `pypi.org` 时通时断、大包卡死 | 一律 `-i https://pypi.tuna.tsinghua.edu.cn/simple`；`uv tool install godot-ai==4.3.1 --default-index <清华>` |
| 插件默认 launch tier 是 `uvx --index https://pypi.org/simple` | 本机已实测：uvx tier 能跑起来就让它跑；若失败，系统安装的 `godot-ai.exe` 是兜底（DSH 侧配置就是直接用系统安装的 exe） |
| `kenney.nl` curl 403 | Cloudflare 拦 UA，浏览器打开即可 |

## 踩过的编码坑（重要）

**不要用 PowerShell 的 `Get-Content -Raw` + `Set-Content` 去改写带中文的 `project.godot`**：
本机 PowerShell 会把 UTF-8 当 GBK 读进来再写回，`config/name="大肥鱼传说"` 变成乱码且引号丢失，
Godot 启动直接 `Error parsing project.godot ... Unterminated string`。
改工程文件请用编辑器、`edit` 工具或明确指定 UTF-8 的方式。

## DSH 侧配置位置

- 配置包：`<本工程>/.dsh-godot-ai-mcp/`（`package.json` + `cordis.patch.yml`）
- 已装入：`C:\Users\a\.dsh\profiles\desktop\node_modules\@local\godot-ai-mcp`
- 生效方式：`plugin_manager(action=install_bundle, target=<该目录绝对路径>)`，热加载，无需重启 DSH
- 关键字段：`serverName: godot-ai`、`transport: stdio`、`command`、`args`、`toolCallTimeoutMs: 180000`、`failOnStartupError: true`

## 自检命令

```powershell
# 服务端是否在跑
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8000,9500 }
# 插件 startup 报错
Get-Content "$env:APPDATA\Godot\app_userdata\大肥鱼传说\godot_ai_server_startup.json"
# 版本
& "$env:USERPROFILE\.local\bin\godot-ai.exe" --version
```
