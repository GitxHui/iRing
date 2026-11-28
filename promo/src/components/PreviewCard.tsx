import React from "react";
import { Img, staticFile } from "remotion";
import { Rect } from "../lib/anim";
import { BLUE, FONT } from "../theme";

/** Frosted preview of where the window will land (mirrors LoopPreviewView). */
export const PreviewCard: React.FC<{
  rect: Rect;
  opacity: number;
  appId?: string;
  appName?: string;
  percent?: number | null;
}> = ({ rect, opacity, appId, appName, percent = null }) => {
  if (opacity <= 0.001) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: rect.x,
        top: rect.y,
        width: rect.w,
        height: rect.h,
        borderRadius: 22,
        opacity,
        zIndex: 30,
        overflow: "hidden",
        backdropFilter: "blur(10px) saturate(1.4)",
        background: "linear-gradient(135deg, rgba(10,108,240,0.26), rgba(0,80,184,0.12)), rgba(235,242,255,0.16)",
        boxShadow: `inset 0 0 0 4px ${BLUE}, inset 0 0 0 5px rgba(255,255,255,0.55), 0 0 36px rgba(10,108,240,0.55), 0 20px 50px rgba(8,22,55,0.25)`,
        fontFamily: FONT,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {appId ? (
        <>
          <Img
            src={staticFile(`icons/${appId}.png`)}
            style={{ width: 84, height: 84, filter: "drop-shadow(0 6px 12px rgba(0,0,0,0.25))" }}
          />
          <div style={{ marginTop: 10, fontSize: 22, fontWeight: 600, color: "#0E1B33" }}>{appName}</div>
        </>
      ) : null}
      {percent !== null ? (
        <div
          style={{
            position: "absolute",
            top: 22,
            left: "50%",
            transform: "translateX(-50%)",
            padding: "8px 18px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.55)",
            backdropFilter: "blur(10px)",
            boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.6), 0 4px 12px rgba(0,0,0,0.12)",
            fontSize: 22,
            fontWeight: 700,
            color: "#0E1B33",
            fontVariantNumeric: "tabular-nums",
            display: "flex",
            gap: 8,
            alignItems: "center",
          }}
        >
          <span style={{ fontSize: 18 }}>⤡</span>
          {Math.round(percent)}%
        </div>
      ) : null}
    </div>
  );
};
