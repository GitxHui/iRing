/**
 * Stylised 3D mouse with a middle-button scroll wheel (CSS 3D, layered contour extrusion).
 * Reusable: any scene can place it on the canvas.
 *
 *   <Mouse3D x={1300} y={720} scale={1} pitch={58} yaw={-28} press={p} glow={g} />
 *
 * pitch: 90 = side-on (edge view of the desk), 0 = straight top-down.
 * yaw:   rotation on the desk (deg); 0 = front pointing up the screen.
 * press: 0..1 middle-button (wheel) press depth. glow: 0..1 blue light on the wheel.
 * Silver body by default (`tone="silver"`), or `tone="graphite"`.
 */
import React from "react";

const W = 300;
const L = 520;
const H = 92; // dome height
const N = 22; // contour layers

const SHAPE =
  "M150,0 C252,0 290,92 292,205 C296,335 278,520 150,520 C22,520 4,335 8,205 C10,92 48,0 150,0 Z";

const TONES = {
  silver: { side0: [150, 154, 162], side1: [214, 217, 224], top0: "#FBFBFD", top1: "#D9DCE3", line: "rgba(60,64,75,0.35)" },
  graphite: { side0: [26, 27, 31], side1: [62, 64, 70], top0: "#5A5C63", top1: "#2C2D32", line: "rgba(0,0,0,0.55)" },
};

const lerpC = (a: number[], b: number[], p: number) => a.map((v, i) => Math.round(v + (b[i] - v) * p));

export const Mouse3D: React.FC<{
  x: number;
  y: number;
  scale?: number;
  pitch?: number;
  yaw?: number;
  press?: number;
  glow?: number;
  tone?: keyof typeof TONES;
  opacity?: number;
  reflection?: boolean;
}> = ({ x, y, scale = 1, pitch = 58, yaw = -25, press = 0, glow = 0, tone = "silver", opacity = 1, reflection = true }) => {
  const c = TONES[tone];
  const layer = (k: number, mirror: boolean) => {
    const f = k / N;
    const s = 1 - 0.5 * Math.pow(f, 2.6);
    const dy = Math.pow(f, 2) * 34; // hump sits toward the back
    const z = H * f * (mirror ? -1 : 1);
    const col = lerpC(c.side0, c.side1, Math.pow(f, 0.8));
    return (
      <svg
        key={`${mirror ? "m" : "l"}${k}`}
        width={W}
        height={L}
        viewBox={`0 0 ${W} ${L}`}
        style={{
          position: "absolute",
          left: -W / 2,
          top: -L / 2,
          transform: `translateZ(${z}px) translateY(${dy}px) scale(${s})`,
          overflow: "visible",
        }}
      >
        <path d={SHAPE} fill={`rgb(${col.join(",")})`} />
      </svg>
    );
  };

  const topS = 1 - 0.5;
  const topDy = 34;
  const wheelZ = H * 0.9 + 16 - press * 12;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: 0,
        height: 0,
        perspective: 2000,
        opacity,
      }}
    >
      <div
        style={{
          position: "absolute",
          transformStyle: "preserve-3d",
          transform: `scale(${scale}) rotateX(${pitch}deg) rotateZ(${yaw}deg)`,
        }}
      >
        {/* contact shadow on the desk */}
        <div
          style={{
            position: "absolute",
            left: -W * 0.62,
            top: -L * 0.58,
            width: W * 1.24,
            height: L * 1.16,
            borderRadius: "50%",
            background: "radial-gradient(closest-side, rgba(0,0,0,0.75), rgba(0,0,0,0))",
            transform: "translateZ(-0.5px)",
          }}
        />
        {/* glossy desk reflection: mirrored stack below the desk plane */}
        {reflection ? (
          <div style={{ position: "absolute", transformStyle: "preserve-3d", opacity: 0.12, filter: "blur(2px)" }}>
            {Array.from({ length: N / 2 }, (_, i) => layer(i * 2, true))}
          </div>
        ) : null}
        {Array.from({ length: N }, (_, k) => layer(k, false))}

        {/* top shell */}
        <svg
          width={W}
          height={L}
          viewBox={`0 0 ${W} ${L}`}
          style={{
            position: "absolute",
            left: -W / 2,
            top: -L / 2,
            transform: `translateZ(${H}px) translateY(${topDy}px) scale(${topS + 0.5 * 0.92})`,
            overflow: "visible",
          }}
        >
          <defs>
            <radialGradient id={`mshell-${tone}`} cx="36%" cy="30%" r="80%">
              <stop offset="0" stopColor={c.top0} />
              <stop offset="1" stopColor={c.top1} />
            </radialGradient>
            <linearGradient id={`mspec-${tone}`} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#fff" stopOpacity="0.55" />
              <stop offset="0.45" stopColor="#fff" stopOpacity="0" />
            </linearGradient>
          </defs>
          <path d={SHAPE} fill={`url(#mshell-${tone})`} />
          <path d={SHAPE} fill={`url(#mspec-${tone})`} />
          {/* button split */}
          <path d="M150,6 L150,205" stroke={c.line} strokeWidth={3} />
          <path d="M30,210 C90,226 210,226 270,210" stroke={c.line} strokeWidth={2} fill="none" opacity={0.6} />
          {/* wheel slot */}
          <rect x={126} y={48} width={48} height={118} rx={24} fill="rgba(0,0,0,0.55)" />
          {/* glow under the wheel */}
          <rect x={112} y={34} width={76} height={146} rx={38} fill="rgba(10,132,255,0.9)" opacity={glow * 0.6} style={{ filter: "blur(14px)" }} />
        </svg>

        {/* scroll wheel (raised, presses down) */}
        <div
          style={{
            position: "absolute",
            left: -16,
            top: -L / 2 + 34 + 56 * 0.75 + 20,
            width: 32,
            height: 96,
            borderRadius: 16,
            transform: `translateZ(${wheelZ}px)`,
            background:
              glow > 0.02
                ? `linear-gradient(180deg, rgba(120,190,255,${0.7 + 0.3 * glow}), rgba(10,132,255,${0.85}))`
                : "linear-gradient(180deg, #3A3C42, #121316)",
            boxShadow: `inset 0 0 0 1.5px rgba(255,255,255,0.25), 0 0 ${glow * 40}px rgba(10,132,255,${glow})`,
            overflow: "hidden",
          }}
        >
          {/* ribs */}
          {Array.from({ length: 9 }).map((_, i) => (
            <div key={i} style={{ position: "absolute", left: 4, right: 4, top: 8 + i * 10, height: 2, borderRadius: 1, background: "rgba(255,255,255,0.28)" }} />
          ))}
          {/* specular */}
          <div style={{ position: "absolute", left: 4, top: 2, width: 8, height: 90, borderRadius: 4, background: "rgba(255,255,255,0.5)" }} />
        </div>
        {/* wheel side wall (gives it height in side views) */}
        <div
          style={{
            position: "absolute",
            left: -16,
            top: -L / 2 + 34 + 56 * 0.75 + 20,
            width: 32,
            height: 96,
            borderRadius: 16,
            transform: `translateZ(${wheelZ - 10}px)`,
            background: glow > 0.02 ? `rgba(10,132,255,${0.6 * glow + 0.2})` : "#0E0F11",
          }}
        />
      </div>
    </div>
  );
};

/** Canvas-space offset of the wheel relative to (x,y) for a given pose (approximate, for flashes/beams). */
export const wheelAnchor = (x: number, y: number, scale: number, pitch: number, yaw: number) => {
  // wheel sits ~0.31*L toward the front and H above the desk
  const fwd = -0.31 * L;
  const yr = (yaw * Math.PI) / 180;
  const pr = (pitch * Math.PI) / 180;
  const px = -fwd * Math.sin(yr);
  const py = Math.cos(yr) * fwd;
  return {
    x: x + px * scale,
    y: y + py * Math.cos(pr) * scale - H * Math.sin(pr) * scale,
  };
};
