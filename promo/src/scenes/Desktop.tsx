import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../components/Sky";
import { AppWindow } from "../components/AppWindow";
import { MenuBar } from "../components/MenuBar";
import { Island } from "../components/Island";
import { Ring } from "../components/Ring";
import { Cursor } from "../components/Cursor";
import { PreviewCard } from "../components/PreviewCard";
import { Keycap, Trackpad } from "../components/Keys";
import { Caption } from "../components/Caption";
import { zoneRect, zoneFromAngle } from "../components/LayoutGlyph";
import { RING_APPS } from "../lib/apps";
import {
  Pt,
  Rect,
  clamp01,
  easeIn,
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
} from "../lib/anim";
import { COPY, Lang } from "../lib/copy";
import { BLUE, FONT, H, MENU_H, W } from "../theme";

export const DESKTOP_LEN = 19.0;

const AREA: Rect = { x: 0, y: MENU_H, w: W, h: H - MENU_H };
export const LEFT = zoneRect("left", AREA, 10);
export const RIGHT = zoneRect("right", AREA, 10);

const CHROME0: Rect = { x: 170, y: 150, w: 1060, h: 700 };
const VSCODE0: Rect = { x: 850, y: 240, w: 920, h: 640 };
const CLAUDE0: Rect = { x: 440, y: 124, w: 1040, h: 730 };

/** Timeline (seconds, local to this scene). */
export const T = {
  altA: 0.7,
  ringA: 0.82,
  toGPT: 1.3,
  toClaude: 2.2,
  releaseA: 3.45,
  moveB: 4.1,
  altB: 4.7,
  ringB: 4.8,
  tabB: 5.25,
  pointB: 5.65,
  releaseB: 6.85,
  moveB2: 7.25,
  altB2: 7.7,
  ringB2: 7.8,
  tabB2: 8.05,
  pointB2: 8.4,
  releaseB2: 9.35,
  moveC: 9.8,
  altC: 10.4,
  ringC: 10.5,
  pointC: 10.8,
  scroll1: 11.3,
  scroll2: 12.4,
  releaseC: 13.45,
  island: 14.15,
  expand: 14.65,
  hover: 15.45,
  badge: 16.35,
  back: 17.85,
};

export const C1: Pt = [960, 560];
export const C2: Pt = [1180, 620];
export const C3: Pt = [700, 560];
export const C4: Pt = [RIGHT.x + RIGHT.w / 2, RIGHT.y + RIGHT.h / 2];

const polar = (c: Pt, deg: number, r: number): Pt => [
  c[0] + Math.cos((deg * Math.PI) / 180) * r,
  c[1] + Math.sin((deg * Math.PI) / 180) * r,
];

export const cursorAt = (t: number): Pt => {
  const base = trackPt(
    t,
    [
      [0, C1],
      [T.toGPT, polar(C1, -25, 172)],
      [T.toClaude, polar(C1, -57, 178)],
      [T.moveB, C2],
      [T.pointB, polar(C2, 0, 168)],
      [T.moveB2, C3],
      [T.pointB2, polar(C3, 180, 168)],
      [T.moveC, C4],
      [T.pointC, polar(C4, -57, 150)],
      [T.island, [640, 112]],
      [T.back, [1120, 620]],
    ],
    { response: 0.5, damping: 1 },
  );
  // dock sweep overrides the spring path
  const sweep = ramp(t, T.hover, T.back - 0.25, easeInOut);
  if (t > T.hover && t < T.back) {
    const sx = kf(
      t,
      [T.hover, T.badge - 0.1, T.badge + 0.5, T.back - 0.2],
      [640, 1010, 1010, 1290],
    );
    const sy = 112 + Math.sin(sweep * Math.PI) * 4;
    const k = Math.min(
      ramp(t, T.hover, T.hover + 0.25),
      1 - ramp(t, T.back - 0.15, T.back),
    );
    return [base[0] + (sx - base[0]) * k, base[1] + (sy - base[1]) * k];
  }
  return base;
};

const pointerOf = (c: Pt, cur: Pt) => {
  const dx = cur[0] - c[0];
  const dy = cur[1] - c[1];
  const dist = Math.hypot(dx, dy);
  return {
    angle: (Math.atan2(dy, dx) * 180) / Math.PI,
    engage: smoothstep(40, 120, dist),
  };
};

export const held = (t: number, a: number, b: number) =>
  Math.min(ramp(t, a, a + 0.07, easeOut), 1 - ramp(t, b, b + 0.09, easeIn));

export const tap = (t: number, a: number) => held(t, a, a + 0.12);

/** Key / trackpad state at desktop-time t (shared with the vertical cut). */
export const keyState = (t: number) => ({
  altDown: Math.max(
    held(t, T.altA, T.releaseA),
    held(t, T.altB, T.releaseB),
    held(t, T.altB2, T.releaseB2),
    held(t, T.altC, T.releaseC),
  ),
  tabDown: Math.max(tap(t, T.tabB), tap(t, T.tabB2)),
  scrollPhase:
    t > T.scroll1 && t < T.scroll1 + 0.9
      ? Math.sin(((t - T.scroll1) / 0.45) * Math.PI)
      : t > T.scroll2 && t < T.scroll2 + 0.7
        ? -Math.sin(((t - T.scroll2) / 0.35) * Math.PI)
        : 0,
});

type Cam = { x: number; y: number; s: number };

const cameraAt = (t: number): Cam => {
  const stages: Array<[number, Cam]> = [
    [0, { x: 960, y: 540, s: 1.0 }],
    [0.55, { x: 980, y: 500, s: 1.13 }],
    [3.55, { x: 960, y: 540, s: 1.0 }],
    [4.5, { x: 1080, y: 560, s: 1.05 }],
    [7.2, { x: 880, y: 560, s: 1.05 }],
    [9.6, { x: 1320, y: 560, s: 1.12 }],
    [13.6, { x: 960, y: 540, s: 1.0 }],
    [14.1, { x: 960, y: 300, s: 1.32 }],
    [T.back, { x: 960, y: 540, s: 1.0 }],
  ];
  const o = { response: 0.95, damping: 0.96 };
  const s = track(
    t,
    stages.map(([a, c]) => [a, c.s]),
    o,
  );
  let x = track(
    t,
    stages.map(([a, c]) => [a, c.x]),
    o,
  );
  let y = track(
    t,
    stages.map(([a, c]) => [a, c.y]),
    o,
  );
  const hw = W / (2 * s);
  const hh = H / (2 * s);
  x = Math.max(hw, Math.min(W - hw, x));
  y = Math.max(hh, Math.min(H - hh, y));
  return { x, y, s };
};

export const Desktop: React.FC<{
  lang: Lang;
  start?: number;
  captions?: boolean;
  /** false = no built-in camera (an outer viewport frames the 1920x1080 world) */
  camera?: boolean;
  keys?: boolean;
}> = ({ lang, start = 0, captions = true, camera = true, keys = true }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps + start;
  const c = COPY[lang];

  const cur = cursorAt(t);
  const cam = camera ? cameraAt(t) : { x: W / 2, y: H / 2, s: 1 };

  // --- windows -------------------------------------------------------------
  const winSpring = { response: 0.5, damping: 0.8 };
  const chromeRect = trackRect(
    t,
    [
      [0, CHROME0],
      [T.releaseB2 + 0.02, LEFT],
    ],
    winSpring,
  );
  const claudeRect = trackRect(
    t,
    [
      [0, CLAUDE0],
      [T.releaseB + 0.02, RIGHT],
      [T.releaseC + 0.02, scaleRect(RIGHT, 0.78)],
    ],
    winSpring,
  );
  const claudeIn = springAt(t, T.releaseA, { response: 0.45, damping: 0.78 });
  const claudeOpacity = clamp01(ramp(t, T.releaseA, T.releaseA + 0.22));
  const claudeFront = t > T.releaseA && !(t > T.releaseB2 && t < T.releaseC);
  const chromeFront = !claudeFront;
  const frontName =
    t < T.releaseA ? "Google Chrome" : claudeFront ? "Claude" : "Google Chrome";

  // --- rings ---------------------------------------------------------------
  const pA = pointerOf(C1, cur);
  const pB = pointerOf(C2, cur);
  const pB2 = pointerOf(C3, cur);
  const pC = pointerOf(C4, cur);

  // --- previews -------------------------------------------------------------
  const prevSpring = { response: 0.42, damping: 0.82 };
  const seed = (p: Pt): Rect => ({ x: p[0] - 70, y: p[1] - 45, w: 140, h: 90 });
  const prevB = trackRect(
    t,
    [
      [0, seed(polar(C2, 0, 168))],
      [T.pointB + 0.12, RIGHT],
    ],
    prevSpring,
  );
  const prevB2 = trackRect(
    t,
    [
      [0, seed(polar(C3, 180, 168))],
      [T.pointB2 + 0.1, LEFT],
    ],
    prevSpring,
  );
  const resizeS = track(
    t,
    [
      [0, 1],
      [T.scroll1, 0.55],
      [T.scroll2, 0.78],
    ],
    { response: 0.7, damping: 0.9 },
  );
  const prevC = scaleRect(RIGHT, resizeS);

  // --- dock -----------------------------------------------------------------
  const expand = track(
    t,
    [
      [0, 0],
      [T.expand, 1],
      [T.back - 0.1, 0],
    ],
    { response: 0.55, damping: 0.78 },
  );
  const dockHover = t > T.hover - 0.2 && t < T.back ? cur[0] : null;

  // --- keys -----------------------------------------------------------------
  const { altDown, tabDown, scrollPhase } = keyState(t);
  const altShow = window01(t, 0.45, 13.75, 0.3, 0.3);
  const tabShow = window01(t, 4.4, 9.6, 0.3, 0.3);
  const padShow = window01(t, 11.0, 13.6, 0.3, 0.3);

  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#3E74B0" }}>
      <AbsoluteFill
        style={{
          transformOrigin: "0 0",
          transform: `translate(${W / 2 - cam.x * cam.s}px, ${H / 2 - cam.y * cam.s}px) scale(${cam.s})`,
        }}
      >
        <Sky t={t} />
        <AppWindow rect={VSCODE0} app="vscode" focused={false} z={1} />
        <AppWindow
          rect={chromeRect}
          app="chrome"
          focused={chromeFront}
          z={t > T.releaseB2 ? 4 : 2}
        />
        <AppWindow
          rect={claudeRect}
          app="claude"
          focused={claudeFront}
          z={3}
          opacity={claudeOpacity}
          scale={0.93 + 0.07 * claudeIn}
          blur={(1 - claudeOpacity) * 10}
        />

        <PreviewCard
          rect={prevB}
          opacity={window01(t, T.pointB + 0.08, T.releaseB, 0.18, 0.22)}
        />
        <PreviewCard
          rect={prevB2}
          opacity={window01(t, T.pointB2 + 0.06, T.releaseB2, 0.18, 0.22)}
        />
        <PreviewCard
          rect={prevC}
          opacity={window01(t, T.scroll1 - 0.25, T.releaseC, 0.2, 0.22)}
        />

        <div style={{ position: "absolute", inset: 0, zIndex: 35 }}>
          <Ring
            cx={C1[0]}
            cy={C1[1]}
            t={t}
            openAt={T.ringA}
            closeAt={T.releaseA}
            pointer={pA.angle}
            engage={pA.engage}
            apps={RING_APPS}
          />
          <Ring
            cx={C2[0]}
            cy={C2[1]}
            t={t}
            openAt={T.ringB}
            closeAt={T.releaseB}
            mode={ramp(t, T.tabB, T.tabB + 0.32, easeOut)}
            pointer={pB.angle}
            engage={pB.engage}
            zone={pB.engage > 0.5 ? zoneFromAngle(pB.angle) : "center"}
            apps={RING_APPS}
          />
          <Ring
            cx={C3[0]}
            cy={C3[1]}
            t={t}
            openAt={T.ringB2}
            closeAt={T.releaseB2}
            mode={ramp(t, T.tabB2, T.tabB2 + 0.28, easeOut)}
            pointer={pB2.angle}
            engage={pB2.engage}
            zone={pB2.engage > 0.5 ? zoneFromAngle(pB2.angle) : "center"}
            apps={RING_APPS}
          />
          <Ring
            cx={C4[0]}
            cy={C4[1]}
            t={t}
            openAt={T.ringC}
            closeAt={T.releaseC}
            pointer={pC.angle}
            engage={pC.engage}
            apps={RING_APPS}
          />
        </div>

        {window01(t, T.scroll1 - 0.25, T.releaseC, 0.2, 0.22) > 0.01 ? (
          <div
            style={{
              position: "absolute",
              left: prevC.x + prevC.w / 2,
              top: prevC.y + prevC.h + 22,
              transform: "translateX(-50%)",
              zIndex: 45,
              opacity: window01(t, T.scroll1 - 0.25, T.releaseC, 0.2, 0.22),
              padding: "10px 22px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.72)",
              backdropFilter: "blur(14px) saturate(1.6)",
              boxShadow:
                "inset 0 0 0 1px rgba(255,255,255,0.8), 0 8px 24px rgba(8,22,55,0.25)",
              fontFamily: FONT,
              fontSize: 30,
              fontWeight: 700,
              color: "#0E1B33",
              fontVariantNumeric: "tabular-nums",
              display: "flex",
              alignItems: "center",
              gap: 10,
            }}
          >
            <span style={{ color: BLUE, fontSize: 26 }}>⤡</span>
            {Math.round(resizeS * 100)}%
          </div>
        ) : null}
        <MenuBar app={frontName} />
        <Island
          t={t}
          expand={expand}
          hoverX={dockHover}
          hoverY={cur[1]}
          badgeAt={T.badge}
          activeId={claudeFront ? "claude" : "chrome"}
        />
        <div style={{ position: "absolute", inset: 0, zIndex: 90 }}>
          <Cursor x={cur[0]} y={cur[1]} />
        </div>
      </AbsoluteFill>

      {/* screen-space overlays */}
      {captions ? (
        <>
          <AbsoluteFill
            style={{
              background:
                "linear-gradient(0deg, rgba(6,16,40,0.55) 0%, rgba(6,16,40,0.22) 22%, rgba(6,16,40,0) 42%)",
              zIndex: 70,
            }}
          />
          <Caption
            t={t}
            at={0.35}
            until={3.85}
            kicker={c.switchKicker}
            title={c.switchTitle}
            lang={lang}
          />
          <Caption
            t={t}
            at={4.25}
            until={9.55}
            kicker={c.tileKicker}
            title={c.tileTitle}
            lang={lang}
          />
          <Caption
            t={t}
            at={9.95}
            until={13.85}
            kicker={c.resizeKicker}
            title={c.resizeTitle}
            lang={lang}
          />
          <Caption
            t={t}
            at={14.35}
            until={18.4}
            kicker={c.islandKicker}
            title={c.islandTitle}
            lang={lang}
          />
        </>
      ) : null}
      {keys ? (
        <div
          style={{
            position: "absolute",
            right: 96,
            bottom: 96,
            display: "flex",
            gap: 18,
            alignItems: "flex-end",
            zIndex: 85,
          }}
        >
          <Keycap glyph="⇥" label="tab" down={tabDown} show={tabShow} />
          <Trackpad show={padShow} phase={scrollPhase} label={c.scroll} />
          <Keycap
            glyph="⌥"
            label="option"
            down={altDown}
            show={altShow}
            width={150}
          />
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
