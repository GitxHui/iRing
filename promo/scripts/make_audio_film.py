"""Audio for the iRing keynote film — all procedurally synthesised (no samples).

Usage: python3 scripts/make_audio_film.py [out_dir]   (default: public/audio)

Writes the new film SFX (sfx_orbit, sfx_flip, sfx_text_in, sfx_mouse_down, sfx_trackpad_tap,
sfx_sub_drop, sfx_heartbeat, sfx_cursor_whir) and music_film.wav (exactly 60.5 s, 120 BPM,
downbeats at 0, 2, 4 …). Section times mirror SCENES / HITS in src/film/contract.ts.
Existing SFX are left untouched.
"""

import os
import sys

import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else "public/audio"
sys.argv = [sys.argv[0], OUT]  # make_audio / make_audio_vertical read argv at import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_audio as ma  # noqa: E402
import make_audio_vertical as mv  # noqa: E402

SR = ma.SR
tt, mtof, filt, noise, stereo, reverb, bell, pluck, place = (
    ma.tt, ma.mtof, ma.filt, ma.noise, ma.stereo, ma.reverb, ma.bell, ma.pluck, ma.place,
)
RNG = np.random.default_rng(41)

TOTAL = 60.5
BEAT = 0.5
BAR = 2.0

# Musical anchors (absolute seconds) — keep in sync with HITS / SCENES in src/film/contract.ts
QUESTION = 7.0
REVEAL = 9.5
LOCKUP = 12.0
ENTRIES = 16.0
KEY_PRESS = 17.5
MID_PRESS = 20.0
CONVERGE = 22.5
GROOVE = 25.0
TILE_LIFT = 31.0
RESIZE = 39.0
ISLAND = 44.5
DETAILS = 52.0
FINAL = 56.0
FADE_END = 60.5
# per-accent trims so the ⌥ (17.5) and middle-button (20.0) hits measure equally loud
ACC_GAIN = (1.27, 1.0)


# ----------------------------------------------------------------- helpers
def pan_sweep(x, p0, p1):
    n = len(x)
    pan = np.linspace(p0, p1, n)
    return np.stack([x * np.cos((pan + 1) * np.pi / 4), x * np.sin((pan + 1) * np.pi / 4)], axis=1) * 1.41


def pitch_sine(f_curve):
    return np.sin(2 * np.pi * np.cumsum(f_curve) / SR)


def felt_piano(f, dur, soft=1.0):
    """Soft felt-piano: slightly inharmonic partials, fast HF decay, felt hammer thump."""
    t = tt(dur)
    y = np.zeros_like(t)
    B = 0.0004
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > 9000:
            break
        y += (1 / k ** 1.4) * np.sin(2 * np.pi * fk * t + k * 0.7) * np.exp(-t * (0.9 + 1.1 * k * soft))
    y *= np.minimum(1, t / 0.006)
    hammer = filt(noise(len(t)), "lp", 900) * np.exp(-t * 60) * 0.08
    return filt(y + hammer, "lp", 4200)


# ----------------------------------------------------------------- new SFX
def sfx_orbit():
    t = tt(2.2)
    n = len(t)
    env = np.sin(np.pi * np.clip(t / 2.1, 0, 1)) ** 2
    air = ma.sweep_filter(noise(n), "bp", 380, 1900, steps=48, width=0.8)
    air = air * env * 0.55
    # second half sweeps back down so the swell feels like a rotation
    air2 = ma.sweep_filter(noise(n), "bp", 2400, 700, steps=48, width=0.6) * env * 0.25
    sub = np.sin(2 * np.pi * 44 * t) * env ** 1.5 * 0.55
    sub = np.tanh(sub * 1.3)
    st = pan_sweep(air + air2, -0.8, 0.8) + stereo(sub, 0)
    return reverb(st, ma.IR_MED, 0.35)


def sfx_flip():
    t = tt(0.6)
    n = len(t)
    env = np.exp(-((t - 0.11) ** 2) / 0.0022)
    sw = ma.sweep_filter(noise(n), "bp", 1400, 6800, steps=36, width=0.55) * env * 0.6
    y = sw.copy()
    b = bell(mtof(96), 0.6 - 0.16, 0.14, ratios=(1, 2.01, 2.76), amps=(1, 0.4, 0.2)) * 0.3
    i = int(0.16 * SR)
    y[i : i + len(b)] += b[: n - i]
    thump = np.sin(2 * np.pi * 180 * t) * np.exp(-((t - 0.17) ** 2) / 0.0008) * 0.18
    return reverb(pan_sweep(y + thump, 0.6, -0.6), ma.IR_SHORT, 0.25)


def sfx_text_in():
    t = tt(0.3)
    n = len(t)
    breath = filt(noise(n), "bp", (3000, 8000)) * np.exp(-((t - 0.04) ** 2) / 0.0006) * 0.25
    blip = np.sin(2 * np.pi * 2350 * t) * np.exp(-t * 70) * 0.12 * np.minimum(1, t / 0.003)
    return reverb(breath + blip, ma.IR_SHORT, 0.3)


def sfx_mouse_down():
    t = tt(0.32)
    n = len(t)
    click = filt(noise(n), "bp", (1100, 4200)) * np.exp(-t * 420) * 0.7
    body = np.sin(2 * np.pi * 620 * t) * np.exp(-t * 85) * 0.45
    low = pitch_sine(140 + 50 * np.exp(-t * 60)) * np.exp(-t * 38) * 0.5
    y = click + body + low
    # wheel ratchet: three faint detents right after the press
    for k, at in enumerate((0.045, 0.075, 0.105)):
        d = tt(0.012)
        tick = filt(noise(len(d)), "hp", 5000) * np.exp(-d * 700) * (0.14 - 0.03 * k)
        j = int(at * SR)
        y[j : j + len(tick)] += tick[: n - j]
    return reverb(y, ma.IR_SHORT, 0.12)


def sfx_trackpad_tap():
    t = tt(0.22)
    n = len(t)
    haptic = pitch_sine(118 + 55 * np.exp(-t * 70)) * np.exp(-t * 34)
    haptic = np.tanh(haptic * 1.4) * 0.8
    tick = filt(noise(n), "hp", 6500) * np.exp(-t * 1600) * 0.28
    return reverb(haptic + tick, ma.IR_SHORT, 0.1)


def sfx_sub_drop():
    t = tt(1.4)
    n = len(t)
    f = 35 + 95 * np.exp(-t * 2.6)
    y = pitch_sine(f) * np.exp(-t * 1.6) * np.minimum(1, t / 0.02)
    rumble = filt(noise(n), "lp", 160) * np.exp(-t * 2.4) * 0.35
    return reverb(np.tanh((y + rumble) * 1.3), ma.IR_MED, 0.2)


def _beat(t, f0, amp):
    f = f0 + 30 * np.exp(-t * 30)
    return pitch_sine(f) * np.exp(-t * 11) * np.minimum(1, t / 0.004) * amp


def sfx_heartbeat():
    n = int(0.9 * SR)
    y = np.zeros(n)
    for at, amp in ((0.0, 1.0), (0.28, 0.7)):
        d = tt(0.6)
        b = _beat(d, 52, amp)
        j = int(at * SR)
        y[j : j + len(b)] += b[: n - j]
    y = filt(np.tanh(y * 1.5), "lp", 220)
    return reverb(y, ma.IR_SHORT, 0.15)


def sfx_cursor_whir():
    t = tt(0.6)
    n = len(t)
    env = np.clip(t / 0.18, 0, 1) ** 1.5 * np.exp(-np.clip(t - 0.18, 0, None) * 9)
    x = ma.sweep_filter(noise(n), "bp", 1800, 5200, steps=32, width=0.5) * env * 0.5
    return reverb(pan_sweep(x, -0.5, 0.5), ma.IR_SHORT, 0.2)


# ----------------------------------------------------------------- music parts
CHORDS = mv.CHORDS  # Dmaj9, Bm9, Gmaj9, A6 — one per 2 s bar


def chord_at(time):
    return CHORDS[int(np.floor(time / BAR)) % 4]


soft_hat, kick, clap, stab, bass_note, riser, reverse_swell, crash_wash = (
    mv.soft_hat, mv.kick, mv.clap, mv.stab, mv.bass_note, mv.riser, mv.reverse_swell, mv.crash_wash,
)


def shaker():
    t = tt(0.09)
    x = filt(noise(len(t)), "bp", (4000, 8500), 2)
    return x * np.exp(-t * 55) * np.minimum(1, t / 0.01) * 0.3


def rim():
    t = tt(0.12)
    y = np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 120) * 0.35
    y += filt(noise(len(t)), "bp", (1500, 5000)) * np.exp(-t * 250) * 0.35
    return y


def pad_chord(voicing, dur, detune=0.14):
    ch = sum(ma.supersaw(mtof(m), dur, detune) for m in voicing) / len(voicing)
    tb = tt(dur)
    return ch * np.minimum(1, tb / 0.35) * np.minimum(1, (dur - tb) / 0.7)


def big_hit(fx, at, voicing, gain=1.0, root=50):
    """Reveal / converge / final style hit: sub boom + bright chord + wash + bells."""
    place(fx, mv.sfx_boom(), at, 0.75 * gain)
    big = sum(ma.supersaw(mtof(m), 2.4, 0.2) for m in voicing) / len(voicing)
    big = ma.time_varying_lp(big, np.interp(tt(2.4), [0, 0.15, 2.4], [7500, 4200, 1600])) * np.exp(-tt(2.4) * 1.1)
    place(fx, reverb(big, ma.IR_LONG, 0.38), at, 0.55 * gain)
    place(fx, crash_wash(3.0), at, 0.5 * gain)
    for k, m in enumerate((86, 90, 93, 98)):
        place(fx, reverb(bell(mtof(m), 2.2, 0.8), ma.IR_LONG, 0.5), at + 0.09 * k, 0.1 * gain)


def accent(fx, drums, at, gain=1.0):
    """Equal-weight press accents (⌥ / middle button)."""
    r, v = chord_at(at + 0.01)
    place(fx, stereo(stab(v, r, 0.32, 5200), 0), at, 0.62 * gain)
    place(drums, stereo(kick(), 0), at, 0.9 * gain)
    place(fx, crash_wash(1.4), at, 0.25 * gain)
    for k, m in enumerate((81, 86)):
        place(fx, reverb(bell(mtof(m + (2 if gain > 1 else 0)), 1.4, 0.5), ma.IR_MED, 0.4), at + 0.06 * k, 0.12 * gain)


# ----------------------------------------------------------------- music
def music():
    n = int((TOTAL + 1.0) * SR)
    t_all = np.arange(n) / SR
    pad = np.zeros(n)
    bass = np.zeros(n)
    arp = np.zeros((n, 2))
    keys = np.zeros((n, 2))
    drums = np.zeros((n, 2))
    fx = np.zeros((n, 2))
    kicks = []

    # ================= 0 – 7.0  problem: restrained suspense in B minor =================
    # dark Bm9 drone, filter slowly opening
    drone_v = [47, 59, 62, 66, 69, 73]
    drone = pad_chord(drone_v, QUESTION + 0.05, 0.08)
    drone = ma.time_varying_lp(drone, np.interp(tt(len(drone) / SR), [0, QUESTION], [260, 1300]))
    drone *= np.interp(tt(len(drone) / SR), [0, 1.0, QUESTION], [0.0, 0.35, 0.8])
    place(fx, stereo(drone, 0), 0.0, 0.34)
    # felt-piano motif — sparse, then accelerating and rising into the question
    motif = [
        (0.5, 66, 0.55), (1.5, 74, 0.5), (2.5, 73, 0.5), (3.5, 71, 0.5),
        (4.5, 66, 0.55), (5.0, 74, 0.5), (5.5, 76, 0.55), (6.0, 78, 0.6), (6.5, 81, 0.62),
    ]
    for at, m, g in motif:
        place(keys, stereo(felt_piano(mtof(m), 2.4), -0.15 if m % 2 else 0.15), at, g * 0.8)
        place(keys, stereo(felt_piano(mtof(m - 24), 1.6, 1.6), 0), at, g * 0.25)
    # heartbeat pulse under every bar, growing
    for k, at in enumerate((0.0, 2.0, 4.0, 6.0)):
        place(drums, stereo(sfx_heartbeat_raw(), 0), at, 0.45 + 0.12 * k)
    # fine ticking enters at 3.0 and densifies
    s = 3.0
    while s < QUESTION - 0.05:
        p = (s - 3.0) / (QUESTION - 3.0)
        step = 0.25 if p < 0.5 else 0.125
        place(drums, stereo(shaker(), 0.35 if int(s / step) % 2 else -0.35), s, 0.14 + 0.22 * p)
        s += step
    for at in (5.0, 5.5, 6.0, 6.25, 6.5, 6.75):
        place(drums, stereo(rim(), 0.2), at, 0.18 + 0.05 * (at - 5.0))
    # sudden cut at 7.0 handled by the gate below (all layers except `air`)

    # ================= 7.0 – 9.5  the question: air + one held note =================
    air = np.zeros((n, 2))
    hold = REVEAL - QUESTION
    t_h = tt(hold)
    note = np.sin(2 * np.pi * mtof(81) * t_h) * (0.5 + 0.5 * np.exp(-t_h * 1.5)) * np.exp(-t_h * 0.35)
    note *= 1 + 0.08 * np.sin(2 * np.pi * 4.5 * t_h)
    place(air, reverb(note * 0.18, ma.IR_LONG, 0.55)[: int(hold * SR)], QUESTION, 1.0)
    breath = filt(noise(len(t_h)), "bp", (1800, 6500)) * np.interp(t_h, [0, 0.4, hold], [0.0, 0.08, 0.05])
    place(air, pan_sweep(breath, -0.4, 0.4), QUESTION, 1.0)
    rs = reverse_swell([62, 66, 69, 73, 76], 1.25)
    place(air, rs, REVEAL - len(rs) / SR - 0.12, 0.4)

    # ================= 9.5 reveal =================
    big_hit(fx, REVEAL, [50, 62, 66, 69, 73, 76, 81], 1.6)
    place(drums, stereo(kick(), 0), REVEAL, 1.0)

    # pad: one chord per bar from the reveal to the final hit
    for b in range(0, int(TOTAL / BAR) + 1):
        bs = b * BAR
        if bs + BAR <= REVEAL or bs >= FINAL:
            continue
        start = max(bs, REVEAL)
        dur = bs + BAR - start + 0.7
        root, voicing = chord_at(bs + 0.01)
        ma.place_mono(pad, pad_chord(voicing, dur), start, 1.0)

    # lockup accent 12.0
    r, v = chord_at(LOCKUP + 0.01)
    for k, m in enumerate((74, 78, 81, 86)):
        place(fx, reverb(bell(mtof(m), 2.0, 0.6), ma.IR_LONG, 0.45), LOCKUP + 0.05 * k, 0.14)
    ma.place_mono(bass, bass_note(r, 1.8, 1.4), LOCKUP, 0.6)

    # ================= arp throughout (from 14.0) =================
    pattern = [0, 2, 4, 1, 3, 2, 4, 3]
    step = 0.0
    a0 = 14.0
    while a0 + step < FINAL - 0.01:
        at = a0 + step
        root, voicing = chord_at(at + 0.01)
        e = int(round(step / (BEAT / 2))) % 8
        if at < ENTRIES:
            g = 0.25 + 0.35 * (at - a0) / (ENTRIES - a0)
            octv, bright = 12, 0.8
        elif at < GROOVE:
            g, octv, bright = 0.62, 12, 1.0
        elif at < TILE_LIFT:
            g, octv, bright = 0.72, 12, 1.0
        elif at < ISLAND:
            g, octv, bright = 0.72, 24, 1.35
        elif at < DETAILS:
            g, octv, bright = 0.62, 24, 1.2
        else:
            g, octv, bright = 0.78, 24, 1.5
        m = voicing[pattern[e] % len(voicing)] + octv - 12
        place(arp, stereo(pluck(mtof(m), 0.6, bright) * 0.5, -0.4 if e % 2 else 0.4), at, g)
        step += BEAT / 2

    # ================= 16.0 – 25.0  entries: restrained groove =================
    b = ENTRIES
    while b < GROOVE - 0.01:
        rel = int(round((b - ENTRIES) / BEAT))
        if rel % 4 == 0:
            kicks.append(b)
            place(drums, stereo(kick(), 0), b, 0.55)
        place(drums, stereo(soft_hat(), 0.3), b + BEAT / 2, 0.22)
        if rel % 4 == 2:
            place(drums, stereo(rim(), -0.2), b, 0.3)
        b += BEAT
    t0 = ENTRIES
    while t0 < GROOVE - 0.01:
        root, _ = chord_at(t0 + 0.01)
        d = min(BAR - (t0 % BAR), GROOVE - t0)
        ma.place_mono(bass, bass_note(root, d, 1.6), t0, 0.7)
        t0 += d
    accent(fx, drums, KEY_PRESS, ACC_GAIN[0])
    accent(fx, drums, MID_PRESS, ACC_GAIN[1])
    # converge: the bigger downbeat
    big_hit(fx, CONVERGE, [57, 64, 66, 69, 71, 76], 1.3)
    place(drums, stereo(kick(), 0), CONVERGE, 1.0)
    rz = riser(1.6)
    rz[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    place(fx, stereo(rz, 0), GROOVE - 1.6, 0.4)
    for k in range(8):
        place(drums, clap(), GROOVE - 1.0 + k * BEAT / 4, 0.12 + 0.04 * k)

    # ================= 25.0 – 44.5  gestures: main groove =================
    b = GROOVE
    while b < ISLAND - 0.01:
        beat_idx = int(round(b / BEAT))
        kicks.append(b)
        place(drums, stereo(kick(), 0), b, 1.0)
        if beat_idx % 2 == 1:
            place(drums, clap(), b, 0.5)
        sub = 4 if b >= TILE_LIFT else 2
        for h in range(sub):
            if sub == 2 and h == 0:
                continue
            hat_at = b + h * BEAT / sub
            place(drums, stereo(soft_hat(), 0.3 if h % 2 else -0.2), hat_at, 0.32 if h % 2 else 0.18)
        root, _ = chord_at(b + 0.01)
        for e in range(2):
            ma.place_mono(bass, bass_note(root, BEAT / 2), b + e * BEAT / 2, 1.0 if e == 0 else 0.7)
        b += BEAT
    place(fx, crash_wash(2.2), GROOVE, 0.5)
    r, v = chord_at(GROOVE + 0.01)
    place(fx, stereo(stab(v, r, 0.4, 6000), 0), GROOVE, 0.5)
    # 31.0 lift
    place(fx, crash_wash(2.0), TILE_LIFT, 0.42)
    r, v = chord_at(TILE_LIFT + 0.01)
    place(fx, stereo(stab(v, r, 0.3, 6500), 0), TILE_LIFT, 0.45)
    # 39.0 small variation: accent stab + one-beat hat drop handled by a gentle filter dip
    r, v = chord_at(RESIZE + 0.01)
    place(fx, stereo(stab(v, r, 0.25, 4800), 0), RESIZE, 0.4)
    place(fx, crash_wash(1.4), RESIZE, 0.28)
    # fill into the island
    fz = riser(1.0)
    place(fx, stereo(fz, 0), ISLAND - 1.0, 0.32)
    for k in range(4):
        place(drums, clap(), ISLAND - 0.5 + k * BEAT / 4, 0.18 + 0.05 * k)

    # ================= 44.5 – 52.0  island: airy half-time =================
    place(fx, crash_wash(2.4), ISLAND, 0.36)
    b = ISLAND
    while b < DETAILS - 0.01:
        rel = int(round((b - ISLAND) / BEAT))
        if rel % 4 == 0:
            kicks.append(b)
            place(drums, stereo(kick(), 0), b, 0.7)
        if rel % 4 == 2:
            place(drums, clap(), b, 0.36)
        place(drums, stereo(soft_hat(), 0.3), b + BEAT / 2, 0.2)
        b += BEAT
    t0 = ISLAND
    while t0 < DETAILS - 0.01:
        root, _ = chord_at(t0 + 0.01)
        d = min(BAR - (t0 % BAR), DETAILS - t0)
        ma.place_mono(bass, bass_note(root, d, 1.2), t0, 0.72)
        t0 += d

    # ================= 52.0 – 56.0  details: build =================
    b = DETAILS
    while b < FINAL - 0.01:
        p = (b - DETAILS) / (FINAL - DETAILS)
        kicks.append(b)
        place(drums, stereo(kick(), 0), b, 0.85 + 0.15 * p)
        for h in range(4):
            place(drums, stereo(soft_hat(), 0.3 if h % 2 else -0.25), b + h * BEAT / 4, 0.18 + 0.18 * p)
        root, _ = chord_at(b + 0.01)
        ma.place_mono(bass, bass_note(root, BEAT, 4), b, 0.95)
        b += BEAT
    for k in range(16):  # accelerating clap/snare roll in the last second
        at = FINAL - 1.0 + 1.0 * (1 - (1 - k / 16) ** 1.6)
        place(drums, clap(), at, 0.12 + 0.03 * k)
    rz2 = riser(1.8)
    rz2[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    place(fx, stereo(rz2, 0), FINAL - 1.8, 0.5)

    # ================= 56.0  final =================
    big_hit(fx, FINAL, [50, 62, 66, 69, 73, 76, 81], 1.55)
    place(drums, stereo(kick(), 0), FINAL, 1.0)
    r, v = CHORDS[0]
    place(fx, stereo(stab([62, 66, 69, 73, 76, 81], r, 0.5, 6000), 0), FINAL, 0.7)
    tail = sum(ma.supersaw(mtof(m), 4.6, 0.18) for m in (50, 62, 66, 69, 73, 76, 81)) / 7
    tail = ma.time_varying_lp(tail, np.interp(tt(4.6), [0, 0.3, 4.6], [6500, 2800, 450])) * np.exp(-tt(4.6) * 0.6)
    place(fx, reverb(tail, ma.IR_LONG, 0.4), FINAL, 0.8)
    place(keys, stereo(felt_piano(mtof(74), 4.0, 0.7), 0), FINAL + 0.5, 0.35)
    place(keys, stereo(felt_piano(mtof(78), 4.0, 0.7), 0), FINAL + 1.0, 0.3)
    place(keys, stereo(felt_piano(mtof(81), 3.5, 0.7), 0), FINAL + 1.5, 0.3)

    # ---------------- pad automation + sidechain
    cutoff = np.interp(
        t_all,
        [0, REVEAL, REVEAL + 0.2, 14.0, ENTRIES, GROOVE, TILE_LIFT, ISLAND, DETAILS, FINAL],
        [400, 400, 5600, 2600, 2400, 3200, 4600, 5400, 5000, 6000],
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

    d = int(BEAT * 0.75 * SR)
    wet = np.zeros_like(arp)
    for k in range(1, 5):
        sh = np.zeros_like(arp)
        src = arp[: n - d * k]
        sh[d * k :] = src[:, ::-1] if k % 2 else src
        wet += sh * (0.36 ** k)
    arp = ma.filt_st(arp + ma.filt_st(wet, "lp", 4800), "hp", 180)

    keys = reverb(keys, ma.IR_LONG, 0.35)[:n]
    mix = pad_st * 0.38 + bass_st * 0.6 + arp * 0.3 + drums * 0.72 + fx * 0.9 + keys * 0.8
    mix = reverb(mix, ma.IR_MED, 0.15)[:n]

    # the sudden "question" cut at 7.0: everything but the air layer drops out until the reveal
    gate = np.interp(t_all, [QUESTION - 0.03, QUESTION, REVEAL - 0.001, REVEAL], [1, 0.0, 0.0, 1])
    mix *= gate[:, None]
    mix += air * 0.9
    # short breaths before the big hits so they land harder
    for hit in (REVEAL, CONVERGE, FINAL):
        g = np.interp(t_all, [hit - 0.14, hit - 0.08, hit - 0.004, hit], [1, 0.15, 0.15, 1])
        mix *= g[:, None]
    fade = np.interp(t_all, [0, 0.02, FINAL + 2.2, FADE_END - 0.05, FADE_END], [0, 1, 1, 0, 0])
    mix *= fade[:, None]
    return mix[: int(round(TOTAL * SR))]


def sfx_heartbeat_raw():
    """Mono heartbeat used inside the music (the SFX file is the stereo, reverbed version)."""
    n = int(0.9 * SR)
    y = np.zeros(n)
    for at, amp in ((0.0, 1.0), (0.28, 0.7)):
        b = _beat(tt(0.6), 52, amp)
        j = int(at * SR)
        y[j : j + len(b)] += b[: n - j]
    return filt(np.tanh(y * 1.5), "lp", 220)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ma.write("sfx_orbit.wav", sfx_orbit(), 0.8)
    ma.write("sfx_flip.wav", sfx_flip(), 0.75)
    ma.write("sfx_text_in.wav", sfx_text_in(), 0.35)
    ma.write("sfx_mouse_down.wav", sfx_mouse_down(), 0.85)
    ma.write("sfx_trackpad_tap.wav", sfx_trackpad_tap(), 0.85)
    ma.write("sfx_sub_drop.wav", sfx_sub_drop(), 0.9)
    ma.write("sfx_heartbeat.wav", sfx_heartbeat(), 0.85)
    ma.write("sfx_cursor_whir.wav", sfx_cursor_whir(), 0.6)
    mus = mv.master(music())
    mv.write_raw("music_film.wav", mus)
    print("done", OUT, f"{len(mus) / SR:.3f}s", f"LUFS {mv.lufs(mus):.1f}", f"TP {mv.true_peak_db(mus):.1f} dB")
