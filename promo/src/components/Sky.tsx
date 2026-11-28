import React from "react";
import { AbsoluteFill } from "remotion";
import { H, W } from "../theme";

type Cloud = { x: number; y: number; w: number; h: number; o: number; speed: number };

const CLOUDS: Cloud[] = [
  { x: -120, y: 120, w: 900, h: 260, o: 0.75, speed: 9 },
  { x: 620, y: 40, w: 700, h: 200, o: 0.55, speed: 6 },
  { x: 1250, y: 210, w: 980, h: 300, o: 0.7, speed: 11 },
  { x: 220, y: 520, w: 1100, h: 280, o: 0.45, speed: 7 },
  { x: 1300, y: 620, w: 900, h: 240, o: 0.4, speed: 8 },
  { x: -200, y: 820, w: 1000, h: 300, o: 0.5, speed: 5 },
];

/** Procedural macOS-like sky wallpaper. `t` in seconds drives a slow drift. */
export const Sky: React.FC<{ t: number; dim?: number }> = ({ t, dim = 0 }) => {
  return (
    <AbsoluteFill
      style={{
        background:
          "linear-gradient(180deg, #3E74B0 0%, #5D8FC4 38%, #8DB3D9 72%, #B9CFE3 100%)",
        overflow: "hidden",
      }}
    >
      {/* sun bloom */}
      <div
        style={{
          position: "absolute",
          left: W * 0.62,
          top: -260,
          width: 1100,
          height: 900,
          background:
            "radial-gradient(closest-side, rgba(255,248,235,0.55), rgba(255,248,235,0))",
        }}
      />
      {CLOUDS.map((c, i) => {
        const dx = ((c.x + t * c.speed + 400) % (W + 1200)) - 400;
        return (
          <div key={i} style={{ position: "absolute", left: dx, top: c.y, width: c.w, height: c.h }}>
            {[0, 1, 2, 3].map((k) => (
              <div
                key={k}
                style={{
                  position: "absolute",
                  left: `${8 + k * 22}%`,
                  top: `${k % 2 === 0 ? 18 : 0}%`,
                  width: `${46 + (k % 3) * 8}%`,
                  height: `${80 + (k % 2) * 20}%`,
                  borderRadius: "50%",
                  background: `radial-gradient(closest-side, rgba(255,255,255,${c.o}), rgba(255,255,255,0))`,
                }}
              />
            ))}
          </div>
        );
      })}
      {/* distant ridge for depth */}
      <svg
        width={W}
        height={H}
        viewBox={`0 0 ${W} ${H}`}
        style={{ position: "absolute", inset: 0 }}
      >
        <defs>
          <linearGradient id="ridge" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#58708C" stopOpacity="0.55" />
            <stop offset="1" stopColor="#2E3F55" stopOpacity="0.85" />
          </linearGradient>
        </defs>
        <path
          d={`M0 ${H - 120} C 260 ${H - 210}, 420 ${H - 150}, 640 ${H - 190} S 1040 ${H - 120}, 1260 ${H - 170} S 1660 ${H - 230}, ${W} ${H - 150} L ${W} ${H} L 0 ${H} Z`}
          fill="url(#ridge)"
        />
      </svg>
      {dim > 0 ? (
        <AbsoluteFill style={{ background: `rgba(8,18,38,${dim})` }} />
      ) : null}
    </AbsoluteFill>
  );
};
