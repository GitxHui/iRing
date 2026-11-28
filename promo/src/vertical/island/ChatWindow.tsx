import React from "react";
import { Rect } from "../../lib/anim";
import { FONT } from "../../theme";

const Bar: React.FC<{ w: string; c: string; h?: number; mb?: number }> = ({ w, c, h = 10, mb = 12 }) => (
  <div style={{ width: w, height: h, borderRadius: h / 2, background: c, marginBottom: mb }} />
);

/** Neutral light chat-app window (used for the ChatGPT slot). Same shell as AppWindow. */
export const ChatWindow: React.FC<{ rect: Rect; opacity?: number; scale?: number; focused?: boolean; z?: number }> = ({
  rect,
  opacity = 1,
  scale = 1,
  focused = true,
  z = 1,
}) => {
  if (opacity <= 0.001) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: rect.x,
        top: rect.y,
        width: rect.w,
        height: rect.h,
        borderRadius: 18,
        overflow: "hidden",
        opacity,
        transform: `scale(${scale})`,
        zIndex: z,
        fontFamily: FONT,
        background: "#FFFFFF",
        display: "flex",
        boxShadow: focused
          ? "0 40px 90px rgba(8,22,55,0.38), 0 10px 30px rgba(8,22,55,0.22), 0 0 0 1px rgba(0,0,0,0.14)"
          : "0 20px 50px rgba(8,22,55,0.22), 0 0 0 1px rgba(0,0,0,0.12)",
      }}
    >
      <div style={{ width: "23%", background: "#F4F4F5", padding: "18px 18px" }}>
        <div style={{ display: "flex", gap: 8, marginBottom: 30 }}>
          {["#FF5F57", "#FEBC2E", "#28C840"].map((c) => (
            <div key={c} style={{ width: 13, height: 13, borderRadius: 7, background: focused ? c : "rgba(0,0,0,0.16)" }} />
          ))}
        </div>
        {[0.8, 0.6, 0.72, 0.5, 0.66].map((w, i) => (
          <Bar key={i} w={`${w * 100}%`} c={i === 0 ? "#D4D4D8" : "#E4E4E7"} mb={16} />
        ))}
      </div>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "60px 9% 26px" }}>
        <div style={{ alignSelf: "flex-end", background: "#F1F1F3", borderRadius: 18, padding: "14px 18px", width: "46%", marginBottom: 26 }}>
          <Bar w="100%" c="#D4D4D8" mb={10} />
          <Bar w="58%" c="#D4D4D8" mb={0} />
        </div>
        {[0.95, 0.9, 0.97, 0.62, 0, 0.88, 0.8, 0.45].map((w, i) =>
          w === 0 ? <div key={i} style={{ height: 12 }} /> : <Bar key={i} w={`${w * 100}%`} c="#E1E1E5" />,
        )}
        <div style={{ flex: 1 }} />
        <div
          style={{
            height: 62,
            borderRadius: 31,
            background: "#F4F4F5",
            boxShadow: "0 0 0 1px #E4E4E7",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            padding: "0 14px 0 24px",
          }}
        >
          <Bar w="34%" c="#D4D4D8" mb={0} />
          <div style={{ width: 36, height: 36, borderRadius: 18, background: "#111" }} />
        </div>
      </div>
    </div>
  );
};
