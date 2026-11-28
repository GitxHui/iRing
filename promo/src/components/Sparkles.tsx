import React from "react";
import { BLUE } from "../theme";
import { rand } from "../lib/anim";

const STAR =
  "M0,-1 C0.12,-0.12 0.12,-0.12 1,0 C0.12,0.12 0.12,0.12 0,1 C-0.12,0.12 -0.12,0.12 -1,0 C-0.12,-0.12 -0.12,-0.12 0,-1Z";

/**
 * Deterministic sparkle field emitted from an arc of the ring around `angle`.
 * Coordinates are relative to the ring centre.
 */
export const Sparkles: React.FC<{
  t: number;
  angle: number;
  spread: number;
  radius: number;
  intensity: number;
  count?: number;
  seed?: number;
}> = ({ t, angle, spread, radius, intensity, count = 64, seed = 1 }) => {
  if (intensity <= 0.001) return null;
  const period = 1.25;
  const items: React.ReactNode[] = [];
  for (let i = 0; i < count; i++) {
    const r1 = rand(seed * 101 + i * 7.3);
    const r2 = rand(seed * 53 + i * 3.1);
    const r3 = rand(seed * 17 + i * 11.7);
    const r4 = rand(seed * 29 + i * 5.9);
    const life = 0.55 + r3 * 0.6;
    const age = (((t + r1 * period) % period) + period) % period;
    if (age > life) continue;
    const p = age / life;
    const a = ((angle + (r2 - 0.5) * spread * 1.6) * Math.PI) / 180;
    const outward = r4 > 0.3 ? 1 : -0.6;
    const dist = radius * (0.75 + r3 * 0.35) + outward * (30 + r1 * 90) * p;
    const swirl = (r2 - 0.5) * 0.5 * p;
    const x = Math.cos(a + swirl) * dist;
    const y = Math.sin(a + swirl) * dist;
    const size = 3 + r4 * 8;
    const alpha = Math.sin(Math.PI * p) * intensity * (0.55 + r2 * 0.45);
    const fill = r3 > 0.62 ? "#FFFFFF" : r3 > 0.3 ? BLUE : "#1E4FB8";
    items.push(
      <path
        key={i}
        d={STAR}
        transform={`translate(${x.toFixed(2)} ${y.toFixed(2)}) scale(${(size * (0.6 + 0.4 * Math.sin(Math.PI * p))).toFixed(2)}) rotate(${(r1 * 40).toFixed(1)})`}
        fill={fill}
        opacity={alpha}
      />,
    );
  }
  return (
    <svg
      width={1}
      height={1}
      style={{ position: "absolute", left: 0, top: 0, overflow: "visible", pointerEvents: "none" }}
    >
      {items}
    </svg>
  );
};
