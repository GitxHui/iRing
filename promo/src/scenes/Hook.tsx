import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../components/Sky";
import { AppWindow, WinApp } from "../components/AppWindow";
import { MenuBar } from "../components/MenuBar";
import { Cursor } from "../components/Cursor";
import { clamp01, easeIn, kf, ramp, rand, springAt } from "../lib/anim";
import { COPY, Lang } from "../lib/copy";
import { FONT } from "../theme";

export const HOOK_LEN = 3.6;

const PILE: Array<{ app: WinApp; x: number; y: number; w: number; h: number }> = Array.from({ length: 9 }).map(
  (_, i) => {
    const apps: WinApp[] = ["chrome", "vscode", "claude"];
    return {
      app: apps[i % 3],
      x: 120 + rand(i * 4.1) * 760,
      y: 90 + rand(i * 7.7) * 260,
      w: 820 + rand(i * 2.3) * 240,
      h: 560 + rand(i * 5.9) * 140,
    };
  },
);

export const Hook: React.FC<{ lang: Lang }> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY[lang];

  const exit = ramp(t, 2.9, HOOK_LEN, easeIn);
  const camS = 1.0 + 0.06 * ramp(t, 0, HOOK_LEN) + 0.25 * exit;
  const curX = kf(t, [0, 0.8, 1.4, 2.0, 2.6], [1500, 980, 1320, 760, 1040]);
  const curY = kf(t, [0, 0.8, 1.4, 2.0, 2.6], [820, 420, 620, 520, 700]);
  const titleIn = springAt(t, 0.55, { response: 0.5, damping: 0.8 });
  const subIn = springAt(t, 1.25, { response: 0.5, damping: 0.85 });

  return (
    <AbsoluteFill style={{ background: "#0B1A33", overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          transform: `scale(${camS})`,
          filter: `blur(${exit * 14}px)`,
        }}
      >
        <Sky t={t + 3} />
        {PILE.map((p, i) => {
          const at = 0.05 + i * 0.16;
          const s = springAt(t, at, { response: 0.34, damping: 0.72 });
          if (t < at) return null;
          return (
            <AppWindow
              key={i}
              rect={{ x: p.x, y: p.y + (1 - s) * 60, w: p.w, h: p.h }}
              app={p.app}
              scale={0.86 + 0.14 * s}
              opacity={clamp01(s * 1.6)}
              focused={i === PILE.length - 1}
              z={i}
            />
          );
        })}
        <MenuBar app="Finder" />
        <div style={{ position: "absolute", inset: 0, zIndex: 60 }}>
          <Cursor x={curX} y={curY} />
        </div>
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse at 50% 55%, rgba(5,12,30,${0.25 + 0.3 * titleIn}) 0%, rgba(5,12,30,${0.55 + 0.25 * titleIn}) 100%)`,
        }}
      />
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          fontFamily: FONT,
          color: "#fff",
          textAlign: "center",
          opacity: 1 - exit,
        }}
      >
        <div
          style={{
            fontSize: lang === "zh" ? 112 : 124,
            fontWeight: 800,
            letterSpacing: lang === "zh" ? 2 : -3,
            opacity: clamp01(titleIn * 1.4),
            transform: `translateY(${(1 - titleIn) * 40}px) scale(${0.94 + 0.06 * titleIn})`,
            filter: `blur(${(1 - clamp01(titleIn)) * 12}px)`,
            textShadow: "0 6px 40px rgba(0,0,0,0.35)",
          }}
        >
          {c.hookTitle}
        </div>
        <div
          style={{
            marginTop: 22,
            fontSize: 38,
            fontWeight: 500,
            opacity: clamp01(subIn) * 0.88,
            transform: `translateY(${(1 - subIn) * 24}px)`,
          }}
        >
          {c.hookSub}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
