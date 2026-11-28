/**
 * One continuous desktop world + camera for the three gesture scenes of the film.
 * Clock W (seconds): switch 0–6, tile 6–14, resize 14–19.5.
 */
import React from "react";
import { Sky } from "../../components/Sky";
import { AppWindow } from "../../components/AppWindow";
import { MenuBar } from "../../components/MenuBar";
import { Island } from "../../components/Island";
import { Ring } from "../../components/Ring";
import { Cursor } from "../../components/Cursor";
import { PreviewCard } from "../../components/PreviewCard";
import { Zone, zoneRect } from "../../components/LayoutGlyph";
import { RING_APPS } from "../../lib/apps";
import {
  Pt,
  Rect,
  clamp01,
  easeInOut,
  easeOut,
  kf,
  ramp,
  scaleRect,
  smoothstep,
  springAt,
  track,
  trackPt,
  trackRect,
  window01,
} from "../../lib/anim";
import { BLUE, FONT, H, MENU_H, W as WW } from "../../theme";
import { MacBook3D, KeyGlow, PadTouch } from "../device/MacBook3D";
import { FilmCue } from "../contract";

export const W_OFF = { switch: 0, tile: 6, resize: 14 } as const;

const AREA: Rect = { x: 0, y: MENU_H, w: WW, h: H - MENU_H };
const Z = (z: Zone) => zoneRect(z, AREA, 10);
const FULL = Z("center");
const CHROME0: Rect = { x: 170, y: 150, w: 1060, h: 700 };
const VSCODE0: Rect = { x: 850, y: 240, w: 920, h: 640 };
const CLAUDE0: Rect = { x: 440, y: 124, w: 1040, h: 730 };
const NOTES0: Rect = { x: 260, y: 360, w: 760, h: 560 };
const center = (r: Rect): Pt => [r.x + r.w / 2, r.y + r.h / 2];
export const polar = (c: Pt, deg: number, r: number): Pt => [
  c[0] + Math.cos((deg * Math.PI) / 180) * r,
  c[1] + Math.sin((deg * Math.PI) / 180) * r,
];

// ---------------- switch (W 0–6) ----------------
const C1: Pt = [960, 540];
const S1 = { gpt: 1.2, claude: 1.95, release: 2.9 };
const P2 = polar(C1, -57, 178);
const S2 = { alt: 3.35, open: 3.42, point: 3.75, release: 4.25 };
const P3 = polar(P2, 41, 172);
const S3 = { alt: 4.55, open: 4.62, point: 4.95, release: 5.35 };
export const SWITCH = { S1, S2, S3 };

// ---------------- tile (W 6–14) ----------------
type Flick = { at: number; c: Pt; dir: number | null; zone: Zone; release: number; via: "tab" | "tap" };
const PA: Pt = [1150, 600];
const PB: Pt = [700, 560];
export const FLICKS: Flick[] = [
  { at: 6.3, c: PA, dir: 0, zone: "right", release: 7.3, via: "tab" },
  { at: 7.55, c: PB, dir: 180, zone: "left", release: 8.4, via: "tap" },
  { at: 8.65, c: center(Z("left")), dir: -135, zone: "tl", release: 9.0, via: "tab" },
  { at: 9.1, c: center(Z("right")), dir: -45, zone: "tr", release: 9.45, via: "tap" },
  { at: 9.55, c: [1310, 820], dir: 135, zone: "bl", release: 9.9, via: "tab" },
  { at: 10.0, c: center(NOTES0), dir: 45, zone: "br", release: 10.35, via: "tap" },
  { at: 10.7, c: [1437, 300], dir: null, zone: "center", release: 11.3, via: "tab" },
];

// ---------------- resize (W 14–19.5) ----------------
export const RZ = { alt: 14.2, ring: 14.27, point: 14.45, s1: 14.8, s2: 15.6, release: 16.4 };
const RC: Pt = [960, 560];

const cursorW = (w: number): Pt => {
  const st: Array<[number, Pt]> = [
    [0, C1],
    [S1.gpt, polar(C1, -25, 172)],
    [S1.claude, P2],
    [S2.point, P3],
    [S3.point, polar(P3, -57, 172)],
  ];
  FLICKS.forEach((f) => {
    st.push([f.at - 0.28, f.c]);
    if (f.dir !== null) st.push([f.at + 0.12, polar(f.c, f.dir, 165)]);
  });
  st.push([13.6, RC]);
  st.push([RZ.point, polar(RC, -57, 150)]);
  st.push([16.6, [1180, 720]]);
  st.sort((a, b) => a[0] - b[0]);
  return trackPt(w, st, { response: 0.32, damping: 1 });
};

const resizeScale = (w: number) => track(w, [[0, 1], [RZ.s1, 0.58], [RZ.s2, 0.84]], { response: 0.55, damping: 0.9 });
export const resizePct = (w: number) => Math.round(resizeScale(w) * 100);

const held = (w: number, a: number, b: number) => Math.min(ramp(w, a, a + 0.06, easeOut), 1 - ramp(w, b, b + 0.08));

/** Keyboard / trackpad state on the device. */
export const inputW = (w: number): { glow: KeyGlow; pad: PadTouch } => {
  let option = 0;
  let tab = 0;
  let tap = 0;
  option = Math.max(option, held(w, -1, S1.release), held(w, S2.alt, S2.release), held(w, S3.alt, S3.release));
  FLICKS.forEach((f) => {
    option = Math.max(option, held(w, f.at - 0.06, f.release));
    if (f.via === "tab") tab = Math.max(tab, held(w, f.at + 0.06, f.at + 0.2));
    else tap = Math.max(tap, held(w, f.at + 0.06, f.at + 0.22));
  });
  option = Math.max(option, held(w, RZ.alt, RZ.release));
  // two-finger swipe during resize
  const swipeShow = window01(w, RZ.s1 - 0.25, RZ.release - 0.1, 0.15, 0.2);
  let px = 0;
  let py = 0;
  if (swipeShow > 0) {
    py = kf(w, [RZ.s1 - 0.1, RZ.s1 + 0.6, RZ.s2 - 0.05, RZ.s2 + 0.5], [-0.7, 0.75, 0.75, -0.15], easeInOut);
  }
  const tapShow = tap;
  const pad: PadTouch =
    swipeShow > tapShow
      ? { show: swipeShow, x: px, y: py, fingers: 2, tap: 0 }
      : { show: tapShow, x: 0.1, y: 0.1, fingers: 1, tap: tapShow };
  return { glow: { option, tab }, pad };
};

// ---------------- camera ----------------
export type DevCam = { cx: number; cy: number; s: number; rx: number; ry: number; lid: number };
// s = 1/WORLD_SCALE makes world px == canvas px when front-on (match cut with the entries ring)
const S0 = 1 / Math.max(1600 / 1920, 1000 / 1080);
const CAM: Array<[number, DevCam]> = [
  [0, { cx: 960, cy: 540 + 540 * S0, s: S0, rx: 0, ry: 0, lid: 90 }],
  [0.12, { cx: 1210, cy: 920, s: 0.64, rx: -9, ry: -24, lid: 104 }],
  [2.9, { cx: 1200, cy: 915, s: 0.67, rx: -7, ry: -16, lid: 102 }],
  [6.0, { cx: 700, cy: 840, s: 0.52, rx: -20, ry: 26, lid: 108 }],
  [8.55, { cx: 700, cy: 820, s: 0.47, rx: -30, ry: 12, lid: 110 }],
  [10.6, { cx: 700, cy: 880, s: 0.53, rx: -4, ry: 8, lid: 96 }],
  [14.0, { cx: 1300, cy: 470, s: 0.46, rx: -26, ry: -38, lid: 112 }],
  [17.5, { cx: 960, cy: 1044, s: 0.95, rx: -2, ry: 0, lid: 90 }], // = closing FULL_FRAME (handoff to Island)
];
export const camW = (w: number): DevCam => {
  const k = (key: keyof DevCam) =>
    track(
      w,
      CAM.map(([a, c]) => [a, c[key]]),
      { response: 1.0, damping: 0.96 },
    );
  return { cx: k("cx"), cy: k("cy"), s: k("s"), rx: k("rx"), ry: k("ry"), lid: k("lid") };
};

// ---------------- world ----------------
const FeatureWorldInner: React.FC<{ w: number }> = ({ w }) => {
  const cur = cursorW(w);
  const sp = { response: 0.42, damping: 0.8 };
  // front app
  const front =
    w < S1.release + 0.05
      ? "chrome"
      : w < S2.release + 0.05
        ? "claude"
        : w < S3.release + 0.05
          ? "chrome"
          : w < 8.4
            ? "claude"
            : w < 9.0
              ? "chrome"
              : w < 9.45
                ? "claude"
                : w < 9.9
                  ? "vscode"
                  : w < 10.35
                    ? "notes"
                    : "claude";
  const pop = (at: number) => springAt(w, at, { response: 0.4, damping: 0.7 });
  const lastAct = (id: string) => {
    const acts: Record<string, number[]> = {
      claude: [S1.release, S3.release],
      chrome: [S2.release],
    };
    const xs = (acts[id] ?? []).filter((a) => a <= w);
    return xs.length ? xs[xs.length - 1] : -10;
  };
  const actScale = (id: string) => {
    const a = lastAct(id);
    return a < 0 ? 1 : 0.95 + 0.05 * pop(a);
  };

  const chrome = trackRect(w, [[0, CHROME0], [8.42, Z("left")], [9.02, Z("tl")]], sp);
  const claude = trackRect(
    w,
    [[0, CLAUDE0], [7.32, Z("right")], [9.47, Z("tr")], [11.32, FULL], [RZ.release + 0.02, scaleRect(FULL, 0.84)]],
    sp,
  );
  const vscode = trackRect(w, [[0, VSCODE0], [9.92, Z("bl")]], sp);
  const notes = trackRect(w, [[0, NOTES0], [10.37, Z("br")]], sp);
  const notesIn = springAt(w, 9.5, { response: 0.4, damping: 0.8 });
  const claudeIn = springAt(w, S1.release, { response: 0.45, damping: 0.78 });
  const claudeOp = clamp01(ramp(w, S1.release, S1.release + 0.2));
  const zf = (id: string, base: number) => (id === front ? 10 : base);
  const frontName = { claude: "Claude", chrome: "Google Chrome", vscode: "Code", notes: "Notes" }[front];
  const rs = resizeScale(w);

  const ringAt = (c: Pt, open: number, close: number, key: string, mode = 0, zone: Zone = "center", fixed?: number) => {
    const dx = cur[0] - c[0];
    const dy = cur[1] - c[1];
    const engage = fixed !== undefined ? fixed : smoothstep(40, 120, Math.hypot(dx, dy));
    return (
      <Ring
        key={key}
        cx={c[0]}
        cy={c[1]}
        t={w}
        openAt={open}
        closeAt={close}
        mode={mode}
        pointer={fixed !== undefined ? -90 : (Math.atan2(dy, dx) * 180) / Math.PI}
        engage={engage}
        zone={zone}
        apps={RING_APPS}
      />
    );
  };

  // intro mask: only the ring is lit at W=0 (matches the entries hand-off on black)
  const mask = 1 - ramp(w, 0.05, 0.95, easeInOut);

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <Sky t={w + 4} />
      <AppWindow rect={vscode} app="vscode" focused={front === "vscode"} z={zf("vscode", 2)} />
      <AppWindow rect={chrome} app="chrome" focused={front === "chrome"} z={zf("chrome", 3)} scale={actScale("chrome")} />
      <AppWindow
        rect={notes}
        app="notes"
        focused={front === "notes"}
        z={zf("notes", 1)}
        opacity={clamp01(notesIn * 1.4)}
        scale={0.9 + 0.1 * notesIn}
      />
      <AppWindow
        rect={claude}
        app="claude"
        focused={front === "claude"}
        z={zf("claude", 4)}
        opacity={claudeOp}
        scale={(0.93 + 0.07 * claudeIn) * (w > S3.release ? actScale("claude") : 1)}
        blur={(1 - claudeOp) * 10}
      />

      {FLICKS.map((f, i) => {
        const target = Z(f.zone);
        const from: Rect =
          f.dir === null
            ? scaleRect(target, 0.2)
            : { x: polar(f.c, f.dir, 165)[0] - 70, y: polar(f.c, f.dir, 165)[1] - 45, w: 140, h: 90 };
        const r = trackRect(w, [[0, from], [f.at + 0.16, target]], { response: 0.34, damping: 0.82 });
        return <PreviewCard key={i} rect={r} opacity={window01(w, f.at + 0.12, f.release, 0.12, 0.18)} />;
      })}
      <PreviewCard rect={scaleRect(FULL, rs)} opacity={window01(w, RZ.s1 - 0.2, RZ.release, 0.15, 0.2)} />

      <div style={{ position: "absolute", inset: 0, zIndex: 35 }}>
        {ringAt(C1, -1, S1.release, "s1")}
        {ringAt(P2, S2.open, S2.release, "s2")}
        {ringAt(P3, S3.open, S3.release, "s3")}
        {FLICKS.map((f, i) => {
          const dx = cur[0] - f.c[0];
          const dy = cur[1] - f.c[1];
          const eng = f.dir === null ? 0 : smoothstep(40, 120, Math.hypot(dx, dy));
          return ringAt(
            f.c,
            f.at,
            f.release,
            `f${i}`,
            ramp(w, f.at + 0.06, f.at + 0.22, easeOut),
            eng > 0.5 || f.dir === null ? f.zone : "center",
            f.dir === null ? 0 : undefined,
          );
        })}
        {ringAt(RC, RZ.ring, RZ.release, "rz")}
      </div>

      {window01(w, RZ.s1 - 0.2, RZ.release, 0.15, 0.2) > 0.01 ? (
        <div
          style={{
            position: "absolute",
            left: WW / 2,
            top: scaleRect(FULL, rs).y + scaleRect(FULL, rs).h - 130,
            transform: "translateX(-50%) scale(1.6)",
            transformOrigin: "50% 0",
            zIndex: 45,
            opacity: window01(w, RZ.s1 - 0.2, RZ.release, 0.15, 0.2),
            padding: "10px 22px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.8)",
            boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.8), 0 8px 24px rgba(8,22,55,0.25)",
            fontFamily: FONT,
            fontSize: 30,
            fontWeight: 600,
            color: "#0E1B33",
            fontVariantNumeric: "tabular-nums",
          }}
        >
          <span style={{ color: BLUE }}>⤡ </span>
          {Math.round(rs * 100)}%
        </div>
      ) : null}

      <MenuBar app={frontName} />
      <Island t={w + 10} expand={0} hoverX={null} hoverY={0} activeId={front} />
      {mask > 0.001 ? (
        <div
          style={{
            position: "absolute",
            inset: 0,
            zIndex: 80,
            opacity: mask,
            background: `radial-gradient(circle at ${C1[0]}px ${C1[1]}px, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 300px, #000 420px)`,
          }}
        />
      ) : null}
      <div style={{ position: "absolute", inset: 0, zIndex: 90 }}>
        <Cursor x={cur[0]} y={cur[1]} scale={1.5} />
      </div>
    </div>
  );
};

/** The device on black with one soft light. */
export const FeatureStage: React.FC<{ w: number }> = ({ w }) => {
  const cam = camW(w);
  const inp = inputW(w);
  const lightO = clamp01(ramp(w, 0.1, 1.2)) * (0.22 + 0.12 * inp.glow.option!);
  return (
    <div style={{ position: "absolute", inset: 0, background: "#000", overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          left: cam.cx - 900,
          top: cam.cy - 1100,
          width: 1800,
          height: 1500,
          background: `radial-gradient(closest-side, rgba(41,120,255,${lightO}), rgba(41,120,255,0))`,
        }}
      />
      <MacBook3D
        cx={cam.cx}
        cy={cam.cy}
        cam={{ rx: cam.rx, ry: cam.ry, s: cam.s }}
        lid={cam.lid}
        keyGlow={inp.glow}
        pad={inp.pad}
        screen={<FeatureWorldInner w={w} />}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(ellipse at 50% 50%, rgba(0,0,0,0) 60%, rgba(0,0,0,0.55) 100%)",
          pointerEvents: "none",
        }}
      />
    </div>
  );
};

// ---------------- cues (absolute W) ----------------
const cue = (sfx: string, at: number, vol?: number) => ({ sfx, at, vol });
const W_CUES: Array<{ sfx: string; at: number; vol?: number }> = [
  cue("whoosh", 0.12, 0.45),
  cue("tick", S1.gpt + 0.12, 0.55),
  cue("tick_hi", S1.claude + 0.12, 0.55),
  cue("key_up", S1.release, 0.55),
  cue("ring_close", S1.release, 0.5),
  cue("select", S1.release + 0.03, 0.7),
  cue("whoosh_fast", S1.release + 0.02, 0.4),
  cue("key_down", S2.alt, 0.75),
  cue("ring_open", S2.open, 0.45),
  cue("tick", S2.point + 0.1, 0.5),
  cue("key_up", S2.release, 0.5),
  cue("select", S2.release + 0.03, 0.55),
  cue("key_down", S3.alt, 0.75),
  cue("ring_open", S3.open, 0.45),
  cue("tick_hi", S3.point + 0.1, 0.5),
  cue("key_up", S3.release, 0.5),
  cue("select", S3.release + 0.03, 0.6),
  cue("orbit", 6.0, 0.55),
  ...FLICKS.flatMap((f, i) => [
    cue("key_down", f.at - 0.06, 0.65),
    cue("ring_open", f.at, i < 2 || i === 6 ? 0.45 : 0.28),
    f.via === "tab" ? cue("key_down", f.at + 0.06, 0.55) : cue("trackpad_tap", f.at + 0.06, 0.7),
    cue("tick_hi", f.at + 0.1, 0.4),
    ...(f.dir !== null ? [cue("whoosh_fast", f.at + 0.14, 0.38)] : []),
    cue("key_up", f.release, 0.45),
    cue(i === 6 ? "impact" : "snap", f.release + 0.06, i === 6 ? 0.42 : 0.75),
  ]),
  cue("orbit", 8.55, 0.4),
  cue("whoosh", 14.0, 0.5),
  cue("key_down", RZ.alt, 0.8),
  cue("ring_open", RZ.ring, 0.5),
  cue("tick", RZ.point + 0.12, 0.5),
  cue("key_up", RZ.release, 0.6),
  cue("ring_close", RZ.release, 0.45),
  cue("snap", RZ.release + 0.12, 0.8),
  cue("whoosh", 17.5, 0.35),
];
for (let s = 0; s < 0.6; s += 0.04 + s * 0.05) W_CUES.push(cue("scroll_tick", RZ.s1 + s, 0.5));
for (let s = 0; s < 0.45; s += 0.05 + s * 0.06) W_CUES.push(cue("scroll_tick", RZ.s2 + s, 0.5));

export const cuesFor = (from: number, len: number): FilmCue[] =>
  W_CUES.filter((c) => c.at >= from && c.at < from + len).map((c) => ({ sfx: c.sfx, at: +(c.at - from).toFixed(3), vol: c.vol }));
