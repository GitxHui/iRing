import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Desktop, T, keyState } from "../../scenes/Desktop";
import { Keycap, Trackpad } from "../../components/Keys";
import { clamp01, easeIn, easeOut, ramp, springAt, track } from "../../lib/anim";
import { FONT, H, W } from "../../theme";
import { KEY, SceneCue, SfxName, VH, VW } from "../contract";

/** The three feature scenes share one continuous desktop timeline, lightly time-warped. */
export type FeatureId = "switch" | "tile" | "resize";
export const WARP: Record<FeatureId, { len: number; d0: number; d1: number }> = {
  switch: { len: 4.0, d0: 0.5, d1: 4.4 },
  tile: { len: 6.0, d0: 4.4, d1: 10.0 },
  resize: { len: 3.0, d0: 10.0, d1: 13.85 },
};
export const toDesk = (id: FeatureId, local: number) => {
  const w = WARP[id];
  return w.d0 + (local / w.len) * (w.d1 - w.d0);
};
export const toLocal = (id: FeatureId, desk: number) => {
  const w = WARP[id];
  return ((desk - w.d0) / (w.d1 - w.d0)) * w.len;
};

// Screen card geometry (vertical canvas)
export const CARD = { x: 40, y: 650, w: 1000, h: 810, r: 40 };

export type Cam = { x: number; y: number; z: number };
const CAM_STAGES: Array<[number, Cam]> = [
  [0, { x: 960, y: 540, z: 0.82 }],
  [0.55, { x: 960, y: 545, z: 1.42 }],
  [3.35, { x: 960, y: 500, z: 0.9 }],
  [4.45, { x: 1190, y: 600, z: 1.36 }],
  [5.55, { x: 1340, y: 560, z: 0.92 }],
  [7.0, { x: 960, y: 540, z: 0.82 }],
  [7.45, { x: 700, y: 560, z: 1.36 }],
  [8.35, { x: 600, y: 560, z: 0.9 }],
  [9.45, { x: 960, y: 540, z: 0.82 }],
  [10.15, { x: 1440, y: 557, z: 1.22 }],
  [13.45, { x: 1280, y: 540, z: 0.9 }],
];

export const deskCam = (dt: number): Cam => {
  const o = { response: 0.85, damping: 0.94 };
  const z = track(dt, CAM_STAGES.map(([a, c]) => [a, c.z]), o);
  let x = track(dt, CAM_STAGES.map(([a, c]) => [a, c.x]), o);
  let y = track(dt, CAM_STAGES.map(([a, c]) => [a, c.y]), o);
  return clampCam({ x, y, z });
};

export const clampCam = (c: Cam): Cam => {
  const ax = (v: number, half: number, size: number) =>
    half >= size / 2 ? size / 2 : Math.max(half, Math.min(size - half, v));
  return { x: ax(c.x, CARD.w / (2 * c.z), W), y: ax(c.y, CARD.h / (2 * c.z), H), z: c.z };
};

const COPYF = {
  switch: {
    zh: { k: "01", kk: "切屏", h: "按住 ⌥ 或中键，指哪切哪", s: "松手即切换，窗口原地不动" },
    en: { k: "01", kk: "Switch", h: "Hold ⌥ or middle. Point. Done.", s: "Release to switch — windows stay put" },
  },
  tile: {
    zh: { k: "02", kk: "分屏", h: "按 Tab，一甩就分屏", s: "" },
    en: { k: "02", kk: "Tile", h: "Tab. Flick. Tiled.", s: "" },
  },
  resize: {
    zh: { k: "03", kk: "缩放", h: "触控板一滑，大小随心", s: "" },
    en: { k: "03", kk: "Resize", h: "Swipe. Any size.", s: "" },
  },
} as const;

export const Headline: React.FC<{
  t: number;
  len: number;
  id: FeatureId;
  lang: "zh" | "en";
  subNode?: React.ReactNode;
  enterIn?: boolean;
}> = ({ t, len, id, lang, subNode, enterIn = true }) => {
  const c = COPYF[id][lang];
  const out = ramp(t, len - 0.32, len, easeIn);
  const lines: string[] =
    lang === "zh" ? c.h.split(/(?<=，)/) : (() => {
      const i = c.h.indexOf(". ");
      return i > 0 ? [c.h.slice(0, i + 1), c.h.slice(i + 2)] : [c.h];
    })();
  let gi = 0;
  const per = lang === "zh" ? 0.03 : 0.06;
  const k = enterIn ? springAt(t, 0.02, { response: 0.45, damping: 0.85 }) : 1;
  const sub = springAt(t, 0.35, { response: 0.5, damping: 0.9 });
  return (
    <div
      style={{
        position: "absolute",
        left: 64,
        right: 40,
        top: 196,
        textAlign: "left",
        fontFamily: FONT,
        color: KEY.ink,
        opacity: 1 - out,
        transform: `translateY(${-out * 40}px) scale(${1 - out * 0.04})`,
        filter: `blur(${out * 14}px)`,
      }}
    >
      <div
        style={{
          display: "inline-flex",
          alignItems: "baseline",
          gap: 14,
          fontSize: 36,
          fontWeight: 600,
          letterSpacing: lang === "zh" ? 2 : 0.2,
          opacity: clamp01(k),
          transform: `translateY(${(1 - k) * 20}px)`,
        }}
      >
        <span style={{ color: "#86868B", fontVariantNumeric: "tabular-nums" }}>{c.k}</span>
        <span style={{ color: "#2997FF" }}>{c.kk}</span>
      </div>
      <div
        style={{
          marginTop: 18,
          fontSize: lang === "zh" ? 108 : 100,
          fontWeight: 600,
          letterSpacing: lang === "zh" ? 1 : -2.5,
          lineHeight: 1.1,
        }}
      >
        {lines.map((line, li) => (
          <div key={li} style={{ whiteSpace: "nowrap" }}>
            {(lang === "zh" ? Array.from(line) : line.split(" ")).map((tok) => {
              const i = gi++;
              const p = enterIn ? clamp01(ramp(t, 0.12 + i * per, 0.12 + i * per + 0.5, easeOut)) : 1;
              return (
                <span
                  key={i}
                  style={{
                    display: "inline-block",
                    opacity: p,
                    transform: `translateY(${(1 - p) * 50}px) scale(${0.9 + 0.1 * p})`,
                    filter: `blur(${(1 - p) * 16}px)`,
                    marginRight: lang === "zh" ? 0 : "0.24em",
                    color: "#F5F5F7",
                  }}
                >
                  {tok === " " ? "\u00A0" : tok}
                </span>
              );
            })}
          </div>
        ))}
      </div>
      <div
        style={{
          marginTop: 22,
          fontSize: 38,
          fontWeight: 400,
          color: "#86868B",
          opacity: clamp01(sub),
          transform: `translateY(${(1 - sub) * 16}px)`,
        }}
      >
        {subNode ?? c.s}
      </div>
    </div>
  );
};

/** Glass mouse card whose middle button lights up together with ⌥. */
const MouseCap: React.FC<{ down: number; label: string }> = ({ down, label }) => (
  <div
    style={{
      width: 104,
      height: 104,
      borderRadius: 22,
      position: "relative",
      transform: `translateY(${down * 5}px)`,
      background: "linear-gradient(180deg, rgba(255,255,255,0.40), rgba(255,255,255,0.16))",
      backdropFilter: "blur(20px) saturate(1.6)",
      boxShadow: `inset 0 1px 0 rgba(255,255,255,0.8), inset 0 0 0 1px rgba(255,255,255,0.35), 0 10px 26px rgba(8,22,55,0.3), 0 0 ${down * 30}px rgba(10,108,240,${down * 0.6})`,
      fontFamily: FONT,
    }}
  >
    <svg width={44} height={60} viewBox="0 0 44 60" style={{ position: "absolute", left: 30, top: 10 }}>
      <rect x={2} y={2} width={40} height={56} rx={20} fill="rgba(255,255,255,0.92)" />
      <line x1={22} y1={2} x2={22} y2={24} stroke="rgba(20,40,80,0.22)" strokeWidth={1.5} />
      <rect x={18} y={9} width={8} height={14} rx={4} fill="#0A6CF0" opacity={0.35 + 0.65 * down} />
    </svg>
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 8, textAlign: "center", fontSize: 15, fontWeight: 600, color: "#fff", opacity: 0.9 }}>
      {label}
    </div>
    <div style={{ position: "absolute", inset: 0, borderRadius: 22, boxShadow: "inset 0 0 0 2px #0A6CF0", opacity: down }} />
  </div>
);

export type StageKeys = { altDown: number; tabDown: number; scrollPhase: number; tabShow: number; padShow: number };

/** Shared keynote frame: headline, floating 3D screen card with a 1920x1080 world, keys, light. */
export const FeatureStage: React.FC<{
  t: number;
  id: FeatureId;
  lang: "zh" | "en";
  cam: Cam;
  keys: StageKeys;
  enter: number;
  /** clock for idle sway */
  clock: number;
  world: React.ReactNode;
  subNode?: React.ReactNode;
  headlineIn?: boolean;
}> = ({ t, id, lang, cam, keys, enter, clock, world, subNode, headlineIn = true }) => {
  const w = WARP[id];
  const tiltX = (1 - enter) * 26 + Math.sin(clock * 0.9) * 1.2;
  const tiltY = Math.sin(clock * 0.6 + 1) * 2.2;
  const cardScale = 0.82 + 0.18 * enter;
  const glow = 0.35 + 0.65 * keys.altDown;
  return (
    <AbsoluteFill style={{ background: KEY.bg, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          left: VW / 2 - 700,
          top: CARD.y + CARD.h / 2 - 700,
          width: 1400,
          height: 1400,
          background: `radial-gradient(closest-side, rgba(40,110,255,${0.32 * glow}), rgba(40,110,255,0))`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: -200,
          top: -300,
          width: 1100,
          height: 900,
          background: "radial-gradient(closest-side, rgba(150,110,255,0.18), rgba(150,110,255,0))",
        }}
      />
      <Headline t={t} len={w.len} id={id} lang={lang} subNode={subNode} enterIn={headlineIn} />

      <div style={{ position: "absolute", inset: 0, perspective: 2400 }}>
        <div
          style={{
            position: "absolute",
            left: CARD.x,
            top: CARD.y,
            width: CARD.w,
            height: CARD.h,
            borderRadius: CARD.r,
            overflow: "hidden",
            transform: `translateY(${(1 - enter) * 260}px) rotateX(${tiltX}deg) rotateY(${tiltY}deg) scale(${cardScale})`,
            transformOrigin: "50% 60%",
            opacity: clamp01(enter * 1.6),
            boxShadow: `0 0 0 1.5px rgba(255,255,255,0.16), 0 50px 120px rgba(0,0,0,0.6), 0 0 ${80 + 60 * glow}px rgba(40,110,255,${0.25 * glow})`,
            background: "radial-gradient(ellipse at 50% 50%, #16233F, #0A0F1C 75%)",
          }}
        >
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              width: W,
              height: H,
              transformOrigin: "0 0",
              transform: `translate(${CARD.w / 2 - cam.x * cam.z}px, ${CARD.h / 2 - cam.y * cam.z}px) scale(${cam.z})`,
              overflow: "hidden",
              borderRadius: cam.z < 0.7 ? 18 : 0,
              boxShadow: cam.z < 0.7 ? "0 0 0 2px rgba(255,255,255,0.12), 0 30px 80px rgba(0,0,0,0.5)" : undefined,
            }}
          >
            {world}
          </div>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: CARD.r,
              background: "linear-gradient(160deg, rgba(255,255,255,0.10), rgba(255,255,255,0) 35%)",
              boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.18)",
              pointerEvents: "none",
            }}
          />
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: CARD.y + CARD.h - 60,
          display: "flex",
          justifyContent: "center",
          gap: 20,
          transform: "scale(1.12)",
          opacity: clamp01(enter * 1.5),
        }}
      >
        <Keycap glyph="⇥" label="tab" down={keys.tabDown} show={keys.tabShow} />
        <Trackpad show={keys.padShow} phase={keys.scrollPhase} label={lang === "zh" ? "双指滑动" : "two-finger scroll"} />
        <Keycap glyph="⌥" label="option" down={keys.altDown} show={1} width={150} />
        <div style={{ alignSelf: "center", fontFamily: FONT, fontSize: 30, color: "#86868B", padding: "0 2px" }}>
          {lang === "zh" ? "或" : "or"}
        </div>
        <MouseCap down={keys.altDown} label={lang === "zh" ? "中键" : "middle"} />
      </div>
      <div
        style={{
          position: "absolute",
          left: 140,
          right: 140,
          top: CARD.y + CARD.h + 70,
          height: 120,
          background: `radial-gradient(closest-side, rgba(60,130,255,${0.22 * glow}), rgba(60,130,255,0))`,
          filter: "blur(10px)",
        }}
      />
    </AbsoluteFill>
  );
};

/** 01 Switch: frames the shared landscape desktop demo. */
export const VFeature: React.FC<{ id: FeatureId; lang: "zh" | "en" }> = ({ id, lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const dt = toDesk(id, t);
  const ks = keyState(dt);
  const enter = id === "switch" ? springAt(t, 0, { response: 0.7, damping: 0.86 }) : 1;
  return (
    <FeatureStage
      t={t}
      id={id}
      lang={lang}
      cam={deskCam(dt)}
      enter={enter}
      clock={dt}
      keys={{ ...ks, tabShow: 0, padShow: 0 }}
      world={<Desktop lang={lang} start={dt - t} captions={false} camera={false} keys={false} />}
    />
  );
};

/** Helper so each feature can express its cues in desktop time. */
export const deskCues = (id: FeatureId, list: Array<[SfxName, number, number?]>): SceneCue[] =>
  list
    .map(([sfx, d, vol]) => ({ sfx, at: toLocal(id, d), vol }))
    .filter((c) => c.at >= 0 && c.at < WARP[id].len);

export { T, VH };
