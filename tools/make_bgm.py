# -*- coding: utf-8 -*-
"""生成一段原创的巴西 funk 风格循环（占位 BGM，非任何现有歌曲）。

用途：在拿到合法音源之前，让游戏有背景音乐；拿到后覆盖 audio/music/bgm.ogg 即可。
运行：python tools/make_bgm.py
"""
import os
import sys
import wave

import numpy as np

SR = 44100
BPM = 108
BEAT = 60.0 / BPM
BARS = 4
TOTAL = int(BARS * 4 * BEAT * SR)

rng = np.random.default_rng(7)


def env(n: int, attack: float = 0.003, decay: float = 0.2) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack) if attack > 0 else 1.0
    return np.exp(-t / decay) * a


def kick() -> np.ndarray:
    n = int(0.20 * SR)
    t = np.arange(n) / SR
    f = 118.0 * np.exp(-t * 32.0) + 46.0
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 17.0) * 0.95


def snare() -> np.ndarray:
    n = int(0.17 * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0.0, 1.0, n)
    hp = np.diff(np.concatenate([[0.0], noise]))
    body = 0.25 * np.sin(2.0 * np.pi * 185.0 * t)
    return (hp * 0.9 + body) * np.exp(-t * 26.0) * 0.32


def hat(open_hat: bool = False) -> np.ndarray:
    n = int((0.09 if not open_hat else 0.20) * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0.0, 1.0, n)
    hp = np.diff(np.concatenate([[0.0], noise]))
    return hp * np.exp(-t * (95.0 if not open_hat else 26.0)) * 0.10


def bass(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = (
        np.sin(2.0 * np.pi * freq * t)
        + 0.45 * np.sin(4.0 * np.pi * freq * t)
        + 0.20 * np.sin(6.0 * np.pi * freq * t)
    )
    return sig * env(n, 0.004, 0.16) * 0.42


def main() -> int:
    out = np.zeros(TOTAL, dtype=np.float64)

    def add(sig: np.ndarray, t: float, gain: float = 1.0) -> None:
        i = int(t * SR)
        if i >= TOTAL:
            return
        n = min(len(sig), TOTAL - i)
        out[i:i + n] += sig[:n] * gain

    roots = [55.00, 55.00, 73.42, 55.00]     # A1 A1 D2 A1
    riff = [0, 0, 7, 0, 3, 0, 10, 7]          # 半音偏移（8 分音符）

    for bar in range(BARS):
        b0 = bar * 4 * BEAT
        for beat in (0.0, 1.75, 2.5, 3.25):
            add(kick(), b0 + beat * BEAT, 1.0)
        for beat in (1.0, 3.0):
            add(snare(), b0 + beat * BEAT, 1.0)
        step = 0
        t = 0.0
        while t < 4 * BEAT - 1e-6:
            add(hat(step % 4 == 2), b0 + t, 0.8 if step % 2 else 1.0)
            t += BEAT / 2
            step += 1
        root = roots[bar % len(roots)]
        for k, off in enumerate(riff):
            add(bass(root * (2.0 ** (off / 12.0)), BEAT * 0.45), b0 + k * (BEAT / 2), 1.0)

    # 归一化 + 首尾短淡入淡出，避免循环点爆音
    peak = np.abs(out).max()
    if peak > 0:
        out = out / peak * 0.82
    fade = int(0.02 * SR)
    out[:fade] *= np.linspace(0.0, 1.0, fade)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)

    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root_dir, "audio", "music")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "bgm.wav")
    pcm = (np.clip(out, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("saved:", os.path.relpath(path, root_dir), "%.2fs" % (TOTAL / SR))
    return 0


if __name__ == "__main__":
    sys.exit(main())
