import React from "react";
import { AbsoluteFill } from "remotion";
import { KEY, VH, VW } from "../contract";
import { FONT } from "../../theme";
import { clamp01, easeOut, ramp, springAt } from "../../lib/anim";

/** Keynote backdrop: near-black with drifting blue/violet light blooms. */
export const Backdrop: React.FC<{ t: number; intensity?: number; focusY?: number }> = ({
  t,
  intensity = 1,
  focusY = 0.55,
}) => (
  <AbsoluteFill style={{ background: KEY.bg, overflow: "hidden" }}>
    <div
      style={{
        position: "absolute",
        left: VW * 0.5 - 900 + Math.sin(t * 0.6) * 60,
        top: VH * focusY - 900 + Math.cos(t * 0.5) * 50,
        width: 1800,
        height: 1800,
        background: `radial-gradient(closest-side, rgba(40,95,255,${0.34 * intensity}), rgba(40,95,255,0))`,
      }}
    />
    <div
      style={{
        position: "absolute",
        left: VW * 0.15 - 600 + Math.cos(t * 0.4) * 80,
        top: VH * (focusY - 0.25) - 600,
        width: 1200,
        height: 1200,
        background: `radial-gradient(closest-side, rgba(150,90,255,${0.22 * intensity}), rgba(150,90,255,0))`,
      }}
    />
    <div
      style={{
        position: "absolute",
        left: VW * 0.9 - 650,
        top: VH * (focusY + 0.22) - 650 + Math.sin(t * 0.7) * 40,
        width: 1300,
        height: 1300,
        background: `radial-gradient(closest-side, rgba(255,110,190,${0.12 * intensity}), rgba(255,110,190,0))`,
      }}
    />
  </AbsoluteFill>
);

export const Vignette: React.FC<{ strength?: number }> = ({ strength = 0.75 }) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(ellipse 75% 60% at 50% 50%, rgba(0,0,0,0) 40%, rgba(0,0,0,${strength}) 100%)`,
      pointerEvents: "none",
    }}
  />
);

/** Per-token reveal: blur-to-sharp, rise, fade. zh splits by character, en by word. */
export const RevealText: React.FC<{
  text: string;
  t: number;
  at: number;
  size: number;
  lang: "zh" | "en";
  per?: number;
  weight?: number;
  gradient?: string;
  color?: string;
  letterSpacing?: number;
  glow?: number;
  out?: number; // 0..1 exit amount
}> = ({ text, t, at, size, lang, per, weight = 800, gradient = KEY.gradText, color, letterSpacing, glow = 0, out = 0 }) => {
  const tokens = lang === "zh" ? Array.from(text) : text.split(" ");
  const step = per ?? (lang === "zh" ? 0.045 : 0.07);
  return (
    <div
      style={{
        fontFamily: FONT,
        fontSize: size,
        fontWeight: weight,
        lineHeight: 1.08,
        letterSpacing: letterSpacing ?? (lang === "zh" ? size * 0.02 : -size * 0.03),
        whiteSpace: "nowrap",
        textAlign: "center",
        opacity: 1 - out,
        filter: out > 0 ? `blur(${out * 14}px)` : undefined,
        transform: `translateY(${-out * 30}px)`,
      }}
    >
      {tokens.map((tok, i) => {
        const p = clamp01(ramp(t, at + i * step, at + i * step + 0.5, easeOut));
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              opacity: p,
              transform: `translateY(${(1 - p) * size * 0.35}px) scale(${1 + (1 - p) * 0.08})`,
              filter: `blur(${(1 - p) * 18}px)`,
              marginRight: lang === "en" && i < tokens.length - 1 ? "0.25em" : 0,
              background: color ? undefined : gradient,
              WebkitBackgroundClip: color ? undefined : "text",
              backgroundClip: color ? undefined : "text",
              color: color ?? "transparent",
              textShadow: glow > 0 ? `0 0 ${glow}px rgba(90,150,255,0.55)` : undefined,
            }}
          >
            {tok === " " ? " " : tok}
          </span>
        );
      })}
    </div>
  );
};

/** Expanding ring shockwave centred at (x,y). */
export const Shockwave: React.FC<{ t: number; at: number; x: number; y: number; max?: number; dur?: number; color?: string; width?: number }> = ({
  t,
  at,
  x,
  y,
  max = 1100,
  dur = 0.9,
  color = "150,195,255",
  width = 8,
}) => {
  if (t < at || t > at + dur) return null;
  const p = ramp(t, at, at + dur, easeOut);
  const r = max * p;
  return (
    <div
      style={{
        position: "absolute",
        left: x - r,
        top: y - r,
        width: r * 2,
        height: r * 2,
        borderRadius: "50%",
        border: `${Math.max(1, width * (1 - p))}px solid rgba(${color},${0.85 * (1 - p)})`,
        boxShadow: `0 0 ${60 * (1 - p)}px rgba(${color},${0.6 * (1 - p)}), inset 0 0 ${40 * (1 - p)}px rgba(${color},${0.4 * (1 - p)})`,
      }}
    />
  );
};

/** Camera shake offset from a list of impact times. */
export const shake = (t: number, hits: number[], amp = 14): [number, number] => {
  let x = 0;
  let y = 0;
  for (const h of hits) {
    if (t < h) continue;
    const d = t - h;
    const e = Math.exp(-d * 14) * amp;
    x += Math.sin(d * 90 + h * 7) * e;
    y += Math.cos(d * 77 + h * 3) * e;
  }
  return [x, y];
};

/** A slam: big scale-down landing with blur and ghost trails. Returns style values. */
export const slam = (t: number, at: number) => {
  const s = springAt(t, at, { response: 0.3, damping: 0.62 });
  return {
    s,
    visible: t >= at,
    scale: 1.45 - 0.45 * s,
    opacity: clamp01(s * 3),
    blur: Math.max(0, (1 - s) * 18),
  };
};
