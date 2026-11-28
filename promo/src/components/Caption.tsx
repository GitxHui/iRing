import React from "react";
import { clamp01, easeOut, ramp, easeIn } from "../lib/anim";
import { BLUE, FONT } from "../theme";
import { Lang } from "../lib/copy";

/** Kicker + headline with per-token reveal. Times in seconds. */
export const Caption: React.FC<{
  t: number;
  at: number;
  until: number;
  kicker: string;
  title: string;
  lang: Lang;
}> = ({ t, at, until, kicker, title, lang }) => {
  if (t < at - 0.05 || t > until + 0.5) return null;
  const out = ramp(t, until, until + 0.35, easeIn);
  const tokens = lang === "zh" ? Array.from(title) : title.split(" ");
  const per = lang === "zh" ? 0.028 : 0.055;
  const k = ramp(t, at, at + 0.35, easeOut);
  return (
    <div
      style={{
        position: "absolute",
        left: 96,
        bottom: 92,
        fontFamily: FONT,
        zIndex: 80,
        opacity: 1 - out,
        transform: `translateY(${-out * 16}px)`,
      }}
    >
      <div
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 10,
          padding: "8px 16px 8px 12px",
          borderRadius: 999,
          background: "rgba(255,255,255,0.2)",
          backdropFilter: "blur(16px) saturate(1.6)",
          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.4)",
          color: "#fff",
          fontSize: 20,
          fontWeight: 650,
          letterSpacing: lang === "zh" ? 1 : 0.6,
          textTransform: "uppercase",
          opacity: k,
          transform: `translateY(${(1 - k) * 14}px)`,
          marginBottom: 18,
        }}
      >
        <div style={{ width: 10, height: 10, borderRadius: 5, background: BLUE, boxShadow: `0 0 10px ${BLUE}` }} />
        {kicker}
      </div>
      <div
        style={{
          fontSize: 76,
          fontWeight: 700,
          letterSpacing: lang === "zh" ? 1 : -1.6,
          color: "#fff",
          lineHeight: 1.05,
          textShadow: "0 2px 24px rgba(5,15,40,0.35), 0 1px 3px rgba(5,15,40,0.3)",
          whiteSpace: "nowrap",
        }}
      >
        {tokens.map((tok, i) => {
          const p = clamp01(ramp(t, at + 0.12 + i * per, at + 0.12 + i * per + 0.45, easeOut));
          return (
            <span
              key={i}
              style={{
                display: "inline-block",
                opacity: p,
                transform: `translateY(${(1 - p) * 34}px)`,
                filter: `blur(${(1 - p) * 10}px)`,
                marginRight: lang === "zh" ? 0 : "0.24em",
              }}
            >
              {tok === " " ? "\u00A0" : tok}
            </span>
          );
        })}
      </div>
    </div>
  );
};
