/**
 * Film scene 9 — Finale (abs 56.0–60.5, 4.5 s).
 * In  : black (Details ends on black). Local 0 = the final musical hit.
 * Look: one soft light, centred lock-up, generous whitespace, grey meta, blue CTA; fades to black.
 */
import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { COPY, FilmCue, FilmSceneProps } from "../contract";
import { Bloom, C, RevealLine, SP, SweepText, T as TY } from "../style";
import { clamp01, easeIn, easeOut, lerp, ramp, springAt } from "../../lib/anim";
import { FONT } from "../../theme";

export const FINALE_LEN = 4.5;
const F = { icon: 0.05, word: 0.32, sweep: 0.9, line: 1.3, meta: 1.9, cta: 2.3, out: 4.1 };

export const Finale: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const copy = COPY.finale[lang];

  const icon = springAt(t, F.icon, SP.pop);
  const word = springAt(t, F.word, SP.ui);
  const meta = springAt(t, F.meta, SP.ui);
  const cta = springAt(t, F.cta, SP.ui);
  const out = ramp(t, F.out, FINALE_LEN, easeIn);
  const flash = Math.exp(-Math.max(0, t) * 5) * (t >= 0 ? 1 : 0);
  const sweepX = lerp(-40, 140, ramp(t, F.sweep, F.sweep + 0.8, easeOut));
  const push = 1 + 0.03 * ramp(t, 0, FINALE_LEN);

  // lock-up geometry (icon + wordmark centred as one unit)
  const ICON = 168;
  const WORD_W = 330;
  const GAP = 34;
  const unitW = ICON + GAP + WORD_W;
  const ux = 960 - unitW / 2;
  const uy = 330;

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <AbsoluteFill style={{ opacity: 1 - out, transform: `scale(${push})` }}>
        {/* final hit: a single breath of light, then a steady glow behind the lock-up */}
        <Bloom x={960} y={420} r={lerp(300, 1100, clamp01(t / 0.6))} o={0.32 * flash} color="120,170,255" />
        <Bloom x={960} y={430} r={760} o={0.17 * clamp01(icon)} />

        {/* icon */}
        <Img
          src={staticFile("icons/iring.png")}
          style={{
            position: "absolute",
            left: ux,
            top: uy,
            width: ICON,
            height: ICON,
            opacity: clamp01(icon * 1.8),
            transform: `scale(${0.7 + 0.3 * icon})`,
            filter: `drop-shadow(0 24px 48px rgba(0,0,0,0.6)) blur(${(1 - clamp01(icon)) * 10}px)`,
          }}
        />
        {/* wordmark with a light sweep */}
        <div
          style={{
            position: "absolute",
            left: ux + ICON + GAP,
            top: uy + 10,
            width: WORD_W + 40,
            fontFamily: FONT,
            fontSize: 150,
            fontWeight: 600,
            letterSpacing: -5,
            lineHeight: 1,
            whiteSpace: "nowrap",
            opacity: clamp01(word * 1.5),
            transform: `translateX(${(1 - word) * -24}px)`,
            filter: `blur(${(1 - clamp01(word)) * 12}px)`,
          }}
        >
          <SweepText text={copy.name} fontSize={150} letterSpacing={-5} sweep={sweepX / 100} band={0.16} />
        </div>

        {/* tagline */}
        <div style={{ position: "absolute", left: 0, right: 0, top: 590, display: "flex", justifyContent: "center" }}>
          <RevealLine
            text={copy.line}
            t={t}
            at={F.line}
            lang={lang}
            style={{ ...TY.title, fontSize: 64, letterSpacing: lang === "zh" ? 1 : -1.4 }}
          />
        </div>

        {/* meta + CTA */}
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 710,
            textAlign: "center",
            fontFamily: FONT,
            ...TY.sub,
            fontSize: 32,
            color: C.grey,
            opacity: clamp01(meta),
            transform: `translateY(${(1 - meta) * 16}px)`,
            filter: `blur(${(1 - clamp01(meta)) * 8}px)`,
          }}
        >
          {copy.meta}
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 770,
            textAlign: "center",
            fontFamily: FONT,
            fontSize: 32,
            fontWeight: 600,
            color: C.blue,
            opacity: clamp01(cta),
            transform: `translateY(${(1 - cta) * 16}px)`,
            filter: `blur(${(1 - clamp01(cta)) * 8}px)`,
          }}
        >
          {copy.cta}
          <span style={{ display: "inline-block", marginLeft: 10, transform: `translateX(${Math.sin(Math.max(0, t - F.cta) * 4) * 3}px)` }}>›</span>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const CUES: FilmCue[] = [
  { sfx: "impact", at: 0.0, vol: 0.9 },
  { sfx: "boom", at: 0.0, vol: 0.55 },
  { sfx: "shimmer", at: 0.1, vol: 0.45 },
  { sfx: "lightsweep", at: F.sweep, vol: 0.5 },
  { sfx: "text_in", at: F.line, vol: 0.3 },
  { sfx: "tile_1", at: F.meta, vol: 0.35 },
  { sfx: "tile_3", at: F.cta, vol: 0.4 },
];
