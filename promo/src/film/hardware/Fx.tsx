/** Small shared effects for the Entries scene: press burst, glass dot ring, light beam. */
import React from "react";
import { clamp01, easeOut, ramp } from "../../lib/anim";

/** Blue press flash + expanding hairline shockwave, starting at `at`. */
export const PressBurst: React.FC<{ t: number; at: number; x: number; y: number; size?: number }> = ({ t, at, x, y, size = 1 }) => {
  if (t < at || t > at + 1.2) return null;
  const p = ramp(t, at, at + 0.9, easeOut);
  const f = 1 - clamp01((t - at) / 0.45);
  return (
    <>
      <div
        style={{
          position: "absolute",
          left: x - 260 * size,
          top: y - 260 * size,
          width: 520 * size,
          height: 520 * size,
          borderRadius: "50%",
          background: "radial-gradient(closest-side, rgba(150,205,255,0.95), rgba(10,132,255,0.45) 45%, rgba(10,132,255,0))",
          opacity: f,
          transform: `scale(${0.4 + 0.8 * p})`,
          mixBlendMode: "screen",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: x - 400 * size * p,
          top: y - 400 * size * p,
          width: 800 * size * p,
          height: 800 * size * p,
          borderRadius: "50%",
          border: `${1.5 + 2 * (1 - p)}px solid rgba(150,200,255,${0.8 * (1 - p)})`,
        }}
      />
    </>
  );
};

/** Plain glass donut without icons (handoff from Reveal). */
export const GlassDonut: React.FC<{ x: number; y: number; r: number; opacity?: number; glow?: number }> = ({ x, y, r, opacity = 1, glow = 0 }) => {
  const ri = r * 0.47;
  return (
    <div style={{ position: "absolute", left: x - r, top: y - r, width: r * 2, height: r * 2, opacity }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: "50%",
          background: `radial-gradient(circle, transparent ${ri - 0.5}px, rgba(246,247,250,0.86) ${ri + 0.5}px)`,
          boxShadow: `0 14px 34px rgba(0,0,0,0.5), 0 0 ${40 * glow}px rgba(41,151,255,${0.8 * glow})`,
        }}
      />
      <svg width={r * 2} height={r * 2} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
        <circle cx={r} cy={r} r={r - 0.7} fill="none" stroke="rgba(255,255,255,0.95)" strokeWidth={1.2} />
        <circle cx={r} cy={r} r={ri + 0.7} fill="none" stroke="rgba(255,255,255,0.8)" strokeWidth={1} />
      </svg>
    </div>
  );
};

/** Light beam travelling from (x0,y0) to (x1,y1); `p` 0..1 = head position. */
export const Beam: React.FC<{ x0: number; y0: number; x1: number; y1: number; p: number; o?: number; id: string }> = ({ x0, y0, x1, y1, p, o = 1, id }) => {
  if (o <= 0.01) return null;
  const hx = x0 + (x1 - x0) * p;
  const hy = y0 + (y1 - y0) * p;
  const tail = Math.max(0, p - 0.35);
  const tx = x0 + (x1 - x0) * tail;
  const ty = y0 + (y1 - y0) * tail;
  return (
    <svg width={1920} height={1080} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", opacity: o }}>
      <defs>
        <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={tx} y1={ty} x2={hx} y2={hy}>
          <stop offset="0" stopColor="#2997FF" stopOpacity="0" />
          <stop offset="1" stopColor="#BFE0FF" stopOpacity="1" />
        </linearGradient>
      </defs>
      <line x1={tx} y1={ty} x2={hx} y2={hy} stroke={`url(#${id})`} strokeWidth={10} strokeLinecap="round" style={{ filter: "blur(6px)" }} />
      <line x1={tx} y1={ty} x2={hx} y2={hy} stroke={`url(#${id})`} strokeWidth={3} strokeLinecap="round" />
      <circle cx={hx} cy={hy} r={7} fill="#E6F2FF" style={{ filter: "drop-shadow(0 0 12px #2997FF)" }} />
    </svg>
  );
};
