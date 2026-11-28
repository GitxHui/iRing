import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../../components/Sky";
import { AppWindow } from "../../components/AppWindow";
import { MenuBar } from "../../components/MenuBar";
import { Cursor } from "../../components/Cursor";
import { Pt, clamp01, easeIn, easeInOut, lerp, ramp, springAt } from "../../lib/anim";
import { COPY, FilmCue, FilmSceneProps, HITS, SCENES } from "../contract";
import { Bloom, C, RevealLine, Vignette, exitAmt } from "../style";
import { Trail, pathAt } from "../opening/helpers";

const LEN = SCENES.problem.len;
const Q = HITS.question - SCENES.problem.start; // 7.0 local

// world -> canvas mapping (2D push-in keeps cursor + trail pixel-exact)
const WC: Pt = [960, 590];
const worldScale = (t: number) => lerp(0.7, 0.8, ramp(t, 2.0, 6.0, easeInOut)) - 0.05 * ramp(t, 6.0, 7.0, easeInOut);
const toCanvas = (p: Pt, s: number): Pt => [WC[0] + (p[0] - 960) * s, WC[1] + (p[1] - 540) * s];

const WPS: Array<[number, Pt]> = [
  [2.3, [1010, 560]],
  [2.85, [250, 880]],
  [3.3, [120, 18]],
  [3.8, [960, 1030]],
  [4.3, [1770, 380]],
  [4.8, [330, 120]],
  [5.3, [1480, 990]],
  [5.85, [960, 540]],
];

const DOCK = ["finder", "safari", "chrome", "chatgpt", "claude", "vscode", "wechat", "notes", "music", "obsidian"];

const World: React.FC<{ t: number }> = ({ t }) => (
  <div style={{ position: "absolute", inset: 0, overflow: "hidden", borderRadius: 28 }}>
    <Sky t={t + 2} />
    <AppWindow rect={{ x: 90, y: 560, w: 760, h: 460 }} app="notes" focused={false} z={1} />
    <AppWindow rect={{ x: 1120, y: 120, w: 760, h: 560 }} app="vscode" focused={false} z={2} />
    <AppWindow rect={{ x: 160, y: 110, w: 900, h: 600 }} app="chrome" focused={false} z={3} />
    <AppWindow rect={{ x: 760, y: 330, w: 880, h: 580 }} app="claude" focused z={4} />
    <MenuBar app="Claude" />
    {/* plain dock (pre-iRing world) */}
    <div
      style={{
        position: "absolute",
        left: 960 - (DOCK.length * 78 + 24) / 2,
        top: 980,
        width: DOCK.length * 78 + 24,
        height: 88,
        borderRadius: 26,
        background: "rgba(255,255,255,0.22)",
        backdropFilter: "blur(20px) saturate(1.6)",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.4), 0 12px 30px rgba(0,0,0,0.25)",
        zIndex: 20,
      }}
    >
      {DOCK.map((id, i) => (
        <Img key={id} src={staticFile(`icons/${id}.png`)} style={{ position: "absolute", left: 16 + i * 78, top: 10, width: 68, height: 68 }} />
      ))}
    </div>
  </div>
);

export const Problem: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const lines = COPY.problem[lang];

  // world
  const wIn = springAt(t, 2.2, { response: 0.8, damping: 0.92 });
  const wOut = ramp(t, 6.0, 7.0, easeInOut);
  const s = worldScale(t) * (0.94 + 0.06 * wIn);
  const worldOpacity = clamp01(wIn * 1.3) * (1 - 0.88 * wOut) * (1 - ramp(t, 7.6, 8.6, easeIn));

  // cursor (world path -> canvas), then settle to centre at scale 1.6
  const wCur = t < WPS[0][0] ? WPS[0][1] : pathAt(t, WPS);
  const cCur = toCanvas(wCur, s);
  const settle = springAt(t, 6.05, { response: 0.75, damping: 0.95 });
  const cur: Pt = [lerp(cCur[0], 960, settle), lerp(cCur[1], 540, settle)];
  const curScale = lerp(1.05, 1.6, settle);
  const curShow = clamp01(ramp(t, 2.1, 2.4));

  // trail samples
  const pts: Array<{ p: Pt; age: number }> = [];
  const collapse = ramp(t, 6.0, 6.9, easeIn);
  if (t > 2.3) {
    for (let ts = 2.3; ts <= Math.min(t, 5.95); ts += 1 / 40) {
      const p = toCanvas(pathAt(ts, WPS), s);
      pts.push({ p: [lerp(p[0], cur[0], collapse), lerp(p[1], cur[1], collapse)], age: Math.max(0, t - ts) * 0.6 });
    }
    pts.push({ p: cur, age: 0 });
  }
  const trailO = clamp01(ramp(t, 2.35, 2.6)) * (1 - ramp(t, 6.5, 7.0));

  // copy
  const l1Out = exitAmt(t, 1.85, 0.45);
  const l2Out = exitAmt(t, 5.75, 0.45);
  const l3Out = exitAmt(t, 8.25, 0.4);
  const camPush = 1 + 0.015 * ramp(t, 0, LEN);

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `scale(${camPush})` }}>
        {/* desktop world */}
        {worldOpacity > 0.005 ? (
          <div
            style={{
              position: "absolute",
              left: WC[0] - 960 * s,
              top: WC[1] - 540 * s,
              width: 1920,
              height: 1080,
              transformOrigin: "0 0",
              transform: `scale(${s})`,
              opacity: worldOpacity,
              filter: `blur(${wOut * 18}px) saturate(${1 - 0.5 * wOut})`,
              boxShadow: "0 40px 120px rgba(0,0,0,0.6)",
              borderRadius: 28,
            }}
          >
            <World t={t} />
          </div>
        ) : null}
        {/* anxiety vignette over the desktop */}
        <AbsoluteFill style={{ background: `radial-gradient(ellipse at 50% 55%, rgba(0,0,0,0) 40%, rgba(0,0,0,${0.55 * clamp01(wIn)}) 100%)` }} />
        <Trail pts={pts} o={trailO} />
        {/* soft glow that gathers on the cursor */}
        <Bloom x={cur[0]} y={cur[1]} r={lerp(160, 320, settle)} o={0.18 + 0.2 * settle} />
        <div style={{ position: "absolute", inset: 0, opacity: curShow }}>
          <Cursor x={cur[0]} y={cur[1]} scale={curScale} />
        </div>
      </AbsoluteFill>

      {/* line 1 — centred on black */}
      {t < 2.4 ? (
        <div style={{ position: "absolute", left: 0, right: 0, top: 470, display: "flex", justifyContent: "center", opacity: 1 - l1Out, filter: `blur(${l1Out * 14}px)`, transform: `scale(${1 + l1Out * 0.03})` }}>
          <RevealLine text={lines[0]} t={t} at={0.4} lang={lang} style={{ fontSize: lang === "zh" ? 84 : 76, fontWeight: 600, letterSpacing: lang === "zh" ? 0 : -2 }} />
        </div>
      ) : null}

      {/* line 2 — over the desktop, top band */}
      {t > 2.8 && t < 6.3 ? (
        <div style={{ position: "absolute", left: 0, right: 0, top: 34, display: "flex", justifyContent: "center", opacity: 1 - l2Out, filter: `blur(${l2Out * 12}px)` }}>
          <RevealLine
            text={lines[1]}
            t={t}
            at={3.0}
            lang={lang}
            style={{ fontSize: lang === "zh" ? 64 : 56, fontWeight: 600, letterSpacing: lang === "zh" ? 0 : -1.4, textShadow: "0 4px 30px rgba(0,0,0,0.6)" }}
          />
        </div>
      ) : null}

      {/* line 3 — the question, above the cursor */}
      {t > Q - 0.1 && t < 8.7 ? (
        <div style={{ position: "absolute", left: 0, right: 0, top: 330, display: "flex", justifyContent: "center", opacity: 1 - l3Out, filter: `blur(${l3Out * 14}px)`, transform: `translateY(${-l3Out * 16}px)` }}>
          <RevealLine
            text={lines[2]}
            t={t}
            at={Q}
            lang={lang}
            accent={lang === "zh" ? "光标所在之处" : "right where your cursor is?"}
            per={lang === "zh" ? 0.045 : 0.075}
            style={{ fontSize: lang === "zh" ? 80 : 62, fontWeight: 600, letterSpacing: lang === "zh" ? 0 : -1.6 }}
          />
        </div>
      ) : null}
      <Vignette o={0.55} />
    </AbsoluteFill>
  );
};

export const CUES: FilmCue[] = [
  { sfx: "text_in", at: 0.4, vol: 0.5 },
  { sfx: "heartbeat", at: 1.0, vol: 0.55 },
  { sfx: "whoosh", at: 1.9, vol: 0.4 },
  ...WPS.slice(1).map((_w, i) => ({ sfx: "cursor_whir", at: WPS[i][0] + 0.05, vol: 0.45 })),
  { sfx: "text_in", at: 3.0, vol: 0.45 },
  { sfx: "sub_drop", at: 6.0, vol: 0.6 },
  { sfx: "text_in", at: Q, vol: 0.55 },
];
