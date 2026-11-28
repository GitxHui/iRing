import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Sky } from "../components/Sky";
import { clamp01, easeIn, easeInOut, easeOut, kf, ramp, springAt } from "../lib/anim";
import { COPY, Lang } from "../lib/copy";
import { BLUE, FONT, W } from "../theme";

export const BENTO_LEN = 4.6;
export const BENTO_AT = [0.45, 0.95, 1.45, 1.95];

const MiniRing: React.FC<{ size: number; angle: number; dark?: boolean }> = ({ size, angle, dark = false }) => {
  const ro = 46;
  const ri = 22;
  const a0 = ((angle - 22) * Math.PI) / 180;
  const a1 = ((angle + 22) * Math.PI) / 180;
  const p = (r: number, a: number) => `${50 + Math.cos(a) * r} ${50 + Math.sin(a) * r}`;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ overflow: "visible", filter: "drop-shadow(0 8px 16px rgba(0,0,0,0.25))" }}>
      <circle cx={50} cy={50} r={(ro + ri) / 2} fill="none" stroke={dark ? "#1C1D22" : "#F3F5F9"} strokeWidth={ro - ri} />
      <path d={`M ${p(ro, a0)} A ${ro} ${ro} 0 0 1 ${p(ro, a1)} L ${p(ri, a1)} A ${ri} ${ri} 0 0 0 ${p(ri, a0)} Z`} fill={BLUE} />
      <circle cx={50} cy={50} r={ro - 0.5} fill="none" stroke={dark ? "rgba(255,255,255,0.18)" : "#fff"} strokeWidth={1} />
    </svg>
  );
};

const Tile: React.FC<{ t: number; at: number; x: number; y: number; w: number; h: number; title: string; sub: string; children: React.ReactNode }> = ({
  t,
  at,
  x,
  y,
  w,
  h,
  title,
  sub,
  children,
}) => {
  const s = springAt(t, at, { response: 0.48, damping: 0.74 });
  if (t < at) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: w,
        height: h,
        borderRadius: 40,
        opacity: clamp01(s * 1.5),
        transform: `translateY(${(1 - s) * 70}px) scale(${0.9 + 0.1 * s})`,
        background: "linear-gradient(160deg, rgba(255,255,255,0.30), rgba(255,255,255,0.10))",
        backdropFilter: "blur(30px) saturate(1.7)",
        boxShadow:
          "inset 0 1px 0 rgba(255,255,255,0.7), inset 0 0 0 1px rgba(255,255,255,0.28), 0 30px 70px rgba(5,15,45,0.35)",
        overflow: "hidden",
        fontFamily: FONT,
        color: "#fff",
      }}
    >
      <div style={{ position: "absolute", left: 0, top: 0, width: h, height: h, display: "flex", alignItems: "center", justifyContent: "center" }}>
        {children}
      </div>
      <div style={{ position: "absolute", left: h + 10, right: 40, top: 0, bottom: 0, display: "flex", flexDirection: "column", justifyContent: "center" }}>
        <div style={{ fontSize: 46, fontWeight: 750, letterSpacing: -0.8, lineHeight: 1.1, textShadow: "0 2px 16px rgba(0,0,0,0.25)" }}>{title}</div>
        <div style={{ fontSize: 27, fontWeight: 500, opacity: 0.82, marginTop: 12 }}>{sub}</div>
      </div>
    </div>
  );
};

export const Bento: React.FC<{ lang: Lang }> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY[lang];
  const exit = ramp(t, BENTO_LEN - 0.4, BENTO_LEN, easeIn);

  const gx = 140;
  const gy = 230;
  const gap = 30;
  const tw = (W - gx * 2 - gap) / 2;
  const th = 340;

  const spin = t * 140;
  const mouseGlow = 0.5 + 0.5 * Math.sin(t * 7);
  const swap = Math.floor(t / 0.55) % 3;
  const knob = kf(t, [1.9, 2.6, 3.3, 4.0], [0.2, 0.85, 0.45, 0.7], easeInOut);

  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#0B1A33" }}>
      <AbsoluteFill style={{ filter: "blur(30px)", transform: "scale(1.12)" }}>
        <Sky t={t + 20} />
      </AbsoluteFill>
      <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(6,16,40,0.35), rgba(6,16,40,0.55))" }} />
      <AbsoluteFill style={{ opacity: 1 - exit, transform: `scale(${1 - 0.04 * exit})` }}>
        <div
          style={{
            position: "absolute",
            left: gx,
            top: 110,
            fontFamily: FONT,
            fontSize: 64,
            fontWeight: 800,
            color: "#fff",
            letterSpacing: lang === "zh" ? 2 : -1.5,
            opacity: ramp(t, 0, 0.35, easeOut),
            transform: `translateY(${(1 - ramp(t, 0, 0.45, easeOut)) * 24}px)`,
            textShadow: "0 4px 30px rgba(0,0,0,0.3)",
          }}
        >
          {c.bentoKicker}
        </div>

        <Tile t={t} at={BENTO_AT[0]} x={gx} y={gy} w={tw} h={th} title={c.bentoMouse} sub={c.bentoMouseSub}>
          <div style={{ position: "relative", width: 230, height: 230 }}>
            <svg width={130} height={190} viewBox="0 0 130 190" style={{ position: "absolute", left: 10, top: 20 }}>
              <rect x={5} y={5} width={120} height={180} rx={60} fill="rgba(255,255,255,0.92)" />
              <line x1={65} y1={5} x2={65} y2={80} stroke="rgba(20,40,80,0.2)" strokeWidth={2} />
              <rect x={56} y={28} width={18} height={36} rx={9} fill={BLUE} opacity={0.6 + 0.4 * mouseGlow} />
            </svg>
            <div style={{ position: "absolute", left: 120, top: 10, filter: `drop-shadow(0 0 ${14 * mouseGlow}px rgba(10,108,240,0.8))` }}>
              <MiniRing size={110} angle={spin} />
            </div>
          </div>
        </Tile>

        <Tile t={t} at={BENTO_AT[1]} x={gx + tw + gap} y={gy} w={tw} h={th} title={c.bentoDisplays} sub={c.bentoDisplaysSub}>
          <svg width={280} height={200} viewBox="0 0 280 200">
            {[0, 1].map((m) => (
              <g key={m} transform={`translate(${m * 142} ${m === 0 ? 20 : 40})`}>
                <rect x={0} y={0} width={132} height={88} rx={10} fill="rgba(255,255,255,0.22)" stroke="rgba(255,255,255,0.8)" strokeWidth={2.5} />
                <rect x={56} y={88} width={20} height={22} fill="rgba(255,255,255,0.6)" />
                <rect x={36} y={108} width={60} height={6} rx={3} fill="rgba(255,255,255,0.6)" />
                {m === 0 ? (
                  <rect x={10} y={12} width={112} height={66} rx={6} fill={["#E8EEF8", "#2A2D34", "#F3EEE4"][swap]} />
                ) : (
                  <>
                    <rect x={10} y={12} width={112} height={66} rx={6} fill="#EAF2FF" stroke={BLUE} strokeWidth={3} />
                    <rect x={20} y={24} width={60} height={7} rx={3.5} fill="#9DB7DE" />
                    <rect x={20} y={38} width={84} height={7} rx={3.5} fill="#C4D4EC" />
                  </>
                )}
              </g>
            ))}
          </svg>
        </Tile>

        <Tile t={t} at={BENTO_AT[2]} x={gx} y={gy + th + gap} w={tw} h={th} title={c.bentoThemes} sub={c.bentoThemesSub}>
          <div style={{ display: "flex", gap: 18 }}>
            <MiniRing size={120} angle={spin * 0.8} />
            <MiniRing size={120} angle={spin * 0.8 + 180} dark />
          </div>
        </Tile>

        <Tile t={t} at={BENTO_AT[3]} x={gx + tw + gap} y={gy + th + gap} w={tw} h={th} title={c.bentoSpeed} sub={c.bentoSpeedSub}>
          <div style={{ width: 240, display: "flex", flexDirection: "column", gap: 30 }}>
            {[knob, 1 - knob * 0.7].map((v, i) => (
              <div key={i} style={{ position: "relative", height: 34 }}>
                <div style={{ position: "absolute", top: 13, left: 0, right: 0, height: 8, borderRadius: 4, background: "rgba(255,255,255,0.3)" }} />
                <div style={{ position: "absolute", top: 13, left: 0, width: `${v * 100}%`, height: 8, borderRadius: 4, background: BLUE }} />
                <div
                  style={{
                    position: "absolute",
                    top: 0,
                    left: `calc(${v * 100}% - 17px)`,
                    width: 34,
                    height: 34,
                    borderRadius: 17,
                    background: "#fff",
                    boxShadow: "0 4px 12px rgba(0,0,0,0.3)",
                  }}
                />
              </div>
            ))}
          </div>
        </Tile>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
