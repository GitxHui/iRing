import React from "react";
import { FONT } from "../../theme";
import { KEY } from "../contract";
import { clamp01 } from "../../lib/anim";

/**
 * Frosted glass ⌥ keycap face. Size in px. `sweep` 0..1 moves a light band across.
 * `press` 0..1 lights it up blue. Transforms (3D) are applied by the parent.
 */
export const GlassKeyFace: React.FC<{
  size: number;
  sweep?: number;
  press?: number;
  glyph?: string;
  label?: string;
}> = ({ size, sweep = -1, press = 0, glyph = "⌥", label = "option" }) => {
  const r = size * 0.2;
  const p = clamp01(press);
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      {/* key body thickness */}
      <div
        style={{
          position: "absolute",
          left: 0,
          top: size * 0.05,
          width: size,
          height: size,
          borderRadius: r,
          background: "linear-gradient(180deg, rgba(40,60,110,0.75), rgba(10,16,34,0.95))",
          boxShadow: `0 ${size * 0.12}px ${size * 0.25}px rgba(0,0,0,0.55), 0 0 ${size * 0.35 * (0.35 + p)}px rgba(61,139,255,${0.25 + 0.5 * p})`,
        }}
      />
      {/* top face */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: r,
          overflow: "hidden",
          background: `linear-gradient(160deg, rgba(255,255,255,${0.26 + 0.1 * p}) 0%, rgba(150,175,235,${0.12 + 0.2 * p}) 45%, rgba(40,70,150,${0.22 + 0.4 * p}) 100%)`,
          boxShadow: `inset 0 ${size * 0.006}px 0 rgba(255,255,255,0.9), inset 0 0 0 ${Math.max(1, size * 0.004)}px rgba(255,255,255,0.45), inset 0 -${size * 0.04}px ${size * 0.08}px rgba(10,30,90,0.35)`,
          backdropFilter: "blur(16px) saturate(1.5)",
        }}
      >
        {/* inner blue fill on press */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: `radial-gradient(circle at 50% 60%, rgba(61,139,255,${0.75 * p}), rgba(10,108,240,${0.25 * p}) 70%)`,
          }}
        />
        {/* light sweep */}
        {sweep > -0.9 && sweep < 1.9 ? (
          <div
            style={{
              position: "absolute",
              top: -size * 0.5,
              left: -size + sweep * size * 2,
              width: size * 0.45,
              height: size * 2,
              transform: "rotate(24deg)",
              background:
                "linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.55) 50%, rgba(255,255,255,0) 100%)",
              filter: `blur(${size * 0.02}px)`,
            }}
          />
        ) : null}
        <div
          style={{
            position: "absolute",
            right: size * 0.12,
            top: size * 0.08,
            fontFamily: FONT,
            fontSize: size * 0.4,
            fontWeight: 400,
            color: KEY.ink,
            textShadow: `0 0 ${size * 0.06}px rgba(140,190,255,${0.5 + 0.5 * p})`,
            lineHeight: 1,
          }}
        >
          {glyph}
        </div>
        <div
          style={{
            position: "absolute",
            left: size * 0.12,
            bottom: size * 0.1,
            fontFamily: FONT,
            fontSize: size * 0.12,
            fontWeight: 600,
            letterSpacing: size * 0.003,
            color: "rgba(245,247,252,0.88)",
          }}
        >
          {label}
        </div>
      </div>
    </div>
  );
};

/** Glass mouse with a middle (wheel) button that glows and sinks on `press`. */
export const GlassMouse: React.FC<{ size: number; glow?: number; press?: number; sweep?: number }> = ({
  size,
  glow = 1,
  press = 0,
  sweep = -1,
}) => {
  const w = size * 0.6;
  const h = size * 0.96;
  const p = clamp01(press);
  return (
    <div style={{ position: "relative", width: size, height: size, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div
        style={{
          position: "relative",
          width: w,
          height: h,
          borderRadius: `${w / 2}px ${w / 2}px ${w * 0.46}px ${w * 0.46}px`,
          background: `linear-gradient(160deg, rgba(255,255,255,${0.3 + 0.08 * p}) 0%, rgba(150,175,235,${0.12 + 0.12 * p}) 48%, rgba(40,70,150,${0.3 + 0.2 * p}) 100%)`,
          boxShadow: `inset 0 ${size * 0.006}px 0 rgba(255,255,255,0.9), inset 0 0 0 ${Math.max(1, size * 0.005)}px rgba(255,255,255,0.42), inset 0 -${size * 0.05}px ${size * 0.1}px rgba(10,30,90,0.35), 0 ${size * 0.1}px ${size * 0.22}px rgba(0,0,0,0.55), 0 0 ${size * 0.3 * (0.3 + p)}px rgba(61,139,255,${0.2 * glow + 0.45 * p})`,
          overflow: "hidden",
          backdropFilter: "blur(16px) saturate(1.5)",
        }}
      >
        {/* button split */}
        <div style={{ position: "absolute", left: w / 2 - 0.75, top: 0, width: 1.5, height: h * 0.4, background: "rgba(255,255,255,0.32)" }} />
        <div style={{ position: "absolute", left: 0, right: 0, top: h * 0.4, height: 1.5, background: "rgba(255,255,255,0.18)" }} />
        {/* wheel */}
        <div
          style={{
            position: "absolute",
            left: w / 2 - w * 0.085,
            top: h * 0.11 + p * size * 0.01,
            width: w * 0.17,
            height: h * 0.21,
            borderRadius: w * 0.085,
            background: `linear-gradient(180deg, ${p > 0.05 ? "#5AA9FF" : "rgba(220,230,255,0.85)"}, ${p > 0.05 ? "#0A6CF0" : "rgba(150,170,220,0.75)"})`,
            boxShadow: `0 0 ${size * 0.05 * (glow * 0.4 + p)}px rgba(90,170,255,${0.4 * glow + 0.6 * p}), 0 0 ${size * 0.16 * p}px rgba(61,139,255,${0.8 * p}), inset 0 1px 0 rgba(255,255,255,0.7)`,
          }}
        />
        {sweep > -0.9 && sweep < 1.9 ? (
          <div
            style={{
              position: "absolute",
              top: -size * 0.5,
              left: -size + sweep * size * 1.6,
              width: size * 0.35,
              height: size * 2,
              transform: "rotate(24deg)",
              background: "linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.5) 50%, rgba(255,255,255,0) 100%)",
              filter: `blur(${size * 0.02}px)`,
            }}
          />
        ) : null}
      </div>
    </div>
  );
};
