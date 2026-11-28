import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../components/Sky";
import { Ring } from "../components/Ring";
import { Keycap } from "../components/Keys";
import { RING_APPS } from "../lib/apps";
import { clamp01, easeIn, easeInOut, easeOut, kf, lerp, ramp, springAt, window01 } from "../lib/anim";
import { COPY, Lang } from "../lib/copy";
import { FONT, H, W } from "../theme";

export const REVEAL_LEN = 3.9;
export const R = { ring: 0.12, sweepA: 0.3, sweepB: 1.45, close: 1.5, logo: 1.55, word: 1.9, tag: 2.3 };

export const Reveal: React.FC<{ lang: Lang }> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY[lang];

  const pointer = kf(t, [R.sweepA, R.sweepB], [-90, 270], easeInOut);
  const engage = window01(t, R.sweepA - 0.1, R.close - 0.1, 0.2, 0.15);

  const logoIn = springAt(t, R.logo, { response: 0.5, damping: 0.62 });
  const wordIn = springAt(t, R.word, { response: 0.55, damping: 0.86 });
  const tagIn = springAt(t, R.tag, { response: 0.6, damping: 0.9 });
  const slide = lerp(0, -230, wordIn);
  const exit = ramp(t, REVEAL_LEN - 0.45, REVEAL_LEN, easeIn);

  const shock = ramp(t, R.logo, R.logo + 0.9, easeOut);

  return (
    <AbsoluteFill style={{ background: "#0B1A33", overflow: "hidden" }}>
      <AbsoluteFill style={{ filter: "blur(26px)", transform: `scale(${1.1 + 0.05 * ramp(t, 0, REVEAL_LEN)})` }}>
        <Sky t={t + 6} />
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at 50% 50%, rgba(40,90,200,${0.25 * engage}) 0%, rgba(6,14,34,0.55) 60%, rgba(4,10,26,0.82) 100%)`,
        }}
      />

      <AbsoluteFill style={{ transform: `scale(${1 + 0.08 * exit})`, opacity: 1 - exit }}>
        <Ring
          cx={W / 2}
          cy={H / 2 - 40}
          t={t}
          openAt={R.ring}
          closeAt={R.close}
          pointer={pointer}
          engage={engage}
          apps={RING_APPS}
          size={1.22}
          sparkle={0.6}
        />

        {/* shockwave */}
        {t > R.logo ? (
          <div
            style={{
              position: "absolute",
              left: W / 2 - 900 * shock,
              top: H / 2 - 900 * shock,
              width: 1800 * shock,
              height: 1800 * shock,
              borderRadius: "50%",
              border: `${lerp(6, 1, shock)}px solid rgba(150,195,255,${0.7 * (1 - shock)})`,
              boxShadow: `0 0 60px rgba(60,140,255,${0.5 * (1 - shock)})`,
            }}
          />
        ) : null}

        {/* lockup */}
        <div
          style={{
            position: "absolute",
            left: W / 2,
            top: H / 2 - 40,
            width: 0,
            height: 0,
            fontFamily: FONT,
          }}
        >
          <Img
            src={staticFile("icons/iring.png")}
            style={{
              position: "absolute",
              left: -110 + slide,
              top: -110,
              width: 220,
              height: 220,
              opacity: clamp01(logoIn * 2),
              transform: `scale(${logoIn})`,
              filter: `drop-shadow(0 20px 40px rgba(0,0,0,0.45)) drop-shadow(0 0 ${30 * (1 - wordIn)}px rgba(80,150,255,0.8))`,
            }}
          />
          <div
            style={{
              position: "absolute",
              left: slide + 130,
              top: -92,
              fontSize: 170,
              fontWeight: 800,
              letterSpacing: -6,
              color: "#fff",
              lineHeight: 1,
              opacity: clamp01(wordIn * 1.4),
              transform: `translateX(${(1 - wordIn) * -40}px)`,
              WebkitMaskImage: `linear-gradient(90deg, #000 ${wordIn * 120 - 20}%, transparent ${wordIn * 120}%)`,
              textShadow: "0 8px 40px rgba(0,0,0,0.35)",
              whiteSpace: "nowrap",
            }}
          >
            iRing
          </div>
          <div
            style={{
              position: "absolute",
              left: -700,
              width: 1400,
              top: 170,
              textAlign: "center",
              fontSize: 42,
              fontWeight: 500,
              color: "rgba(255,255,255,0.88)",
              opacity: clamp01(tagIn),
              transform: `translateY(${(1 - tagIn) * 24}px)`,
              letterSpacing: lang === "zh" ? 2 : 0,
            }}
          >
            {c.revealTag}
          </div>
        </div>
      </AbsoluteFill>

      <div style={{ position: "absolute", left: W / 2 - 75, bottom: 70, opacity: 1 - ramp(t, R.close, R.close + 0.4, easeIn) }}>
        <Keycap glyph="⌥" label="option" down={window01(t, 0.02, R.close - 0.1, 0.08, 0.1)} show={window01(t, 0, R.close, 0.15, 0.35)} width={150} />
      </div>
    </AbsoluteFill>
  );
};
