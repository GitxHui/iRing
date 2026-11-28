/**
 * Film scene 8 — Details (abs 52.0–56.0, 4.0 s).
 * In  : MacBook3D front-on (FULL_FRAME). The device turns edge-on (rotateY) and the first glass
 *       detail card flips out of it; three more cards flip in on the 0.5 s grid.
 * Out : cards recede into black — Finale starts on black.
 */
import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { ISLAND_LEN, IslandWorld } from "./Island";
import { Sparkles } from "../../components/Sparkles";
import { MacBook3D } from "../device/MacBook3D";
import { COPY, FilmCue, FilmSceneProps } from "../contract";
import { Bloom, C, RevealLine, T as TY, Vignette } from "../style";
import { FULL_FRAME } from "../closing/common";
import {
  clamp01,
  easeIn,
  easeInOut,
  easeOut,
  kf,
  lerp,
  ramp,
  springAt,
} from "../../lib/anim";
import { FONT } from "../../theme";

export const DETAILS_LEN = 4.0;

const FLIP_END = 0.42; // device reaches edge-on
const CARD_AT = [0.45, 0.95, 1.45, 1.95];
const RECEDE = 3.45;

// grid (2 x 2) under the title
const GX = 140;
const GY = 300;
const GAP = 32;
const CW = (1920 - GX * 2 - GAP) / 2;
const CH = 330;
const slot = (i: number) => ({
  x: GX + (i % 2) * (CW + GAP),
  y: GY + Math.floor(i / 2) * (CH + GAP),
});

// ---------------------------------------------------------------- card illustrations
const Monitors: React.FC<{ t: number }> = ({ t }) => {
  const swap = Math.floor(Math.max(0, t - 0.6) / 0.45) % 3;
  const leftFill = ["#E8EEF8", "#2A2D34", "#F3EEE4"][swap];
  const pulse = 0.5 + 0.5 * Math.sin(t * 5);
  return (
    <svg width={300} height={200} viewBox="0 0 300 200">
      {[0, 1].map((m) => (
        <g key={m} transform={`translate(${m * 152} ${m === 0 ? 14 : 34})`}>
          <rect
            x={0}
            y={0}
            width={140}
            height={92}
            rx={10}
            fill="rgba(255,255,255,0.06)"
            stroke="rgba(255,255,255,0.55)"
            strokeWidth={2}
          />
          <rect
            x={60}
            y={92}
            width={20}
            height={20}
            fill="rgba(255,255,255,0.35)"
          />
          <rect
            x={40}
            y={110}
            width={60}
            height={5}
            rx={2.5}
            fill="rgba(255,255,255,0.35)"
          />
          {m === 0 ? (
            <rect
              x={10}
              y={12}
              width={120}
              height={68}
              rx={6}
              fill={leftFill}
            />
          ) : (
            <>
              <rect
                x={10}
                y={12}
                width={120}
                height={68}
                rx={6}
                fill="#EAF2FF"
              />
              <rect
                x={10}
                y={12}
                width={120}
                height={68}
                rx={6}
                fill="none"
                stroke={C.blue}
                strokeWidth={2.5}
                opacity={0.5 + 0.5 * pulse}
              />
              <rect
                x={22}
                y={26}
                width={60}
                height={7}
                rx={3.5}
                fill="#9DB7DE"
              />
              <rect
                x={22}
                y={40}
                width={86}
                height={7}
                rx={3.5}
                fill="#C4D4EC"
              />
            </>
          )}
        </g>
      ))}
    </svg>
  );
};

const MiniRing: React.FC<{ size: number; angle: number; dark?: boolean }> = ({
  size,
  angle,
  dark = false,
}) => {
  const ro = 46;
  const ri = 22;
  const a0 = ((angle - 22) * Math.PI) / 180;
  const a1 = ((angle + 22) * Math.PI) / 180;
  const p = (r: number, a: number) =>
    `${50 + Math.cos(a) * r} ${50 + Math.sin(a) * r}`;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      style={{ overflow: "visible" }}
    >
      <circle
        cx={50}
        cy={50}
        r={(ro + ri) / 2}
        fill="none"
        stroke={dark ? "#1C1D22" : "#F3F5F9"}
        strokeWidth={ro - ri}
      />
      <path
        d={`M ${p(ro, a0)} A ${ro} ${ro} 0 0 1 ${p(ro, a1)} L ${p(ri, a1)} A ${ri} ${ri} 0 0 0 ${p(ri, a0)} Z`}
        fill="#0A84FF"
      />
      <circle
        cx={50}
        cy={50}
        r={ro - 0.5}
        fill="none"
        stroke={dark ? "rgba(255,255,255,0.22)" : "#fff"}
        strokeWidth={1}
      />
      <circle
        cx={50}
        cy={50}
        r={ri + 0.5}
        fill="none"
        stroke={dark ? "rgba(255,255,255,0.12)" : "rgba(255,255,255,0.9)"}
        strokeWidth={1}
      />
    </svg>
  );
};

const Looks: React.FC<{ t: number }> = ({ t }) => (
  <div style={{ display: "flex", gap: 34, alignItems: "center" }}>
    <div style={{ filter: "drop-shadow(0 10px 22px rgba(0,0,0,0.45))" }}>
      <MiniRing size={150} angle={-60 + t * 90} />
    </div>
    <div style={{ filter: "drop-shadow(0 10px 22px rgba(0,0,0,0.45))" }}>
      <MiniRing size={150} angle={120 + t * 90} dark />
    </div>
  </div>
);

const Motion: React.FC<{ t: number }> = ({ t }) => {
  const knob = kf(t, [0.3, 1.0, 1.7, 2.4], [0.25, 0.85, 0.45, 0.7], easeInOut);
  return (
    <div style={{ position: "relative", width: 300, height: 200 }}>
      <div
        style={{
          position: "absolute",
          left: 20,
          top: 10,
          filter: "drop-shadow(0 8px 18px rgba(0,0,0,0.4))",
        }}
      >
        <MiniRing size={120} angle={t * 200} />
      </div>
      <div style={{ position: "absolute", left: 80, top: 70 }}>
        <Sparkles
          t={t}
          angle={t * 200}
          spread={50}
          radius={55}
          intensity={1}
          count={40}
          seed={7}
        />
      </div>
      <div style={{ position: "absolute", left: 170, top: 56, width: 120 }}>
        {[knob, 1 - knob * 0.6].map((v, i) => (
          <div
            key={i}
            style={{ position: "relative", height: 26, marginBottom: 22 }}
          >
            <div
              style={{
                position: "absolute",
                top: 10,
                left: 0,
                right: 0,
                height: 5,
                borderRadius: 3,
                background: "rgba(255,255,255,0.22)",
              }}
            />
            <div
              style={{
                position: "absolute",
                top: 10,
                left: 0,
                width: `${v * 100}%`,
                height: 5,
                borderRadius: 3,
                background: C.sysBlue,
              }}
            />
            <div
              style={{
                position: "absolute",
                top: 0,
                left: `calc(${v * 100}% - 13px)`,
                width: 26,
                height: 26,
                borderRadius: 13,
                background: "#fff",
                boxShadow: "0 3px 10px rgba(0,0,0,0.45)",
              }}
            />
          </div>
        ))}
      </div>
    </div>
  );
};

const Bilingual: React.FC<{ t: number }> = ({ t }) => {
  const en = Math.floor(Math.max(0, t - 0.5) / 0.7) % 2 === 1;
  const k = springAt(t, 0.5 + Math.floor(Math.max(0, t - 0.5) / 0.7) * 0.7, {
    response: 0.35,
    damping: 0.8,
  });
  const words = en ? ["Switch", "Tile", "Resize"] : ["切屏", "分屏", "缩放"];
  return (
    <div style={{ width: 300, fontFamily: FONT }}>
      <div
        style={{
          position: "relative",
          display: "flex",
          width: 260,
          height: 48,
          borderRadius: 24,
          background: "rgba(255,255,255,0.1)",
          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.14)",
          marginBottom: 22,
        }}
      >
        <div
          style={{
            position: "absolute",
            top: 4,
            left: en ? 130 : 4,
            width: 126,
            height: 40,
            borderRadius: 20,
            background: "rgba(255,255,255,0.92)",
            transition: "none",
          }}
        />
        {["中文", "English"].map((l, i) => (
          <div
            key={l}
            style={{
              position: "relative",
              flex: 1,
              textAlign: "center",
              lineHeight: "48px",
              fontSize: 20,
              fontWeight: 600,
              color: (i === 1) === en ? "#111" : "rgba(255,255,255,0.7)",
            }}
          >
            {l}
          </div>
        ))}
      </div>
      <div
        style={{
          display: "flex",
          gap: 18,
          opacity: clamp01(k),
          filter: `blur(${(1 - clamp01(k)) * 6}px)`,
        }}
      >
        {words.map((w) => (
          <div key={w} style={{ fontSize: 26, fontWeight: 600, color: C.ink }}>
            {w}
          </div>
        ))}
      </div>
    </div>
  );
};

/** "A · B" / "A，B" / "A, B" → two lines (keynote: statement + grey qualifier). */
const splitLabel = (l: string) => {
  for (const sep of [" · ", "，", ", "]) {
    const i = l.indexOf(sep);
    if (i > 0) return [l.slice(0, i), l.slice(i + sep.length)];
  }
  return [l];
};

const Card: React.FC<{
  t: number;
  i: number;
  label: string;
  children: React.ReactNode;
  recede: number;
}> = ({ t, i, label, children, recede }) => {
  const at = CARD_AT[i];
  if (t < at - 0.02) return null;
  const f = springAt(t, at, { response: 0.5, damping: 0.8 });
  const { x, y } = slot(i);
  // first card flips out of the device from centre-stage, others flip in place
  const fromCenter =
    i === 0 ? 1 - springAt(t, at + 0.18, { response: 0.6, damping: 0.86 }) : 0;
  const cx = lerp(x, 960 - CW / 2, fromCenter);
  const cy = lerp(y, 540 - CH / 2, fromCenter);
  const sc = lerp(1, 1.35, fromCenter);
  const rotY = (1 - clamp01(f)) * -90;
  return (
    <div
      style={{
        position: "absolute",
        left: cx,
        top: cy,
        width: CW,
        height: CH,
        transform: `perspective(2200px) rotateY(${rotY}deg) scale(${sc * (1 - 0.12 * recede)}) translateZ(${-recede * 300}px)`,
        transformOrigin: i % 2 === 0 ? "0% 50%" : "100% 50%",
        opacity: clamp01(f * 2) * (1 - recede),
        filter: `blur(${recede * 12}px)`,
        borderRadius: 34,
        background:
          "linear-gradient(160deg, rgba(255,255,255,0.11), rgba(255,255,255,0.035))",
        boxShadow:
          "inset 0 1px 0 rgba(255,255,255,0.22), inset 0 0 0 1px rgba(255,255,255,0.1), 0 40px 90px rgba(0,0,0,0.55)",
        overflow: "hidden",
        fontFamily: FONT,
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: 400,
          height: CH,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        {children}
      </div>
      <div
        style={{
          position: "absolute",
          left: 400,
          right: 30,
          top: 0,
          bottom: 0,
          display: "flex",
          alignItems: "center",
        }}
      >
        <div
          style={{
            fontSize: 44,
            fontWeight: 600,
            letterSpacing: -0.6,
            lineHeight: 1.18,
          }}
        >
          {splitLabel(label).map((ln, k) => (
            <div
              key={k}
              style={{ color: k === 0 ? C.ink : C.grey, whiteSpace: "nowrap" }}
            >
              {ln}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export const Details: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const copy = COPY.details[lang];

  // device: front-on → turns edge-on and drops away
  const turn = ramp(t, 0, FLIP_END, easeIn);
  const devOpacity = 1 - ramp(t, FLIP_END - 0.06, FLIP_END + 0.02);
  const recede = ramp(t, RECEDE, DETAILS_LEN, easeIn);

  // open on the exact last frame of the Island scene
  const world = <IslandWorld t={ISLAND_LEN - 1 / 60} />;

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <Bloom x={960} y={560} r={950} o={0.14 * (1 - recede)} />
      {devOpacity > 0.01 ? (
        <div style={{ position: "absolute", inset: 0, opacity: devOpacity }}>
          <MacBook3D
            cx={FULL_FRAME.cx}
            cy={FULL_FRAME.cy}
            cam={{
              rx: FULL_FRAME.rx,
              ry: lerp(FULL_FRAME.ry, 88, turn),
              s: lerp(FULL_FRAME.s, 0.78, turn),
            }}
            lid={FULL_FRAME.lid}
            screen={world}
          />
        </div>
      ) : null}

      <div
        style={{
          position: "absolute",
          left: GX,
          top: 150,
          opacity: 1 - recede,
          filter: `blur(${recede * 10}px)`,
        }}
      >
        <RevealLine
          text={copy.title}
          t={t}
          at={0.45}
          lang={lang}
          style={{
            ...TY.title,
            fontSize: 80,
            letterSpacing: lang === "zh" ? 0 : -1.8,
          }}
        />
      </div>

      <Card t={t} i={0} label={copy.cards[0]} recede={recede}>
        <Monitors t={t} />
      </Card>
      <Card t={t} i={1} label={copy.cards[1]} recede={recede}>
        <Looks t={t} />
      </Card>
      <Card t={t} i={2} label={copy.cards[2]} recede={recede}>
        <Motion t={t} />
      </Card>
      <Card t={t} i={3} label={copy.cards[3]} recede={recede}>
        <Bilingual t={t} />
      </Card>
      <Vignette o={0.5} />
      {/* last frames: fully black for the Finale hand-off */}
      <AbsoluteFill
        style={{
          background: "#000",
          opacity: ramp(t, DETAILS_LEN - 0.15, DETAILS_LEN, easeOut),
        }}
      />
    </AbsoluteFill>
  );
};

export const CUES: FilmCue[] = [
  { sfx: "flip", at: 0.0, vol: 0.8 },
  { sfx: "text_in", at: 0.45, vol: 0.3 },
  ...CARD_AT.map((at, i) => ({ sfx: `tile_${i}`, at: at + 0.05, vol: 0.6 })),
  { sfx: "shimmer", at: 2.3, vol: 0.3 },
  { sfx: "whoosh", at: RECEDE, vol: 0.4 },
];
