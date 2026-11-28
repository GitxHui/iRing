import React from "react";
import { Img, staticFile } from "remotion";
import { DOCK_APPS, DOCK_RUNNING } from "../lib/apps";
import { clamp01, lerp, springAt } from "../lib/anim";
import { BLUE, FONT, MENU_H, W } from "../theme";
import { NOTCH_W } from "./MenuBar";

/**
 * Liquid Glass island, matching the real app:
 *  - collapsed (`expand` 0): a thin glass bar flush with the top edge at menu-bar height,
 *    wrapping the notch (drawn by MenuBar above it); left wing = front app,
 *    right wing = two mini icons + a status dot
 *  - expanded (`expand` 1): a glass panel hanging from the top edge with the dock row
 *    in its lower part; icons blur in/out during the transition
 * `hoverX` is the cursor x in canvas space (for magnification), or null.
 */
const BAR_W = 420;
const EXP_H = 172;
const ICON = 64;
const GAP = 18;
const PAD = 26;
const MINI = 20;

const LAYOUT = (() => {
  let x = PAD;
  const items = [...DOCK_APPS, "+", "⚙"];
  const slots = items.map((id, i) => {
    if (i > 0) x += GAP;
    const w = id === "|" ? 2 : ICON;
    const s = { id, x, w };
    x += w;
    return s;
  });
  return { slots, w: x + PAD };
})();

export const Island: React.FC<{
  t: number;
  expand: number;
  hoverX: number | null;
  hoverY: number;
  badgeAt?: number;
  activeId?: string;
  opacity?: number;
}> = ({ t, expand, hoverX, hoverY, badgeAt = 1e9, activeId = "claude", opacity = 1 }) => {
  const e = clamp01(expand);
  const width = lerp(BAR_W, LAYOUT.w, e);
  const h = lerp(MENU_H, EXP_H, e);
  const left = W / 2 - width / 2;
  const rowY = MENU_H + (EXP_H - MENU_H) / 2; // icon row centre when expanded
  const compactK = clamp01(1 - e * 2.6);
  const minis = ["chatgpt", "vscode", "claude", "chrome"].filter((id) => id !== activeId).slice(0, 2);
  const hoverInside = hoverX !== null && hoverY < h + 40;

  return (
    // sits above the MenuBar strip (whose backdrop blur would smear it) and redraws the notch on top
    <div style={{ position: "absolute", left, top: 0, width, height: h, opacity, zIndex: 55, fontFamily: FONT }}>
      {/* glass slab, flush with the top edge */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: `0 0 ${lerp(12, 30, e)}px ${lerp(12, 30, e)}px`,
          backdropFilter: "blur(24px) saturate(1.8)",
          background: `linear-gradient(180deg, rgba(${lerp(34, 255, e)},${lerp(46, 255, e)},${lerp(70, 255, e)},${lerp(0.6, 0.26, e)}), rgba(${lerp(26, 255, e)},${lerp(36, 255, e)},${lerp(58, 255, e)},${lerp(0.54, 0.12, e)}))`,
          boxShadow: `inset 0 0 0 1px rgba(255,255,255,${lerp(0.2, 0.34, e)}), inset 0 -1px 0 rgba(255,255,255,${lerp(0.22, 0.5, e)}), 0 ${lerp(4, 18, e)}px ${lerp(10, 40, e)}px rgba(10,30,70,${lerp(0.16, 0.25, e)})`,
        }}
      />

      {/* hardware notch stays above the island */}
      <div
        style={{
          position: "absolute",
          left: width / 2 - NOTCH_W / 2,
          top: 0,
          width: NOTCH_W,
          height: MENU_H + 2,
          background: "#000",
          borderRadius: "0 0 14px 14px",
          zIndex: 3,
        }}
      />

      {/* collapsed wings around the notch */}
      {compactK > 0.01 ? (
        <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: MENU_H, opacity: compactK, filter: `blur(${(1 - compactK) * 8}px)` }}>
          <Img
            src={staticFile(`icons/${activeId}.png`)}
            style={{
              position: "absolute",
              left: 16,
              top: (MENU_H - MINI - 2) / 2,
              width: MINI + 2,
              height: MINI + 2,
              filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.35))",
            }}
          />
          {minis.map((id, i) => (
            <Img
              key={id}
              src={staticFile(`icons/${id}.png`)}
              style={{
                position: "absolute",
                right: 34 + (1 - i) * (MINI + 6),
                top: (MENU_H - MINI) / 2,
                width: MINI,
                height: MINI,
                filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.3))",
              }}
            />
          ))}
          <div
            style={{
              position: "absolute",
              right: 14,
              top: MENU_H / 2 - 4.5,
              width: 9,
              height: 9,
              borderRadius: 5,
              background: "rgba(220,226,236,0.7)",
            }}
          />
        </div>
      ) : null}

      {/* expanded dock row */}
      {e > 0.02
        ? LAYOUT.slots.map((sl, i) => {
            const a = clamp01((e - 0.28 - 0.03 * i) / 0.38);
            if (a <= 0.01) return null;
            const x = sl.x - (LAYOUT.w - width) / 2;
            if (sl.id === "|") {
              return (
                <div
                  key={`sep-${i}`}
                  style={{
                    position: "absolute",
                    left: x,
                    top: rowY - ICON * 0.24,
                    width: 2,
                    height: ICON * 0.48,
                    background: "rgba(40,60,90,0.25)",
                    opacity: a,
                  }}
                />
              );
            }
            const cx = left + x + ICON / 2;
            const d = hoverInside && hoverX !== null ? (cx - hoverX) / (ICON * 1.4) : 9;
            const mag = 1 + 0.32 * Math.exp(-d * d) * e;
            const isBtn = sl.id === "+" || sl.id === "⚙";
            const running = DOCK_RUNNING.has(sl.id);
            const isActive = sl.id === activeId;
            const pop = springAt(t, 0, { response: 0.4 });
            return (
              <div
                key={sl.id}
                style={{
                  position: "absolute",
                  left: x,
                  top: rowY - ICON / 2,
                  width: ICON,
                  height: ICON,
                  opacity: a * pop,
                  filter: a < 0.99 ? `blur(${(1 - a) * 10}px)` : undefined,
                  transform: `translateY(${-(mag - 1) * ICON * 0.35}px) scale(${mag * lerp(0.82, 1, a)})`,
                  transformOrigin: "50% 100%",
                }}
              >
                {isBtn ? (
                  <div
                    style={{
                      position: "absolute",
                      inset: 4,
                      borderRadius: "50%",
                      border: "1.5px solid rgba(40,60,90,0.2)",
                      background: "rgba(255,255,255,0.12)",
                      color: "rgba(40,55,80,0.6)",
                      fontSize: ICON * 0.4,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    {sl.id}
                  </div>
                ) : (
                  <>
                    {isActive ? (
                      <div
                        style={{
                          position: "absolute",
                          inset: -7,
                          borderRadius: 18,
                          background: "rgba(255,255,255,0.32)",
                          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.6)",
                        }}
                      />
                    ) : null}
                    <Img
                      src={staticFile(`icons/${sl.id}.png`)}
                      style={{
                        position: "absolute",
                        inset: 0,
                        width: "100%",
                        height: "100%",
                        filter: "drop-shadow(0 3px 6px rgba(10,25,60,0.22))",
                      }}
                    />
                    {running ? (
                      <div
                        style={{
                          position: "absolute",
                          left: "50%",
                          bottom: -13,
                          width: isActive ? 16 : 6,
                          height: 6,
                          marginLeft: isActive ? -8 : -3,
                          borderRadius: 3,
                          background: BLUE,
                        }}
                      />
                    ) : null}
                    {sl.id === "wechat" && t > badgeAt ? (
                      <div
                        style={{
                          position: "absolute",
                          right: -6,
                          top: -6,
                          minWidth: 26,
                          height: 26,
                          borderRadius: 13,
                          background: "linear-gradient(180deg,#FF5A4E,#E5352B)",
                          color: "#fff",
                          fontSize: 15,
                          fontWeight: 700,
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          boxShadow: "0 2px 6px rgba(200,30,20,0.4), inset 0 0 0 1px rgba(255,255,255,0.35)",
                          transform: `scale(${springAt(t, badgeAt, { response: 0.35, damping: 0.55 })})`,
                        }}
                      >
                        3
                      </div>
                    ) : null}
                  </>
                )}
              </div>
            );
          })
        : null}
    </div>
  );
};
