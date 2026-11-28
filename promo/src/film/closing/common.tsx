/**
 * Shared bits for the closing scenes (island / details / finale).
 */
import React from "react";
import { clamp01, easeIn, easeOut, ramp } from "../../lib/anim";
import { FONT } from "../../theme";
import { C, T as TY, revealStyle } from "../style";

/**
 * Hand-off framing: MacBook3D front-on, full screen filling the frame.
 * Resize must END on this; Island STARTS on it and ENDS on it; Details STARTS on it.
 */
export const FULL_FRAME = { cx: 960, cy: 1044, rx: -2, ry: 0, s: 0.95, lid: 90 };

/** Visible world range inside the 16:10 panel (world is cover-scaled, sides cropped). */
export const VIS = { x0: 96, x1: 1824, y0: 0, y1: 1080 };

/**
 * A line of grey copy that swaps between beats: each beat blurs out upward
 * while the next one reveals.
 */
export const BeatLine: React.FC<{
  t: number;
  lang: "zh" | "en";
  beats: readonly string[];
  /** start time of each beat */
  at: number[];
  /** time the last beat leaves */
  until: number;
  style?: React.CSSProperties;
}> = ({ t, lang, beats, at, until, style }) => {
  return (
    <div style={{ position: "relative", height: 56, fontFamily: FONT, ...style }}>
      {beats.map((b, i) => {
        const start = at[i];
        const end = i + 1 < at.length ? at[i + 1] : until;
        if (t < start - 0.05 || t > end + 0.45) return null;
        const out = ramp(t, end, end + 0.35, easeIn);
        const toks = lang === "zh" ? Array.from(b) : b.split(" ");
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              whiteSpace: "nowrap",
              color: C.grey,
              ...TY.sub,
              opacity: 1 - out,
              filter: `blur(${out * 10}px)`,
              transform: `translateY(${-out * 18}px)`,
            }}
          >
            {/* small blue index dot */}
            <span
              style={{
                display: "inline-block",
                width: 10,
                height: 10,
                borderRadius: 5,
                background: C.blue,
                marginRight: 16,
                verticalAlign: "middle",
                opacity: clamp01(ramp(t, start, start + 0.25, easeOut)),
                transform: "translateY(-4px)",
              }}
            />
            {toks.map((tok, k) => (
              <span key={k} style={{ ...revealStyle(t, start + k * (lang === "zh" ? 0.025 : 0.05), 0.45, 18), marginRight: lang === "zh" ? 0 : "0.25em" }}>
                {tok}
              </span>
            ))}
          </div>
        );
      })}
    </div>
  );
};

/** 0→1 bump that decays (for key/icon pulses). */
export const bump = (t: number, at: number, decay = 4.5) => {
  const x = t - at;
  if (x <= 0) return 0;
  return Math.sin(Math.min(1, x / 0.1) * (Math.PI / 2)) * Math.exp(-x * decay);
};
