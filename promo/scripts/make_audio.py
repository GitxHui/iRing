"""Procedurally synthesise every sound in the iRing promo (no third-party samples).

Usage: python3 scripts/make_audio.py <out_dir> <total_seconds>

Writes one-shot SFX (sfx_*.wav) and the music bed (music.wav). The music's bar
grid is anchored so that the logo impact (MUSIC_IMPACT) lands on a downbeat.
"""

import sys
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, fftconvolve

SR = 48000
RNG = np.random.default_rng(7)

OUT = sys.argv[1] if len(sys.argv) > 1 else "public/audio"
TOTAL = float(sys.argv[2]) if len(sys.argv) > 2 else 35.0
os.makedirs(OUT, exist_ok=True)

BPM = 120
BEAT = 60 / BPM
BAR = BEAT * 4
GRID0 = 0.75  # first downbeat (s); impact at 4.75 = GRID0 + 2 bars
MUSIC_IMPACT = 4.75
GROOVE_IN = 6.75
LIFT_IN = 26.75
FINAL = 29.75
BUTTON = 32.75


# ----------------------------------------------------------------- helpers
def tt(dur):
    return np.arange(int(dur * SR)) / SR


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def sos(kind, f, order=2):
    nyq = SR / 2
    if kind == "bp":
        return butter(order, [max(20, f[0]) / nyq, min(f[1], nyq * 0.98) / nyq], btype="band", output="sos")
    return butter(order, min(f, nyq * 0.98) / nyq, btype=kind, output="sos")


def filt(x, kind, f, order=2):
    return sosfilt(sos(kind, f, order), x)


def sweep_filter(x, kind, f0, f1, steps=48, width=0.6):
    """Time-varying filter by block crossfading (cheap but smooth enough)."""
    n = len(x)
    out = np.zeros(n)
    edges = np.linspace(0, n, steps + 1).astype(int)
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        p = i / max(1, steps - 1)
        f = f0 * (f1 / f0) ** p
        if kind == "bp":
            y = filt(x, "bp", (f * (1 - width / 2), f * (1 + width / 2)))
        else:
            y = filt(x, kind, f)
        out[a:b] = y[a:b]
    return out


def noise(n):
    return RNG.standard_normal(n)


def stereo(x, pan=0.0):
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    return np.stack([x * l * 1.4142, x * r * 1.4142], axis=1)


def make_ir(seconds, damp=6000, pre=0.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 6.9 / seconds)
    chans = []
    for _ in range(2):
        c = filt(noise(n), "lp", damp) * env
        if pre > 0:
            c = np.concatenate([np.zeros(int(pre * SR)), c])
        chans.append(c / np.sqrt(np.sum(c**2)))
    return np.stack(chans, axis=1)


IR_SHORT = make_ir(0.6, 7000)
IR_MED = make_ir(1.6, 6500, 0.012)
IR_LONG = make_ir(3.2, 5000, 0.02)


def reverb(x, ir, wet=0.25):
    if x.ndim == 1:
        x = stereo(x)
    pad = np.zeros((len(ir), 2))
    xx = np.concatenate([x, pad])
    w = np.stack([fftconvolve(xx[:, c], ir[:, c])[: len(xx)] for c in range(2)], axis=1)
    return xx * (1 - wet * 0.5) + w * wet


def bell(f, dur, decay=1.2, ratios=(1, 2.0, 2.76, 4.07, 5.4), amps=(1, 0.5, 0.32, 0.18, 0.1)):
    t = tt(dur)
    y = np.zeros_like(t)
    for k, (r, a) in enumerate(zip(ratios, amps)):
        y += a * np.sin(2 * np.pi * f * r * t + k) * np.exp(-t * (1 / decay) * (1 + k * 1.6))
    att = np.minimum(1, t / 0.002)
    return y * att


def pluck(f, dur, bright=1.0):
    t = tt(dur)
    y = np.zeros_like(t)
    for k in range(1, 9):
        y += (1 / k) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (2.5 + k * 5 / bright))
    return y * np.minimum(1, t / 0.003)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x * (peak / m)


def fade(x, fin=0.002, fout=0.02):
    n = len(x)
    a = np.ones(n)
    i = int(fin * SR)
    o = int(fout * SR)
    if i:
        a[:i] = np.linspace(0, 1, i)
    if o:
        a[-o:] = np.linspace(1, 0, o)
    return x * (a[:, None] if x.ndim == 2 else a)


def write(name, x, peak=0.9):
    if x.ndim == 1:
        x = stereo(x)
    x = fade(norm(x, peak))
    wavfile.write(os.path.join(OUT, name), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


def place(buf, x, at, gain=1.0):
    if x.ndim == 1:
        x = stereo(x)
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i] * gain


# ----------------------------------------------------------------- SFX
def sfx_key_down():
    t = tt(0.22)
    f = 95 + 90 * np.exp(-t * 60)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 32)
    click = filt(noise(len(t)), "hp", 2500) * np.exp(-t * 400) * 0.5
    thock = filt(noise(len(t)), "bp", (500, 1500)) * np.exp(-t * 70) * 0.35
    return reverb(body + click + thock, IR_SHORT, 0.12)


def sfx_key_up():
    t = tt(0.12)
    body = np.sin(2 * np.pi * 240 * t) * np.exp(-t * 60) * 0.5
    click = filt(noise(len(t)), "hp", 3500) * np.exp(-t * 500) * 0.6
    return reverb(body + click, IR_SHORT, 0.1)


def sfx_ring_open():
    t = tt(1.6)
    n = len(t)
    whoosh = sweep_filter(noise(n), "bp", 500, 7000, width=0.9) * np.exp(-((t - 0.12) ** 2) / 0.006) * 0.35
    air = filt(noise(n), "bp", (4000, 10000)) * np.minimum(1, t / 0.08) * np.exp(-t * 4) * 0.12
    b1 = bell(mtof(81), 1.6, 0.7) * 0.5  # A5
    b2 = np.concatenate([np.zeros(int(0.045 * SR)), bell(mtof(86), 1.6, 0.6)])[:n] * 0.35  # D6
    b3 = np.concatenate([np.zeros(int(0.09 * SR)), bell(mtof(90), 1.6, 0.5)])[:n] * 0.22  # F#6
    sub = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 14) * 0.25
    return reverb(whoosh + air + b1 + b2 + b3 + sub, IR_MED, 0.38)


def sfx_ring_close():
    t = tt(0.35)
    n = len(t)
    sw = sweep_filter(noise(n), "bp", 6000, 700, width=0.8) * np.exp(-t * 14) * 0.6
    f = 340 - 160 * np.minimum(1, t / 0.12)
    blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 22) * 0.35
    return reverb(sw + blip, IR_SHORT, 0.2)


def sfx_tick(f=2400):
    t = tt(0.08)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 160) + filt(noise(len(t)), "hp", 5000) * np.exp(-t * 600) * 0.4
    return reverb(y, IR_SHORT, 0.15)


def sfx_select():
    n = int(1.4 * SR)
    y = np.zeros(n)
    for k, (m, d) in enumerate([(86, 0.0), (93, 0.07)]):
        b = bell(mtof(m), 1.4 - d, 0.55)
        i = int(d * SR)
        y[i : i + len(b)] += b * (0.6 if k == 0 else 0.45)
    t = tt(1.4)
    y += np.sin(2 * np.pi * 147 * t) * np.exp(-t * 10) * 0.25
    return reverb(y, IR_MED, 0.35)


def sfx_whoosh(dur=0.6, f0=350, f1=4200, bright=1.0):
    t = tt(dur)
    n = len(t)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    x = sweep_filter(noise(n), "bp", f0, f1, width=0.9) * env
    x = filt(x, "hp", 150)
    pan = np.linspace(-0.6, 0.6, n)
    st = np.stack([x * np.cos((pan + 1) * np.pi / 4), x * np.sin((pan + 1) * np.pi / 4)], axis=1) * 1.41
    return reverb(st * bright, IR_SHORT, 0.2)


def sfx_snap():
    t = tt(0.5)
    f = 55 + 60 * np.exp(-t * 40)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 16)
    click = filt(noise(len(t)), "bp", (1800, 5000)) * np.exp(-t * 300) * 0.45
    tone = np.sin(2 * np.pi * mtof(74) * t) * np.exp(-t * 30) * 0.15
    return reverb(thud + click + tone, IR_SHORT, 0.18)


def sfx_scroll_tick():
    t = tt(0.04)
    return np.sin(2 * np.pi * 3200 * t) * np.exp(-t * 300) + filt(noise(len(t)), "hp", 6000) * np.exp(-t * 900) * 0.3


def sfx_pop():
    t = tt(0.3)
    f = 380 + 700 * (1 - np.exp(-t * 45))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 26)
    y += filt(noise(len(t)), "hp", 4000) * np.exp(-t * 700) * 0.2
    return reverb(y, IR_SHORT, 0.22)


def sfx_riser(dur=1.6):
    t = tt(dur)
    n = len(t)
    p = t / dur
    nz = sweep_filter(noise(n), "bp", 250, 9000, steps=64, width=0.7) * (p**2.2)
    f = 180 * (2 ** (p * 2.2))
    tone = sum(np.sin(2 * np.pi * np.cumsum(f * r) / SR) / r for r in (1, 2, 3)) * (p**3) * 0.18
    y = nz * 0.8 + tone
    y[-int(0.004 * SR) :] *= np.linspace(1, 0, int(0.004 * SR))
    return stereo(y) + np.stack([np.zeros(n), np.roll(y, 240) * 0.0], axis=1)


def sfx_impact():
    t = tt(3.6)
    n = len(t)
    f = 34 + 50 * np.exp(-t * 9)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    boom = np.tanh(boom * 1.6)
    crack = filt(noise(n), "lp", 2400) * np.exp(-t * 18) * 0.5
    sh = np.zeros(n)
    for m in (74, 78, 81, 85, 88, 93):  # Dmaj9 sparkle
        b = bell(mtof(m), 3.6, 1.1)
        sh += b * 0.16
    y = boom * 0.9 + crack + sh
    return reverb(y, IR_LONG, 0.42)


def sfx_shimmer(dur=1.4, density=55):
    n = int(dur * SR)
    y = np.zeros(n)
    k = int(density * dur)
    for i in range(k):
        at = RNG.uniform(0, dur * 0.8)
        f = RNG.uniform(3500, 9500)
        d = 0.05
        g = np.sin(2 * np.pi * f * tt(d)) * np.hanning(int(d * SR)) * (1 - at / dur)
        j = int(at * SR)
        y[j : j + len(g)] += g[: n - j] * RNG.uniform(0.2, 0.6)
    return reverb(y, IR_MED, 0.5)


def sfx_click():
    n = int(0.25 * SR)
    y = np.zeros(n)
    for at, g in ((0.0, 1.0), (0.075, 0.6)):
        t = tt(0.03)
        c = filt(noise(len(t)), "bp", (1500, 6000)) * np.exp(-t * 500) + np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 400) * 0.5
        j = int(at * SR)
        y[j : j + len(c)] += c * g
    return reverb(y, IR_SHORT, 0.1)


def sfx_tile(m):
    t = tt(0.9)
    f = mtof(m)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 7) + 0.35 * np.sin(2 * np.pi * f * 3.9 * t) * np.exp(-t * 30)
    y += np.sin(2 * np.pi * f / 2 * t) * np.exp(-t * 12) * 0.3
    y *= np.minimum(1, t / 0.002)
    w = sfx_whoosh(0.25, 1200, 5000, 0.25)
    out = reverb(y, IR_MED, 0.3)
    out[: len(w)] += w[: len(out)]
    return out


def sfx_window_in(v):
    t = tt(0.4)
    f = 70 + 40 * np.exp(-t * 30) + v * 8
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 22)
    sw = filt(noise(len(t)), "bp", (800 + v * 200, 3000 + v * 300)) * np.exp(-t * 25) * 0.35
    return reverb(thud + sw, IR_SHORT, 0.15)


# ----------------------------------------------------------------- music
CHORDS = [  # (bass midi, pad voicing)
    (50, [62, 66, 69, 73, 76]),  # Dmaj9
    (47, [62, 66, 69, 73, 74]),  # Bm9
    (43, [59, 62, 66, 69, 71]),  # Gmaj9
    (45, [61, 64, 66, 69, 71]),  # A6
]


def chord_at(time):
    k = int(np.floor((time - GRID0) / BAR)) % 4
    return CHORDS[k]


def supersaw(f, dur, detune=0.12):
    t = tt(dur)
    y = np.zeros_like(t)
    for d in np.linspace(-detune, detune, 5):
        ff = f * 2 ** (d / 12)
        ph = (ff * t + RNG.uniform()) % 1.0
        y += 2 * ph - 1
    return y / 5


def music():
    n = int((TOTAL + 2.5) * SR)
    t_all = np.arange(n) / SR
    pad = np.zeros(n)
    bass = np.zeros(n)
    arp = np.zeros((n, 2))
    drums = np.zeros((n, 2))
    kicks = []

    nbars = int(np.ceil((TOTAL + 2) / BAR)) + 1
    for b in range(-1, nbars):
        start = GRID0 + b * BAR
        if start + BAR < 0 or start > TOTAL + 1:
            continue
        root, voicing = chord_at(start + 0.01)
        # pad: one sustained chord per bar
        dur = BAR + 0.6
        ch = sum(supersaw(mtof(m), dur) for m in voicing) / len(voicing)
        env = np.minimum(1, tt(dur) / 0.35) * np.minimum(1, (dur - tt(dur)) / 0.6)
        i0 = int(max(0, start) * SR)
        seg = (ch * env)[int(max(0, -start) * SR) :]
        j = min(n, i0 + len(seg))
        pad[i0:j] += seg[: j - i0]
        if start >= MUSIC_IMPACT - 0.01 and start < FINAL:
            # bass: 8th-note pulse
            for e in range(8):
                at = start + e * BEAT / 2
                d = BEAT / 2
                tb = tt(d)
                f = mtof(root)
                note = (np.sin(2 * np.pi * f * tb) + 0.25 * np.sin(2 * np.pi * 2 * f * tb)) * np.exp(-tb * 5) * np.minimum(1, tb / 0.004)
                note *= np.minimum(1, (d - tb) / 0.01)
                place_mono(bass, np.tanh(note * 1.5), at, 1.0 if e % 2 == 0 else 0.7)
            # arp: 8ths, chord tones up an octave
            pattern = [0, 2, 4, 1, 3, 2, 4, 3]
            octv = 24 if start >= LIFT_IN else 12
            for e in range(8):
                at = start + e * BEAT / 2
                m = voicing[pattern[e] % len(voicing)] + octv - 12
                p = pluck(mtof(m), 0.6, 1.4 if start >= LIFT_IN else 1.0) * 0.5
                place(arp, stereo(p, -0.35 if e % 2 else 0.35), at, 0.9)
        if GROOVE_IN - 0.01 <= start < FINAL:
            for e in range(4):
                at = start + e * BEAT
                kicks.append(at)
                place(drums, stereo(kick(), 0), at, 1.0)
                if e in (1, 3):
                    place(drums, clap(), at, 0.55)
                for h in range(2 if start < LIFT_IN else 4):
                    if start < LIFT_IN and h == 0:
                        continue
                    hat_at = at + h * BEAT / (2 if start < LIFT_IN else 4)
                    place(drums, stereo(hat(), 0.25 if h % 2 else -0.15), hat_at, 0.32 if h % 2 else 0.2)
        elif start < MUSIC_IMPACT - 0.01:
            # intro: ticking 16th hats rising + soft heartbeat kick
            for e in range(16):
                at = start + e * BEAT / 4
                if at < 0:
                    continue
                g = 0.05 + 0.25 * min(1, max(0, at / MUSIC_IMPACT)) ** 2
                place(drums, stereo(hat(), 0.3 if e % 2 else -0.3), at, g * (1 if e % 4 == 2 else 0.55))
            for e in (0, 2):
                at = start + e * BEAT
                if at >= 0:
                    place(drums, stereo(kick() * 0.6, 0), at, 0.5)

    # pad filter automation: closed intro -> open after impact -> close at the end
    cutoff = np.interp(
        t_all,
        [0, MUSIC_IMPACT - 0.05, MUSIC_IMPACT, GROOVE_IN, LIFT_IN, FINAL, TOTAL, TOTAL + 2.5],
        [300, 1600, 2600, 3200, 4800, 3600, 900, 400],
    )
    pad = time_varying_lp(pad, cutoff)
    pad_st = stereo(pad, 0) + np.stack([np.roll(pad, 380) * 0.0, np.roll(pad, 380) * 0.0], axis=1)
    # stereo widen pad with short delay
    pad_st[:, 1] = 0.75 * pad_st[:, 1] + 0.25 * np.roll(pad_st[:, 0], int(0.011 * SR))

    # sidechain from kicks
    sc = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.35 * SR))
        if m > 0:
            sc[i : i + m] *= 1 - 0.55 * np.exp(-np.arange(m) / SR / 0.11)
    pad_st *= sc[:, None]
    bass_st = stereo(filt(bass, "lp", 900), 0) * sc[:, None]

    # dotted-8th ping-pong delay on arp
    d = int(BEAT * 0.75 * SR)
    wet = np.zeros_like(arp)
    fb = arp.copy()
    for k in range(1, 5):
        sh = np.zeros_like(arp)
        sh[d * k :] = fb[: n - d * k][:, ::-1] if k % 2 else fb[: n - d * k]
        wet += sh * (0.38**k)
    arp = arp + filt_st(wet, "lp", 5000)

    mix = pad_st * 0.42 + bass_st * 0.55 + arp * 0.32 + drums * 0.75
    mix = reverb(mix, IR_MED, 0.18)[:n]

    # final sustain: big chord + low D at FINAL
    tail = sum(supersaw(mtof(m), 4.5, 0.18) for m in (50, 62, 66, 69, 73, 76, 81)) / 7
    tail = time_varying_lp(tail, np.interp(tt(4.5), [0, 0.5, 4.5], [5000, 2600, 600])) * np.exp(-tt(4.5) * 0.45)
    place(mix, reverb(tail * 0.6, IR_LONG, 0.35), FINAL, 0.6)

    # master fades
    g = np.interp(t_all, [0, 0.3, TOTAL - 1.6, TOTAL], [0.0, 1.0, 1.0, 0.0])
    mix *= g[:, None]
    mix = np.tanh(mix * 1.1) / 1.1
    return mix[: int(TOTAL * SR)]


def place_mono(buf, x, at, gain=1.0):
    i = int(at * SR)
    if i < 0 or i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i] * gain


def filt_st(x, kind, f):
    return np.stack([filt(x[:, 0], kind, f), filt(x[:, 1], kind, f)], axis=1)


def time_varying_lp(x, cutoff, block=2048):
    out = np.zeros_like(x)
    zi = None
    from scipy.signal import sosfilt_zi

    for a in range(0, len(x), block):
        b = min(len(x), a + block)
        s = sos("lp", float(np.mean(cutoff[a:b])), 2)
        if zi is None:
            zi = sosfilt_zi(s) * 0
        y, zi = sosfilt(s, x[a:b], zi=zi)
        out[a:b] = y
    return out


def kick():
    t = tt(0.45)
    f = 44 + 120 * np.exp(-t * 38)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    y += filt(noise(len(t)), "hp", 3000) * np.exp(-t * 700) * 0.15
    return np.tanh(y * 1.4) * 0.9


def clap():
    n = int(0.35 * SR)
    y = np.zeros(n)
    for k, d in enumerate((0, 0.009, 0.019)):
        t = tt(0.3)
        c = filt(noise(len(t)), "bp", (900, 2600)) * np.exp(-t * (60 if k < 2 else 18))
        j = int(d * SR)
        y[j : j + len(c)] += c[: n - j]
    return reverb(y * 0.6, IR_SHORT, 0.3)[:n]


def hat():
    t = tt(0.07)
    return filt(noise(len(t)), "hp", 7500) * np.exp(-t * 80) * 0.6


# ----------------------------------------------------------------- write
if __name__ == "__main__":
    write("sfx_key_down.wav", sfx_key_down(), 0.85)
    write("sfx_key_up.wav", sfx_key_up(), 0.6)
    write("sfx_ring_open.wav", sfx_ring_open(), 0.8)
    write("sfx_ring_close.wav", sfx_ring_close(), 0.6)
    write("sfx_tick.wav", sfx_tick(2400), 0.5)
    write("sfx_tick_hi.wav", sfx_tick(3000), 0.5)
    write("sfx_select.wav", sfx_select(), 0.75)
    write("sfx_whoosh.wav", sfx_whoosh(0.6), 0.75)
    write("sfx_whoosh_fast.wav", sfx_whoosh(0.32, 800, 6000), 0.7)
    write("sfx_snap.wav", sfx_snap(), 0.85)
    write("sfx_scroll_tick.wav", sfx_scroll_tick(), 0.35)
    write("sfx_pop.wav", sfx_pop(), 0.75)
    write("sfx_riser.wav", sfx_riser(1.6), 0.8)
    write("sfx_impact.wav", sfx_impact(), 0.95)
    write("sfx_shimmer.wav", sfx_shimmer(), 0.5)
    write("sfx_click.wav", sfx_click(), 0.8)
    for i, m in enumerate((74, 78, 81, 86)):
        write(f"sfx_tile_{i}.wav", sfx_tile(m), 0.7)
    for v in range(3):
        write(f"sfx_window_{v}.wav", sfx_window_in(v), 0.7)
    m = music()
    write("music.wav", m, 0.7)
    print("done", OUT, f"{TOTAL:.2f}s")
