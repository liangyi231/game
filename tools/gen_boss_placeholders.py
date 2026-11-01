# -*- coding: utf-8 -*-
"""生成 3 个原创 Boss 的占位立绘 PNG（512x512，透明背景）。

用途：作为《大肥鱼传说》Boss 战原型的临时美术。
风格：平涂 + 粗描边 + 大圆脸 + 极简五官（网络梗图语汇）。
运行：python tools/gen_boss_placeholders.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter

S = 4  # 超采样倍数，先画大图再缩小，得到抗锯齿边缘
W = 512
INK = (43, 34, 28, 255)


def P(v):
    return int(round(v * S))


def new_canvas():
    return Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))


def ellipse(d, box, fill=None, outline=None, width=0):
    d.ellipse(
        [P(box[0]), P(box[1]), P(box[2]), P(box[3])],
        fill=fill,
        outline=outline,
        width=P(width) if width else 0,
    )


def polygon(d, pts, fill, outline=INK, width=4):
    d.polygon([(P(x), P(y)) for x, y in pts], fill=fill)
    if outline:
        d.line(
            [(P(x), P(y)) for x, y in pts + [pts[0]]],
            fill=outline,
            width=P(width),
            joint="curve",
        )


def line(d, pts, fill=INK, width=4):
    d.line([(P(x), P(y)) for x, y in pts], fill=fill, width=P(width), joint="curve")


def star(d, cx, cy, r, fill, outline=None):
    import math

    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = r if i % 2 == 0 else r * 0.42
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    polygon(d, pts, fill, outline=outline, width=2)


def soft_layer():
    return Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))


def downscale(img, name):
    out = img.resize((W, W), Image.LANCZOS)
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "placeholders", name)
    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, "PNG")
    print("saved:", path)
    return out


# ---------------------------------------------------------------- Boss 1 奶膘兽
def boss_milk():
    img = new_canvas()

    # 地面软阴影
    sh = soft_layer()
    ds = ImageDraw.Draw(sh)
    ds.ellipse([P(150), P(400), P(362), P(452)], fill=(30, 20, 15, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(P(8)))
    img.alpha_composite(sh)

    d = ImageDraw.Draw(img)
    BODY = (250, 227, 172, 255)
    CREAM = (255, 246, 219, 255)
    BLUSH = (244, 143, 143)

    # 两只小角/耳
    ellipse(d, (168, 118, 236, 186), fill=BODY, outline=INK, width=5)
    ellipse(d, (276, 118, 344, 186), fill=BODY, outline=INK, width=5)

    # 身体
    ellipse(d, (128, 150, 384, 412), fill=BODY, outline=INK, width=6)
    # 肚皮
    ellipse(d, (186, 240, 326, 386), fill=CREAM)
    # 脸颊高光
    hl = soft_layer()
    ImageDraw.Draw(hl).ellipse([P(168), P(178), P(266), P(250)], fill=(255, 255, 255, 90))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(P(10))))

    # 手
    ellipse(d, (104, 268, 156, 330), fill=BODY, outline=INK, width=5)
    ellipse(d, (356, 268, 408, 330), fill=BODY, outline=INK, width=5)
    # 脚
    ellipse(d, (176, 386, 244, 434), fill=BODY, outline=INK, width=5)
    ellipse(d, (268, 386, 336, 434), fill=BODY, outline=INK, width=5)

    # 呆眼
    ellipse(d, (204, 210, 234, 250), fill=INK)
    ellipse(d, (278, 210, 308, 250), fill=INK)
    ellipse(d, (211, 216, 220, 226), fill=(255, 255, 255, 255))
    ellipse(d, (285, 216, 294, 226), fill=(255, 255, 255, 255))
    # 腮红
    blush = soft_layer()
    db = ImageDraw.Draw(blush)
    db.ellipse([P(160), P(258), P(212), P(292)], fill=BLUSH + (110,))
    db.ellipse([P(300), P(258), P(352), P(292)], fill=BLUSH + (110,))
    img.alpha_composite(blush.filter(ImageFilter.GaussianBlur(P(5))))

    # 嘴：一个小 w
    d.arc([P(230), P(272), P(258), P(296)], 200, 340, fill=INK, width=P(5))
    d.arc([P(254), P(272), P(282), P(296)], 200, 340, fill=INK, width=P(5))
    # 尾巴
    ellipse(d, (352, 330, 404, 382), fill=BODY, outline=INK, width=5)

    return downscale(img, "boss_1_milkbeast.png")


# ---------------------------------------------------------------- Boss 2 发酵企鹅
def boss_penguin():
    img = new_canvas()

    # 臭气团（先画在身体后面）
    gas = soft_layer()
    dg = ImageDraw.Draw(gas)
    for x, y, r in [(120, 200, 46), (392, 210, 40), (150, 120, 32), (360, 118, 30),
                    (250, 96, 26), (96, 300, 28), (416, 300, 26)]:
        dg.ellipse([P(x - r), P(y - r), P(x + r), P(y + r)], fill=(150, 214, 120, 120))
    img.alpha_composite(gas.filter(ImageFilter.GaussianBlur(P(10))))

    sh = soft_layer()
    ImageDraw.Draw(sh).ellipse([P(150), P(400), P(362), P(452)], fill=(30, 20, 15, 70))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(P(8))))

    d = ImageDraw.Draw(img)
    BLACK = (46, 48, 56, 255)
    WHITE = (252, 250, 246, 255)

    # 翅膀
    ellipse(d, (92, 250, 158, 360), fill=BLACK, outline=INK, width=5)
    ellipse(d, (354, 250, 420, 360), fill=BLACK, outline=INK, width=5)
    # 脚
    ellipse(d, (172, 392, 250, 436), fill=(240, 158, 58, 255), outline=INK, width=5)
    ellipse(d, (262, 392, 340, 436), fill=(240, 158, 58, 255), outline=INK, width=5)
    # 身体
    ellipse(d, (140, 148, 372, 412), fill=BLACK, outline=INK, width=6)
    # 白肚皮
    ellipse(d, (178, 230, 334, 396), fill=WHITE)
    # 喙
    polygon(d, [(238, 214), (306, 214), (272, 250)], fill=(240, 158, 58, 255))

    # 大黑眼圈 + 死鱼眼
    d.ellipse([P(186), P(172), P(256), P(232)], fill=(255, 255, 255, 255), outline=INK, width=P(4))
    d.ellipse([P(288), P(172), P(358), P(232)], fill=(255, 255, 255, 255), outline=INK, width=P(4))
    ellipse(d, (206, 190, 230, 216), fill=INK)
    ellipse(d, (326, 190, 350, 216), fill=INK)
    ellipse(d, (211, 195, 219, 203), fill=(255, 255, 255, 255))
    ellipse(d, (331, 195, 339, 203), fill=(255, 255, 255, 255))
    # 上眼皮（半睁，做出嫌弃感）
    d.arc([P(186), P(166), P(256), P(226)], 190, 350, fill=INK, width=P(7))
    d.arc([P(288), P(166), P(358), P(226)], 190, 350, fill=INK, width=P(7))
    # 歪嘴
    line(d, [(250, 268), (272, 262), (294, 270)], width=5)

    return downscale(img, "boss_2_sourpenguin.png")


# ---------------------------------------------------------------- Boss 3 大饼脸偶像
def boss_phebe():
    img = new_canvas()

    sh = soft_layer()
    ImageDraw.Draw(sh).ellipse([P(140), P(410), P(372), P(456)], fill=(30, 20, 15, 70))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(P(8))))

    d = ImageDraw.Draw(img)
    SKIN = (251, 222, 200, 255)
    HAIR = (247, 176, 200, 255)
    DRESS = (176, 208, 240, 255)

    # 蓬松的头发（云朵状）
    for x, y, r in [(150, 200, 52), (362, 200, 52), (170, 132, 48), (342, 132, 48),
                    (256, 106, 54), (210, 118, 40), (302, 118, 40), (126, 268, 40),
                    (386, 268, 40)]:
        ellipse(d, (x - r, y - r, x + r, y + r), fill=HAIR, outline=INK, width=5)
    # 脸：一张巨大的圆饼
    ellipse(d, (140, 148, 372, 380), fill=SKIN, outline=INK, width=6)

    # 刘海
    d.pieslice([P(140), P(148), P(372), P(290)], 180, 360, fill=HAIR)
    d.arc([P(140), P(148), P(372), P(290)], 180, 360, fill=INK, width=P(5))

    # 豆豆眼 + 星星高光
    ellipse(d, (196, 250, 240, 306), fill=INK)
    ellipse(d, (272, 250, 316, 306), fill=INK)
    ellipse(d, (206, 258, 222, 276), fill=(255, 255, 255, 255))
    ellipse(d, (282, 258, 298, 276), fill=(255, 255, 255, 255))
    star(d, 226, 292, 8, (255, 246, 200, 255), outline=None)
    star(d, 302, 292, 8, (255, 246, 200, 255), outline=None)
    # 腮红
    blush = soft_layer()
    db = ImageDraw.Draw(blush)
    db.ellipse([P(160), P(300), P(210), P(330)], fill=(244, 143, 143, 120))
    db.ellipse([P(302), P(300), P(352), P(330)], fill=(244, 143, 143, 120))
    img.alpha_composite(blush.filter(ImageFilter.GaussianBlur(P(5))))
    # 小嘴
    d.arc([P(244), P(316), P(268), P(338)], 20, 160, fill=INK, width=P(5))
    # 发饰星星
    star(d, 372, 176, 22, (255, 226, 122, 255))

    # 身体（小小的，衬托大饼脸）
    ellipse(d, (214, 366, 298, 436), fill=DRESS, outline=INK, width=5)
    # 小手
    ellipse(d, (186, 388, 222, 424), fill=SKIN, outline=INK, width=4)
    ellipse(d, (290, 388, 326, 424), fill=SKIN, outline=INK, width=4)
    # 飘散的星星
    for cx, cy, r in [(88, 150, 12), (420, 214, 10), (104, 340, 9), (404, 344, 11)]:
        star(d, cx, cy, r, (255, 236, 160, 220), outline=None)

    return downscale(img, "boss_3_bigfaceidol.png")


if __name__ == "__main__":
    boss_milk()
    boss_penguin()
    boss_phebe()
