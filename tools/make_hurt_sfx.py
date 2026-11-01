# -*- coding: utf-8 -*-
"""生成受击音效（原创合成撞击声，不含任何人声/歌词）。

用途：替换掉原先取自视频的受击音（那段可能包含「Deep Deep」人声）。
运行：python tools/make_hurt_sfx.py  ->  audio/sfx/hurt.wav
"""
import os
import sys
import wave

import numpy as np

SR = 44100


def main() -> int:
    rng = np.random.default_rng(3)
    dur = 0.34
    n = int(dur * SR)
    t = np.arange(n) / SR

    # 低频撞击：110Hz 快速下滑到 42Hz
    f = 110.0 * np.exp(-t * 26.0) + 42.0
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    thump = np.sin(ph) * np.exp(-t * 16.0)

    # 噪声碎裂（短促，模拟"啪/砰"）
    noise = rng.normal(0.0, 1.0, n)
    hp = np.diff(np.concatenate([[0.0], noise]))
    crack = hp * np.exp(-t * 55.0) * 0.55

    # 轻微金属感尾音
    ring = np.sin(2.0 * np.pi * 320.0 * t) * np.exp(-t * 40.0) * 0.12

    sig = thump * 0.9 + crack + ring
    peak = np.abs(sig).max()
    if peak > 0:
        sig = sig / peak * 0.9

    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root_dir, "audio", "sfx", "hurt.wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(sig, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("saved:", os.path.relpath(path, root_dir), "%.2fs" % dur)
    return 0


if __name__ == "__main__":
    sys.exit(main())
