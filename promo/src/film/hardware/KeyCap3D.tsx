/**
 * One big extruded keycap (matches the MacBook3D dark keys). Reusable.
 *   <KeyCap3D x={420} y={640} size={220} pitch={52} yaw={18} press={p} glow={g} glyph="⌥" label="option" />
 */
import React from "react";

export const KeyCap3D: React.FC<{
  x: number;
  y: number;
  size?: number;
  pitch?: number;
  yaw?: number;
  press?: number;
  glow?: number;
  glyph?: string;
  label?: string;
  opacity?: number;
}> = ({ x, y, size = 220, pitch = 50, yaw = 15, press = 0, glow = 0, glyph = "⌥", label = "option", opacity = 1 }) => {
  const depth = size * 0.22;
  const n = 10;
  const travel = depth * 0.45 * press;
  const r = size * 0.14;
  return (
    <div style={{ position: "absolute", left: x, top: y, width: 0, height: 0, perspective: 1800, opacity }}>
      <div style={{ position: "absolute", transformStyle: "preserve-3d", transform: `rotateX(${pitch}deg) rotateZ(${yaw}deg)` }}>
        {/* well / deck */}
        <div
          style={{
            position: "absolute",
            left: -size * 0.75,
            top: -size * 0.75,
            width: size * 1.5,
            height: size * 1.5,
            borderRadius: r * 1.6,
            background: "radial-gradient(closest-side, #0D0E10 60%, rgba(13,14,16,0))",
            transform: "translateZ(-1px)",
          }}
        />
        {/* glow pool on the deck */}
        <div
          style={{
            position: "absolute",
            left: -size * 0.9,
            top: -size * 0.9,
            width: size * 1.8,
            height: size * 1.8,
            borderRadius: "50%",
            background: "radial-gradient(closest-side, rgba(10,132,255,0.75), rgba(10,132,255,0))",
            opacity: glow,
            transform: "translateZ(0px)",
          }}
        />
        {Array.from({ length: n }, (_, k) => {
          const f = k / (n - 1);
          const col = Math.round(13 + 14 * f);
          return (
            <div
              key={k}
              style={{
                position: "absolute",
                left: -size / 2,
                top: -size / 2,
                width: size,
                height: size,
                borderRadius: r,
                transform: `translateZ(${f * (depth - travel)}px)`,
                background: glow > 0.02 ? `rgb(${col + Math.round(20 * glow)},${col + Math.round(60 * glow)},${col + Math.round(150 * glow)})` : `rgb(${col},${col + 1},${col + 4})`,
              }}
            />
          );
        })}
        {/* top face */}
        <div
          style={{
            position: "absolute",
            left: -size / 2,
            top: -size / 2,
            width: size,
            height: size,
            borderRadius: r,
            transform: `translateZ(${depth - travel + 0.5}px)`,
            background:
              glow > 0.02
                ? `linear-gradient(160deg, rgba(90,170,255,${0.55 + 0.4 * glow}), rgba(10,110,240,${0.6 + 0.35 * glow}))`
                : "linear-gradient(160deg, #2A2B30, #17181B)",
            boxShadow: `inset 0 1px 0 rgba(255,255,255,0.18), inset 0 0 0 1.5px rgba(255,255,255,${0.06 + 0.4 * glow}), 0 0 ${glow * 60}px rgba(10,132,255,${glow * 0.9})`,
            fontFamily: '-apple-system, "SF Pro Display", sans-serif',
            color: glow > 0.3 ? "#fff" : "#A1A1A6",
          }}
        >
          <div style={{ position: "absolute", right: size * 0.12, top: size * 0.08, fontSize: size * 0.34, lineHeight: 1 }}>{glyph}</div>
          <div style={{ position: "absolute", left: size * 0.12, bottom: size * 0.1, fontSize: size * 0.12, fontWeight: 500 }}>{label}</div>
        </div>
      </div>
    </div>
  );
};
