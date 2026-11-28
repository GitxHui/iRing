import React from "react";
import { Img, staticFile } from "remotion";
import { FONT, MONO } from "../theme";
import { Rect, rand } from "../lib/anim";

export type WinApp = "chrome" | "claude" | "vscode" | "notes";

const Bar: React.FC<{ w: string | number; c: string; h?: number; mb?: number; ml?: number | string }> = ({
  w,
  c,
  h = 10,
  mb = 12,
  ml = 0,
}) => <div style={{ width: w, height: h, borderRadius: h / 2, background: c, marginBottom: mb, marginLeft: ml, flexShrink: 0 }} />;

const Lights: React.FC<{ focused: boolean }> = ({ focused }) => (
  <div style={{ display: "flex", gap: 8 }}>
    {["#FF5F57", "#FEBC2E", "#28C840"].map((c) => (
      <div
        key={c}
        style={{
          width: 13,
          height: 13,
          borderRadius: 7,
          background: focused ? c : "rgba(0,0,0,0.16)",
          boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.18)",
        }}
      />
    ))}
  </div>
);

const ChromeBody: React.FC<{ focused: boolean }> = ({ focused }) => (
  <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#fff" }}>
    <div style={{ height: 46, background: "#DFE4EC", display: "flex", alignItems: "center", padding: "0 16px", gap: 18 }}>
      <Lights focused={focused} />
      <div
        style={{
          marginTop: 10,
          height: 36,
          width: 240,
          background: "#fff",
          borderRadius: "10px 10px 0 0",
          display: "flex",
          alignItems: "center",
          gap: 10,
          padding: "0 14px",
          fontSize: 14,
          color: "#333",
        }}
      >
        <div style={{ width: 16, height: 16, borderRadius: 8, background: "#24292F" }} />
        Release notes
      </div>
    </div>
    <div style={{ height: 44, display: "flex", alignItems: "center", padding: "0 16px", gap: 14, borderBottom: "1px solid #E6E8EC" }}>
      {[0, 1, 2].map((k) => (
        <div key={k} style={{ width: 14, height: 14, borderRadius: 7, background: "#C9CED6" }} />
      ))}
      <div
        style={{
          flex: 1,
          height: 30,
          borderRadius: 15,
          background: "#EEF1F5",
          display: "flex",
          alignItems: "center",
          padding: "0 16px",
          fontSize: 14,
          color: "#555",
        }}
      >
        github.com/GitxHui/iRing/releases
      </div>
    </div>
    <div style={{ flex: 1, padding: "28px 36px", overflow: "hidden", display: "flex", flexDirection: "column" }}>
      <div
        style={{
          height: "34%",
          borderRadius: 16,
          background: "linear-gradient(120deg, #1B2A55 0%, #3651A8 55%, #6C7DFF 100%)",
          marginBottom: 24,
          flexShrink: 0,
        }}
      />
      <Bar w="46%" c="#1F2328" h={18} mb={18} />
      <Bar w="88%" c="#D7DBE1" />
      <Bar w="80%" c="#D7DBE1" />
      <Bar w="62%" c="#D7DBE1" mb={22} />
      <div style={{ display: "flex", gap: 16, flex: 1 }}>
        {["#EAF2FF", "#F1ECFF", "#E9F8F1"].map((c) => (
          <div key={c} style={{ flex: 1, borderRadius: 14, background: c }} />
        ))}
      </div>
    </div>
  </div>
);

const ClaudeBody: React.FC<{ focused: boolean }> = ({ focused }) => (
  <div style={{ display: "flex", height: "100%", background: "#FAF8F3" }}>
    <div style={{ width: "24%", background: "#F1EEE6", padding: "18px 18px", display: "flex", flexDirection: "column" }}>
      <Lights focused={focused} />
      <div style={{ height: 28 }} />
      <Bar w="70%" c="#D9D3C6" h={12} mb={20} />
      {[0.82, 0.64, 0.74, 0.58, 0.7, 0.5].map((w, i) => (
        <Bar key={i} w={`${w * 100}%`} c={i === 1 ? "#C9C1B0" : "#E1DBCF"} mb={16} />
      ))}
    </div>
    <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "64px 8% 26px" }}>
      <div style={{ alignSelf: "flex-end", background: "#ECE7DC", borderRadius: 16, padding: "14px 18px", width: "48%", marginBottom: 26 }}>
        <Bar w="100%" c="#CFC6B4" mb={10} />
        <Bar w="64%" c="#CFC6B4" mb={0} />
      </div>
      <div style={{ display: "flex", gap: 14, marginBottom: 12 }}>
        <div style={{ width: 26, height: 26, borderRadius: 8, background: "#D97757", flexShrink: 0 }} />
        <div style={{ flex: 1, paddingTop: 6 }}>
          {[0.96, 0.9, 0.98, 0.7].map((w, i) => (
            <Bar key={i} w={`${w * 100}%`} c="#D8D2C5" />
          ))}
          <div style={{ height: 10 }} />
          {[0.92, 0.86, 0.5].map((w, i) => (
            <Bar key={i} w={`${w * 100}%`} c="#D8D2C5" />
          ))}
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <div
        style={{
          height: 64,
          borderRadius: 18,
          background: "#fff",
          boxShadow: "0 0 0 1px #E4DED2, 0 4px 14px rgba(80,60,20,0.06)",
          display: "flex",
          alignItems: "center",
          padding: "0 20px",
          justifyContent: "space-between",
        }}
      >
        <Bar w="36%" c="#E4DED2" mb={0} />
        <div style={{ width: 34, height: 34, borderRadius: 10, background: "#D97757" }} />
      </div>
    </div>
  </div>
);

const NotesBody: React.FC<{ focused: boolean }> = ({ focused }) => (
  <div style={{ display: "flex", height: "100%", background: "#FFFDF6" }}>
    <div style={{ width: "30%", background: "#F6F1E1", padding: "18px 16px", display: "flex", flexDirection: "column" }}>
      <Lights focused={focused} />
      <div style={{ height: 26 }} />
      {[0, 1, 2, 3, 4].map((i) => (
        <div
          key={i}
          style={{
            borderRadius: 10,
            padding: "12px 12px",
            marginBottom: 10,
            background: i === 0 ? "#F2C94C" : "transparent",
          }}
        >
          <Bar w="80%" c={i === 0 ? "#7A5A00" : "#D9CFAE"} h={9} mb={8} />
          <Bar w="55%" c={i === 0 ? "#A88A2E" : "#E6DDC0"} h={7} mb={0} />
        </div>
      ))}
    </div>
    <div style={{ flex: 1, padding: "56px 7% 24px" }}>
      <Bar w="52%" c="#2B2410" h={20} mb={22} />
      {[0.94, 0.88, 0.97, 0.6, 0, 0.9, 0.82, 0.7].map((w, i) =>
        w === 0 ? <div key={i} style={{ height: 16 }} /> : <Bar key={i} w={`${w * 100}%`} c="#E5DFCC" />,
      )}
    </div>
  </div>
);

const CODE_COLORS = ["#569CD6", "#CE9178", "#9CDCFE", "#C586C0", "#DCDCAA", "#6A9955", "#4EC9B0"];

const VSCodeBody: React.FC<{ focused: boolean }> = ({ focused }) => (
  <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#1F1F1F" }}>
    <div style={{ height: 40, background: "#181818", display: "flex", alignItems: "center", padding: "0 16px", gap: 16 }}>
      <Lights focused={focused} />
      <div style={{ flex: 1, textAlign: "center", color: "#9DA1A6", fontSize: 13, fontFamily: FONT }}>
        LoopRadialMenu.swift — iRing
      </div>
    </div>
    <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
      <div style={{ width: 52, background: "#181818", display: "flex", flexDirection: "column", alignItems: "center", gap: 22, paddingTop: 16 }}>
        {[0, 1, 2, 3].map((k) => (
          <div key={k} style={{ width: 22, height: 22, borderRadius: 5, border: `2px solid ${k === 0 ? "#D7D7D7" : "#6E7176"}` }} />
        ))}
      </div>
      <div style={{ width: "20%", background: "#181818", padding: "14px 14px", borderRight: "1px solid #2B2B2B" }}>
        {[0.7, 0.55, 0.8, 0.62, 0.74, 0.5, 0.66, 0.58].map((w, i) => (
          <Bar key={i} w={`${w * 100}%`} c={i === 2 ? "#3C79C8" : "#3A3D41"} h={9} mb={14} ml={i > 1 && i < 6 ? 14 : 0} />
        ))}
      </div>
      <div style={{ flex: 1, padding: "18px 22px", overflow: "hidden", fontFamily: MONO }}>
        {Array.from({ length: 26 }).map((_, i) => {
          const indent = [0, 1, 1, 2, 2, 2, 1, 2, 3, 3, 2, 1, 0, 0, 1, 1, 2, 2, 1, 0, 1, 2, 2, 1, 0, 0][i];
          const segs = 1 + Math.floor(rand(i * 3.7) * 3);
          return (
            <div key={i} style={{ display: "flex", alignItems: "center", height: 22 }}>
              <div style={{ width: 34, color: "#6E7681", fontSize: 12, textAlign: "right", marginRight: 18 }}>{i + 1}</div>
              <div style={{ width: indent * 26 }} />
              {Array.from({ length: segs }).map((__, k) => (
                <div
                  key={k}
                  style={{
                    width: 30 + rand(i * 9.1 + k * 2.3) * 120,
                    height: 9,
                    borderRadius: 4.5,
                    background: CODE_COLORS[Math.floor(rand(i * 1.7 + k * 5.1) * CODE_COLORS.length)],
                    opacity: 0.85,
                    marginRight: 10,
                  }}
                />
              ))}
            </div>
          );
        })}
      </div>
    </div>
  </div>
);

export const AppWindow: React.FC<{
  rect: Rect;
  app: WinApp;
  opacity?: number;
  scale?: number;
  focused?: boolean;
  z?: number;
  blur?: number;
}> = ({ rect, app, opacity = 1, scale = 1, focused = true, z = 1, blur = 0 }) => {
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
        boxShadow: focused
          ? "0 40px 90px rgba(8,22,55,0.38), 0 10px 30px rgba(8,22,55,0.22), 0 0 0 1px rgba(0,0,0,0.14)"
          : "0 20px 50px rgba(8,22,55,0.22), 0 0 0 1px rgba(0,0,0,0.12)",
        filter: blur > 0 ? `blur(${blur}px)` : undefined,
      }}
    >
      {app === "chrome" ? <ChromeBody focused={focused} /> : null}
      {app === "claude" ? <ClaudeBody focused={focused} /> : null}
      {app === "vscode" ? <VSCodeBody focused={focused} /> : null}
      {app === "notes" ? <NotesBody focused={focused} /> : null}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 18,
          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.22)",
          pointerEvents: "none",
        }}
      />
    </div>
  );
};

export const WindowIcon: React.FC<{ app: string; size: number }> = ({ app, size }) => (
  <Img src={staticFile(`icons/${app}.png`)} style={{ width: size, height: size }} />
);
