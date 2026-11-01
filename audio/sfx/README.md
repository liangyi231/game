# 音效目录（存档约定）

把音效文件放在本目录，文件名对上就会自动播放；缺文件时静默跳过，不影响战斗。

支持格式：`.ogg`（推荐）> `.wav` > `.mp3`。
播放器：autoload `Sfx`（`scripts/audio/sfx.gd`），8 路复用、默认 -6 dB。

## 当前接线（三个视频各对应一个音效）

| 文件名 | 来源视频 | 触发时机 |
|---|---|---|
| `seekseek.wav` | 4384b091…mp4「Seek Seek（与我何干）」 | **大肥鱼行动**：玩家出任意牌 |
| `laugh.wav` | video_20261101_234257.mp4（奶龙捧腹大笑） | **奶龙行动**：奶龙出手 / 格挡 |
| `hurt.wav` | ea94ebece…mp4（截取前 1.2 秒） | **受击**：任何角色实际掉血 |

处理：`ffmpeg` 90Hz 高通 + 首尾静音裁剪 + 响度归一（-16 LUFS / TP -1.5）。
**不做人声分离**（之前 demucs 分离会产生「回音/水声」感，已弃用）。

旧的 `deepdepp.wav`（Deep Deep）与 demucs 版旧 `seekseek` 均已删除，现在只保留 Seek Seek 这一条行动音。

## 可加但暂未接的

| 文件名 | 触发时机 |
|---|---|
| `victory.ogg` / `defeat.ogg` | 战斗结算（当前无文件→静默） |
| `click.ogg` | 点击（未接入） |
| `draw.ogg` | 抽牌（未接入） |

## 想换/加音效

直接替换同名文件，或在 `scripts/battle/battle_screen.gd` 里改 `_sfx("名字")`，再把同名文件丢进来即可。
