import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { clamp01, easeIn, easeInOut, easeOut, kf, ramp, springAt } from "../../lib/anim";
import { FONT } from "../../theme";
import { SceneCue, VSceneProps, VW } from "../contract";
import { A, AppleBackdrop, Line, flashAt } from "../kinetic/apple";

const LOGO = 1.35;
const SWEEP = 1.75;
const INFO = 2.15;
const URL = 2.5;
const END = 4.55;

export const CUES: SceneCue[] = [
  { sfx: "boom", at: 0.0, vol: 0.85 },
  { sfx: "impact", at: 0.0, vol: 0.45 },
  { sfx: "shimmer", at: LOGO, vol: 0.5 },
  { sfx: "lightsweep", at: SWEEP, vol: 0.5 },
  { sfx: "tile_1", at: INFO, vol: 0.4 },
  { sfx: "tile_3", at: URL, vol: 0.45 },
];

const COPY = {
  zh: { l1: "一个键，或一个中键，", l2: "管好所有窗口。", info: "免费公测 · macOS 15+ · Apple 芯片", url: "GitHub 搜索 iRing" },
  en: { l1: "One key. Or one click of the wheel.", l2: "Every window, handled.", info: "Free public beta · macOS 15+ · Apple silicon", url: "github.com/GitxHui/iRing" },
};

export const VFinale: React.FC<VSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY[lang];

  const hit = flashAt(t, 0, 5);
  const push = 1 + 0.03 * ramp(t, 0, 5, easeInOut);
  const logo = springAt(t, LOGO, { response: 0.6, damping: 0.8 });
  const word = springAt(t, LOGO + 0.12, { response: 0.6, damping: 0.9 });
  const sweep = kf(t, [SWEEP, SWEEP + 0.8], [-0.3, 1.3], easeInOut);
  const info = clamp01(ramp(t, INFO, INFO + 0.55, easeOut));
  const url = clamp01(ramp(t, URL, URL + 0.55, easeOut));
  const fade = ramp(t, END, 5.0, easeIn);
  const lockY = 1010;

  return (
    <AbsoluteFill style={{ background: A.bg, overflow: "hidden" }}>
      <AppleBackdrop t={t + 9} glow={0.55 + 0.9 * hit + 0.35 * clamp01(logo)} y={lockY} />
      <AbsoluteFill style={{ background: "#DCE8FF", opacity: 0.18 * hit, mixBlendMode: "screen" }} />

      <AbsoluteFill style={{ transform: `scale(${push})`, opacity: 1 - fade }}>
        {/* slogan on the left grid */}
        <div style={{ position: "absolute", left: 0, width: VW, top: 360 }}>
          <Line text={c.l1} t={t} at={0.05} size={lang === "zh" ? 64 : 46} lang={lang} color={A.gray} weight={600} align="center" />
          <div style={{ height: 10 }} />
          <Line text={c.l2} t={t} at={0.45} size={lang === "zh" ? 112 : 88} lang={lang} weight={600} align="center" />
        </div>

        {/* lock-up */}
        <div
          style={{
            position: "absolute",
            left: 0,
            width: VW,
            top: lockY - 92,
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            gap: 30,
          }}
        >
          <Img
            src={staticFile("icons/iring.png")}
            style={{
              width: 184,
              height: 184,
              opacity: clamp01(logo * 1.6),
              transform: `scale(${0.88 + 0.12 * logo})`,
              filter: `drop-shadow(0 24px 48px rgba(0,0,0,0.6))${logo < 0.98 ? ` blur(${(1 - clamp01(logo)) * 10}px)` : ""}`,
            }}
          />
          <div
            style={{
              position: "relative",
              fontFamily: FONT,
              fontSize: 168,
              fontWeight: 600,
              letterSpacing: -5,
              lineHeight: 1,
              color: A.ink,
              opacity: clamp01(word * 1.5),
              transform: `translateX(${(1 - word) * -24}px)`,
              filter: word < 0.98 ? `blur(${(1 - clamp01(word)) * 10}px)` : undefined,
              overflow: "hidden",
              paddingBottom: 12,
            }}
          >
            iRing
            {sweep > -0.25 && sweep < 1.25 ? (
              <div
                style={{
                  position: "absolute",
                  top: 0,
                  bottom: 0,
                  left: `${sweep * 100 - 20}%`,
                  width: "22%",
                  background: "linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,0.65), rgba(255,255,255,0))",
                  mixBlendMode: "overlay",
                  filter: "blur(6px)",
                }}
              />
            ) : null}
          </div>
        </div>

        {/* info lines, centred under the lock-up */}
        <div
          style={{
            position: "absolute",
            left: 0,
            width: VW,
            top: lockY + 150,
            textAlign: "center",
            fontFamily: FONT,
            fontSize: lang === "zh" ? 36 : 32,
            fontWeight: 500,
            color: A.gray,
            opacity: info,
            transform: `translateY(${(1 - info) * 12}px)`,
            filter: info < 0.999 ? `blur(${(1 - info) * 8}px)` : undefined,
          }}
        >
          {c.info}
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            width: VW,
            top: lockY + 214,
            textAlign: "center",
            fontFamily: FONT,
            fontSize: 40,
            fontWeight: 600,
            color: A.accent,
            opacity: url,
            transform: `translateY(${(1 - url) * 12}px)`,
            filter: url < 0.999 ? `blur(${(1 - url) * 8}px)` : undefined,
          }}
        >
          {c.url}
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{ background: "#000", opacity: fade }} />
    </AbsoluteFill>
  );
};
