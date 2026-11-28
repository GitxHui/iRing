import React from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
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
  easeOut,
  ramp,
  scaleRect,
  smoothstep,
  springAt,
  track,
  trackPt,
  trackRect,
  window01,
} from "../../lib/anim";
import { cursorAt } from "../../scenes/Desktop";
import { BLUE, FONT, H, MENU_H, W } from "../../theme";
import { SceneCue, SfxName } from "../contract";
import { Cam, FeatureStage, clampCam, deskCam, toDesk } from "./featureCommon";

/**
 * Tile + resize showcase on one continuous clock S (0..9 s):
 *   tile   S 0–6  halves -> quarters -> full screen
 *   resize S 6–9  two-finger swipe on the maximised window
 * Starts from the exact state the switch scene ends in.
 */
export const TILE_LEN = 6.0;
export const RESIZE_LEN = 3.0;

const AREA: Rect = { x: 0, y: MENU_H, w: W, h: H - MENU_H };
const Z = (z: Zone) => zoneRect(z, AREA, 10);
const CHROME0: Rect = { x: 170, y: 150, w: 1060, h: 700 };
const VSCODE0: Rect = { x: 850, y: 240, w: 920, h: 640 };
const CLAUDE0: Rect = { x: 440, y: 124, w: 1040, h: 730 };
const NOTES0: Rect = { x: 260, y: 360, w: 760, h: 560 };
const center = (r: Rect): Pt => [r.x + r.w / 2, r.y + r.h / 2];
const polar = (c: Pt, deg: number, r: number): Pt => [
  c[0] + Math.cos((deg * Math.PI) / 180) * r,
  c[1] + Math.sin((deg * Math.PI) / 180) * r,
];

// ---- timeline (S seconds) ---------------------------------------------------
type Flick = { at: number; c: Pt; dir: number | null; zone: Zone; release: number };
const PA: Pt = [1150, 600];
const PB: Pt = [700, 560];
const FLICKS: Flick[] = [
  { at: 0.3, c: PA, dir: 0, zone: "right", release: 1.3 }, // Claude -> right half
  { at: 1.55, c: PB, dir: 180, zone: "left", release: 2.4 }, // Chrome -> left half
  { at: 2.65, c: center(Z("left")), dir: -135, zone: "tl", release: 3.0 },
  { at: 3.1, c: center(Z("right")), dir: -45, zone: "tr", release: 3.45 },
  { at: 3.55, c: [1310, 820], dir: 135, zone: "bl", release: 3.9 },
  { at: 4.0, c: center(NOTES0), dir: 45, zone: "br", release: 4.35 },
  { at: 4.7, c: [1437, 300], dir: null, zone: "center", release: 5.3 }, // maximise
];
const RZ = { alt: 6.15, ring: 6.22, point: 6.4, s1: 6.7, s2: 7.45, release: 8.25 };
const ACTIVE_FULL = Z("center");

const startCursor = cursorAt(toDesk("switch", 4.0));
const startCam = deskCam(toDesk("switch", 4.0));

const cursorS = (S: number): Pt => {
  const stages: Array<[number, Pt]> = [[0, startCursor]];
  FLICKS.forEach((f) => {
    stages.push([f.at - 0.28, f.c]);
    if (f.dir !== null) stages.push([f.at + 0.12, polar(f.c, f.dir, 165)]);
  });
  stages.push([5.6, [960, 560]]);
  stages.push([RZ.point, polar([960, 560], -57, 150)]);
  stages.push([8.5, [1180, 700]]);
  return trackPt(S, stages, { response: 0.32, damping: 1 });
};

const camS = (S: number): Cam => {
  const st: Array<[number, Cam]> = [
    [0, startCam],
    [0.05, { x: PA[0], y: PA[1], z: 1.25 }],
    [0.85, { x: 1340, y: 560, z: 0.88 }],
    [1.35, { x: PB[0], y: PB[1], z: 1.25 }],
    [1.95, { x: 600, y: 560, z: 0.88 }],
    [2.5, { x: 960, y: 540, z: 0.52 }],
    [4.5, { x: 1437, y: 330, z: 0.95 }],
    [5.15, { x: 960, y: 540, z: 0.52 }],
    [6.0, { x: 960, y: 560, z: 0.78 }],
    [8.2, { x: 960, y: 540, z: 0.55 }],
  ];
  const o = { response: 0.7, damping: 0.92 };
  return clampCam({
    x: track(S, st.map(([a, c]) => [a, c.x]), o),
    y: track(S, st.map(([a, c]) => [a, c.y]), o),
    z: track(S, st.map(([a, c]) => [a, c.z]), o),
  });
};

const held = (S: number, a: number, b: number) =>
  Math.min(ramp(S, a, a + 0.06, easeOut), 1 - ramp(S, b, b + 0.08));

const keysS = (S: number) => {
  let alt = 0;
  let tab = 0;
  FLICKS.forEach((f) => {
    alt = Math.max(alt, held(S, f.at - 0.06, f.release));
    tab = Math.max(tab, held(S, f.at + 0.06, f.at + 0.16));
  });
  alt = Math.max(alt, held(S, RZ.alt, RZ.release));
  const scrollPhase =
    S > RZ.s1 && S < RZ.s1 + 0.7
      ? Math.sin(((S - RZ.s1) / 0.35) * Math.PI)
      : S > RZ.s2 && S < RZ.s2 + 0.5
        ? -Math.sin(((S - RZ.s2) / 0.25) * Math.PI)
        : 0;
  return { altDown: alt, tabDown: tab, scrollPhase };
};

const resizeScale = (S: number) => track(S, [[0, 1], [RZ.s1, 0.58], [RZ.s2, 0.84]], { response: 0.55, damping: 0.9 });

// ---- world -------------------------------------------------------------------
const ShowcaseWorld: React.FC<{ S: number }> = ({ S }) => {
  const cur = cursorS(S);
  const sp = { response: 0.42, damping: 0.8 };
  const chrome = trackRect(S, [[0, CHROME0], [2.42, Z("left")], [3.02, Z("tl")]], sp);
  const claude = trackRect(
    S,
    [
      [0, CLAUDE0],
      [1.32, Z("right")],
      [3.47, Z("tr")],
      [5.32, ACTIVE_FULL],
      [RZ.release + 0.02, scaleRect(ACTIVE_FULL, 0.84)],
    ],
    sp,
  );
  const vscode = trackRect(S, [[0, VSCODE0], [3.92, Z("bl")]], sp);
  const notes = trackRect(S, [[0, NOTES0], [4.37, Z("br")]], sp);
  const notesIn = springAt(S, 3.55, { response: 0.4, damping: 0.8 });

  const front = S < 2.4 ? "claude" : S < 3.0 ? "chrome" : S < 3.45 ? "claude" : S < 3.9 ? "vscode" : S < 4.35 ? "notes" : "claude";
  const z = (id: string, base: number) => (id === front ? 10 : base);
  const frontName = { claude: "Claude", chrome: "Google Chrome", vscode: "Code", notes: "Notes" }[front];

  const rs = resizeScale(S);

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <Sky t={S + 4} />
      <AppWindow rect={vscode} app="vscode" focused={front === "vscode"} z={z("vscode", 2)} />
      <AppWindow rect={chrome} app="chrome" focused={front === "chrome"} z={z("chrome", 3)} />
      <AppWindow
        rect={notes}
        app="notes"
        focused={front === "notes"}
        z={z("notes", 1)}
        opacity={clamp01(notesIn * 1.4)}
        scale={0.9 + 0.1 * notesIn}
      />
      <AppWindow rect={claude} app="claude" focused={front === "claude"} z={z("claude", 4)} />

      {FLICKS.map((f, i) => {
        const target = Z(f.zone);
        const from: Rect = f.dir === null ? scaleRect(target, 0.2) : { x: polar(f.c, f.dir, 165)[0] - 70, y: polar(f.c, f.dir, 165)[1] - 45, w: 140, h: 90 };
        const r = trackRect(S, [[0, from], [f.at + 0.16, target]], { response: 0.34, damping: 0.82 });
        return <PreviewCard key={i} rect={r} opacity={window01(S, f.at + 0.12, f.release, 0.12, 0.18)} />;
      })}
      <PreviewCard rect={scaleRect(ACTIVE_FULL, rs)} opacity={window01(S, RZ.s1 - 0.2, RZ.release, 0.15, 0.2)} />

      <div style={{ position: "absolute", inset: 0, zIndex: 35 }}>
        {FLICKS.map((f, i) => {
          const dx = cur[0] - f.c[0];
          const dy = cur[1] - f.c[1];
          const engage = f.dir === null ? 0 : smoothstep(40, 120, Math.hypot(dx, dy));
          return (
            <Ring
              key={i}
              cx={f.c[0]}
              cy={f.c[1]}
              t={S}
              openAt={f.at}
              closeAt={f.release}
              mode={i < 2 ? ramp(S, f.at + 0.1, f.at + 0.35, easeOut) : ramp(S, f.at, f.at + 0.12, easeOut)}
              pointer={f.dir === null ? -90 : (Math.atan2(dy, dx) * 180) / Math.PI}
              engage={engage}
              zone={engage > 0.5 || f.dir === null ? f.zone : "center"}
              apps={RING_APPS}
            />
          );
        })}
        {(() => {
          const c: Pt = [960, 560];
          const dx = cur[0] - c[0];
          const dy = cur[1] - c[1];
          return (
            <Ring
              cx={c[0]}
              cy={c[1]}
              t={S}
              openAt={RZ.ring}
              closeAt={RZ.release}
              pointer={(Math.atan2(dy, dx) * 180) / Math.PI}
              engage={smoothstep(40, 120, Math.hypot(dx, dy))}
              apps={RING_APPS}
            />
          );
        })()}
      </div>

      {window01(S, RZ.s1 - 0.2, RZ.release, 0.15, 0.2) > 0.01 ? (
        <div
          style={{
            position: "absolute",
            left: W / 2,
            top: scaleRect(ACTIVE_FULL, rs).y + scaleRect(ACTIVE_FULL, rs).h - 120,
            transform: "translateX(-50%) scale(1.6)",
            transformOrigin: "50% 0",
            zIndex: 45,
            opacity: window01(S, RZ.s1 - 0.2, RZ.release, 0.15, 0.2),
            padding: "10px 22px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.78)",
            boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.8), 0 8px 24px rgba(8,22,55,0.25)",
            fontFamily: FONT,
            fontSize: 30,
            fontWeight: 700,
            color: "#0E1B33",
            fontVariantNumeric: "tabular-nums",
          }}
        >
          <span style={{ color: BLUE }}>⤡ </span>
          {Math.round(rs * 100)}%
        </div>
      ) : null}

      <MenuBar app={frontName} />
      <Island t={S + 10} expand={0} hoverX={null} hoverY={0} activeId={front} />
      <div style={{ position: "absolute", inset: 0, zIndex: 90, transform: "scale(1)", transformOrigin: "0 0" }}>
        <Cursor x={cur[0]} y={cur[1]} scale={1.5} />
      </div>
    </div>
  );
};

// ---- headline extras ----------------------------------------------------------
const ModeChips: React.FC<{ S: number; lang: "zh" | "en" }> = ({ S, lang }) => {
  const labels = lang === "zh" ? ["二分屏", "四分屏", "全屏"] : ["Halves", "Quarters", "Full screen"];
  const at = [0, 2.55, 4.55];
  const active = S < at[1] ? 0 : S < at[2] ? 1 : 2;
  // sliding underline between labels
  const w = lang === "zh" ? 150 : 210;
  const gap = 44;
  const pos = track(S, [[0, 0], [at[1], 1], [at[2], 2]], { response: 0.45, damping: 0.85 });
  return (
    <div style={{ position: "relative", display: "inline-flex", gap, paddingBottom: 16 }}>
      {labels.map((l, i) => (
        <div
          key={l}
          style={{
            width: w,
            fontSize: 38,
            fontWeight: i === active ? 600 : 400,
            color: i === active ? "#F5F5F7" : "#6E6E73",
          }}
        >
          {l}
        </div>
      ))}
      <div
        style={{
          position: "absolute",
          left: pos * (w + gap),
          bottom: 0,
          width: lang === "zh" ? 112 : 150,
          height: 4,
          borderRadius: 2,
          background: "#2997FF",
          boxShadow: "0 0 16px rgba(41,151,255,0.6)",
        }}
      />
    </div>
  );
};

const PercentReadout: React.FC<{ S: number }> = ({ S }) => {
  const pct = Math.round(resizeScale(S) * 100);
  return (
    <div style={{ display: "inline-flex", alignItems: "baseline", gap: 20 }}>
      <span style={{ fontSize: 84, fontWeight: 600, color: "#F5F5F7", fontVariantNumeric: "tabular-nums", letterSpacing: -2 }}>
        {pct}
        <span style={{ fontSize: 48, color: "#86868B", marginLeft: 4 }}>%</span>
      </span>
      <span style={{ fontSize: 34, color: "#86868B" }}>45% – 100%</span>
    </div>
  );
};

export const VShowcase: React.FC<{ part: "tile" | "resize"; lang: "zh" | "en" }> = ({ part, lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const S = part === "tile" ? t : TILE_LEN + t;
  const ks = keysS(S);
  return (
    <FeatureStage
      t={t}
      id={part}
      lang={lang}
      cam={camS(S)}
      enter={1}
      clock={toDesk("switch", 4.0) + S}
      keys={{
        ...ks,
        tabShow: part === "tile" ? 1 : 0,
        padShow: part === "resize" ? clamp01(ramp(S, 6.3, 6.55)) : 0,
      }}
      subNode={part === "tile" ? <ModeChips S={S} lang={lang} /> : <PercentReadout S={S} />}
      world={<ShowcaseWorld S={S} />}
    />
  );
};

// ---- cues ---------------------------------------------------------------------
const cue = (sfx: SfxName, at: number, vol?: number): SceneCue => ({ sfx, at, vol });

export const TILE_CUES: SceneCue[] = FLICKS.flatMap((f, i) => [
  cue("key_down", f.at - 0.06, 0.7),
  cue("ring_open", f.at, i < 2 || i === 6 ? 0.5 : 0.3),
  cue("tick_hi", f.at + 0.08, 0.45),
  ...(f.dir !== null ? [cue("whoosh_fast", f.at + 0.14, 0.4)] : []),
  cue("key_up", f.release, 0.5),
  cue(i === 6 ? "impact" : "snap", f.release + 0.06, i === 6 ? 0.45 : 0.75),
]).filter((c) => c.at >= 0 && c.at < TILE_LEN);

const ticks: SceneCue[] = [];
for (let s = 0; s < 0.6; s += 0.04 + s * 0.05) ticks.push(cue("scroll_tick", RZ.s1 + s - TILE_LEN, 0.5));
for (let s = 0; s < 0.45; s += 0.05 + s * 0.06) ticks.push(cue("scroll_tick", RZ.s2 + s - TILE_LEN, 0.5));
export const RESIZE_CUES: SceneCue[] = [
  cue("key_down", RZ.alt - TILE_LEN, 0.8),
  cue("ring_open", RZ.ring - TILE_LEN, 0.5),
  cue("tick", RZ.point + 0.12 - TILE_LEN, 0.5),
  ...ticks,
  cue("key_up", RZ.release - TILE_LEN, 0.6),
  cue("ring_close", RZ.release - TILE_LEN, 0.45),
  cue("snap", RZ.release + 0.12 - TILE_LEN, 0.8),
].filter((c) => c.at >= 0 && c.at < RESIZE_LEN);
