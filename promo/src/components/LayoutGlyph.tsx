import React from "react";
import { BLUE } from "../theme";

export type Zone = "center" | "left" | "right" | "top" | "bottom" | "tl" | "tr" | "bl" | "br";

const REGIONS: Record<Zone, [number, number, number, number]> = {
  center: [0, 0, 1, 1],
  left: [0, 0, 0.5, 1],
  right: [0.5, 0, 0.5, 1],
  top: [0, 0, 1, 0.5],
  bottom: [0, 0.5, 1, 0.5],
  tl: [0, 0, 0.5, 0.5],
  tr: [0.5, 0, 0.5, 0.5],
  bl: [0, 0.5, 0.5, 0.5],
  br: [0.5, 0.5, 0.5, 0.5],
};

export const zoneFromAngle = (deg: number): Zone => {
  const a = ((deg % 360) + 360) % 360;
  const zones: Zone[] = ["right", "br", "bottom", "bl", "left", "tl", "top", "tr"];
  return zones[Math.round(a / 45) % 8];
};

export const zoneRect = (
  zone: Zone,
  area: { x: number; y: number; w: number; h: number },
  gap = 10,
) => {
  const [rx, ry, rw, rh] = REGIONS[zone];
  return {
    x: area.x + area.w * rx + gap,
    y: area.y + area.h * ry + gap,
    w: area.w * rw - gap * 2,
    h: area.h * rh - gap * 2,
  };
};

/** Tiny screen icon with the chosen region highlighted. */
export const LayoutGlyph: React.FC<{ zone: Zone; w?: number; h?: number }> = ({ zone, w = 64, h = 44 }) => {
  const [rx, ry, rw, rh] = REGIONS[zone];
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
      <rect x={1} y={1} width={w - 2} height={h - 2} rx={7} fill="rgba(255,255,255,0.85)" stroke="rgba(255,255,255,1)" />
      <rect
        x={4 + (w - 8) * rx}
        y={4 + (h - 8) * ry}
        width={(w - 8) * rw - (rw < 1 ? 1.5 : 0)}
        height={(h - 8) * rh - (rh < 1 ? 1.5 : 0)}
        rx={4}
        fill={BLUE}
      />
    </svg>
  );
};
