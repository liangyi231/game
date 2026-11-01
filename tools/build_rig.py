# -*- coding: utf-8 -*-
"""生成主角「大肥鱼」的占位骨架场景 scenes/player_rig.tscn。

思路：每个部件用一个 Polygon2D（当前是纯色占位）。
等真美术拆件完成后，只需要给这些 Polygon2D 设置 texture + uv，
或直接换成 Sprite2D，节点树与动画都不用动。

运行：python tools/build_rig.py
"""

import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "scenes", "player_rig.tscn")


def ellipse(cx, cy, rx, ry, n=28, start=0.0, end=2 * math.pi):
    pts = []
    for i in range(n + 1):
        a = start + (end - start) * i / n
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return pts


def poly(pts):
    body = ", ".join(f"{x:.1f}, {y:.1f}" for x, y in pts)
    return f"PackedVector2Array({body})"


def color(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.3f}, {g:.3f}, {b:.3f}, {a})"


# ---------------------------------------------------------------- 调色板
HAIR = "#4A72C4"
HAIR_DARK = "#33497F"
SKIN = "#FBDCC8"
DRESS = "#1E2A4A"
APRON = "#F7F5F0"
WHITE = "#FFFFFF"
EYE = "#2B3A5C"
BLUSH = "#F2919C"
TAIL = "#5C7FC0"
TAIL_DARK = "#41629F"
FIN = "#86AEE0"
MOUTH = "#C4505F"

# ---------------------------------------------------------------- 节点定义
# (name, type, parent, position, extras)
nodes = []


def add(name, parent, pos=(0, 0), poly_pts=None, fill=None, rotation=None):
    nodes.append(dict(name=name, parent=parent, pos=pos, pts=poly_pts,
                      fill=fill, rotation=rotation))


# 根：脚底中点
add("Player", ".", (0, 0))
add("Hip", "Player", (0, 0))

# 鲸尾（身后）
add("TailRoot", "Hip", (34, -88))
add("Tail1", "TailRoot", (0, 0), ellipse(34, 6, 40, 14), TAIL)
add("TailTip", "Tail1", (40, 0), [(0, 0), (44, -18), (52, 6)], TAIL_DARK)

# 腿 + 鞋
add("LegL", "Hip", (-20, 0), ellipse(0, -10, 11, 12), SKIN)
add("ShoeL", "LegL", (0, 0), ellipse(0, -3, 14, 7), DRESS)
add("LegR", "Hip", (20, 0), ellipse(0, -10, 11, 12), SKIN)
add("ShoeR", "LegR", (0, 0), ellipse(0, -3, 14, 7), DRESS)

# 裙 + 围裙
add("Skirt", "Hip", (0, -18), [(-58, 0), (58, 0), (46, -74), (-46, -74)], DRESS)
add("Apron", "Hip", (0, -22), [(-26, 0), (26, 0), (20, -66), (-20, -66)], APRON)

# 脊柱（呼吸/侧倾都在这一层）
add("Spine", "Hip", (0, -92))
add("Torso", "Spine", (0, 0), [(-30, 0), (30, 0), (26, -48), (-26, -48)], DRESS)
add("Collar", "Spine", (0, -46), ellipse(0, 0, 26, 9), WHITE)

# 手臂
add("ArmL", "Spine", (-36, -36), ellipse(0, 14, 11, 24), DRESS)
add("HandL", "ArmL", (0, 34), ellipse(0, 0, 11, 11), SKIN)
add("ArmR", "Spine", (36, -36), ellipse(0, 14, 11, 24), DRESS)
add("HandR", "ArmR", (0, 34), ellipse(0, 0, 11, 11), SKIN)

# 胸腔 → 头
add("Chest", "Spine", (0, -46))
add("HairBack", "Chest", (0, -44), ellipse(0, 0, 86, 82), HAIR_DARK)
add("Head", "Chest", (0, -48))
add("HeadBase", "Head", (0, 0), ellipse(0, 0, 70, 68), SKIN)
add("FinL", "Head", (-66, -4), [(-6, 0), (18, -20), (20, 16)], FIN)
add("FinR", "Head", (66, -4), [(6, 0), (-18, -20), (-20, 16)], FIN)

# 脸：眼睛 / 腮红 / 嘴
add("Face", "Head", (0, 0))
add("EyeL", "Face", (-26, 4), ellipse(0, 0, 9, 12), EYE)
add("GlintL", "EyeL", (0, 0), ellipse(-3, -4, 3.5, 4.5), WHITE)
add("EyeR", "Face", (26, 4), ellipse(0, 0, 9, 12), EYE)
add("GlintR", "EyeR", (0, 0), ellipse(3, -4, 3.5, 4.5), WHITE)
add("BlushL", "Face", (-44, 20), ellipse(0, 0, 12, 7), BLUSH)
add("BlushR", "Face", (44, 20), ellipse(0, 0, 12, 7), BLUSH)
add("Mouth", "Face", (0, 26), ellipse(0, 0, 5, 3.5), MOUTH)

# 刘海（盖住头顶）
add("HairFront", "Head", (0, 0),
    [(x, y) for x, y in ellipse(0, 0, 74, 70, 24, math.pi, 2 * math.pi)]
    + [(x, y) for x, y in ellipse(0, 6, 56, 44, 24, 2 * math.pi, math.pi)],
    HAIR)
# 女仆头饰
add("Headdress", "Head", (0, -56), ellipse(0, 0, 64, 15), WHITE)
# 呆毛
add("Ahoge", "Head", (0, -64), [(-4, 0), (2, -26), (10, -34), (6, -18), (3, 0)], HAIR_DARK)

class Vector2:
    def __init__(self, x, y):
        self.x, self.y = x, y


class Color:
    def __init__(self, r, g, b, a):
        self.r, self.g, self.b, self.a = r, g, b, a


# ---------------------------------------------------------------- 动画
ANIMS = [
    dict(name="idle", length=2.0, loop=1, tracks=[
        ("Hip:position", [0.0, 1.0, 2.0], [Vector2(0, 0), Vector2(0, 2), Vector2(0, 0)]),
        ("Ahoge:rotation", [0.0, 1.0, 2.0], [0.0, 0.12, 0.0]),
        ("Tail1:rotation", [0.0, 1.0, 2.0], [0.0, 0.15, 0.0]),
        ("HairBack:scale", [0.0, 1.0, 2.0], [Vector2(1, 1), Vector2(1.02, 1.01), Vector2(1, 1)]),
    ]),
    dict(name="move", length=0.6, loop=1, tracks=[
        ("Hip:rotation", [0.0, 0.3, 0.6], [0.0, 0.10, 0.0]),
        ("Tail1:rotation", [0.0, 0.3, 0.6], [0.0, -0.25, 0.0]),
    ]),
    dict(name="hurt", length=0.25, loop=0, tracks=[
        ("Player:modulate", [0.0, 0.06, 0.14, 0.25],
         [Color(1, 1, 1, 1), Color(1.8, 1.8, 1.8, 1), Color(1.2, 1.2, 1.2, 1), Color(1, 1, 1, 1)]),
        ("Hip:position", [0.0, 0.06, 0.12, 0.18, 0.25],
         [Vector2(0, 0), Vector2(5, 0), Vector2(-5, 0), Vector2(3, 0), Vector2(0, 0)]),
    ]),
]


def fmt_val(v):
    if isinstance(v, Vector2):
        return f"Vector2({v.x:g}, {v.y:g})"
    if isinstance(v, Color):
        return f"Color({v.r:g}, {v.g:g}, {v.b:g}, {v.a:g})"
    return f"{v}"


# ---------------------------------------------------------------- 输出 tscn
lines = []
sub_res = []
anim_names = []

for i, a in enumerate(ANIMS):
    rid = f"Anim_{a['name']}"
    anim_names.append((a["name"], rid))
    body = [f'[sub_resource type="Animation" id="{rid}"]',
            f'resource_name = "{a["name"]}"',
            f"length = {a['length']}",
            f"loop_mode = {a['loop']}"]
    for t, (path, times, values) in enumerate(a["tracks"]):
        body += [
            f"tracks/{t}/type = &\"value\"",
            f"tracks/{t}/imported = false",
            f"tracks/{t}/enabled = true",
            f"tracks/{t}/path = NodePath(\"{path}\")",
            f"tracks/{t}/interp = 1",
            f"tracks/{t}/loop_wrap = true",
            f"tracks/{t}/keys = {{",
            f'"times": PackedFloat32Array({", ".join(f"{x:g}" for x in times)}),',
            f'"transitions": PackedFloat32Array({", ".join("1" for _ in times)}),',
            f'"update": 0,',
            f'"values": [{", ".join(fmt_val(v) for v in values)}]',
            "}",
        ]
    sub_res += body

lib = ['[sub_resource type="AnimationLibrary" id="AnimLib"]', "_data = {",
       ", ".join(f'"%s": SubResource("%s")' % (n, r) for n, r in anim_names), "}", ""]
sub_res += lib

load_steps = len(ANIMS) + 1 + 1  # 动画 + 动画库 + 场景本身
out = [f'[gd_scene load_steps={load_steps + 1} format=3]', ""]
out += sub_res

for n in nodes:
    is_root = n["name"] == "Player"
    is_container = n.get("fill") is None
    header = f'[node name="{n["name"]}"'
    header += (' type="Node2D"' if (is_root or is_container) else ' type="Polygon2D"')
    header += (']' if is_root else f' parent="{n["parent"]}"]')
    out.append(header)
    if not is_root:
        out.append(f"position = Vector2({n['pos'][0]:g}, {n['pos'][1]:g})")
        if n.get("rotation") is not None:
            out.append(f"rotation = {n['rotation']}")
        if not is_container:
            out.append(f"color = {color(n['fill'], n.get('alpha', 1.0))}")
            out.append(f"polygon = {poly(n['pts'])}")
    out.append("")

out.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]')
out.append('libraries = {\n&"": SubResource("AnimLib")\n}')
out.append('autoplay = "idle"')
out.append("")

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print("saved:", OUT, "nodes:", len(nodes))
