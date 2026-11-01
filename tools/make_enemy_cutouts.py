# -*- coding: utf-8 -*-
"""把奶龙的两张棚拍图抠成透明 PNG（站立 / 抬手）。

背景是灰白渐变棚拍（含地面柔影），不是纯白，泛洪会被阴影边缘的零散像素切断。
因此改用颜色判据：奶龙本体是黄色/深色（高饱和或低亮度），背景是中性灰白。
  前景 = 饱和度足够高 或 足够暗
再做闭运算补掉高光小孔，最后腐蚀 1px 去 JPEG 灰边。

两张图共用同一张画布输出（同机位对齐），切换姿势时角色不会跳。
运行：python tools/make_enemy_cutouts.py
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOBS = [
    ("art/enemies/nailong_src_a.jpg", "art/enemies/nailong_idle.png"),
    ("art/enemies/nailong_src_b.jpg", "art/enemies/nailong_action.png"),
]

CHROMA_MIN = 30   # 通道最大差：黄/棕/绿都远高于它
LUM_DARK = 110    # 低于该亮度算本体（深色手脚、描边；A 图地面 188+，B 图地面 139+，都高于它）
CLOSE_PX = 3      # 闭运算半径：补高光小孔
ERODE_PX = 1      # 边缘腐蚀：去 JPEG 灰边


def _dilate(mask: np.ndarray, rounds: int) -> np.ndarray:
    for _ in range(rounds):
        p = np.pad(mask, 1, mode="constant", constant_values=False)
        mask = (
            p[1:-1, 1:-1] | p[0:-2, 1:-1] | p[2:, 1:-1]
            | p[1:-1, 0:-2] | p[1:-1, 2:]
        )
    return mask


def _erode(mask: np.ndarray, rounds: int) -> np.ndarray:
    for _ in range(rounds):
        p = np.pad(mask, 1, mode="constant", constant_values=False)
        mask = (
            p[1:-1, 1:-1] & p[0:-2, 1:-1] & p[2:, 1:-1]
            & p[1:-1, 0:-2] & p[1:-1, 2:]
        )
    return mask


def cutout_rgba(src: str) -> Image.Image:
    im = Image.open(src).convert("RGB")
    arr = np.array(im).astype(np.int32)
    mx = arr.max(axis=2)
    mn = arr.min(axis=2)
    lum = (arr[:, :, 0] * 299 + arr[:, :, 1] * 587 + arr[:, :, 2] * 114) // 1000

    fg = ((mx - mn) >= CHROMA_MIN) | (lum <= LUM_DARK)
    fg = _dilate(fg, CLOSE_PX)       # 闭运算：先膨胀
    fg = _erode(fg, CLOSE_PX)        # 再腐蚀，补掉内部小孔
    fg = _erode(fg, ERODE_PX)        # 最后再收 1px

    alpha = np.where(fg, 255, 0).astype(np.uint8)
    rgba = np.dstack([arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], alpha]).astype(np.uint8)
    return Image.fromarray(rgba, mode="RGBA")


def main() -> int:
    paths = [(os.path.join(ROOT, s), os.path.join(ROOT, d)) for s, d in JOBS]
    missing = [p for p, _ in paths if not os.path.exists(p)]
    if missing:
        print("missing:", missing)
        return 1

    layers = [cutout_rgba(p) for p, _ in paths]
    canvas_w = max(im.size[0] for im in layers)
    canvas_h = max(im.size[1] for im in layers)
    for im, (_, dst) in zip(layers, paths):
        canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        canvas.alpha_composite(im, (0, 0))
        canvas.save(dst, "PNG")
        print("saved:", os.path.relpath(dst, ROOT), canvas.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
