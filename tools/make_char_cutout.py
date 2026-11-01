# -*- coding: utf-8 -*-
"""把白底角色参考图抠成透明 PNG，供 Godot 当主角立绘使用。

做法：从四角 flood fill 去掉背景 -> 二值化 alpha -> 1px 腐蚀消除白边 -> 按内容裁剪。
运行：python tools/make_char_cutout.py
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "characters", "main_char_ref.jpg")
DST = os.path.join(ROOT, "art", "characters", "whale_girl.png")

MARKER = (255, 0, 255)
FLOOD_THRESH = 20


def main() -> int:
    if not os.path.exists(SRC):
        print("missing source:", SRC)
        return 1
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    # 从四角灌入标记色，吃掉白色背景
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(im, seed, MARKER, thresh=FLOOD_THRESH)

    arr = np.array(im)
    bg = (
        (arr[:, :, 0] == MARKER[0])
        & (arr[:, :, 1] == MARKER[1])
        & (arr[:, :, 2] == MARKER[2])
    )
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # 1px 腐蚀：去掉抗锯齿留下的白边
    p = np.pad(alpha, 1, mode="constant", constant_values=0)
    neighbours = np.minimum.reduce(
        [p[0:-2, 1:-1], p[2:, 1:-1], p[1:-1, 0:-2], p[1:-1, 2:]]
    )
    alpha = np.where(
        (alpha == 255) & (neighbours == 255), 255, alpha
    ).astype(np.uint8)
    alpha[bg] = 0

    rgba = np.dstack([arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], alpha])
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0:
        print("empty cutout")
        return 2
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    out = Image.fromarray(rgba, mode="RGBA").crop(box)
    out.save(DST, "PNG")
    print("saved:", DST, out.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
