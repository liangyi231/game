# 大肥鱼 · 2D 角色拆件与骨骼规范 v0.1

> 主角：DeepSeek Q 版形象「大肥鱼」（蓝发、鲸鱼尾、女仆装、精灵鳍耳）。
> 目标：2D 弹幕肉鸽，主角在战斗场景中以正面朝向出现，靠倾斜 / 翻转 / 上下飘表现方向与状态。
> 技术路线：**纯 2D**，不使用 3D 建模。Godot 4.7.2 + `gl_compatibility` 渲染器。

---

## 1. 尺寸与坐标规范

| 项目 | 数值 | 说明 |
| --- | --- | --- |
| 游戏视口 | 1280×720 | 已配置 `canvas_items` 拉伸 |
| 主角显示高度 | 128 px | 弹幕游戏里主角不能太大，否则躲弹困难 |
| 主角素材分辨率 | 2×（256 px 高） | 留清晰度余量，非像素风不需要整数倍 |
| 判定点 | 8–12 px 圆形 | 与视觉尺寸分离，只画一个小圆点提示 |
| 描边色 | `#2B221C`，4–6 px | 与 Boss 统一，保证同屏风格一致 |
| 导出格式 | PNG-24 带 Alpha | 透明通道必须是直通（straight），不要预乘 |
| 部件留白 | 每个部件四周留 4 px 透明边 | 防止旋转 / 缩放时被裁掉描边 |

---

## 2. 拆件清单（共 17 部件，按绘制顺序从后往前）

> 所有部件都从同一张 2048×2048 画布上裁出，并记录各自在画布中的 `x, y, w, h`，写进 `parts.json`。Godot 里按这份数据把部件摆回原位，避免手动对齐。

| 层序 | 部件名 | 中文 | 枢轴（旋转中心） | 绑骨情况 |
| --- | --- | --- | --- | --- |
| 01 | `tail_back` | 鲸尾后半 | 尾根（与身体连接处） | 绑 `tail_1`，末端可加 2 节 |
| 02 | `hair_back` | 后发 | 后脑中心 | 静态挂 `head` |
| 03 | `skirt` | 裙摆 | 腰部中心 | 绑 `hip`，裙边可做 2 节摆 |
| 04 | `leg_l` / `leg_r` | 左右腿 + 鞋 | 髋关节 | 绑 `leg_l` / `leg_r` |
| 05 | `apron` | 围裙 | 腰前中心 | 挂 `spine` |
| 06 | `torso` | 上身 + 衣领 + 蝴蝶结 | 腰中心 | 绑 `spine` |
| 07 | `arm_l` / `arm_r` | 左右手臂 + 袖口 | 肩关节 | 绑 `arm_l` / `arm_r` |
| 08 | `head` | 脸 + 脖子 | 脖子根部 | 绑 `neck`→`head` |
| 09 | `fin_l` / `fin_r` | 两侧鳍耳 | 耳根 | 绑 `head` |
| 10 | `eye_l` / `eye_r` | 左右眼（含高光） | 眼球中心 | 不绑骨，贴图切换 |
| 11 | `brow_l` / `brow_r` | 眉毛（可选） | 眉根 | 不绑骨，贴图切换 |
| 12 | `mouth` | 嘴（多差分） | 嘴中心 | 不绑骨，贴图切换 |
| 13 | `blush` | 腮红 | 脸颊处 | 可独立做害羞/生气动画 |
| 14 | `hair_front` | 刘海 | 头顶中心 | 分左右两簇，各绑 1–2 节 |
| 15 | `headdress` | 女仆头饰 | 头顶 | 挂 `head` |
| 16 | `ahoge` | 呆毛 | 头顶正中 | 单节骨骼，做摇摆 |
| 17 | `tail_front` | 鲸尾前半（可选） | 尾根 | 用于尾尖甩到身前时的遮挡 |

**拆件技巧**

- 用 **LayerDivider** 先把整张插画自动分层，再在 PS/Krita 里手工按上表整理；自动分层的结果通常对不齐，必须人工修边缘。
- 头发一定要拆 `hair_back` / `hair_front` 两层，否则头部转动时后发会穿到脸前面。
- 眼睛、嘴、腮红做成独立小图，方便做表情差分和「看向弹幕方向」的视线移动。
- 每个部件导出前合并多余的图层，不要留半透明叠加层（会导致边缘发灰）。

---

## 3. 骨骼层级（Godot 节点树）

```
Player (Node2D)              # 根，锚点在脚底中点
└─ Hip (Node2D)              # 位移、整体翻转都在这层
   ├─ TailRoot (Node2D)
   │  └─ Tail1 → Tail2 → Tail3
   ├─ LegL / LegR (Node2D)
   ├─ Spine (Node2D)         # 呼吸、侧倾
   │  ├─ Skirt (Node2D)
   │  ├─ Torso (Sprite2D)
   │  ├─ ArmL → HandL
   │  ├─ ArmR → HandR
   │  └─ Chest (Node2D)
   │     └─ Neck → Head (Node2D)
   │        ├─ FinL / FinR
   │        ├─ Face (Node2D) # eye_l/eye_r/brow/mouth/blush 都在这里
   │        ├─ HairFront (Node2D)
   │        ├─ Ahoge (Node2D)
   │        └─ Headdress (Sprite2D)
```

> 每个部件用 `Sprite2D`，`centered = true`，节点的 `position` 就是枢轴点；
> 贴图用 `offset` 让画面相对枢轴对齐。这样旋转一个部件时，是围绕关节转，而不是围绕图片中心转。

---

## 4. 动画清单（先做 5 个跑通）

| 动画 | 时长 | 循环 | 内容 |
| --- | --- | --- | --- |
| `idle` | 2.0s | 是 | 呼吸上下 2px + 头发/尾巴 sin 摆动 + 呆毛轻摇 |
| `move` | 0.6s | 是 | 整体侧倾 8°，头发与鲸尾向反方向飘 |
| `hurt` | 0.25s | 否 | 闪白（modulate 变白）+ 左右抖动 4px |
| `cast` | 0.4s | 否 | 抬手 → 手部发光 → 回位 |
| `death` | 0.8s | 否 | 溶解 shader + 缩放收缩 |

后续再加：`dash`（压缩拉伸）、`ult`（全屏演出）、`win`（转圈）。

---

## 5. 表情差分（≤ 6 个，用贴图切换实现）

`normal` / `blink`（眨眼）/ `happy`（笑眼）/ `angry`（眉压 + 鼓脸）/ `hurt`（泪眼）/ `serious`（无高光）

- 实现方式：`Sprite2D.texture = preload(...)` 直接换图，或 `AnimatedSprite2D` 播帧。
- 眨眼用 0.15s 的随机定时器触发，别做进 idle 里，否则节奏呆板。

---

## 6. Godot 实现方案（二选一）

### 方案 A：Sprite2D 层级动画（推荐起步）

- 优点：零学习成本、调试直观、性能好、导图即用；
- 做法：上面的节点树 + `AnimationPlayer` 对每个 Node2D 的 `rotation` / `position` / `scale` 打关键帧；
- 适用：你现在这个规模（5–10 个动作、单朝向）完全够。

### 方案 B：Polygon2D + Skeleton2D 蒙皮（进阶）

- 优点：头发、鲸尾、裙摆能做出柔性弯曲，动起来非常"活"；
- 代价：每个部件要画网格 + 刷权重，改一次图要重刷，返工成本高；
- 建议：**只在头发和尾巴这两个地方局部使用**，其余仍用方案 A 的层级动画。

### 通用设置

- 项目设置 → `rendering/textures/canvas_textures/default_texture_filter` = **Linear**（非像素风）
- 导入预设：开启 Mipmaps，压缩选 `VRAM Compressed` 或 `Lossless`
- 受伤闪白：`CanvasItemMaterial` + 一个简单的 `modulate` shader，别用换图
- 主角节点加 `z_index` 分层（背景 < 主角 < 弹幕 < UI）

---

## 7. 资产目录约定

```
art/characters/fish/
├─ parts/                # 拆件 PNG（按层序编号）
│  ├─ 01_tail_back.png
│  ├─ 02_hair_back.png
│  ├─ ...
│  └─ 17_tail_front.png
├─ expressions/          # 表情差分
│  ├─ eye_normal.png
│  └─ eye_blink.png
├─ parts.json            # 每个部件在画布中的 x,y,w,h 与枢轴
└─ main_char_ref.jpg     # 参考图（已放入）
```

---

## 8. 进度

- [ ] 拆件（17 个部件导出 PNG）
- [ ] 写 `parts.json`（画布坐标 + 枢轴）
- [ ] Godot 里搭节点树 + 绑定部件
- [ ] 5 个基础动作动画
- [ ] 表情差分接入
- [ ] 受伤闪白 + 判定点显示
