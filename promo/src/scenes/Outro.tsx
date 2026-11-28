import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../components/Sky";
import { Cursor } from "../components/Cursor";
import { clamp01, easeIn, easeOut, ramp, springAt, trackPt, window01 } from "../lib/anim";
import { COPY, Lang } from "../lib/copy";
import { BLUE, BLUE_DEEP, FONT, H, W } from "../theme";

export const OUTRO_LEN = 5.4;
export const O = { logo: 0.25, word: 0.45, sub: 0.75, pills: 1.1, button: 1.45, url: 1.7, cursor: 2.1, click: 3.25, end: 5.0 };

const Pill: React.FC<{ text: string; s: number }> = ({ text, s }) => (
  <div
    style={{
      padding: "12px 26px",
      borderRadius: 999,
      background: "rgba(255,255,255,0.16)",
      backdropFilter: "blur(16px) saturate(1.6)",
      boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.38)",
      fontSize: 28,
      fontWeight: 600,
      color: "#fff",
      opacity: clamp01(s * 1.4),
      transform: `translateY(${(1 - s) * 20}px)`,
    }}
  >
    {text}
  </div>
);

export const Outro: React.FC<{ lang: Lang }> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY[lang];

  const logo = springAt(t, O.logo, { response: 0.5, damping: 0.66 });
  const word = springAt(t, O.word, { response: 0.55, damping: 0.86 });
  const sub = springAt(t, O.sub, { response: 0.55, damping: 0.9 });
  const p1 = springAt(t, O.pills, { response: 0.5, damping: 0.8 });
  const p2 = springAt(t, O.pills + 0.12, { response: 0.5, damping: 0.8 });
  const btn = springAt(t, O.button, { response: 0.5, damping: 0.7 });
  const url = springAt(t, O.url, { response: 0.5, damping: 0.9 });
  const press = window01(t, O.click, O.click + 0.1, 0.06, 0.2);
  const ripple = ramp(t, O.click, O.click + 0.7, easeOut);
  const fadeOut = ramp(t, O.end, OUTRO_LEN, easeIn);

  const btnY = 760;
  const cur = trackPt(t, [[0, [W + 80, H + 80]], [O.cursor, [W / 2 + 60, btnY + 20]]], { response: 0.7, damping: 1 });

  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#07101F" }}>
      <AbsoluteFill style={{ filter: "blur(34px)", transform: `scale(${1.15 - 0.04 * ramp(t, 0, OUTRO_LEN)})` }}>
        <Sky t={t + 30} />
      </AbsoluteFill>
      <AbsoluteFill
        style={{ background: "radial-gradient(ellipse at 50% 45%, rgba(10,30,80,0.25), rgba(4,10,26,0.8) 75%)" }}
      />
      <AbsoluteFill style={{ fontFamily: FONT, color: "#fff", opacity: 1 - fadeOut }}>
        {/* lockup */}
        <div style={{ position: "absolute", left: W / 2, top: 300, width: 0, height: 0 }}>
          <Img
            src={staticFile("icons/iring.png")}
            style={{
              position: "absolute",
              left: -310,
              top: -95,
              width: 190,
              height: 190,
              transform: `scale(${logo})`,
              opacity: clamp01(logo * 2),
              filter: "drop-shadow(0 18px 36px rgba(0,0,0,0.45))",
            }}
          />
          <div
            style={{
              position: "absolute",
              left: -100,
              top: -80,
              fontSize: 150,
              fontWeight: 800,
              letterSpacing: -5,
              lineHeight: 1,
              opacity: clamp01(word * 1.4),
              transform: `translateX(${(1 - word) * -30}px)`,
              textShadow: "0 8px 40px rgba(0,0,0,0.35)",
              whiteSpace: "nowrap",
            }}
          >
            iRing
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 460,
            textAlign: "center",
            fontSize: 44,
            fontWeight: 550,
            opacity: clamp01(sub) * 0.9,
            transform: `translateY(${(1 - sub) * 24}px)`,
            letterSpacing: lang === "zh" ? 2 : -0.3,
          }}
        >
          {c.outroSub}
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, top: 560, display: "flex", justifyContent: "center", gap: 20 }}>
          <Pill text={c.pillBeta} s={p1} />
          <Pill text={c.pillReq} s={p2} />
        </div>
        {/* download button */}
        <div style={{ position: "absolute", left: 0, right: 0, top: btnY - 45, display: "flex", justifyContent: "center" }}>
          <div
            style={{
              position: "relative",
              padding: "24px 52px",
              borderRadius: 999,
              background: `linear-gradient(180deg, #2A86FF, ${BLUE} 55%, ${BLUE_DEEP})`,
              boxShadow: `inset 0 1px 0 rgba(255,255,255,0.5), 0 16px 40px rgba(10,108,240,${0.45 + press * 0.2}), 0 0 ${40 + 40 * press}px rgba(10,108,240,0.5)`,
              fontSize: 38,
              fontWeight: 700,
              display: "flex",
              alignItems: "center",
              gap: 16,
              opacity: clamp01(btn * 1.4),
              transform: `scale(${(0.85 + 0.15 * btn) * (1 - 0.05 * press)})`,
            }}
          >
            <svg width={30} height={30} viewBox="0 0 24 24">
              <path d="M12 3v12m0 0l-5-5m5 5l5-5M4 20h16" stroke="#fff" strokeWidth={2.6} fill="none" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            {c.download}
            {t > O.click ? (
              <div
                style={{
                  position: "absolute",
                  left: "50%",
                  top: "50%",
                  width: 600 * ripple,
                  height: 600 * ripple,
                  marginLeft: -300 * ripple,
                  marginTop: -300 * ripple,
                  borderRadius: "50%",
                  border: `2px solid rgba(140,190,255,${1 - ripple})`,
                }}
              />
            ) : null}
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: btnY + 80,
            textAlign: "center",
            fontSize: 32,
            fontWeight: 600,
            color: "rgba(200,222,255,0.95)",
            opacity: clamp01(url),
            transform: `translateY(${(1 - url) * 16}px)`,
            letterSpacing: 0.4,
          }}
        >
          {c.url}
        </div>
        <Cursor x={cur[0]} y={cur[1]} scale={1 - 0.12 * press} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
