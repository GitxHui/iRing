"""Audio for the vertical (Xiaohongshu / Douyin) keynote cut — all procedurally synthesised.

Usage: python3 scripts/make_audio_vertical.py [out_dir]   (default: public/audio)

Writes the new SFX (sfx_slam, sfx_boom, sfx_glass_flip, sfx_swipe, sfx_drag_start,
sfx_dock_snap, sfx_chip_0..3, sfx_lightsweep) and music_vertical.wav (35.0 s, 120 BPM,
downbeats at 0, 2, 4 …). Section times mirror VSCENES in src/vertical/contract.ts.
Existing SFX from make_audio.py are left untouched.
"""

import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.ndimage import minimum_filter1d, uniform_filter1d
from scipy.signal import resample_poly

OUT = sys.argv[1] if len(sys.argv) > 1 else "public/audio"
sys.argv = [sys.argv[0], OUT]  # make_audio reads argv at import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_audio as ma  # noqa: E402

SR = ma.SR
tt, mtof, filt, noise, stereo, reverb, bell, pluck, place = (
    ma.tt, ma.mtof, ma.filt, ma.noise, ma.stereo, ma.reverb, ma.bell, ma.pluck, ma.place,
)
RNG = np.random.default_rng(23)

TOTAL = 36.0
BEAT = 0.5
BAR = 2.0

# Section map (absolute seconds) — keep in sync with VSCENES.
HOOK_END = 2.5
DROP = 4.0
GROOVE_IN = 5.5
LIFT = 15.5
ACCENT = 21.5
FILL_IN = 23.5
ISLAND = 24.5
FINAL = 31.0
FADE_END = 36.0


# ----------------------------------------------------------------- SFX
def sfx_slam():
    t = tt(0.9)
    n = len(t)
    f = 46 + 140 * np.exp(-t * 30)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
    crack = filt(noise(n), "bp", (900, 4200)) * np.exp(-t * 90) * 0.55
    click = filt(noise(n), "hp", 5000) * np.exp(-t * 600) * 0.35
    body = filt(noise(n), "lp", 500) * np.exp(-t * 25) * 0.35
    y = np.tanh((sub * 1.1 + crack + click + body) * 1.8)
    return reverb(y, ma.IR_SHORT, 0.16)


def sfx_boom():
    t = tt(2.4)
    n = len(t)
    f = 26 + 38 * np.exp(-t * 2.4)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6)
    rumble = filt(noise(n), "lp", 180) * np.exp(-t * 2.2) * 0.6
    hit = filt(noise(n), "lp", 1800) * np.exp(-t * 20) * 0.35
    y = np.tanh((sub + rumble + hit) * 1.3)
    return reverb(y, ma.IR_LONG, 0.3)


def sfx_glass_flip():
    t = tt(0.7)
    n = len(t)
    env = np.exp(-((t - 0.16) ** 2) / 0.004)
    sw = ma.sweep_filter(noise(n), "bp", 1800, 8500, steps=40, width=0.5) * env * 0.5
    y = sw.copy()
    for d, m in ((0.05, 88), (0.13, 95)):
        b = bell(mtof(m), 0.7 - d, 0.18)
        i = int(d * SR)
        y[i : i + len(b)] += b[: n - i] * 0.35
    pan = np.linspace(-0.7, 0.7, n)
    st = np.stack([y * np.cos((pan + 1) * np.pi / 4), y * np.sin((pan + 1) * np.pi / 4)], axis=1) * 1.41
    return reverb(st, ma.IR_MED, 0.3)


def sfx_swipe():
    return ma.sfx_whoosh(0.26, 900, 7000, 0.9)


def sfx_drag_start():
    t = tt(0.18)
    y = np.sin(2 * np.pi * 1250 * t) * np.exp(-t * 90) * 0.6
    y += np.sin(2 * np.pi * 210 * t) * np.exp(-t * 45) * 0.5
    y += filt(noise(len(t)), "bp", (2500, 6000)) * np.exp(-t * 400) * 0.25
    return reverb(y, ma.IR_SHORT, 0.12)


def sfx_dock_snap():
    t = tt(0.8)
    n = len(t)
    click = filt(noise(n), "bp", (2000, 7000)) * np.exp(-t * 500) * 0.6
    f = 50 + 70 * np.exp(-t * 45)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18)
    ring = np.zeros(n)
    b = bell(mtof(93), 0.75, 0.25) * 0.22
    i = int(0.012 * SR)
    ring[i : i + len(b)] += b[: n - i]
    return reverb(click + thud + ring, ma.IR_SHORT, 0.2)


def sfx_chip(m):
    t = tt(0.9)
    f = mtof(m)
    y = bell(f, 0.9, 0.32, ratios=(1, 2.0, 3.01, 4.2), amps=(1, 0.35, 0.18, 0.08)) * 0.8
    y += np.sin(2 * np.pi * f / 2 * t) * np.exp(-t * 14) * 0.25
    y += filt(noise(len(t)), "hp", 6000) * np.exp(-t * 300) * 0.12
    return reverb(y, ma.IR_MED, 0.32)


def sfx_lightsweep():
    t = tt(0.9)
    n = len(t)
    env = np.sin(np.pi * np.clip(t / 0.8, 0, 1)) ** 1.5
    sw = ma.sweep_filter(noise(n), "bp", 1000, 10000, steps=48, width=0.35) * env * 0.5
    grains = np.zeros(n)
    for _ in range(40):
        at = RNG.uniform(0.05, 0.75)
        fr = 2500 + at / 0.8 * 7000 + RNG.uniform(-500, 500)
        d = 0.04
        g = np.sin(2 * np.pi * fr * tt(d)) * np.hanning(int(d * SR))
        j = int(at * SR)
        grains[j : j + len(g)] += g[: n - j] * RNG.uniform(0.1, 0.3)
    return reverb(sw + grains, ma.IR_MED, 0.4)


# ----------------------------------------------------------------- music parts
CHORDS = [  # (bass midi, pad voicing) — D major colour
    (50, [62, 66, 69, 73, 76]),  # Dmaj9
    (47, [62, 66, 69, 73, 74]),  # Bm9
    (43, [59, 62, 66, 69, 71]),  # Gmaj9
    (45, [61, 64, 66, 69, 71]),  # A6
]


def chord_at(time):
    return CHORDS[int(np.floor(time / BAR)) % 4]


def soft_hat():
    """Shaped, band-limited hat — no harsh broadband fizz."""
    t = tt(0.06)
    x = filt(noise(len(t)), "bp", (5200, 10500), 2)
    x = filt(x, "lp", 11000)
    return x * np.exp(-t * 95) * 0.45


def kick():
    t = tt(0.42)
    f = 46 + 115 * np.exp(-t * 40)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
    y += filt(noise(len(t)), "bp", (2500, 6000)) * np.exp(-t * 650) * 0.1
    return np.tanh(y * 1.5) * 0.9


def clap():
    return ma.clap()


def stab(voicing, root, dur=0.18, cutoff=1400):
    ch = sum(ma.supersaw(mtof(m), dur + 0.25, 0.1) for m in voicing) / len(voicing)
    t = tt(dur + 0.25)
    env = np.minimum(1, t / 0.004) * np.exp(-t * (1 / dur) * 2.2)
    ch = filt(ch * env, "lp", cutoff)
    b = np.sin(2 * np.pi * mtof(root - 12) * t) * np.exp(-t * 9)
    return ch + b * 0.6


def bass_note(m, d, decay=5.0):
    t = tt(d)
    f = mtof(m)
    y = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)) * np.exp(-t * decay)
    y *= np.minimum(1, t / 0.004) * np.minimum(1, (d - t) / 0.012)
    return np.tanh(y * 1.5)


def riser(dur):
    t = tt(dur)
    n = len(t)
    p = t / dur
    nz = ma.sweep_filter(noise(n), "bp", 300, 7000, steps=56, width=0.6) * (p ** 2.4)
    nz = filt(nz, "lp", 9000)
    f = 220 * (2 ** (p * 2.0))
    tone = sum(np.sin(2 * np.pi * np.cumsum(f * r) / SR) / r for r in (1, 1.5, 2)) * (p ** 3) * 0.12
    return nz * 0.7 + tone


def reverse_swell(voicing, dur):
    ch = sum(ma.supersaw(mtof(m), dur, 0.15) for m in voicing) / len(voicing)
    ch = filt(ch, "lp", 2400) * np.exp(-tt(dur) * 2.5)
    w = reverb(ch, ma.IR_LONG, 0.8)[: len(ch)]
    return w[::-1]


def crash_wash(dur=3.0):
    t = tt(dur)
    x = filt(noise(len(t)), "bp", (3000, 9000))
    x = filt(x, "lp", 9000) * np.exp(-t * 1.6) * 0.35
    return reverb(x, ma.IR_LONG, 0.5)


def limiter(x, ceiling, look=0.004):
    L = max(2, int(look * SR))
    amp = np.max(np.abs(x), axis=1) + 1e-9
    g = np.minimum(1.0, ceiling / amp)
    g = minimum_filter1d(g, size=2 * L)
    g = uniform_filter1d(g, size=L)
    return x * g[:, None]


def true_peak_db(x):
    up = resample_poly(x, 4, 1, axis=0)
    return 20 * np.log10(np.max(np.abs(up)) + 1e-12)


def lufs(x):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    wavfile.write(path, SR, np.clip(x, -1, 1).astype(np.float32))
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
        capture_output=True,
        text=True,
    ).stderr
    os.unlink(path)
    for line in out.splitlines()[::-1]:
        line = line.strip()
        if line.startswith("I:"):
            return float(line.split()[1])
    raise RuntimeError("could not measure loudness")


# ----------------------------------------------------------------- music
def music():
    n = int((TOTAL + 1.0) * SR)
    t_all = np.arange(n) / SR
    pad = np.zeros(n)
    bass = np.zeros(n)
    arp = np.zeros((n, 2))
    drums = np.zeros((n, 2))
    fx = np.zeros((n, 2))
    kicks = []

    # ---- pad: one chord per bar from the drop onward; filtered swell before it
    for b in range(0, int(TOTAL / BAR) + 1):
        start = b * BAR
        root, voicing = chord_at(start + 0.01)
        if start < DROP:
            continue
        dur = BAR + 0.7
        if start >= FINAL:
            continue
        ch = sum(ma.supersaw(mtof(m), dur, 0.14) for m in voicing) / len(voicing)
        tb = tt(dur)
        env = np.minimum(1, tb / 0.25) * np.minimum(1, (dur - tb) / 0.7)
        ma.place_mono(pad, ch * env, start, 1.0)

    # suspense swell 2.5 -> 4.0 (A6 sus colour), plus reverse swell landing on the drop
    sw_dur = DROP - HOOK_END
    sus = sum(ma.supersaw(mtof(m), sw_dur, 0.18) for m in (57, 64, 69, 71, 76)) / 5
    st = tt(sw_dur)
    sus = ma.time_varying_lp(sus * (st / sw_dur) ** 1.6, np.interp(st, [0, sw_dur], [250, 1500]))
    sus[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))  # breath before the drop
    place(fx, stereo(sus, 0), HOOK_END, 0.55)
    rs = reverse_swell([62, 66, 69, 73, 76], 1.3)
    place(fx, rs, DROP - len(rs) / SR - 0.02, 0.35)

    # ---- hook 0 -> 2.5: sparse staccato stabs off the slam beats + riser
    for at, g in ((0.25, 0.5), (0.75, 0.55), (1.25, 0.6), (1.75, 0.45), (2.0, 0.4)):
        r, v = CHORDS[1]
        place(fx, stereo(stab(v, r + 12, 0.12, 1100), -0.2 if at % 0.5 else 0.2), at, g)
    for e in range(10):  # low ticking pulse
        at = e * 0.25
        place(drums, stereo(soft_hat(), 0.25 if e % 2 else -0.25), at, 0.12 + 0.02 * e)
    for at in (0.0, 0.5, 1.0):  # felt sub under the text slams (slam SFX carry the transient)
        ma.place_mono(bass, bass_note(38, 0.35, 9), at, 0.7)
    rz = riser(1.0)
    rz[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    place(fx, stereo(rz, 0), HOOK_END - 1.0, 0.6)

    # ---- DROP at 4.0: sub + full chord + wash
    boom = sfx_boom()
    place(fx, boom, DROP, 0.7)
    big = sum(ma.supersaw(mtof(m), 2.2, 0.2) for m in (50, 62, 66, 69, 73, 76, 81)) / 7
    big = ma.time_varying_lp(big, np.interp(tt(2.2), [0, 0.15, 2.2], [7000, 4200, 1800])) * np.exp(-tt(2.2) * 1.2)
    place(fx, reverb(big, ma.IR_LONG, 0.35), DROP, 0.55)
    place(fx, crash_wash(3.0), DROP, 0.6)

    # ---- arp + bass from the drop to the final hit
    pattern = [0, 2, 4, 1, 3, 2, 4, 3]
    step = 0.0
    while DROP + step < FINAL - 0.01:
        at = DROP + step
        root, voicing = chord_at(at + 0.01)
        e = int(round(step / (BEAT / 2))) % 8
        lifted = at >= LIFT and at < ISLAND
        octv = 24 if lifted else 12
        bright = 1.4 if lifted else 1.0
        m = voicing[pattern[e] % len(voicing)] + octv - 12
        p = pluck(mtof(m), 0.6, bright) * 0.5
        g = 0.75 if at < GROOVE_IN else 0.9
        if at >= ISLAND:
            g = 0.7
        place(arp, stereo(p, -0.4 if e % 2 else 0.4), at, g)
        if GROOVE_IN <= at < ISLAND:
            ma.place_mono(bass, bass_note(root, BEAT / 2), at, 1.0 if e % 2 == 0 else 0.7)
        step += BEAT / 2
    # sustained bass under the airy island section
    t0 = ISLAND
    while t0 < FINAL - 0.01:
        root, _ = chord_at(t0 + 0.01)
        d = min(BAR - (t0 % BAR), FINAL - t0)
        ma.place_mono(bass, bass_note(root, d, 1.2), t0, 0.75)
        t0 += d

    # ---- drums
    b = GROOVE_IN
    while b < ISLAND - 0.01:
        beat_idx = int(round(b / BEAT))
        kicks.append(b)
        place(drums, stereo(kick(), 0), b, 1.0)
        if beat_idx % 2 == 1:
            place(drums, clap(), b, 0.5)
        sub = 4 if b >= LIFT else 2
        for h in range(sub):
            if sub == 2 and h == 0:
                continue
            hat_at = b + h * BEAT / sub
            accent = 0.32 if (h % 2 == 1) else 0.18
            place(drums, stereo(soft_hat(), 0.3 if h % 2 else -0.2), hat_at, accent)
        b += BEAT
    # small accent where the resize scene starts
    r, v = chord_at(ACCENT + 0.01)
    place(fx, stereo(stab(v, r, 0.3, 4500), 0), ACCENT, 0.45)
    place(fx, crash_wash(1.6), ACCENT, 0.3)
    # fill into the island: clap roll + rising filter riser
    for k in range(8):
        at = FILL_IN + k * BEAT / 4
        place(drums, clap(), at, 0.18 + 0.05 * k)
    fz = riser(1.0)
    place(fx, stereo(fz, 0), ISLAND - 1.0, 0.35)
    place(fx, crash_wash(2.2), ISLAND, 0.4)
    # island: half-time (kick on 1, clap on 3), soft 8th hats
    b = ISLAND
    while b < FINAL - 0.01:
        rel = int(round((b - ISLAND) / BEAT))
        if rel % 4 == 0:
            kicks.append(b)
            place(drums, stereo(kick(), 0), b, 0.75)
        if rel % 4 == 2:
            place(drums, clap(), b, 0.4)
        place(drums, stereo(soft_hat(), 0.3), b + BEAT / 2, 0.22)
        b += BEAT
    rz2 = riser(1.0)
    rz2[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    place(fx, stereo(rz2, 0), FINAL - 1.0, 0.45)

    # ---- FINAL at 28.0: big chord + sub, then sustain and decay
    place(fx, sfx_boom(), FINAL, 1.0)
    place(drums, stereo(kick(), 0), FINAL, 1.0)
    r, v = CHORDS[0]
    place(fx, stereo(stab([62, 66, 69, 73, 76, 81], r, 0.5, 6000), 0), FINAL, 0.8)
    tail = sum(ma.supersaw(mtof(m), 5.0, 0.18) for m in (50, 62, 66, 69, 73, 76, 81)) / 7
    tail = ma.time_varying_lp(tail, np.interp(tt(5.0), [0, 0.3, 5.0], [6500, 3000, 500])) * np.exp(-tt(5.0) * 0.55)
    place(fx, reverb(tail, ma.IR_LONG, 0.4), FINAL, 0.85)
    place(fx, crash_wash(3.5), FINAL, 0.55)
    for k, m in enumerate((86, 90, 93, 98)):
        place(fx, reverb(bell(mtof(m), 2.5, 0.9), ma.IR_LONG, 0.5), FINAL + 0.12 * k, 0.12)

    # ---- pad automation + sidechain
    cutoff = np.interp(
        t_all,
        [0, DROP, DROP + 0.2, GROOVE_IN, LIFT, ISLAND - 0.01, ISLAND, FINAL],
        [400, 400, 5200, 3000, 4500, 4500, 5500, 5500],
    )
    pad = ma.time_varying_lp(pad, cutoff)
    pad_st = stereo(pad, 0)
    pad_st[:, 1] = 0.7 * pad_st[:, 1] + 0.3 * np.roll(pad_st[:, 0], int(0.013 * SR))
    pad_st[:, 0] = 0.85 * pad_st[:, 0] + 0.15 * np.roll(pad_st[:, 1], int(0.007 * SR))

    sc = np.ones(n)
    for k in kicks:
        i = int(k * SR)
        m = min(n - i, int(0.35 * SR))
        if m > 0:
            sc[i : i + m] *= 1 - 0.5 * np.exp(-np.arange(m) / SR / 0.11)
    pad_st *= sc[:, None]
    bass_st = stereo(filt(bass, "lp", 900), 0) * sc[:, None]

    # dotted-8th ping-pong on arp
    d = int(BEAT * 0.75 * SR)
    wet = np.zeros_like(arp)
    for k in range(1, 5):
        sh = np.zeros_like(arp)
        src = arp[: n - d * k]
        sh[d * k :] = src[:, ::-1] if k % 2 else src
        wet += sh * (0.36 ** k)
    arp = arp + ma.filt_st(wet, "lp", 4800)
    arp = ma.filt_st(arp, "hp", 180)

    mix = pad_st * 0.38 + bass_st * 0.6 + arp * 0.3 + drums * 0.72 + fx * 0.9
    mix = reverb(mix, ma.IR_MED, 0.15)[:n]

    # short breaths right before the two big hits make them land harder
    for hit in (DROP, FINAL):
        gap = np.interp(t_all, [hit - 0.14, hit - 0.08, hit - 0.004, hit], [1, 0.12, 0.12, 1])
        mix *= gap[:, None]
    g = np.interp(t_all, [0, 0.02, FINAL + 2.5, FADE_END - 0.05, FADE_END], [0, 1, 1, 0, 0])
    mix *= g[:, None]
    return mix[: int(TOTAL * SR)]


def master(x, target=-14.0, tp_ceiling_db=-1.3):
    ceiling = 10 ** (tp_ceiling_db / 20)
    y = x.copy()
    for _ in range(4):
        cur = lufs(y)
        y = y * 10 ** ((target - cur) / 20)
        y = limiter(y, ceiling * 0.97)
        tp = true_peak_db(y)
        if tp > tp_ceiling_db:
            y *= 10 ** ((tp_ceiling_db - 0.05 - tp) / 20)
        if abs(lufs(y) - target) < 0.3:
            break
    return y


def write_raw(name, x):
    wavfile.write(os.path.join(OUT, name), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ma.write("sfx_slam.wav", sfx_slam(), 0.95)
    ma.write("sfx_boom.wav", sfx_boom(), 0.95)
    ma.write("sfx_glass_flip.wav", sfx_glass_flip(), 0.75)
    ma.write("sfx_swipe.wav", sfx_swipe(), 0.7)
    ma.write("sfx_drag_start.wav", sfx_drag_start(), 0.6)
    ma.write("sfx_dock_snap.wav", sfx_dock_snap(), 0.85)
    for i, m in enumerate((74, 78, 81, 86)):  # D5 F#5 A5 D6
        ma.write(f"sfx_chip_{i}.wav", sfx_chip(m), 0.7)
    ma.write("sfx_lightsweep.wav", sfx_lightsweep(), 0.6)
    mus = master(music())
    write_raw("music_vertical.wav", mus)
    print("done", OUT, f"{len(mus) / SR:.2f}s", f"LUFS {lufs(mus):.1f}", f"TP {true_peak_db(mus):.1f} dB")
