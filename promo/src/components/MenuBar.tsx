import React from "react";
import { FONT, MENU_H, W } from "../theme";

export const NOTCH_W = 200;

export const MenuBar: React.FC<{ app: string; opacity?: number }> = ({ app, opacity = 1 }) => (
  <div
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      width: W,
      height: MENU_H,
      opacity,
      background: "rgba(255,255,255,0.18)",
      backdropFilter: "blur(24px) saturate(1.6)",
      display: "flex",
      alignItems: "center",
      fontFamily: FONT,
      fontSize: 15,
      color: "rgba(255,255,255,0.96)",
      textShadow: "0 1px 2px rgba(0,0,0,0.18)",
      padding: "0 22px",
      gap: 24,
      zIndex: 50,
    }}
  >
    <div style={{ width: 14, height: 14, borderRadius: 4, background: "rgba(255,255,255,0.92)" }} />
    <b style={{ fontWeight: 700 }}>{app}</b>
    {["File", "Edit", "View", "Window", "Help"].map((m) => (
      <span key={m} style={{ fontWeight: 500 }}>
        {m}
      </span>
    ))}
    <div style={{ flex: 1 }} />
    {/* iRing status item */}
    <svg width={18} height={18} viewBox="0 0 20 20">
      <path d="M5 13.5 A6.2 6.2 0 1 1 15 13.5" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round" />
      <circle cx={10} cy={13.6} r={1.6} fill="#fff" />
    </svg>
    <span style={{ fontWeight: 500 }}>100%</span>
    <span style={{ fontWeight: 500 }}>Fri 9:41</span>
    {/* notch */}
    <div
      style={{
        position: "absolute",
        left: W / 2 - NOTCH_W / 2,
        top: 0,
        width: NOTCH_W,
        height: MENU_H + 2,
        background: "#000",
        borderRadius: "0 0 14px 14px",
      }}
    />
  </div>
);
