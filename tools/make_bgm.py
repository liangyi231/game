# -*- coding: utf-8 -*-
"""生成一段偏“燃”的原创 funky/electro 循环（占位 BGM，非任何现有歌曲）。

与旧版相比：BPM 108→132、四踩底鼓 + 拍手、锯齿贝斯 + 侧链压缩感、
offbeat 和弦 stab、后半段 16 分琶音、末小节军鼓滚奏 + 上升噪声，
8 小节无缝循环（约 14.5 秒）。

侧链只作用于旋律/贝斯/和弦，不打鼓组，避免底鼓被压低。

运行：python tools/make_bgm.py
"""
import os
import sys
import wave

import numpy as np

SR = 44100
BPM = 132.0
BEAT = 60.0 / BPM
BAR = 4.0 * BEAT
BARS = 8
TOTAL = int(BARS * BAR * SR)

rng = np.random.default_rng(11)


def env(n: int, attack: float = 0.002, decay: float = 0.2) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack) if attack > 0 else 1.0
    return np.exp(-t / decay) * a


def kick() -> np.ndarray:
    n = int(0.24 * SR)
    t = np.arange(n) / SR
    f = 150.0 * np.exp(-t * 34.0) + 44.0
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.25 * np.sin(2.0 * ph)) * np.exp(-t * 13.0) * 0.95


def clap() -> np.ndarray:
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0.0, 1.0, n)
    hp = np.diff(np.concatenate([[0.0], noise]))
    body = 0.22 * np.sin(2.0 * np.pi * 210.0 * t)
    return (hp * 0.8 + body) * np.exp(-t * 22.0) * 0.30


def hat(open_hat: bool = False) -> np.ndarray:
    n = int((0.07 if not open_hat else 0.18) * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0.0, 1.0, n)
    hp = np.diff(np.concatenate([[0.0], noise]))
    return hp * np.exp(-t * (110.0 if not open_hat else 24.0)) * 0.07


def saw_voice(freq: float, dur: float, harmonics: int = 7, gain: float = 1.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for k in range(1, harmonics + 1):
        sig += np.sin(2.0 * np.pi * freq * k * t) / k
    return sig * env(n, 0.004, dur * 0.55) * gain


def chord(root: float, intervals, dur: float, gain: float = 1.0) -> np.ndarray:
    n = int(dur * SR)
    out = np.zeros(n)
    for semi in intervals:
        out += saw_voice(root * (2.0 ** (semi / 12.0)), dur, 5, 1.0)
    out /= max(1, len(intervals))
    return out * gain


def main() -> int:
    drums = np.zeros(TOTAL, dtype=np.float64)
    music = np.zeros(TOTAL, dtype=np.float64)

    def add(buf: np.ndarray, sig: np.ndarray, t: float, gain: float = 1.0) -> None:
        i = int(t * SR)
        if i >= TOTAL:
            return
        n = min(len(sig), TOTAL - i)
        buf[i:i + n] += sig[:n] * gain

    # A 小调：Am - Am - F - F - C - C - G - G
    roots = [55.00, 55.00, 43.65, 43.65, 65.41, 65.41, 49.00, 49.00]
    chords = [
        [0, 3, 7], [0, 3, 7], [0, 4, 7], [0, 4, 7],
        [0, 4, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7],
    ]

    # 1) 鼓组：四踩 + 奇数小节切分底鼓 + 2/4 拍手 + 16 分 hi-hat
    for bar in range(BARS):
        b0 = bar * BAR
        for beat in (0.0, 1.0, 2.0, 3.0):
            add(drums, kick(), b0 + beat * BEAT, 1.0)
        if bar % 2 == 1:
            add(drums, kick(), b0 + 2.75 * BEAT, 0.7)
            add(drums, kick(), b0 + 3.5 * BEAT, 0.6)
        for beat in (1.0, 3.0):
            add(drums, clap(), b0 + beat * BEAT, 1.0)
        for step in range(16):
            g = 1.0 if step % 4 == 0 else (0.55 if step % 2 == 0 else 0.3)
            add(drums, hat(step % 8 == 6), b0 + step * BEAT / 4.0, g)
        if bar == BARS - 1:  # 末小节军鼓滚奏
            for step in range(8):
                add(drums, clap(), b0 + 2.0 * BEAT + step * BEAT / 8.0, 0.35 + 0.05 * step)

    # 2) 侧链包络：只在底鼓处压低旋律层
    duck = np.ones(TOTAL, dtype=np.float64)
    for bar in range(BARS):
        b0 = bar * BAR
        for beat in (0.0, 1.0, 2.0, 3.0):
            i = int((b0 + beat * BEAT) * SR)
            n = min(int(0.20 * SR), TOTAL - i)
            if n > 0:
                t = np.arange(n) / SR
                duck[i:i + n] = np.minimum(duck[i:i + n], 1.0 - 0.55 * np.exp(-t * 16.0))

    # 3) 贝斯：锯齿 + 8 分推动型 riff
    bass_notes = [0, 0, 12, 0, 7, 0, 3, 12]
    for bar in range(BARS):
        b0 = bar * BAR
        root = roots[bar]
        for k, semi in enumerate(bass_notes):
            f = root * (2.0 ** (semi / 12.0))
            add(music, saw_voice(f, BEAT * 0.42, 6, 0.55), b0 + k * BEAT / 2.0, 1.0)

    # 4) 和弦 stab：反拍短促
    for bar in range(BARS):
        b0 = bar * BAR
        root = roots[bar] * 2.0
        for beat in (0.5, 1.5, 2.5, 3.5):
            add(music, chord(root, chords[bar], BEAT * 0.28, 0.22), b0 + beat * BEAT, 1.0)

    # 5) 后半段 16 分琶音，把能量推上去
    for bar in range(4, BARS):
        b0 = bar * BAR
        root = roots[bar] * 4.0
        tones = chords[bar] + [12]
        for step in range(16):
            semi = tones[step % len(tones)]
            f = root * (2.0 ** (semi / 12.0))
            add(music, saw_voice(f, BEAT * 0.16, 4, 0.18), b0 + step * BEAT / 4.0, 1.0)

    # 6) 末段上升噪声（循环回首时像"再来一遍"的推进）
    n = int(BAR * SR)
    sweep = rng.normal(0.0, 1.0, n) * np.linspace(0.0, 0.22, n) ** 2
    add(music, sweep, (BARS - 1) * BAR, 1.0)

    # 混合：鼓组不被侧链压低
    out = drums + music * duck
    peak = np.abs(out).max()
    if peak > 0:
        out = out / peak * 0.9
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
