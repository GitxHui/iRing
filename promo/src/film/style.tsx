/**
 * Keynote design system for the film (shared; owned by the lead).
 * Look: near-black canvas, one restrained light, SF Pro / PingFang Semibold, Apple greys,
 * blur-to-sharp entrances, nothing decorative that does not carry meaning.
 */
import React from "react";
import { clamp01, easeIn, easeOut, ramp, springAt } from "../lib/anim";
import { FONT } from "../theme";

export const C = {
  bg: "#000000",
  ink: "#F5F5F7",
  grey: "#86868B",
  greyDim: "#6E6E73",
  hair: "rgba(255,255,255,0.12)",
  blue: "#2997FF",
  sysBlue: "#0A84FF",
  grad: "linear-gradient(90deg, #2997FF 0%, #A78BFA 55%, #F472B6 100%)",
};

export const T = {
  hero: { fontSize: 132, fontWeight: 600, letterSpacing: -3, lineHeight: 1.04 },
  title: { fontSize: 96, fontWeight: 600, letterSpacing: -2, lineHeight: 1.06 },
  sub: { fontSize: 40, fontWeight: 400, letterSpacing: -0.3, lineHeight: 1.3 },
  eyebrow: { fontSize: 30, fontWeight: 600, letterSpacing: 0.2 },
};

/** Spring presets (SwiftUI-like) */
export const SP = {
  soft: { response: 0.7, damping: 0.92 },
  ui: { response: 0.45, damping: 0.82 },
  pop: { response: 0.38, damping: 0.68 },
};

/** Blur-to-sharp reveal factor helper: returns style for a token appearing at `at`. */
export const revealStyle = (t: number, at: number, dur = 0.55, rise = 28): React.CSSProperties => {
  const p = clamp01(ramp(t, at, at + dur, easeOut));
  return {
    display: "inline-block",
    opacity: p,
    transform: `translateY(${(1 - p) * rise}px)`,
    filter: `blur(${(1 - p) * 14}px)`,
  };
};

const ACCENT_STOPS: Array<[number, [number, number, number]]> = [
  [0, [41, 151, 255]],
  [0.55, [167, 139, 250]],
  [1, [244, 114, 182]],
];
/** Colour at position p (0..1) along the brand gradient. */
export const accentColor = (p: number) => {
  const x = Math.max(0, Math.min(1, p));
  let i = 0;
  while (i < ACCENT_STOPS.length - 2 && x > ACCENT_STOPS[i + 1][0]) i++;
  const [a, ca] = ACCENT_STOPS[i];
  const [b, cb] = ACCENT_STOPS[i + 1];
  const k = (x - a) / (b - a);
  const c = ca.map((v, j) => Math.round(v + (cb[j] - v) * k));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
};

/**
 * Wordmark with a moving light sweep, drawn as SVG text + SVG gradient.
 * CSS background-clip:text renders a solid box in the headless renderer once filters/opacity
 * are involved, so it must never be used in the film. `sweep` 0..1 = highlight position.
 */
export const SweepText: React.FC<{
  text: string;
  fontSize: number;
  letterSpacing?: number;
  fontWeight?: number;
  sweep: number;
  base?: string;
  glint?: string;
  width?: number;
  band?: number;
}> = ({ text, fontSize, letterSpacing = 0, fontWeight = 600, sweep, base = C.ink, glint = "#A9C8FF", width = 900, band = 0.16 }) => {
  const id = React.useId().replace(/[^a-zA-Z0-9]/g, "");
  const h = Math.round(fontSize * 1.25);
  const st = (v: number) => Math.max(0, Math.min(1, v));
  return (
    <svg width={width} height={h} viewBox={`0 0 ${width} ${h}`} style={{ overflow: "visible", display: "block" }}>
      <defs>
        <linearGradient id={`sw${id}`} x1="0" y1="0" x2="1" y2="0.18">
          <stop offset={st(sweep - band * 2)} stopColor={base} />
          <stop offset={st(sweep - band * 0.5)} stopColor="#FFFFFF" />
          <stop offset={st(sweep)} stopColor={glint} />
          <stop offset={st(sweep + band * 0.5)} stopColor="#FFFFFF" />
          <stop offset={st(sweep + band * 2)} stopColor={base} />
        </linearGradient>
      </defs>
      <text x={0} y={Math.round(fontSize * 0.95)} fill={`url(#sw${id})`} style={{ fontFamily: FONT, fontSize, fontWeight, letterSpacing }}>
        {text}
      </text>
    </svg>
  );
};

/** Exit factor 0..1 (use for fade + blur + slight scale out). */
export const exitAmt = (t: number, at: number, dur = 0.4) => ramp(t, at, at + dur, easeIn);

/**
 * Keynote text line with per-token reveal. zh splits per character, en per word.
 * `accent` tokens (substring match) are painted with the gradient.
 */
export const RevealLine: React.FC<{
  text: string;
  t: number;
  at: number;
  lang: "zh" | "en";
  style?: React.CSSProperties;
  per?: number;
  accent?: string;
  color?: string;
}> = ({ text, t, at, lang, style, per, accent, color = C.ink }) => {
  const toks = lang === "zh" ? Array.from(text) : text.split(" ");
  const step = per ?? (lang === "zh" ? 0.035 : 0.07);
  let accentRange: [number, number] | null = null;
  if (accent) {
    const joined = lang === "zh" ? text : toks.join(" ");
    const idx = joined.indexOf(accent);
    if (idx >= 0) {
      if (lang === "zh") accentRange = [idx, idx + Array.from(accent).length];
      else {
        const before = joined.slice(0, idx).split(" ").length - 1;
        accentRange = [before, before + accent.split(" ").length];
      }
    }
  }
  return (
    <div style={{ fontFamily: FONT, color, whiteSpace: "nowrap", ...style }}>
      {toks.map((tok, i) => {
        const isAcc = accentRange && i >= accentRange[0] && i < accentRange[1];
        return (
          <span
            key={i}
            style={{
              ...revealStyle(t, at + i * step),
              marginRight: lang === "zh" ? 0 : "0.25em",
            }}
          >
            {/* accent: per-token solid colours along the brand gradient (background-clip:text breaks in the renderer) */}
            {isAcc && accentRange ? (
              <span style={{ color: accentColor((i - accentRange[0]) / Math.max(1, accentRange[1] - accentRange[0] - 1)) }}>
                {tok === " " ? " " : tok}
              </span>
            ) : tok === " " ? (
              " "
            ) : (
              tok
            )}
          </span>
        );
      })}
    </div>
  );
};

/** Eyebrow + title + sub block, left aligned on the keynote grid (x = 140). */
export const TitleBlock: React.FC<{
  t: number;
  at: number;
  lang: "zh" | "en";
  eyebrow?: string;
  title: string;
  sub?: string;
  x?: number;
  y?: number;
  align?: "left" | "center";
  exitAt?: number;
  scale?: number;
}> = ({ t, at, lang, eyebrow, title, sub, x = 140, y = 150, align = "left", exitAt = 1e9, scale = 1 }) => {
  const out = exitAmt(t, exitAt);
  const e = springAt(t, at, SP.ui);
  return (
    <div
      style={{
        position: "absolute",
        left: align === "left" ? x : 0,
        right: align === "center" ? 0 : undefined,
        top: y,
        textAlign: align,
        display: "flex",
        flexDirection: "column",
        alignItems: align === "center" ? "center" : "flex-start",
        opacity: 1 - out,
        filter: `blur(${out * 12}px)`,
        transform: `translateY(${-out * 20}px) scale(${scale})`,
        transformOrigin: align === "center" ? "50% 0" : "0 0",
      }}
    >
      {eyebrow ? (
        <div style={{ fontFamily: FONT, color: C.blue, ...T.eyebrow, opacity: clamp01(e), marginBottom: 18 }}>{eyebrow}</div>
      ) : null}
      <RevealLine text={title} t={t} at={at + 0.08} lang={lang} style={{ ...T.title, letterSpacing: lang === "zh" ? 0 : T.title.letterSpacing }} />
      {sub ? (
        <RevealLine text={sub} t={t} at={at + 0.35} lang={lang} color={C.grey} per={lang === "zh" ? 0.012 : 0.03} style={{ ...T.sub, marginTop: 22 }} />
      ) : null}
    </div>
  );
};

/** One soft light bloom on black. */
export const Bloom: React.FC<{ x: number; y: number; r: number; color?: string; o?: number }> = ({
  x,
  y,
  r,
  color = "41,120,255",
  o = 0.28,
}) => (
  <div
    style={{
      position: "absolute",
      left: x - r,
      top: y - r,
      width: r * 2,
      height: r * 2,
      background: `radial-gradient(closest-side, rgba(${color},${o}), rgba(${color},0))`,
      pointerEvents: "none",
    }}
  />
);

/** Fine film grain + vignette to make flat black feel cinematic. */
export const Vignette: React.FC<{ o?: number }> = ({ o = 0.6 }) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      background: `radial-gradient(ellipse at 50% 50%, rgba(0,0,0,0) 55%, rgba(0,0,0,${o}) 100%)`,
      pointerEvents: "none",
    }}
  />
);
