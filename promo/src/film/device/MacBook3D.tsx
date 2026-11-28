/**
 * Stylised 3D MacBook (CSS 3D). Shared device for the film — owned by the lead.
 *
 * Coordinates: the rig origin is the HINGE centre, placed at (cx, cy) on the canvas.
 * The lid (screen) stands up from the hinge; the base deck extends toward the viewer.
 *
 *   <MacBook3D cx={960} cy={760} cam={{ rx: -8, ry: 0 }} lid={100} screen={<World/>} />
 *
 * `screen` is rendered into a 1920x1080 world, scaled to cover the 16:10 panel (sides cropped
 * ~90 px each), so keep important UI within x 100..1820.
 * No Apple logo anywhere (trademark) — the lid back is plain aluminium with a soft iRing glyph.
 */
import React from "react";

export type Cam = {
  /** tilt: negative looks down onto the keyboard */
  rx?: number;
  /** orbit: positive turns the laptop to show its right side */
  ry?: number;
  rz?: number;
  /** dolly toward camera (px) */
  z?: number;
  /** overall scale */
  s?: number;
};

export const PANEL = { w: 1600, h: 1000 }; // visible screen area
const BEZEL = 22;
const LID = { w: PANEL.w + BEZEL * 2, h: PANEL.h + BEZEL * 2 + 18 };
const BASE = { w: LID.w + 60, d: 1120, t: 26 };

/** World -> panel mapping (cover). */
export const WORLD_SCALE = Math.max(PANEL.w / 1920, PANEL.h / 1080);
export const WORLD_OFF = { x: (PANEL.w - 1920 * WORLD_SCALE) / 2, y: (PANEL.h - 1080 * WORLD_SCALE) / 2 };

export type KeyGlow = { option?: number; tab?: number; cmd?: number; digits?: number[] };
export type PadTouch = { show: number; x: number; y: number; fingers?: 1 | 2; tap?: number };

const KEY = 78; // key pitch on the deck
const Keyboard: React.FC<{ glow: KeyGlow }> = ({ glow }) => {
  // 6 rows; widths in key units; special keys tagged for glow
  const rows: Array<Array<[number, string?]>> = [
    [[1.4, "esc"], ...Array.from({ length: 12 }, () => [1] as [number]), [1.4]],
    [[1, "`"], [1, "1"], [1, "2"], [1, "3"], [1, "4"], [1, "5"], [1, "6"], [1, "7"], [1, "8"], [1, "9"], [1, "0"], [1], [1], [1.8]],
    [[1.5, "tab"], ...Array.from({ length: 12 }, () => [1] as [number]), [1.3]],
    [[1.8], ...Array.from({ length: 11 }, () => [1] as [number]), [2]],
    [[2.35], ...Array.from({ length: 10 }, () => [1] as [number]), [2.45]],
    [[1, "fn"], [1, "ctrl"], [1, "option"], [1.25, "cmd"], [5.1], [1.25], [1], [1], [1], [1]],
  ];
  const out: React.ReactNode[] = [];
  let y = 0;
  rows.forEach((row, ri) => {
    let x = 0;
    const h = ri === 0 ? KEY * 0.55 : KEY;
    row.forEach(([u, tag], ki) => {
      const w = u * KEY - 8;
      let g = 0;
      if (tag === "option") g = glow.option ?? 0;
      if (tag === "tab") g = glow.tab ?? 0;
      if (tag === "cmd") g = glow.cmd ?? 0;
      if (ri === 1 && glow.digits && tag && /^[1-9]$/.test(tag)) g = glow.digits[Number(tag) - 1] ?? 0;
      out.push(
        <g key={`${ri}-${ki}`} transform={`translate(${x} ${y})`}>
          <rect width={w} height={h - 8} rx={9} fill={g > 0.01 ? `rgba(10,132,255,${0.25 + 0.6 * g})` : "#17181B"} />
          <rect width={w} height={h - 8} rx={9} fill="none" stroke={g > 0.01 ? `rgba(120,190,255,${g})` : "rgba(255,255,255,0.05)"} strokeWidth={g > 0.01 ? 2.5 : 1} />
          {tag === "option" ? (
            <text x={w / 2} y={(h - 8) / 2 + 12} textAnchor="middle" fontSize={30} fill={g > 0.3 ? "#fff" : "#8E8E93"} fontFamily="-apple-system">⌥</text>
          ) : null}
          {tag === "tab" ? (
            <text x={w / 2} y={(h - 8) / 2 + 9} textAnchor="middle" fontSize={20} fill={g > 0.3 ? "#fff" : "#8E8E93"} fontFamily="-apple-system">tab</text>
          ) : null}
          {tag === "cmd" ? (
            <text x={w / 2} y={(h - 8) / 2 + 12} textAnchor="middle" fontSize={30} fill={g > 0.3 ? "#fff" : "#8E8E93"} fontFamily="-apple-system">⌘</text>
          ) : null}
          {ri === 1 && tag && /^[1-9]$/.test(tag) ? (
            <text x={w / 2} y={(h - 8) / 2 + 9} textAnchor="middle" fontSize={22} fill={g > 0.3 ? "#fff" : "#6E6E73"} fontFamily="-apple-system">{tag}</text>
          ) : null}
          {g > 0.01 ? <rect width={w} height={h - 8} rx={9} fill="none" stroke="rgba(10,132,255,0.6)" strokeWidth={10} opacity={g * 0.5} style={{ filter: "blur(6px)" }} /> : null}
        </g>,
      );
      x += u * KEY;
    });
    y += h;
  });
  return (
    <svg width={14.6 * KEY} height={5.55 * KEY} viewBox={`0 0 ${14.6 * KEY} ${5.55 * KEY}`}>
      {out}
    </svg>
  );
};

export const MacBook3D: React.FC<{
  cx: number;
  cy: number;
  cam?: Cam;
  /** lid opening angle vs the base: 90 = upright, 105 typical */
  lid?: number;
  screen: React.ReactNode;
  showBase?: boolean;
  keyGlow?: KeyGlow;
  pad?: PadTouch;
  /** 0..1 screen brightness (for power-on / emphasis) */
  power?: number;
  perspective?: number;
}> = ({ cx, cy, cam = {}, lid = 104, screen, showBase = true, keyGlow = {}, pad, power = 1, perspective = 3400 }) => {
  const { rx = -6, ry = 0, rz = 0, z = 0, s = 1 } = cam;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: "100%", height: "100%", perspective, perspectiveOrigin: `${cx}px ${cy - 300}px` }}>
      <div
        style={{
          position: "absolute",
          left: cx,
          top: cy,
          width: 0,
          height: 0,
          transformStyle: "preserve-3d",
          transform: `translateZ(${z}px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg) scale(${s})`,
        }}
      >
        {/* ---------- base deck ---------- */}
        {showBase ? (
          <div
            style={{
              position: "absolute",
              left: -BASE.w / 2,
              top: 0,
              width: BASE.w,
              height: BASE.d,
              transformOrigin: "50% 0",
              transform: "rotateX(90deg)",
              borderRadius: "10px 10px 46px 46px",
              background: "linear-gradient(180deg, #3A3B3F 0%, #2C2D31 40%, #232428 100%)",
              boxShadow: "inset 0 0 0 1.5px rgba(255,255,255,0.08), inset 0 -18px 30px rgba(0,0,0,0.35)",
              backfaceVisibility: "hidden",
            }}
          >
            {/* keyboard well */}
            <div
              style={{
                position: "absolute",
                left: (BASE.w - 14.6 * KEY) / 2 - 14,
                top: 70,
                padding: 14,
                borderRadius: 18,
                background: "#0D0E10",
                boxShadow: "inset 0 2px 10px rgba(0,0,0,0.7)",
              }}
            >
              <Keyboard glow={keyGlow} />
            </div>
            {/* trackpad */}
            <div
              style={{
                position: "absolute",
                left: BASE.w / 2 - 330,
                top: 610,
                width: 660,
                height: 420,
                borderRadius: 22,
                background: "linear-gradient(180deg, #34353A, #2A2B2F)",
                boxShadow: "inset 0 0 0 1.5px rgba(255,255,255,0.07), inset 0 2px 8px rgba(0,0,0,0.4)",
                overflow: "hidden",
              }}
            >
              {pad && pad.show > 0.01
                ? Array.from({ length: pad.fingers ?? 2 }).map((_, i) => (
                    <div
                      key={i}
                      style={{
                        position: "absolute",
                        left: 330 + pad.x * 260 + (i - ((pad.fingers ?? 2) - 1) / 2) * 90 - 32,
                        top: 210 + pad.y * 150 - 32,
                        width: 64,
                        height: 64,
                        borderRadius: 32,
                        background: "radial-gradient(circle, rgba(150,200,255,0.95), rgba(10,132,255,0.35) 60%, rgba(10,132,255,0) 72%)",
                        opacity: pad.show,
                        transform: `scale(${1 + 0.25 * (pad.tap ?? 0)})`,
                        boxShadow: `0 0 ${30 + 40 * (pad.tap ?? 0)}px rgba(10,132,255,0.8)`,
                      }}
                    />
                  ))
                : null}
            </div>
            {/* front lip highlight */}
            <div style={{ position: "absolute", left: 40, right: 40, bottom: 0, height: 3, background: "rgba(255,255,255,0.18)", borderRadius: 2 }} />
          </div>
        ) : null}
        {/* deck thickness (front edge) */}
        {showBase ? (
          <div
            style={{
              position: "absolute",
              left: -BASE.w / 2,
              top: BASE.d * 0 - 0,
              width: BASE.w,
              height: BASE.t,
              transformOrigin: "50% 0",
              transform: `translateZ(${BASE.d}px)`,
              background: "linear-gradient(180deg, #4A4B50, #1C1D20)",
              borderRadius: "0 0 18px 18px",
            }}
          />
        ) : null}

        {/* ---------- lid ---------- */}
        <div
          style={{
            position: "absolute",
            left: -LID.w / 2,
            top: -LID.h,
            width: LID.w,
            height: LID.h,
            transformOrigin: "50% 100%",
            transform: `rotateX(${lid - 90}deg)`,
            transformStyle: "preserve-3d",
          }}
        >
          {/* front: bezel + panel */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 34,
              background: "#050506",
              boxShadow: "0 0 0 3px #2B2C30, inset 0 0 0 1px rgba(255,255,255,0.06)",
              backfaceVisibility: "hidden",
            }}
          >
            <div
              style={{
                position: "absolute",
                left: BEZEL,
                top: BEZEL,
                width: PANEL.w,
                height: PANEL.h,
                borderRadius: 14,
                overflow: "hidden",
                background: "#000",
              }}
            >
              <div
                style={{
                  position: "absolute",
                  left: WORLD_OFF.x,
                  top: WORLD_OFF.y,
                  width: 1920,
                  height: 1080,
                  transformOrigin: "0 0",
                  transform: `scale(${WORLD_SCALE})`,
                  opacity: power,
                }}
              >
                {screen}
              </div>
              {/* glass reflection */}
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  background: `linear-gradient(${115 + ry * 0.6}deg, rgba(255,255,255,0) 35%, rgba(255,255,255,0.07) 48%, rgba(255,255,255,0) 62%)`,
                  pointerEvents: "none",
                }}
              />
              {/* notch */}
              <div
                style={{
                  position: "absolute",
                  left: PANEL.w / 2 - 92,
                  top: 0,
                  width: 184,
                  height: 30,
                  background: "#050506",
                  borderRadius: "0 0 12px 12px",
                }}
              />
            </div>
          </div>
          {/* back: aluminium */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 34,
              transform: "rotateY(180deg)",
              backfaceVisibility: "hidden",
              background: "linear-gradient(135deg, #4A4B50, #2E2F33 60%, #26272B)",
              boxShadow: "inset 0 0 0 2px rgba(255,255,255,0.08)",
            }}
          >
            <svg width={120} height={120} viewBox="0 0 20 20" style={{ position: "absolute", left: LID.w / 2 - 60, top: LID.h / 2 - 60, opacity: 0.35 }}>
              <path d="M5 13.5 A6.2 6.2 0 1 1 15 13.5" fill="none" stroke="#C8CBD2" strokeWidth={2.2} strokeLinecap="round" />
              <circle cx={10} cy={13.6} r={1.5} fill="#C8CBD2" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  );
};

/** Canvas position of a world point when the device is viewed exactly front-on (rx=ry=0, lid=90, s=1). */
export const frontOnWorldToCanvas = (cx: number, cy: number, wx: number, wy: number) => ({
  x: cx - LID.w / 2 + BEZEL + WORLD_OFF.x + wx * WORLD_SCALE,
  y: cy - LID.h + BEZEL + WORLD_OFF.y + wy * WORLD_SCALE,
});
