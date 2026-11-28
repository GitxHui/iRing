import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { Reveal } from "./scenes/Reveal";
import { Lang } from "./contract";
import { FONT } from "../theme";

/** README poster for the keynote film: the iRing lock-up frame + a play pill. */
export const FilmPoster: React.FC<{ lang: Lang }> = ({ lang }) => (
  <AbsoluteFill style={{ background: "#000" }}>
    <Sequence from={-Math.round(4.6 * 60)}>
      <Reveal lang={lang} />
    </Sequence>
    <div
      style={{
        position: "absolute",
        left: "50%",
        bottom: 120,
        transform: "translateX(-50%)",
        display: "flex",
        alignItems: "center",
        gap: 22,
        padding: "18px 40px 18px 20px",
        borderRadius: 999,
        background: "rgba(255,255,255,0.12)",
        backdropFilter: "blur(20px) saturate(1.6)",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.35), 0 20px 50px rgba(0,0,0,0.45)",
        fontFamily: FONT,
        color: "#F5F5F7",
        fontSize: 36,
        fontWeight: 600,
        whiteSpace: "nowrap",
      }}
    >
      <div style={{ width: 72, height: 72, borderRadius: 36, background: "#fff", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <svg width={28} height={32} viewBox="0 0 30 34">
          <path d="M4 3 L27 17 L4 31 Z" fill="#0A84FF" />
        </svg>
      </div>
      {lang === "zh" ? "观看 60 秒宣传片 · 有声" : "Watch the 60-second film · Sound on"}
    </div>
  </AbsoluteFill>
);
