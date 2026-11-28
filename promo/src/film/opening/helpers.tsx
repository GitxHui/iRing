import React from "react";
import { Pt, easeInOut, kf } from "../../lib/anim";

/** Glass donut used for the reveal -> entries handoff (matches Ring's look, no icons). */
export const GlassDonut: React.FC<{ cx: number; cy: number; r: number; s?: number; o?: number; wedge?: number; angle?: number }> = ({
  cx,
  cy,
  r,
  s = 1,
  o = 1,
  wedge = 0,
  angle = -60,
}) => {
  const ri = r * 0.47;
  const a0 = ((angle - 22) * Math.PI) / 180;
  const a1 = ((angle + 22) * Math.PI) / 180;
  const p = (rad: number, a: number) => `${(Math.cos(a) * rad).toFixed(2)} ${(Math.sin(a) * rad).toFixed(2)}`;
  return (
    <div style={{ position: "absolute", left: cx, top: cy, width: 0, height: 0, transform: `scale(${s})`, opacity: o }}>
      <div
        style={{
          position: "absolute",
          left: -r,
          top: -r,
          width: r * 2,
          height: r * 2,
          borderRadius: "50%",
          boxShadow: "0 18px 50px rgba(10,60,160,0.35), 0 0 80px rgba(41,120,255,0.18)",
        }}
      />
      <svg width={1} height={1} style={{ position: "absolute", overflow: "visible" }}>
        <defs>
          <radialGradient id="gd-fill" cx="0.5" cy="0.35" r="0.75">
            <stop offset="0" stopColor="#FFFFFF" stopOpacity="0.97" />
            <stop offset="1" stopColor="#DDE3EE" stopOpacity="0.9" />
          </radialGradient>
        </defs>
        <path
          d={`M ${r} 0 A ${r} ${r} 0 1 1 ${-r} 0 A ${r} ${r} 0 1 1 ${r} 0 Z M ${ri} 0 A ${ri} ${ri} 0 1 0 ${-ri} 0 A ${ri} ${ri} 0 1 0 ${ri} 0 Z`}
          fillRule="evenodd"
          fill="url(#gd-fill)"
        />
        {wedge > 0.01 ? (
          <path d={`M ${p(r, a0)} A ${r} ${r} 0 0 1 ${p(r, a1)} L ${p(ri, a1)} A ${ri} ${ri} 0 0 0 ${p(ri, a0)} Z`} fill="#0A6CF0" opacity={wedge} />
        ) : null}
        <circle r={r - 0.7} fill="none" stroke="rgba(255,255,255,0.95)" strokeWidth={1.4} />
        <circle r={ri + 0.7} fill="none" stroke="rgba(255,255,255,0.8)" strokeWidth={1.2} />
        <circle r={ri} fill="rgba(20,30,50,0.55)" />
      </svg>
    </div>
  );
};

/** Eased path through waypoints [time, point]; each leg bows into a gentle arc (hand-like motion). */
export const pathAt = (t: number, wps: Array<[number, Pt]>): Pt => {
  if (t <= wps[0][0]) return wps[0][1];
  if (t >= wps[wps.length - 1][0]) return wps[wps.length - 1][1];
  let i = 0;
  while (i < wps.length - 2 && t > wps[i + 1][0]) i++;
  const [t0, a] = wps[i];
  const [t1, b] = wps[i + 1];
  const u = easeInOut(Math.min(1, Math.max(0, (t - t0) / (t1 - t0))));
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const bow = Math.sin(Math.PI * u) * 0.16 * (i % 2 === 0 ? 1 : -1);
  return [a[0] + dx * u - dy * bow, a[1] + dy * u + dx * bow];
};
void kf;

/** Glowing, age-faded trail drawn from sampled points (canvas coords). */
export const Trail: React.FC<{ pts: Array<{ p: Pt; age: number }>; o?: number; width?: number }> = ({ pts, o = 1, width = 5 }) => {
  if (pts.length < 2 || o <= 0.001) return null;
  const segs: React.ReactNode[] = [];
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1].p;
    const b = pts[i].p;
    const k = Math.max(0.12, 1 - pts[i].age / 3.2);
    segs.push(
      <line
        key={i}
        x1={a[0].toFixed(1)}
        y1={a[1].toFixed(1)}
        x2={b[0].toFixed(1)}
        y2={b[1].toFixed(1)}
        stroke={`rgba(90,170,255,${(0.9 * k).toFixed(3)})`}
        strokeWidth={width * (0.5 + 0.5 * k)}
        strokeLinecap="round"
      />,
    );
  }
  return (
    <svg width={1920} height={1080} style={{ position: "absolute", left: 0, top: 0, opacity: o, overflow: "visible" }}>
      <g style={{ filter: "blur(9px)" }} opacity={0.7}>
        {segs}
      </g>
      <g>{segs}</g>
    </svg>
  );
};
