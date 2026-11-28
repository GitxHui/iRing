/**
 * Film scene 7 — Island (abs 44.5–52.0, 7.5 s).
 * In  : MacBook3D front-on, full screen (FULL_FRAME) — matches the end of Resize.
 * Beat: dolly up into the notch → hover expands the island → unread badge → ⌘1…⌘4 bring apps
 *       forward in slot order → collapses to the flush bar → camera pulls back to a 3/4 view →
 *       island is dragged to the left / bottom / right edges (snaps) and back to the top.
 * Out : back to FULL_FRAME, ready for the Details flip.
 */
import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../../components/Sky";
import { AppWindow } from "../../components/AppWindow";
import { MenuBar } from "../../components/MenuBar";
import { Cursor } from "../../components/Cursor";
import { Keycap } from "../../components/Keys";
import { ChatWindow } from "../../vertical/island/ChatWindow";
import {
  BAR_H,
  DockIsland,
  FlushSide,
  islandGeom,
} from "../../vertical/island/DockIsland";
import { MacBook3D } from "../device/MacBook3D";
import { COPY, FilmCue, FilmSceneProps } from "../contract";
import { Bloom, C, SP, TitleBlock, Vignette } from "../style";
import { BeatLine, FULL_FRAME, VIS, bump } from "../closing/common";
import {
  Pt,
  Rect,
  clamp01,
  easeInOut,
  kf,
  lerp,
  ramp,
  springAt,
  track,
  trackPt,
  window01,
} from "../../lib/anim";

export const ISLAND_LEN = 7.5;

// ---------------------------------------------------------------- timeline (local s)
const E = {
  dolly: 0.0,
  title: 0.35,
  hover: 0.95,
  expand: 1.05,
  badge: 1.6,
  cmdDown: 1.95,
  cmdUp: 3.35,
  collapse: 3.5,
  pull: 3.65,
  grab: 3.95,
  toLeft: 4.3,
  toBottom: 4.85,
  toRight: 5.4,
  toTop: 5.95,
  home: 6.35,
  exit: 7.0,
};
const SNAPS = [E.toLeft, E.toBottom, E.toRight, E.toTop].map((s) => s + 0.12);

/** ⌘1…⌘4 — slot order of the island (chatgpt, claude, chrome, vscode). */
const PRESS: Array<{ at: number; id: string; digit: number }> = [
  { at: 2.1, id: "chatgpt", digit: 1 },
  { at: 2.45, id: "claude", digit: 2 },
  { at: 2.8, id: "chrome", digit: 3 },
  { at: 3.15, id: "vscode", digit: 4 },
];

// ---------------------------------------------------------------- world geometry
/** During the edge-docking beat the island is drawn larger than life so it reads in the wide shot. */
const DRAG_K = 1.75;
const HALF = (BAR_H * DRAG_K) / 2;
const TOP: Pt = [960, BAR_H / 2];
const TOP_K: Pt = [960, HALF];
const LEFT: Pt = [VIS.x0 + HALF, 560];
const BOTTOM: Pt = [960, VIS.y1 - HALF];
const RIGHT: Pt = [VIS.x1 - HALF, 560];

const DRAG: Array<[number, Pt]> = [
  [0, TOP],
  [E.grab + 0.12, [620, 230]],
  [E.toLeft, LEFT],
  [4.6, [520, 760]],
  [E.toBottom, BOTTOM],
  [5.15, [1380, 700]],
  [E.toRight, RIGHT],
  [5.7, [1300, 220]],
  [E.toTop, TOP_K],
  [E.toTop + 0.45, TOP],
];
/** [from, to, flush side, notch?] windows in which the island sits docked on an edge */
const DOCKED: Array<[number, number, FlushSide, boolean]> = [
  [-1, E.grab, "top", true],
  [E.toLeft + 0.12, E.toLeft + 0.32, "bottom", false], // rotated 90°: local bottom faces left
  [E.toBottom + 0.12, E.toBottom + 0.32, "bottom", false],
  [E.toRight + 0.12, E.toRight + 0.32, "top", false], // rotated 90°: local top faces right
  [E.toTop + 0.12, 99, "top", true],
];

const WINS: Array<{ id: string; rect: Rect; act: number }> = [
  { id: "vscode", rect: { x: 640, y: 190, w: 1000, h: 660 }, act: -3 },
  { id: "chrome", rect: { x: 260, y: 240, w: 1000, h: 640 }, act: -2 },
  { id: "claude", rect: { x: 820, y: 280, w: 900, h: 620 }, act: -1 },
  { id: "chatgpt", rect: { x: 360, y: 200, w: 960, h: 650 }, act: -9 },
];
const NAMES: Record<string, string> = {
  chatgpt: "ChatGPT",
  claude: "Claude",
  chrome: "Google Chrome",
  vscode: "Code",
};

// ---------------------------------------------------------------- camera
type Shot = { cx: number; cy: number; rx: number; ry: number; s: number };
const NOTCH: Shot = { cx: 960, cy: 2654, rx: -1, ry: 0, s: 2.1 };
const THREE_Q: Shot = { cx: 990, cy: 1040, rx: -9, ry: -12, s: 0.72 };
const FULL: Shot = {
  cx: FULL_FRAME.cx,
  cy: FULL_FRAME.cy,
  rx: FULL_FRAME.rx,
  ry: FULL_FRAME.ry,
  s: FULL_FRAME.s,
};

const SHOTS: Array<[number, Shot]> = [
  [0, FULL],
  [E.dolly + 0.05, NOTCH],
  [E.pull, THREE_Q],
  [E.home, FULL],
];
const camAt = (t: number): Shot => {
  const o = SP.soft;
  const k = (key: keyof Shot) =>
    track(
      t,
      SHOTS.map(([a, s]) => [a, s[key]]),
      o,
    );
  return { cx: k("cx"), cy: k("cy"), rx: k("rx"), ry: k("ry"), s: k("s") };
};

/** The desktop inside the MacBook for scene time `t` (exported so Details can open on the exact last frame). */
export const IslandWorld: React.FC<{ t: number }> = ({ t }) => {
  // island state
  const expand = track(
    t,
    [
      [0, 0],
      [E.expand, 1],
      [E.collapse, 0],
    ],
    { response: 0.5, damping: 0.8 },
  );
  const geom = islandGeom(clamp01(expand));
  const pos = trackPt(t, DRAG, { response: 0.34, damping: 0.82 });
  const dragK = lerp(
    1,
    DRAG_K,
    window01(t, E.grab - 0.25, E.toTop + 0.12, 0.3, 0.4),
  );
  const icx = pos[0];
  const icy = pos[1] + (geom.h - BAR_H) / 2;
  const vertical = track(
    t,
    [
      [0, 0],
      [E.toLeft - 0.22, 1],
      [E.toBottom - 0.22, 0],
      [E.toRight - 0.22, 1],
      [E.toTop - 0.22, 0],
    ],
    { response: 0.34, damping: 0.82 },
  );
  const dockAmt = DOCKED.map(([a, b]) => window01(t, a, b, 0.07, 0.08));
  const docked = Math.max(...dockAmt);
  const lift = 1 - docked;
  const flush: FlushSide = DOCKED[dockAmt.indexOf(docked)][2];
  const notch = 0; // the MacBook panel draws the hardware notch itself
  let squish = 1;
  for (const s of SNAPS) {
    const x = t - s;
    if (x > 0 && x < 0.35)
      squish -=
        0.06 * Math.sin(Math.PI * Math.min(1, x / 0.18)) * Math.exp(-x * 7);
  }

  // cursor (world coords)
  let cur: Pt;
  if (t < E.grab) {
    const times = [
      0,
      E.hover - 0.25,
      E.hover + 0.15,
      1.75,
      1.95,
      E.collapse + 0.1,
      E.grab - 0.05,
    ];
    cur = [
      kf(t, times, [1250, 1080, 760, 1150, 1150, 900, TOP[0] + 60], easeInOut),
      kf(t, times, [620, 200, 120, 120, 330, 330, TOP[1] + 6], easeInOut),
    ];
  } else {
    const lead = trackPt(t, DRAG, { response: 0.22, damping: 0.9 });
    const away = ramp(t, E.toTop + 0.25, E.toTop + 0.7, easeInOut);
    cur = [lerp(lead[0] + 50, 1240, away), lerp(lead[1] + 8, 520, away)];
  }
  const hover: [number, number] | null =
    t > E.expand - 0.1 && t < E.collapse + 0.1 ? cur : null;
  const curOpacity =
    ramp(t, 0.6, 0.9) *
    (1 - 0.7 * window01(t, E.cmdDown, E.cmdUp, 0.2, 0.2)) *
    (1 - ramp(t, 6.4, 6.7));

  // ⌘N
  const numbers = window01(t, E.cmdDown - 0.1, E.cmdUp, 0.2, 0.25);
  const pulse = (id: string) =>
    PRESS.filter((p) => p.id === id).reduce(
      (m, p) => Math.max(m, bump(t, p.at)),
      0,
    );
  const actOf = (id: string) =>
    Math.max(
      WINS.find((w) => w.id === id)!.act,
      ...PRESS.filter((p) => p.id === id && t >= p.at).map((p) => p.at),
    );
  const order = [...WINS].sort((a, b) => actOf(a.id) - actOf(b.id));
  const frontId = order[order.length - 1].id;

  // edge glow while dragging (world coords)
  const gl = {
    left: window01(t, E.toLeft - 0.3, E.toLeft + 0.06, 0.12, 0.25),
    bottom: window01(t, E.toBottom - 0.3, E.toBottom + 0.06, 0.12, 0.25),
    right: window01(t, E.toRight - 0.3, E.toRight + 0.06, 0.12, 0.25),
    top: window01(t, E.toTop - 0.3, E.toTop + 0.06, 0.12, 0.25),
  };

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <Sky t={t + 44} />
      {order.map((w, zi) => {
        const act = actOf(w.id);
        const pop =
          act > 0 ? springAt(t, act, { response: 0.38, damping: 0.72 }) : 1;
        const focused = w.id === frontId;
        const scale = act > 0 ? 0.95 + 0.05 * pop : 1;
        if (w.id === "chatgpt") {
          return (
            <ChatWindow
              key={w.id}
              rect={w.rect}
              focused={focused}
              z={zi + 1}
              opacity={clamp01((t - PRESS[0].at) / 0.12)}
              scale={scale}
            />
          );
        }
        return (
          <AppWindow
            key={w.id}
            rect={w.rect}
            app={w.id as "chrome" | "claude" | "vscode"}
            focused={focused}
            z={zi + 1}
            scale={scale}
          />
        );
      })}
      <MenuBar app={NAMES[frontId] ?? "Claude"} />
      <EdgeGlow side="left" k={gl.left} />
      <EdgeGlow side="bottom" k={gl.bottom} />
      <EdgeGlow side="right" k={gl.right} />
      <EdgeGlow side="top" k={gl.top} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          zIndex: 56,
          transformOrigin: `${icx}px ${icy}px`,
          transform: `scale(${dragK})`,
        }}
      >
        <DockIsland
          t={t}
          cx={icx}
          cy={icy}
          expand={expand}
          vertical={vertical}
          lift={lift}
          squish={squish}
          flush={flush}
          notch={notch}
          hover={hover}
          badgeAt={E.badge}
          activeId={frontId}
          numbers={numbers}
          pulse={pulse}
        />
      </div>
      <div style={{ position: "absolute", inset: 0, zIndex: 90 }}>
        <Cursor
          x={cur[0]}
          y={cur[1]}
          scale={1.1 * (1 - 0.08 * lift * ramp(t, E.grab, E.grab + 0.1))}
          opacity={curOpacity}
        />
      </div>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- scene
export const Island: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const copy = COPY.island[lang];
  const cam = camAt(t);

  const lastPress = [...PRESS].reverse().find((p) => t >= p.at);
  const digitDown = Math.max(
    ...PRESS.map((p) => window01(t, p.at - 0.03, p.at + 0.08, 0.03, 0.1)),
  );
  const cmdHeld = window01(t, E.cmdDown, E.cmdUp, 0.06, 0.1);
  const keysShow = window01(t, E.cmdDown - 0.15, E.cmdUp + 0.05, 0.25, 0.3);
  const digits = [0, 0, 0, 0].map((_, i) =>
    window01(t, PRESS[i].at - 0.03, PRESS[i].at + 0.12, 0.03, 0.12),
  );
  const world = <IslandWorld t={t} />;

  const titleOut = E.pull - 0.1;
  // beats sit under the title; when the title leaves, the line hides and returns higher up
  const beatsHigh = t >= E.grab - 0.05;
  const beatsOpacity = beatsHigh
    ? ramp(t, E.grab - 0.05, E.grab + 0.1) * (1 - ramp(t, E.exit, E.exit + 0.4))
    : 1 - ramp(t, titleOut, titleOut + 0.3);
  const glow = 0.5 + 0.5 * window01(t, E.expand, E.collapse, 0.3, 0.4);

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <Bloom x={960} y={620} r={900} o={0.16 + 0.1 * glow} />
      <MacBook3D
        cx={cam.cx}
        cy={cam.cy}
        cam={{ rx: cam.rx, ry: cam.ry, s: cam.s }}
        lid={
          90 +
          14 *
            ramp(t, E.pull - 0.1, E.pull + 0.6, easeInOut) *
            (1 - ramp(t, E.home - 0.2, E.home + 0.5, easeInOut))
        }
        screen={world}
        keyGlow={{ cmd: cmdHeld, digits }}
      />
      <Vignette o={0.55} />

      {/* title + beats (top-left, over the black above the lid) */}
      <TitleBlock
        t={t}
        at={E.title}
        lang={lang}
        eyebrow={copy.eyebrow}
        title={copy.title}
        x={140}
        y={96}
        exitAt={titleOut}
        scale={0.82}
      />
      <div
        style={{
          position: "absolute",
          left: 140,
          top: beatsHigh ? 118 : 96 + 0.82 * 220,
          opacity: beatsOpacity,
        }}
      >
        <BeatLine
          t={t}
          lang={lang}
          beats={copy.beats}
          at={[E.expand + 0.05, E.cmdDown, E.grab]}
          until={E.exit}
        />
      </div>

      {/* ⌘ + digit keycaps (bottom-right) */}
      <div
        style={{
          position: "absolute",
          right: 120,
          bottom: 90,
          display: "flex",
          gap: 16,
          alignItems: "flex-end",
          zIndex: 20,
        }}
      >
        <Keycap
          glyph="⌘"
          label="command"
          down={cmdHeld}
          show={keysShow}
          width={150}
        />
        <div
          style={{
            alignSelf: "center",
            color: C.grey,
            fontSize: 44,
            fontWeight: 300,
            opacity: keysShow,
            fontFamily: "-apple-system",
          }}
        >
          +
        </div>
        <Keycap
          glyph={String(lastPress ? lastPress.digit : 1)}
          label=""
          down={digitDown}
          show={keysShow}
          width={104}
        />
      </div>
    </AbsoluteFill>
  );
};

/** Magnetic target highlight on the screen edge (world coords). */
const EdgeGlow: React.FC<{
  side: "left" | "right" | "top" | "bottom";
  k: number;
}> = ({ side, k }) => {
  if (k <= 0.01) return null;
  const th = 10;
  const vertical = side === "left" || side === "right";
  const style: React.CSSProperties = {
    position: "absolute",
    zIndex: 54,
    opacity: k,
    borderRadius: 999,
    background: vertical
      ? "linear-gradient(180deg, rgba(41,151,255,0), rgba(41,151,255,0.95) 30%, rgba(167,139,250,0.95) 70%, rgba(167,139,250,0))"
      : "linear-gradient(90deg, rgba(41,151,255,0), rgba(41,151,255,0.95) 30%, rgba(167,139,250,0.95) 70%, rgba(167,139,250,0))",
    boxShadow: "0 0 30px 8px rgba(41,151,255,0.5)",
  };
  if (side === "left")
    Object.assign(style, {
      left: VIS.x0 + 2,
      top: 200,
      width: th,
      height: 720,
    });
  if (side === "right")
    Object.assign(style, {
      left: VIS.x1 - th - 2,
      top: 200,
      width: th,
      height: 720,
    });
  if (side === "bottom")
    Object.assign(style, {
      left: 460,
      top: VIS.y1 - th - 2,
      width: 1000,
      height: th,
    });
  if (side === "top")
    Object.assign(style, { left: 460, top: 40, width: 1000, height: th });
  return <div style={style} />;
};

export const CUES: FilmCue[] = [
  { sfx: "orbit", at: 0.0, vol: 0.45 },
  { sfx: "text_in", at: E.title + 0.1, vol: 0.3 },
  { sfx: "swipe", at: E.expand, vol: 0.5 },
  { sfx: "ring_open", at: E.expand + 0.05, vol: 0.3 },
  ...[0, 1, 2, 3].map((i) => ({
    sfx: "scroll_tick",
    at: E.expand + 0.2 + i * 0.13,
    vol: 0.4,
  })),
  { sfx: "pop", at: E.badge, vol: 0.75 },
  { sfx: "key_down", at: E.cmdDown, vol: 0.7 },
  ...PRESS.flatMap((p) => [
    { sfx: "tick", at: p.at, vol: 0.5 },
    { sfx: "select", at: p.at + 0.05, vol: 0.5 },
  ]),
  { sfx: "key_up", at: E.cmdUp, vol: 0.5 },
  { sfx: "swipe", at: E.collapse, vol: 0.45 },
  { sfx: "orbit", at: E.pull, vol: 0.4 },
  { sfx: "drag_start", at: E.grab, vol: 0.6 },
  ...SNAPS.map((s) => ({ sfx: "dock_snap", at: s, vol: 0.75 })),
  { sfx: "whoosh", at: E.home - 0.05, vol: 0.35 },
];
