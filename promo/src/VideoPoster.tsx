import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { Reveal } from "./scenes/Reveal";
import { Lang } from "./lib/copy";
import { FONT } from "./theme";

/** README poster: brand frame with a play button, linking to the full film. */
export const VideoPoster: React.FC<{ lang: Lang }> = ({ lang }) => (
  <AbsoluteFill>
    <Sequence from={-Math.round(3.2 * 60)}>
      <Reveal lang={lang} />
    </Sequence>
    <AbsoluteFill style={{ background: "linear-gradient(0deg, rgba(4,10,26,0.55), rgba(4,10,26,0) 45%)" }} />
    <div
      style={{
        position: "absolute",
        left: "50%",
        bottom: 110,
        transform: "translateX(-50%)",
        display: "flex",
        alignItems: "center",
        gap: 22,
        padding: "20px 40px 20px 22px",
        borderRadius: 999,
        background: "rgba(255,255,255,0.16)",
        backdropFilter: "blur(20px) saturate(1.6)",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.45), 0 20px 50px rgba(0,0,0,0.35)",
        fontFamily: FONT,
        color: "#fff",
        fontSize: 38,
        fontWeight: 700,
      }}
    >
      <div
        style={{
          width: 76,
          height: 76,
          borderRadius: 38,
          background: "#fff",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0 8px 20px rgba(0,0,0,0.25)",
        }}
      >
        <svg width={30} height={34} viewBox="0 0 30 34">
          <path d="M4 3 L27 17 L4 31 Z" fill="#0A6CF0" strokeLinejoin="round" />
        </svg>
      </div>
      {lang === "zh" ? "观看 35 秒宣传片 · 有声" : "Watch the 35-second film · Sound on"}
    </div>
  </AbsoluteFill>
);
