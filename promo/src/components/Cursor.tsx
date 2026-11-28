import React from "react";

/** macOS-style arrow cursor; (x,y) is the hotspot. */
export const Cursor: React.FC<{ x: number; y: number; scale?: number; opacity?: number }> = ({
  x,
  y,
  scale = 1,
  opacity = 1,
}) => (
  <svg
    width={40}
    height={48}
    viewBox="-2 -2 22 30"
    style={{
      position: "absolute",
      left: x - 2 * 1.6 * scale,
      top: y - 2 * 1.6 * scale,
      width: 22 * 1.6 * scale,
      height: 30 * 1.6 * scale,
      opacity,
      filter: "drop-shadow(0 2px 3px rgba(0,0,0,0.35))",
      overflow: "visible",
    }}
  >
    <path
      d="M0 0 L0 22.5 L5.6 17.3 L9.3 25.8 L12.9 24.3 L9.3 16 L16.8 16 Z"
      fill="#111"
      stroke="#fff"
      strokeWidth={1.5}
      strokeLinejoin="round"
    />
  </svg>
);
