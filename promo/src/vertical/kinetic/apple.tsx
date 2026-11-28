import React from "react";
import { AbsoluteFill } from "remotion";
import { FONT } from "../../theme";
import { clamp01, easeOut, ramp } from "../../lib/anim";
import { VH, VW } from "../contract";

/** Apple-keynote type palette for the vertical cut. */
export const A = {
  bg: "#000000",
  ink: "#F5F5F7",
  gray: "#86868B",
  gray2: "#6E6E73",
  hair: "rgba(255,255,255,0.14)",
  accent: "#2997FF",
  accentGrad: "linear-gradient(90deg, #2997FF 0%, #8A7CFF 55%, #C17CFF 100%)",
};

/** Left grid line used by every kinetic scene (keeps everything inside SAFE). */
export const GRID_X = 96;

/** Pure black stage with one restrained light pool. */
export const AppleBackdrop: React.FC<{
  t: number;
  glow?: number;
  x?: number;
  y?: number;
  rgb?: string;
  size?: number;
}> = ({ t, glow = 1, x = VW / 2, y = VH * 0.55, rgb = "41,120,255", size = 1500 }) => (
  <AbsoluteFill style={{ background: A.bg, overflow: "hidden" }}>
    <div
      style={{
        position: "absolute",
        left: x - size / 2 + Math.sin(t * 0.35) * 30,
        top: y - size / 2 + Math.cos(t * 0.3) * 24,
        width: size,
        height: size,
        background: `radial-gradient(closest-side, rgba(${rgb},${0.2 * glow}), rgba(${rgb},${0.06 * glow}) 55%, rgba(${rgb},0))`,
      }}
    />
  </AbsoluteFill>
);

/**
 * Restrained keynote reveal: each token rises a little and goes blur -> sharp.
 * zh splits by character, en by word. Semibold, white by default, tight Latin tracking.
 */
export const Line: React.FC<{
  text: string;
  t: number;
  at: number;
  size: number;
  lang: "zh" | "en";
  weight?: number;
  color?: string;
  gradient?: string;
  align?: "left" | "center";
  per?: number;
  out?: number;
  lineHeight?: number;
}> = ({ text, t, at, size, lang, weight = 600, color = A.ink, gradient, align = "left", per, out = 0, lineHeight = 1.12 }) => {
  const tokens = lang === "zh" ? Array.from(text) : text.split(" ");
  const step = per ?? (lang === "zh" ? 0.035 : 0.06);
  return (
    <div
      style={{
        fontFamily: FONT,
        fontSize: size,
        fontWeight: weight,
        lineHeight,
        letterSpacing: lang === "zh" ? size * 0.01 : -size * 0.022,
        whiteSpace: "nowrap",
        textAlign: align,
        opacity: 1 - out,
        filter: out > 0.001 ? `blur(${out * 12}px)` : undefined,
        transform: `translateY(${-out * 18}px)`,
      }}
    >
      {tokens.map((tok, i) => {
        const p = clamp01(ramp(t, at + i * step, at + i * step + 0.55, easeOut));
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              opacity: p,
              transform: `translateY(${(1 - p) * size * 0.14}px)`,
              filter: p < 0.999 ? `blur(${(1 - p) * 12}px)` : undefined,
              marginRight: lang === "en" && i < tokens.length - 1 ? "0.24em" : 0,
              color: gradient ? "transparent" : color,
              background: gradient,
              WebkitBackgroundClip: gradient ? "text" : undefined,
              backgroundClip: gradient ? "text" : undefined,
            }}
          >
            {tok === " " ? " " : tok}
          </span>
        );
      })}
    </div>
  );
};

/** Small accent eyebrow above headlines. */
export const Eyebrow: React.FC<{ text: string; t: number; at: number; lang: "zh" | "en"; out?: number }> = ({
  text,
  t,
  at,
  lang,
  out = 0,
}) => {
  const p = clamp01(ramp(t, at, at + 0.5, easeOut));
  return (
    <div
      style={{
        fontFamily: FONT,
        fontSize: 34,
        fontWeight: 600,
        letterSpacing: lang === "zh" ? 4 : 0.5,
        color: A.accent,
        opacity: p * (1 - out),
        transform: `translateY(${(1 - p) * 10}px)`,
        filter: p < 0.999 ? `blur(${(1 - p) * 8}px)` : undefined,
      }}
    >
      {text}
    </div>
  );
};

/** Soft radial light burst (press / impact), screen-blended. */
export const Burst: React.FC<{ x: number; y: number; amount: number; size?: number; rgb?: string }> = ({
  x,
  y,
  amount,
  size = 1400,
  rgb = "70,150,255",
}) =>
  amount > 0.002 ? (
    <div
      style={{
        position: "absolute",
        left: x - size / 2,
        top: y - size / 2,
        width: size,
        height: size,
        background: `radial-gradient(closest-side, rgba(${rgb},${0.55 * amount}), rgba(${rgb},${0.12 * amount}) 45%, rgba(${rgb},0))`,
        mixBlendMode: "screen",
        pointerEvents: "none",
      }}
    />
  ) : null;

/** Exponential flash decay from a hit time. */
export const flashAt = (t: number, at: number, k = 8) => (t >= at ? Math.exp(-(t - at) * k) : 0);
