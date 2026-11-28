import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../../components/Sky";
import { AppWindow } from "../../components/AppWindow";
import { Keycap } from "../../components/Keys";
import { ChatWindow } from "../island/ChatWindow";
import { MenuBar } from "../../components/MenuBar";
import { Cursor } from "../../components/Cursor";
import { BAR_H, DockIsland, FlushSide, islandGeom } from "../island/DockIsland";
import { KEY, SAFE, SceneCue, VSceneProps, VW } from "../contract";
import {
  Pt,
  Rect,
  clamp01,
  easeInOut,
  easeOut,
  kf,
  lerp,
  ramp,
  springAt,
  track,
  trackPt,
  window01,
} from "../../lib/anim";
import { FONT } from "../../theme";

// ---------------------------------------------------------------- layout
const CARD_W = 860;
const CARD_H = 538;
const CARD_X = (SAFE.left + SAFE.right) / 2 - CARD_W / 2; // centred in the safe column
const CARD_Y = 1050 - CARD_H / 2;
const WORLD_S = CARD_H / 1080;
const WORLD_X = (CARD_W - 1920 * WORLD_S) / 2;
// collapsed island centres, flush with each edge of the screen card
const TOP: Pt = [CARD_W / 2, BAR_H / 2];
const LEFT: Pt = [BAR_H / 2, CARD_H / 2];
const BOTTOM: Pt = [CARD_W / 2, CARD_H - BAR_H / 2];
const RIGHT: Pt = [CARD_W - BAR_H / 2, CARD_H / 2];

// ---------------------------------------------------------------- timeline (local s)
const E = {
  expand: 0.45,
  badge: 1.1,
  cmdDown: 1.45,
  cmdUp: 2.95,
  collapse: 3.2,
  grab: 3.6,
  toLeft: 4.0,
  toBottom: 4.55,
  toRight: 5.1,
  toTop: 5.65,
};
/** ⌘1..⌘4 presses: slot order of the island = chatgpt, claude, chrome, vscode */
const PRESS: Array<{ at: number; id: string; digit: string }> = [
  { at: 1.55, id: "chatgpt", digit: "1" },
  { at: 1.9, id: "claude", digit: "2" },
  { at: 2.25, id: "chrome", digit: "3" },
  { at: 2.6, id: "vscode", digit: "4" },
];
const SNAP = [E.toLeft, E.toBottom, E.toRight, E.toTop].map((s) => s + 0.12);

const DRAG: Array<[number, Pt]> = [
  [0, TOP],
  [3.72, [300, 150]],
  [E.toLeft, LEFT],
  [4.3, [250, 380]],
  [E.toBottom, BOTTOM],
  [4.85, [610, 350]],
  [E.toRight, RIGHT],
  [5.4, [600, 150]],
  [E.toTop, TOP],
];
/** windows in which the island sits docked (flush) on an edge */
const DOCKED: Array<[number, number, FlushSide, boolean]> = [
  [-1, E.grab, "top", true],
  [SNAP0(E.toLeft), 4.27, "bottom", false], // left edge: rotated 90°, local bottom faces left
  [SNAP0(E.toBottom), 4.82, "bottom", false],
  [SNAP0(E.toRight), 5.37, "top", false], // right edge: rotated 90°, local top faces right
  [SNAP0(E.toTop), 99, "top", true],
];
function SNAP0(at: number) {
  return at + 0.12;
}

/** Desktop windows (world coords) and the time each was last brought forward. */
const WINS: Array<{ id: string; rect: Rect; act: number }> = [
  { id: "vscode", rect: { x: 600, y: 150, w: 1040, h: 690 }, act: -3 },
  { id: "chrome", rect: { x: 200, y: 210, w: 1020, h: 660 }, act: -2 },
  { id: "claude", rect: { x: 860, y: 260, w: 900, h: 630 }, act: -1 },
  { id: "chatgpt", rect: { x: 330, y: 170, w: 980, h: 670 }, act: -9 },
];

const bump = (t: number, at: number) => {
  const x = t - at;
  if (x <= 0) return 0;
  return Math.sin(Math.min(1, x / 0.1) * (Math.PI / 2)) * Math.exp(-x * 4.5);
};

const COPY = {
  zh: {
    num: "04",
    kicker: "灵动岛",
    lines: ["随叫随到，", "四边任你停"],
    subs: ["收放自如", "⌘1～9 按顺序直达", "拖到任意一边，自动吸附"],
  },
  en: {
    num: "04",
    kicker: "Liquid Glass island",
    lines: ["Pops open.", "Docks on any edge."],
    subs: ["Expands and tucks away", "⌘1–9 jumps by slot order", "Drag to any edge — it snaps"],
  },
};

export const CUES: SceneCue[] = [
  { sfx: "swipe", at: 0.0, vol: 0.6 },
  { sfx: "whoosh", at: 0.05, vol: 0.35 },
  { sfx: "ring_open", at: E.expand, vol: 0.55 },
  ...[0.8, 0.93, 1.06, 1.19, 1.32].map((at) => ({ sfx: "scroll_tick" as const, at, vol: 0.4 })),
  { sfx: "pop", at: E.badge, vol: 0.8 },
  { sfx: "key_down", at: E.cmdDown, vol: 0.6 },
  ...PRESS.flatMap((p) => [
    { sfx: "key_down" as const, at: p.at, vol: 0.75 },
    { sfx: "tick" as const, at: p.at + 0.01, vol: 0.5 },
    { sfx: "select" as const, at: p.at + 0.05, vol: 0.4 },
  ]),
  { sfx: "key_up", at: E.cmdUp, vol: 0.5 },
  { sfx: "swipe", at: E.collapse, vol: 0.5 },
  { sfx: "drag_start", at: E.grab, vol: 0.7 },
  ...SNAP.map((at) => ({ sfx: "dock_snap" as const, at, vol: 0.8 })),
];

// ---------------------------------------------------------------- text
const Headline: React.FC<{ t: number; lang: "zh" | "en" }> = ({ t, lang }) => {
  const c = COPY[lang];
  const per = lang === "zh" ? 0.04 : 0.09;
  let idx = 0;
  const kIn = ramp(t, 0.05, 0.45, easeOut);
  return (
    <>
      <div
        style={{
          position: "absolute",
          left: SAFE.left + 20,
          top: 250,
          fontFamily: FONT,
          fontSize: 40,
          fontWeight: 700,
          letterSpacing: lang === "zh" ? 4 : 1,
          opacity: kIn,
          transform: `translateY(${(1 - kIn) * 20}px)`,
          display: "flex",
          gap: 18,
          alignItems: "baseline",
        }}
      >
        <span
          style={{
            backgroundImage: KEY.accentGrad,
            WebkitBackgroundClip: "text",
            backgroundClip: "text",
            color: "transparent",
          }}
        >
          {c.num}
        </span>
        <span style={{ color: KEY.dim }}>{c.kicker}</span>
      </div>
      {c.lines.map((line, li) => {
        const tokens = lang === "zh" ? Array.from(line) : line.split(" ");
        return (
          <div
            key={li}
            style={{
              position: "absolute",
              left: SAFE.left + 16,
              top: 320 + li * (lang === "zh" ? 140 : 108),
              fontFamily: FONT,
              fontSize: lang === "zh" ? 124 : 92,
              fontWeight: 800,
              letterSpacing: lang === "zh" ? 2 : -2.5,
              lineHeight: 1.1,
              whiteSpace: "nowrap",
            }}
          >
            {tokens.map((tok, i) => {
              const at = 0.18 + idx++ * per;
              const p = springAt(t, at, { response: 0.55, damping: 0.86 });
              return (
                <span
                  key={i}
                  style={{
                    display: "inline-block",
                    marginRight: lang === "zh" ? 0 : "0.25em",
                    opacity: clamp01(p * 1.3),
                    transform: `translateY(${(1 - p) * 48}px) scale(${lerp(0.94, 1, p)})`,
                    filter: `blur(${(1 - clamp01(p)) * 14}px)`,
                    backgroundImage: KEY.gradText,
                    WebkitBackgroundClip: "text",
                    backgroundClip: "text",
                    color: "transparent",
                  }}
                >
                  {tok}
                </span>
              );
            })}
          </div>
        );
      })}
      {c.subs.map((txt, i) => {
        const win = [
          [0.35, 1.38],
          [1.45, 3.12],
          [3.22, 99],
        ][i];
        const k = window01(t, win[0], win[1], 0.3, 0.2);
        if (k <= 0.01) return null;
        const leaving = t > win[1];
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: SAFE.left + 20,
              top: lang === "zh" ? 630 : 560,
              fontFamily: FONT,
              fontSize: lang === "zh" ? 44 : 40,
              fontWeight: 650,
              letterSpacing: lang === "zh" ? 3 : -0.3,
              opacity: k,
              transform: `translateY(${(1 - k) * (leaving ? -18 : 22)}px)`,
              filter: `blur(${(1 - k) * 6}px)`,
              display: "flex",
              alignItems: "center",
              gap: 16,
              whiteSpace: "nowrap",
            }}
          >
            <span style={{ width: 10, height: 10, borderRadius: 5, background: KEY.blueGlow, boxShadow: `0 0 12px ${KEY.blueGlow}` }} />
            <span style={{ color: i === 1 ? KEY.ink : KEY.dim }}>{txt}</span>
          </div>
        );
      })}
    </>
  );
};

// ---------------------------------------------------------------- edge glow
const EdgeGlow: React.FC<{ side: "left" | "right" | "top" | "bottom"; k: number }> = ({ side, k }) => {
  if (k <= 0.01) return null;
  const vertical = side === "left" || side === "right";
  const th = 10;
  const style: React.CSSProperties = {
    position: "absolute",
    zIndex: 35,
    opacity: k,
    borderRadius: 999,
    background: vertical
      ? "linear-gradient(180deg, rgba(90,162,255,0), rgba(90,162,255,0.95) 30%, rgba(165,139,255,0.95) 70%, rgba(165,139,255,0))"
      : "linear-gradient(90deg, rgba(90,162,255,0), rgba(90,162,255,0.95) 30%, rgba(165,139,255,0.95) 70%, rgba(165,139,255,0))",
    boxShadow: "0 0 24px 6px rgba(60,140,255,0.55)",
  };
  if (side === "left") Object.assign(style, { left: 2, top: CARD_H * 0.18, width: th * 0.6, height: CARD_H * 0.64 });
  if (side === "right") Object.assign(style, { right: 2, top: CARD_H * 0.18, width: th * 0.6, height: CARD_H * 0.64 });
  if (side === "bottom") Object.assign(style, { bottom: 2, left: CARD_W * 0.2, height: th * 0.6, width: CARD_W * 0.6 });
  if (side === "top") Object.assign(style, { top: 2, left: CARD_W * 0.2, height: th * 0.6, width: CARD_W * 0.6 });
  return <div style={style} />;
};

// ---------------------------------------------------------------- scene
export const VIsland: React.FC<VSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;

  // card entrance + slow push-in
  const enter = springAt(t, 0, { response: 0.75, damping: 0.88 });
  const rotX = lerp(26, 7, enter) - 4 * ramp(t, 0.8, 4.0, easeInOut);
  const rotY = Math.sin(t * 0.9) * 1.6 * enter;
  const push = 1.15 + 0.05 * ramp(t, 0.6, 6.5, easeInOut);

  // island state
  const expand = track(t, [[0, 0], [E.expand, 1], [E.collapse, 0]], { response: 0.5, damping: 0.8 });
  const geom = islandGeom(clamp01(expand));
  const pos = trackPt(t, DRAG, { response: 0.36, damping: 0.82 });
  const icx = pos[0];
  const icy = pos[1] + (geom.h - BAR_H) / 2;
  const vertical = track(t, [[0, 0], [3.8, 1], [4.35, 0], [4.9, 1], [5.45, 0]], { response: 0.34, damping: 0.82 });
  const dockAmt = DOCKED.map(([a, b]) => window01(t, a, b, 0.07, 0.08));
  const docked = Math.max(...dockAmt);
  const lift = 1 - docked;
  const di = dockAmt.indexOf(docked);
  const flush: FlushSide = DOCKED[di][2];
  const notch = DOCKED.reduce((m, d, i) => (d[3] ? Math.max(m, dockAmt[i]) : m), 0);
  let squish = 1;
  for (const s of SNAP) {
    const x = t - s;
    if (x > 0 && x < 0.35) squish -= 0.06 * Math.sin(Math.PI * Math.min(1, x / 0.18)) * Math.exp(-x * 7);
  }

  // cursor
  let cur: Pt;
  if (t < E.grab) {
    const times = [0, 0.45, 0.75, 1.4, 1.6, 3.2, E.grab - 0.05];
    cur = [
      kf(t, times, [640, 300, 130, 640, 640, 640, TOP[0] + 40], easeInOut),
      kf(t, times, [380, 140, 104, 104, 330, 330, TOP[1] + 6], easeInOut),
    ];
  } else {
    const lead = trackPt(t, DRAG, { response: 0.22, damping: 0.9 });
    const away = ramp(t, E.toTop + 0.25, E.toTop + 0.75, easeInOut);
    cur = [lerp(lead[0] + 40, 600, away), lerp(lead[1] + 6, 250, away)];
  }
  const hover: [number, number] | null = t > E.expand && t < E.collapse + 0.1 ? cur : null;
  const curOpacity = ramp(t, 0.3, 0.6) * (1 - ramp(t, 6.3, 6.5)) * (1 - 0.6 * window01(t, 1.5, 3.0, 0.2, 0.2));

  // edge glows
  const gl = {
    left: window01(t, 3.75, E.toLeft + 0.06, 0.12, 0.25),
    bottom: window01(t, 4.3, E.toBottom + 0.06, 0.12, 0.25),
    right: window01(t, 4.85, E.toRight + 0.06, 0.12, 0.25),
    top: window01(t, 5.4, E.toTop + 0.06, 0.12, 0.25),
  };

  // ⌘N slot switching
  const numbers = window01(t, E.cmdDown - 0.1, E.cmdUp, 0.2, 0.25);
  const pulse = (id: string) => PRESS.filter((p) => p.id === id).reduce((m, p) => Math.max(m, bump(t, p.at)), 0);
  const actOf = (id: string) => Math.max(WINS.find((w) => w.id === id)!.act, ...PRESS.filter((p) => p.id === id && t >= p.at).map((p) => p.at));
  const order = [...WINS].sort((a, b) => actOf(a.id) - actOf(b.id));
  const frontId = order[order.length - 1].id;
  const lastPress = [...PRESS].reverse().find((p) => t >= p.at);
  const digit = lastPress ? lastPress.digit : "1";
  const digitDown = Math.max(...PRESS.map((p) => window01(t, p.at - 0.03, p.at + 0.08, 0.03, 0.1)));
  const cmdHeld = window01(t, E.cmdDown, E.cmdUp, 0.06, 0.1);
  const keysShow = window01(t, E.cmdDown - 0.2, E.cmdUp + 0.05, 0.25, 0.3);

  // gentle reframing toward the island
  const fx = (icx - CARD_W / 2) * -0.04;
  const fy = (icy - CARD_H / 2) * -0.03;

  return (
    <AbsoluteFill style={{ background: KEY.bg, overflow: "hidden" }}>
      {/* ambient light */}
      <div
        style={{
          position: "absolute",
          left: VW / 2 - 700,
          top: 1050 - 520,
          width: 1400,
          height: 1040,
          background: "radial-gradient(closest-side, rgba(40,100,230,0.32), rgba(40,100,230,0))",
          opacity: enter,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: -200,
          top: -300,
          width: 1100,
          height: 900,
          background: "radial-gradient(closest-side, rgba(120,110,255,0.14), rgba(120,110,255,0))",
        }}
      />

      <Headline t={t} lang={lang} />

      {/* floor reflection */}
      <div
        style={{
          position: "absolute",
          left: CARD_X + 40,
          top: CARD_Y + CARD_H + 40,
          width: CARD_W - 80,
          height: 90,
          borderRadius: "50%",
          background: "radial-gradient(closest-side, rgba(110,160,255,0.35), rgba(110,160,255,0))",
          filter: "blur(18px)",
          opacity: enter,
        }}
      />

      {/* stage: perspective + card */}
      <div
        style={{
          position: "absolute",
          left: CARD_X,
          top: CARD_Y,
          width: CARD_W,
          height: CARD_H,
          perspective: 2200,
          transform: `translate(${fx}px, ${fy + (1 - enter) * 140}px) scale(${push})`,
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 36,
            overflow: "hidden",
            transform: `rotateX(${rotX}deg) rotateY(${rotY}deg) scale(${lerp(0.86, 1, enter)})`,
            transformOrigin: "50% 60%",
            opacity: clamp01(enter * 1.6),
            filter: `blur(${(1 - clamp01(enter)) * 14}px)`,
            boxShadow:
              "0 50px 120px rgba(0,0,0,0.55), 0 0 0 1.5px rgba(255,255,255,0.16), 0 0 80px rgba(60,120,255,0.18)",
            background: "#3E74B0",
          }}
        >
          {/* scaled desktop world */}
          <div
            style={{
              position: "absolute",
              left: WORLD_X,
              top: 0,
              width: 1920,
              height: 1080,
              transform: `scale(${WORLD_S})`,
              transformOrigin: "0 0",
            }}
          >
            <Sky t={t + 40} />
            {order.map((w, zi) => {
              const act = actOf(w.id);
              const pop = act > 0 ? springAt(t, act, { response: 0.38, damping: 0.72 }) : 1;
              const focused = w.id === frontId;
              const opacity = w.id === "chatgpt" ? clamp01((t - PRESS[0].at) / 0.12) : 1;
              const scale = act > 0 ? 0.94 + 0.06 * pop : 1;
              return w.id === "chatgpt" ? (
                <ChatWindow key={w.id} rect={w.rect} focused={focused} z={zi + 1} opacity={opacity} scale={scale} />
              ) : (
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
            <MenuBar app={{ chatgpt: "ChatGPT", claude: "Claude", chrome: "Google Chrome", vscode: "Code" }[frontId] ?? "Claude"} />
          </div>

          <EdgeGlow side="left" k={gl.left} />
          <EdgeGlow side="bottom" k={gl.bottom} />
          <EdgeGlow side="right" k={gl.right} />
          <EdgeGlow side="top" k={gl.top} />

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

          <div style={{ position: "absolute", inset: 0, zIndex: 60 }}>
            <Cursor x={cur[0]} y={cur[1]} scale={0.78 * (1 - 0.08 * lift)} opacity={curOpacity} />
          </div>

          {/* glass sheen */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              zIndex: 70,
              borderRadius: 36,
              background: "linear-gradient(155deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 35%)",
              boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.18)",
              pointerEvents: "none",
            }}
          />
        </div>
      </div>

      {/* ⌘ + digit keycaps under the card */}
      <div
        style={{
          position: "absolute",
          left: 0,
          width: VW,
          top: CARD_Y + CARD_H + 62,
          display: "flex",
          justifyContent: "center",
          gap: 22,
          transform: `translateX(${(SAFE.left + SAFE.right) / 2 - VW / 2}px)`,
        }}
      >
        <Keycap glyph="⌘" label="command" down={cmdHeld} show={keysShow} width={150} />
        <div style={{ alignSelf: "center", color: KEY.dim, fontFamily: FONT, fontSize: 48, fontWeight: 300, opacity: keysShow }}>+</div>
        <Keycap glyph={digit} label="" down={digitDown} show={keysShow} width={112} />
      </div>
    </AbsoluteFill>
  );
};
