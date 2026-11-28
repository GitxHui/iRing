import React from "react";
import { Img, staticFile } from "remotion";
import { clamp01, lerp, springAt } from "../../lib/anim";
import { BLUE } from "../../theme";

/**
 * Liquid Glass island as it really behaves (matches the user's screen recording):
 *  - collapsed: a thin glass bar flush with a screen edge (menu-bar height), wrapping the
 *    notch when on the top edge; left wing = front app, right wing = 2 mini icons + dot
 *  - expanded: a glass panel hanging from the edge, icons in the lower part
 * Geometry is in the parent's (card) coordinates; the box is laid out horizontally and
 * rotated 90° for the left/right edges.
 */

const RUN = ["chatgpt", "claude", "chrome", "vscode", "wechat"];
const EXTRA = ["gemini", "obsidian"];

export const BAR_H = 34; // collapsed thickness (menu-bar height, larger than life)
export const BAR_W = 330; // collapsed length
export const NOTCH_W = 116;
const EXP_H = 168;
const ICON = 64;
const MINI = 22;

type Slot = { kind: "icon" | "sep" | "btn"; id: string; w: number };
const EXP_SLOTS: Slot[] = [
  ...RUN.map((id) => ({ kind: "icon" as const, id, w: ICON })),
  { kind: "sep" as const, id: "sep", w: 2 },
  ...EXTRA.map((id) => ({ kind: "icon" as const, id, w: ICON })),
  { kind: "btn" as const, id: "+", w: ICON },
  { kind: "btn" as const, id: "⚙", w: ICON },
];
const GAP = 14;
const PAD = 26;
const EXP_LAYOUT = (() => {
  let x = PAD;
  const out = EXP_SLOTS.map((s, i) => {
    if (i > 0) x += GAP;
    const r = { ...s, x };
    x += s.w;
    return r;
  });
  return { slots: out, w: x + PAD };
})();
export const EXP_W = EXP_LAYOUT.w;

/** Box size for expansion amount e (0 collapsed … 1 expanded). */
export const islandGeom = (e: number) => {
  const k = clamp01(e);
  return { w: lerp(BAR_W, EXP_W, k), h: lerp(BAR_H, EXP_H, k) };
};

export type FlushSide = "top" | "bottom";

export const DockIsland: React.FC<{
  t: number;
  /** centre of the (unrotated) box in parent coords */
  cx: number;
  cy: number;
  expand: number;
  /** 0 horizontal … 1 rotated 90° (left/right edges) */
  vertical: number;
  /** 0 docked … 1 picked up (all corners round, floating shadow) */
  lift: number;
  squish: number;
  /** local side that touches the screen edge while docked */
  flush: FlushSide;
  /** 0..1 draw the hardware notch (only on the top edge) */
  notch: number;
  hover: [number, number] | null;
  badgeAt: number;
  activeId?: string;
  numbers?: number;
  pulse?: (id: string) => number;
}> = ({ t, cx, cy, expand, vertical, lift, squish, flush, notch, hover, badgeAt, activeId = "claude", numbers = 0, pulse }) => {
  const e = clamp01(expand);
  const { w, h } = islandGeom(e);
  const rot = vertical * 90;
  const dock = 1 - clamp01(lift);

  // corner radii: flush side square while docked, capsule while lifted
  const free = lerp(12, 30, e);
  const cap = h / 2;
  const outer = lerp(cap, free, dock);
  const edge = lerp(cap, 0, dock);
  const r =
    flush === "top"
      ? `${edge}px ${edge}px ${outer}px ${outer}px`
      : `${outer}px ${outer}px ${edge}px ${edge}px`;
  const scale = (1 + 0.06 * lift) * squish;

  const compactK = clamp01(1 - e * 2.6);
  const contentTop = flush === "top" ? BAR_H + (h - BAR_H) / 2 : (h - BAR_H) / 2;
  const minis = ["chatgpt", "vscode", "claude", "chrome"].filter((id) => id !== activeId).slice(0, 2);

  return (
    <div
      style={{
        position: "absolute",
        left: cx - w / 2,
        top: cy - h / 2,
        width: w,
        height: h,
        transform: `rotate(${rot}deg) scale(${scale})`,
        zIndex: 40,
      }}
    >
      {/* glass slab: darker when collapsed, lighter Liquid Glass when expanded */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: r,
          overflow: "hidden",
          backdropFilter: "blur(22px) saturate(1.8)",
          background: `linear-gradient(180deg, rgba(${lerp(34, 255, e)},${lerp(46, 255, e)},${lerp(70, 255, e)},${lerp(0.62, 0.26, e)}), rgba(${lerp(26, 255, e)},${lerp(36, 255, e)},${lerp(58, 255, e)},${lerp(0.56, 0.12, e)}))`,
          boxShadow: `inset 0 0 0 1px rgba(255,255,255,${lerp(0.2, 0.36, e)}), inset 0 ${flush === "top" ? -1 : 1}px 0 rgba(255,255,255,${lerp(0.22, 0.55, e)}), 0 ${4 + lift * 22}px ${10 + lift * 34}px rgba(6,18,48,${0.18 + lift * 0.26})`,
        }}
      />

      {/* hardware notch (top edge only) */}
      {notch > 0.01 ? (
        <div
          style={{
            position: "absolute",
            left: w / 2 - NOTCH_W / 2,
            top: flush === "top" ? 0 : h - BAR_H,
            width: NOTCH_W,
            height: BAR_H,
            background: "#000",
            borderRadius: flush === "top" ? "0 0 12px 12px" : "12px 12px 0 0",
            opacity: notch,
          }}
        />
      ) : null}

      {/* collapsed wings */}
      {compactK > 0.01 ? (
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: flush === "top" ? 0 : h - BAR_H,
            height: BAR_H,
            opacity: compactK,
            filter: `blur(${(1 - compactK) * 8}px)`,
          }}
        >
          <Img
            src={staticFile(`icons/${activeId}.png`)}
            style={{
              position: "absolute",
              left: 14,
              top: (BAR_H - MINI - 2) / 2,
              width: MINI + 2,
              height: MINI + 2,
              transform: `rotate(${-rot}deg)`,
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
                top: (BAR_H - MINI) / 2,
                width: MINI,
                height: MINI,
                transform: `rotate(${-rot}deg)`,
                filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.3))",
              }}
            />
          ))}
          <div
            style={{
              position: "absolute",
              right: 14,
              top: BAR_H / 2 - 4.5,
              width: 9,
              height: 9,
              borderRadius: 5,
              background: "rgba(220,226,236,0.7)",
            }}
          />
        </div>
      ) : null}

      {/* expanded row */}
      {e > 0.02 ? (
        <div style={{ position: "absolute", inset: 0, borderRadius: r, overflow: "visible" }}>
          {EXP_LAYOUT.slots.map((sl, i) => {
            const a = clamp01((e - 0.28 - 0.03 * i) / 0.38);
            if (a <= 0.01) return null;
            const x = sl.x - (EXP_W - w) / 2;
            if (sl.kind === "sep") {
              return (
                <div
                  key="sep"
                  style={{
                    position: "absolute",
                    left: x,
                    top: contentTop - ICON * 0.24,
                    width: 2,
                    height: ICON * 0.48,
                    borderRadius: 1,
                    background: "rgba(30,50,90,0.25)",
                    opacity: a,
                  }}
                />
              );
            }
            const icx = cx - w / 2 + x + ICON / 2;
            let mag = 1;
            if (hover && vertical < 0.05 && Math.abs(hover[1] - (cy - h / 2 + contentTop)) < ICON * 1.4) {
              const d = (icx - hover[0]) / (ICON * 1.3);
              mag = 1 + 0.3 * Math.exp(-d * d) * e;
            }
            const pu = pulse ? pulse(sl.id) : 0;
            mag *= 1 + 0.28 * pu;
            const isActive = sl.id === activeId;
            const running = RUN.includes(sl.id);
            const slotNo = RUN.indexOf(sl.id) + 1;
            return (
              <div
                key={sl.id}
                style={{
                  position: "absolute",
                  left: x,
                  top: contentTop - ICON / 2,
                  width: ICON,
                  height: ICON,
                  opacity: a,
                  filter: a < 0.99 ? `blur(${(1 - a) * 10}px)` : undefined,
                  transform: `rotate(${-rot}deg) translateY(${-(mag - 1) * ICON * 0.3}px) scale(${mag * lerp(0.82, 1, a)})`,
                }}
              >
                {sl.kind === "btn" ? (
                  <div
                    style={{
                      position: "absolute",
                      inset: 5,
                      borderRadius: "50%",
                      border: "2px solid rgba(30,50,90,0.2)",
                      background: "rgba(255,255,255,0.14)",
                      color: "rgba(30,45,75,0.62)",
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
                          background: "rgba(255,255,255,0.34)",
                          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.7)",
                        }}
                      />
                    ) : null}
                    {pu > 0.01 ? (
                      <div
                        style={{
                          position: "absolute",
                          inset: -6,
                          borderRadius: 16,
                          boxShadow: `0 0 0 2.5px ${BLUE}, 0 0 ${18 * pu}px ${6 * pu}px rgba(60,140,255,0.75)`,
                          opacity: Math.min(1, pu * 1.6),
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
                        filter: "drop-shadow(0 3px 6px rgba(10,25,60,0.25))",
                      }}
                    />
                    {running ? (
                      <div
                        style={{
                          position: "absolute",
                          left: "50%",
                          bottom: -12,
                          width: isActive ? 16 : 6,
                          height: 6,
                          marginLeft: isActive ? -8 : -3,
                          borderRadius: 3,
                          background: BLUE,
                        }}
                      />
                    ) : null}
                    {numbers > 0.01 && slotNo > 0 && slotNo <= 4 ? (
                      <div
                        style={{
                          position: "absolute",
                          left: "50%",
                          top: ICON + 14,
                          transform: `translateX(-50%) scale(${0.6 + 0.4 * numbers + 0.25 * pu})`,
                          opacity: numbers,
                          minWidth: 22,
                          height: 20,
                          borderRadius: 6,
                          padding: "0 4px",
                          background: pu > 0.2 ? BLUE : "rgba(20,32,60,0.72)",
                          color: "#fff",
                          fontSize: 13,
                          fontWeight: 700,
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          boxShadow: "0 2px 6px rgba(0,0,0,0.3), inset 0 0 0 1px rgba(255,255,255,0.25)",
                          fontFamily: '"SF Pro Display", -apple-system, sans-serif',
                          whiteSpace: "nowrap",
                        }}
                      >
                        ⌘{slotNo}
                      </div>
                    ) : null}
                    {sl.id === "wechat" && t > badgeAt ? (
                      <div
                        style={{
                          position: "absolute",
                          right: -8,
                          top: -8,
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
                          boxShadow: "0 2px 6px rgba(200,30,20,0.45), inset 0 0 0 1px rgba(255,255,255,0.35)",
                          transform: `scale(${springAt(t, badgeAt, { response: 0.35, damping: 0.55 })})`,
                          fontFamily: '"SF Pro Display", -apple-system, sans-serif',
                        }}
                      >
                        3
                      </div>
                    ) : null}
                  </>
                )}
              </div>
            );
          })}
        </div>
      ) : null}
    </div>
  );
};
