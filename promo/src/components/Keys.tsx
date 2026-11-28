import React from "react";
import { clamp01, lerp, rand } from "../lib/anim";
import { BLUE, FONT } from "../theme";

/** Glass keycap. `down` 0..1 press amount, `show` 0..1 visibility. */
export const Keycap: React.FC<{
  glyph: string;
  label: string;
  down: number;
  show: number;
  width?: number;
}> = ({ glyph, label, down, show, width = 132 }) => {
  if (show <= 0.001) return null;
  const d = clamp01(down);
  return (
    <div
      style={{
        width,
        height: 104,
        borderRadius: 22,
        position: "relative",
        opacity: show,
        transform: `translateY(${(1 - show) * 24 + d * 5}px) scale(${lerp(0.92, 1, show)})`,
        background: `linear-gradient(180deg, rgba(255,255,255,${lerp(0.42, 0.3, d)}), rgba(255,255,255,${lerp(0.2, 0.14, d)}))`,
        backdropFilter: "blur(20px) saturate(1.6)",
        boxShadow: `inset 0 1px 0 rgba(255,255,255,0.8), inset 0 0 0 1px rgba(255,255,255,0.35), 0 ${lerp(10, 3, d)}px ${lerp(26, 8, d)}px rgba(8,22,55,${lerp(0.3, 0.2, d)}), 0 0 ${d * 30}px rgba(10,108,240,${d * 0.6})`,
        fontFamily: FONT,
        color: "#fff",
        textShadow: "0 1px 3px rgba(0,0,0,0.25)",
        padding: "14px 18px",
        boxSizing: "border-box",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
      }}
    >
      <div style={{ fontSize: 40, fontWeight: 500, lineHeight: 1, textAlign: "right" }}>{glyph}</div>
      <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: 0.4, opacity: 0.9 }}>{label}</div>
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 22,
          boxShadow: `inset 0 0 0 2px ${BLUE}`,
          opacity: d,
        }}
      />
    </div>
  );
};

/** Trackpad with two finger dots gliding by `phase` (-1..1). */
export const Trackpad: React.FC<{ show: number; phase: number; label: string }> = ({ show, phase, label }) => {
  if (show <= 0.001) return null;
  return (
    <div
      style={{
        width: 190,
        height: 104,
        borderRadius: 22,
        position: "relative",
        opacity: show,
        transform: `translateY(${(1 - show) * 24}px)`,
        background: "linear-gradient(180deg, rgba(255,255,255,0.36), rgba(255,255,255,0.16))",
        backdropFilter: "blur(20px) saturate(1.6)",
        boxShadow:
          "inset 0 1px 0 rgba(255,255,255,0.8), inset 0 0 0 1px rgba(255,255,255,0.35), 0 10px 26px rgba(8,22,55,0.3)",
        fontFamily: FONT,
        overflow: "hidden",
      }}
    >
      {[0, 1].map((k) => (
        <div
          key={k}
          style={{
            position: "absolute",
            left: 74 + k * 32,
            top: 38 + phase * 22 + rand(k) * 2,
            width: 22,
            height: 22,
            borderRadius: 11,
            background: "rgba(255,255,255,0.95)",
            boxShadow: `0 0 14px rgba(10,108,240,0.8), 0 ${-phase * 10}px 12px rgba(255,255,255,0.4)`,
          }}
        />
      ))}
      <div
        style={{
          position: "absolute",
          left: 16,
          bottom: 12,
          fontSize: 15,
          fontWeight: 600,
          color: "#fff",
          textShadow: "0 1px 3px rgba(0,0,0,0.25)",
          opacity: 0.9,
        }}
      >
        {label}
      </div>
    </div>
  );
};
