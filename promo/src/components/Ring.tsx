import React from "react";
import { Img, staticFile } from "remotion";
import { AppDef, ringAngle } from "../lib/apps";
import { angDiff, clamp01, lerp, ramp, smoothstep, springAt, easeIn } from "../lib/anim";
import { Sparkles } from "./Sparkles";
import { LayoutGlyph, Zone } from "./LayoutGlyph";

export const R_OUT = 132;
export const R_IN = 62;
export const ORBIT = 236;
export const ICON = 92;

const annulus = (ro: number, ri: number) =>
  `M ${ro} 0 A ${ro} ${ro} 0 1 1 ${-ro} 0 A ${ro} ${ro} 0 1 1 ${ro} 0 Z M ${ri} 0 A ${ri} ${ri} 0 1 0 ${-ri} 0 A ${ri} ${ri} 0 1 0 ${ri} 0 Z`;

const sector = (ro: number, ri: number, a0: number, a1: number) => {
  const r = Math.PI / 180;
  const p = (rad: number, a: number) => `${(Math.cos(a * r) * rad).toFixed(2)} ${(Math.sin(a * r) * rad).toFixed(2)}`;
  const large = a1 - a0 > 180 ? 1 : 0;
  return `M ${p(ro, a0)} A ${ro} ${ro} 0 ${large} 1 ${p(ro, a1)} L ${p(ri, a1)} A ${ri} ${ri} 0 ${large} 0 ${p(ri, a0)} Z`;
};

export type RingProps = {
  cx: number;
  cy: number;
  t: number;
  openAt: number;
  closeAt?: number;
  /** 0 = app ring, 1 = tiling ring */
  mode?: number;
  /** pointer direction in degrees (0 = right, 90 = down) */
  pointer: number;
  /** 0..1 how strongly the pointer is engaged (wedge + selection) */
  engage: number;
  apps: AppDef[];
  size?: number;
  zone?: Zone;
  /** constant sparkle boost (intro) */
  sparkle?: number;
};

export const Ring: React.FC<RingProps> = ({
  cx,
  cy,
  t,
  openAt,
  closeAt = 1e9,
  mode = 0,
  pointer,
  engage,
  apps,
  size = 1,
  zone = "center",
  sparkle = 0,
}) => {
  const open = springAt(t, openAt, { response: 0.36, damping: 0.74 });
  const close = ramp(t, closeAt, closeAt + 0.18, easeIn);
  const vis = open * (1 - close);
  if (t < openAt || vis <= 0.001) return null;

  const n = apps.length;
  const step = 360 / n;
  const wedgeW = lerp(Math.max(step, 34), 45, mode);
  const ringScale = (0.7 + 0.3 * vis) * size;
  const alpha = clamp01(vis * 1.5) * (1 - close);

  const sel = apps.map((_, i) => {
    const d = Math.abs(angDiff(pointer, ringAngle(i, n))) / step;
    return (1 - smoothstep(0.38, 0.62, d)) * engage * (1 - mode);
  });

  const gradId = `wedge-${Math.round(cx)}-${Math.round(cy)}`;
  const pr = (pointer * Math.PI) / 180;

  return (
    <div
      style={{
        position: "absolute",
        left: cx,
        top: cy,
        width: 0,
        height: 0,
        transform: `scale(${ringScale})`,
        opacity: alpha,
      }}
    >
      {/* soft drop shadow */}
      <div
        style={{
          position: "absolute",
          left: -R_OUT,
          top: -R_OUT,
          width: R_OUT * 2,
          height: R_OUT * 2,
          borderRadius: "50%",
          boxShadow: "0 14px 34px rgba(10,25,60,0.22), 0 2px 6px rgba(10,25,60,0.12)",
        }}
      />
      {/* frosted glass body */}
      <div
        style={{
          position: "absolute",
          left: -R_OUT,
          top: -R_OUT,
          width: R_OUT * 2,
          height: R_OUT * 2,
          borderRadius: "50%",
          backdropFilter: "blur(18px) saturate(1.5)",
          WebkitMaskImage: `radial-gradient(circle, transparent ${R_IN - 0.5}px, #000 ${R_IN + 0.5}px)`,
          maskImage: `radial-gradient(circle, transparent ${R_IN - 0.5}px, #000 ${R_IN + 0.5}px)`,
        }}
      />
      {/* inner well */}
      <div
        style={{
          position: "absolute",
          left: -R_IN,
          top: -R_IN,
          width: R_IN * 2,
          height: R_IN * 2,
          borderRadius: "50%",
          backdropFilter: "blur(8px) brightness(0.86) saturate(0.8)",
          background: "rgba(40,55,80,0.10)",
          boxShadow: "inset 0 2px 8px rgba(0,0,0,0.18)",
        }}
      />
      <svg width={1} height={1} style={{ position: "absolute", overflow: "visible" }}>
        <defs>
          <linearGradient
            id={gradId}
            gradientUnits="userSpaceOnUse"
            x1={Math.cos(pr) * R_IN}
            y1={Math.sin(pr) * R_IN}
            x2={Math.cos(pr) * R_OUT}
            y2={Math.sin(pr) * R_OUT}
          >
            <stop offset="0" stopColor="#0A5AD6" />
            <stop offset="1" stopColor="#2A7FFF" />
          </linearGradient>
        </defs>
        <path d={annulus(R_OUT, R_IN)} fillRule="evenodd" fill="rgba(246,247,250,0.84)" />
        {/* wedge glow */}
        <path
          d={sector(R_OUT + 6, R_IN - 2, pointer - wedgeW / 2 - 4, pointer + wedgeW / 2 + 4)}
          fill="#2A7FFF"
          opacity={0.28 * engage}
          style={{ filter: "blur(10px)" }}
        />
        <path
          d={sector(R_OUT, R_IN, pointer - wedgeW / 2, pointer + wedgeW / 2)}
          fill={`url(#${gradId})`}
          opacity={engage}
        />
        <circle r={R_OUT - 0.7} fill="none" stroke="rgba(255,255,255,0.95)" strokeWidth={1.4} />
        <circle r={R_OUT + 0.4} fill="none" stroke="rgba(10,30,70,0.10)" strokeWidth={0.8} />
        <circle r={R_IN + 0.7} fill="none" stroke="rgba(255,255,255,0.85)" strokeWidth={1.2} />
        {/* tiling ticks */}
        {mode > 0.01
          ? [0, 45, 90, 135, 180, 225, 270, 315].map((a) => (
              <line
                key={a}
                x1={Math.cos(((a + 22.5) * Math.PI) / 180) * (R_IN + 6)}
                y1={Math.sin(((a + 22.5) * Math.PI) / 180) * (R_IN + 6)}
                x2={Math.cos(((a + 22.5) * Math.PI) / 180) * (R_OUT - 6)}
                y2={Math.sin(((a + 22.5) * Math.PI) / 180) * (R_OUT - 6)}
                stroke="rgba(20,40,80,0.10)"
                strokeWidth={1.2}
                opacity={mode}
              />
            ))
          : null}
      </svg>

      <Sparkles
        t={t}
        angle={pointer}
        spread={wedgeW}
        radius={R_OUT}
        intensity={Math.max(engage, sparkle) * vis}
        seed={3}
      />

      {/* centre content */}
      {apps.map((a, i) =>
        sel[i] > 0.01 ? (
          <Img
            key={`c-${a.id}`}
            src={staticFile(`icons/${a.id}.png`)}
            style={{
              position: "absolute",
              left: -36,
              top: -36,
              width: 72,
              height: 72,
              opacity: sel[i],
              transform: `scale(${0.8 + 0.2 * sel[i]})`,
              filter: "drop-shadow(0 4px 8px rgba(0,0,0,0.25))",
            }}
          />
        ) : null,
      )}
      {mode > 0.01 ? (
        <div
          style={{
            position: "absolute",
            left: -32,
            top: -22,
            opacity: mode,
            transform: `scale(${0.7 + 0.3 * mode})`,
          }}
        >
          <LayoutGlyph zone={zone} />
        </div>
      ) : null}

      {/* orbiting app icons */}
      {apps.map((a, i) => {
        const ang = ringAngle(i, n);
        const oi = springAt(t, openAt + 0.018 * i, { response: 0.42, damping: 0.72 });
        const r =
          (ORBIT * (0.42 + 0.58 * oi) + sel[i] * 16) * lerp(1, 0.6, mode);
        const s = (0.35 + 0.65 * oi) * (1 + 0.28 * sel[i]) * lerp(1, 0.4, mode);
        const x = Math.cos((ang * Math.PI) / 180) * r;
        const y = Math.sin((ang * Math.PI) / 180) * r;
        const base = a.running ? 1 : 0.5;
        const op = lerp(base, 1, sel[i]) * clamp01(oi * 1.3) * (1 - mode);
        return (
          <Img
            key={a.id}
            src={staticFile(`icons/${a.id}.png`)}
            style={{
              position: "absolute",
              left: x - ICON / 2,
              top: y - ICON / 2,
              width: ICON,
              height: ICON,
              transform: `scale(${s})`,
              opacity: op,
              filter: `saturate(${a.running ? 1 : lerp(0.35, 1, sel[i])}) drop-shadow(0 ${6 + 6 * sel[i]}px ${10 + 8 * sel[i]}px rgba(10,25,60,${0.22 + 0.12 * sel[i]}))`,
              zIndex: sel[i] > 0.5 ? 2 : 1,
            }}
          />
        );
      })}
    </div>
  );
};
