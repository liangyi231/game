# 大肥鱼传说 · 项目约定（给 AI 助手）

## 每轮迭代后必须自动提交

**规则：每次完成一轮改动（本轮最后一次验证通过后），立即执行：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/git-auto-commit.ps1 "feat: 本轮摘要"
```

> 本机没有 `pwsh`，只有 `powershell.exe`（5.1），命令里别用 `pwsh`。
> 等价的手工命令：`git add -A` 然后 `git commit -m "feat: 本轮摘要"`。

- 提交信息用中文，格式 `类型: 摘要`，类型取 `feat / fix / docs / art / chore`
- 摘要写「这轮改了什么、验证结果」，一行说清
- 远程是 GitHub `https://github.com/liangyi231/game.git`（分支 `main`），**已设置上游跟踪，凭据由 Git Credential Manager 记住**（2026-11-03 首次登录后不再询问）
- 默认仍然只做本地提交；作者明确说「上传 / 推送」时才执行 `git push`（直接 `git push` 即可，不需要再带参数）
- 不要主动索要账号、密码或 Token；凭据缺失时提示作者运行 `tools/推送到GitHub.bat` 登录一次
- 不要手动 `git add .godot` 之类：`.gitignore` 已排除缓存与本机工具链

## 工程约定

- Godot 4.7.2，启动场景 `scenes/battle.tscn`，全屏运行，`F11` 切全屏 / `Esc` 退出
- UI 全部代码构建（`scripts/battle/battle_screen.gd`），绝对定位，中文用 `SystemFont`（不塞字体文件）
- 卡牌数据集中在 `scripts/cards/card_db.gd`，加牌只改这一处
- 战斗逻辑在 `scripts/battle/battle_state.gd`（信号驱动 UI），改数值/状态优先改这里
- 音效走 autoload `Sfx`，文件放 `audio/sfx/`，缺文件静默跳过
- 编辑器插件 `addons/godot_ai` 已启用（MCP 直连，可让 AI 直接操作编辑器）

## 美术与素材

- 主角：`art/characters/whale_girl.png`（鲸娘，透明 PNG）
- 敌人：`art/enemies/nailong_idle.png` / `nailong_action.png`（同画布两帧）
- 卡面：`art/ui/card_face.jpg`；背景：`art/bg/night_sky.jpg`
- 抠图/音效脚本在 `tools/`，可复现；原始素材保留在 `art/**/*_src*` 与 `art/characters/main_char_ref.jpg`
- 音频：`audio/sfx/`（`seekseek`=玩家出牌、`laugh`=奶龙行动、`hurt`=受击）；`audio/music/bgm.ogg` 是循环 BGM，替换同名文件即生效

## 文档

- `docs/卡牌战斗设计.md`：玩法、数值、状态、文件结构、下一步
- `docs/资源库清单.md`：可复用的开源 Godot 资源（含网络实测）
- `docs/AI插件安装说明.md`：Godot AI 插件与 MCP 接线、排错

## git 身份

本仓库已设置 `liangyi231 <liangyi231@users.noreply.github.com>`（与 GitHub 账号对应，提交可正确归属）。
如需修改：

```powershell
git config user.name "你的名字"
git config user.email "你的邮箱"
```
