import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { AppWindow, WinApp } from "../../components/AppWindow";
import { clamp01, easeIn, easeInOut, lerp, rand, ramp } from "../../lib/anim";
import { FONT } from "../../theme";
import { KEY, SceneCue, VH, VSceneProps, VW } from "../contract";
import { Vignette, shake, slam } from "../kinetic/primitives";
import { A, AppleBackdrop } from "../kinetic/apple";

const BEATS = [0, 0.5, 1.0];
const WORDS = { zh: ["窗口。", "太多。", "太乱？"], en: ["Windows.", "Everywhere.", "Chaos?"] };

type Flyer = { app: WinApp; x: number; y: number; z: number; rot: number; vx: number; vy: number; vr: number; at: number };
const APPS: WinApp[] = ["chrome", "vscode", "claude"];
const FLYERS: Flyer[] = Array.from({ length: 14 }).map((_, i) => ({
  app: APPS[i % 3],
  x: rand(i * 3.3) * VW,
  y: 160 + rand(i * 5.7) * (VH - 320),
  z: 0.25 + rand(i * 9.1) * 0.75, // depth: 1 = near
  rot: (rand(i * 2.9) - 0.5) * 30,
  vx: (rand(i * 4.4) - 0.5) * 160,
  vy: (rand(i * 6.6) - 0.5) * 120,
  vr: (rand(i * 8.8) - 0.5) * 22,
  at: (i % 7) * 0.12,
}));

export const CUES: SceneCue[] = [
  { sfx: "slam", at: 0.0, vol: 1 },
  { sfx: "slam", at: 0.5, vol: 1 },
  { sfx: "slam", at: 1.0, vol: 1 },
  { sfx: "window_0", at: 0.06, vol: 0.4 },
  { sfx: "window_1", at: 0.3, vol: 0.4 },
  { sfx: "window_2", at: 0.62, vol: 0.4 },
  { sfx: "window_0", at: 0.86, vol: 0.35 },
  { sfx: "whoosh", at: 1.45, vol: 0.55 },
  // 1.6 s riser lands exactly on the key press (hook-local 4.0)
  { sfx: "riser", at: 2.4, vol: 0.75 },
];

export const VHook: React.FC<VSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const words = WORDS[lang];

  // 1.5 → 2.5: everything is sucked into the centre and we zoom through into darkness
  const suck = ramp(t, 1.5, 2.45, easeIn);
  const [sx, sy] = shake(t, BEATS, 9);
  const push = 1 + 0.04 * ramp(t, 0, 1.5, easeInOut);

  const fit = (w: string) => {
    if (lang === "zh") return 220;
    return Math.min(230, 900 / (w.length * 0.58));
  };

  return (
    <AbsoluteFill style={{ background: KEY.bg, overflow: "hidden" }}>
      <AppleBackdrop t={t} glow={0.7 * (1 - suck)} y={1050} />

      {/* tumbling windows at depth */}
      <AbsoluteFill style={{ transform: `translate(${sx * 0.5}px, ${sy * 0.5}px)` }}>
        {FLYERS.map((f, i) => {
          if (t < f.at) return null;
          const a = clamp01((t - f.at) / 0.25);
          const s = lerp(0.18, 0.5, f.z) * (0.7 + 0.3 * a);
          let x = f.x + f.vx * t * f.z;
          let y = f.y + f.vy * t * f.z;
          // suck towards the centre
          x = lerp(x, VW / 2, suck);
          y = lerp(y, VH / 2, suck);
          const sc = s * (1 - suck * 0.92);
          const blur = (1 - f.z) * 10 + suck * 12;
          const w = 1000;
          const h = 660;
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: x - (w * sc) / 2,
                top: y - (h * sc) / 2,
                width: w * sc,
                height: h * sc,
                opacity: a * (0.25 + 0.4 * f.z) * (1 - suck * 0.6),
                transform: `rotate(${f.rot + f.vr * t + suck * 180 * (i % 2 ? 1 : -1)}deg)`,
                filter: `blur(${blur + 2}px) brightness(${0.45 + 0.3 * f.z})`,
                zIndex: Math.round(f.z * 10),
              }}
            >
              <div style={{ width: w, height: h, transform: `scale(${sc})`, transformOrigin: "0 0" }}>
                <AppWindow rect={{ x: 0, y: 0, w, h }} app={f.app} focused={false} />
              </div>
            </div>
          );
        })}
      </AbsoluteFill>

      {/* slam words */}
      <AbsoluteFill
        style={{
          transform: `translate(${sx}px, ${sy}px) scale(${push * (1 + suck * 2.6)})`,
          opacity: 1 - ramp(t, 1.9, 2.4, easeIn),
          filter: `blur(${suck * 26}px)`,
        }}
      >
        {words.map((w, i) => {
          const st = slam(t, BEATS[i]);
          if (!st.visible) return null;
          const size = fit(w);
          const y = 700 + i * 270;
          const isLast = i === words.length - 1;
          // older words dim slightly when the next one lands
          const dim = i < words.length - 1 ? 1 - 0.35 * ramp(t, BEATS[i + 1], BEATS[i + 1] + 0.2) : 1;
          const ghosts: number[] = [];
          const style: React.CSSProperties = {
            position: "absolute",
            left: 0,
            right: 0,
            top: y - size * 0.6,
            textAlign: "center",
            fontFamily: FONT,
            fontSize: size,
            fontWeight: 600,
            letterSpacing: lang === "zh" ? size * 0.02 : -size * 0.03,
            lineHeight: 1.1,
            whiteSpace: "nowrap",
          };
          return (
            <React.Fragment key={i}>
              {ghosts.map((g, k) => (
                <div
                  key={k}
                  style={{
                    ...style,
                    color: "rgba(120,170,255,1)",
                    opacity: 0.22 / (k + 1) * (1 - (t - BEATS[i]) / 0.14),
                    transform: `scale(${st.scale * g})`,
                    filter: `blur(${8 + k * 6}px)`,
                  }}
                >
                  {w}
                </div>
              ))}
              <div
                style={{
                  ...style,
                  opacity: st.opacity * dim,
                  transform: `scale(${st.scale})`,
                  background: isLast ? A.accentGrad : undefined,
                  WebkitBackgroundClip: isLast ? "text" : undefined,
                  backgroundClip: isLast ? "text" : undefined,
                  color: isLast ? "transparent" : A.ink,
                  filter: st.blur > 0.2 ? `blur(${st.blur}px)` : undefined,
                }}
              >
                {w}
              </div>
            </React.Fragment>
          );
        })}
      </AbsoluteFill>

      {/* flash on every slam */}
      <AbsoluteFill
        style={{
          background: "radial-gradient(circle at 50% 50%, rgba(120,170,255,0.16), rgba(0,0,0,0) 60%)",
          opacity: Math.max(...BEATS.map((b) => (t >= b ? Math.exp(-(t - b) * 12) : 0))),
          pointerEvents: "none",
        }}
      />
      <Vignette strength={0.7 + 0.3 * suck} />
      {/* close to darkness for the hand-off */}
      <AbsoluteFill style={{ background: "#000", opacity: ramp(t, 2.05, 2.5, easeIn) }} />
    </AbsoluteFill>
  );
};
