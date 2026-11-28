import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Ring } from "../../components/Ring";
import { Cursor } from "../../components/Cursor";
import { RING_APPS } from "../../lib/apps";
import { clamp01, easeIn, easeInOut, easeOut, kf, lerp, rand, ramp, springAt, track, window01 } from "../../lib/anim";
import { FONT } from "../../theme";
import { COPY, FilmCue, FilmSceneProps, HITS, SCENES } from "../contract";
import { Bloom, C, RevealLine, SP, SweepText, T as TY, Vignette } from "../style";
import { GlassDonut } from "../opening/helpers";

const LEN = SCENES.reveal.len;
const BLOOM = HITS.reveal - SCENES.reveal.start; // 0.5
const LOCK = HITS.lockup - SCENES.reveal.start; // 3.0
const OUT = 6.2;

// lock-up geometry
const ICON = 190;
const ICON_C = { x: 760, y: 470 };
const WORD_X = ICON_C.x + ICON / 2 + 42;

const Bokeh: React.FC<{ t: number; o: number }> = ({ t, o }) => (
  <>
    {Array.from({ length: 9 }).map((_, i) => {
      const r = 20 + rand(i * 3.1) * 70;
      const x = rand(i * 7.7) * 1920 + Math.sin(t * 0.4 + i) * 40;
      const y = rand(i * 5.3) * 1080 + Math.cos(t * 0.3 + i) * 30;
      const blue = rand(i * 2.2) > 0.4;
      return (
        <div
          key={i}
          style={{
            position: "absolute",
            left: x - r,
            top: y - r,
            width: r * 2,
            height: r * 2,
            borderRadius: "50%",
            background: blue ? "rgba(80,150,255,0.5)" : "rgba(255,255,255,0.35)",
            filter: `blur(${10 + r * 0.25}px)`,
            opacity: o * (0.25 + rand(i) * 0.35),
          }}
        />
      );
    })}
  </>
);

export const Reveal: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const copy = COPY.reveal[lang];

  // --- cursor that becomes the ring -------------------------------------------
  const curGone = ramp(t, BLOOM, BLOOM + 0.25, easeIn);
  const curPulse = window01(t, 0.15, BLOOM, 0.3, 0.05);

  // --- hero ring: 3D orbit from the side back to front --------------------------
  const ringAt = BLOOM;
  const ringClose = LOCK - 0.15;
  const orbit = { response: 1.25, damping: 0.9 };
  const ry = kf(t, [ringAt, ringAt + 1.9], [-58, 0], easeInOut) + Math.sin(t * 1.3) * 2.5 * ramp(t, 2.0, 2.5);
  const rx = kf(t, [ringAt, ringAt + 1.9], [28, 0], easeInOut) + track(t, [[0, 0]], orbit);
  const sweep = kf(t, [ringAt + 0.45, ringClose - 0.25], [-90, 270], easeInOut);
  const engage = window01(t, ringAt + 0.35, ringClose - 0.2, 0.25, 0.2);
  const toIcon = springAt(t, ringClose - 0.15, SP.ui);
  const ringX = lerp(960, ICON_C.x, toIcon);
  const ringY = lerp(540, ICON_C.y, toIcon);

  // shockwave
  const shock = ramp(t, BLOOM, BLOOM + 1.1, easeOut);

  // --- lock-up ---------------------------------------------------------------
  const icon = springAt(t, LOCK - 0.05, SP.pop);
  const out = ramp(t, OUT, OUT + 0.45, easeInOut);
  const iconToCenter = springAt(t, OUT, SP.ui);
  const iconX = lerp(ICON_C.x, 960, iconToCenter);
  const iconY = lerp(ICON_C.y, 540, iconToCenter);
  const wordP = clamp01(ramp(t, LOCK + 0.1, LOCK + 0.75, easeOut));
  const sweepX = kf(t, [LOCK + 0.55, LOCK + 1.6], [-40, 140], easeInOut);
  const push = 1 + 0.03 * ramp(t, LOCK, OUT, easeInOut);
  const donut = springAt(t, OUT + 0.12, SP.ui);

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <Bloom x={960} y={540} r={320} o={0.38 * (1 - ramp(t, 0, BLOOM + 0.2))} />
      <Bloom x={960} y={540} r={lerp(300, 820, clamp01(shock * 1.4))} o={0.32 * window01(t, BLOOM - 0.1, LOCK, 0.15, 0.8) + 0.12 * curPulse} />
      <Bloom x={ICON_C.x + 300} y={500} r={900} color="120,90,255" o={0.14 * window01(t, LOCK - 0.2, OUT, 0.6, 0.5)} />

      {/* background bokeh (depth) */}
      <AbsoluteFill style={{ opacity: 0.8 }}>
        <Bokeh t={t} o={window01(t, BLOOM, OUT, 0.6, 0.6) * 0.6} />
      </AbsoluteFill>

      {/* shockwave */}
      {t > BLOOM && shock < 1 ? (
        <div
          style={{
            position: "absolute",
            left: 960 - 900 * shock,
            top: 540 - 900 * shock,
            width: 1800 * shock,
            height: 1800 * shock,
            borderRadius: "50%",
            border: `${lerp(5, 1, shock)}px solid rgba(160,200,255,${0.65 * (1 - shock)})`,
            boxShadow: `0 0 70px rgba(60,140,255,${0.45 * (1 - shock)})`,
          }}
        />
      ) : null}

      {/* hero ring in 3D */}
      <AbsoluteFill style={{ perspective: 1500, perspectiveOrigin: "960px 540px" }}>
        <AbsoluteFill
          style={{
            transformStyle: "preserve-3d",
            transformOrigin: `${ringX}px ${ringY}px`,
            transform: `rotateX(${rx}deg) rotateY(${ry}deg)`,
          }}
        >
          <Ring
            cx={ringX}
            cy={ringY}
            t={t}
            openAt={ringAt}
            closeAt={ringClose}
            pointer={sweep}
            engage={engage}
            apps={RING_APPS}
            size={1.5 * lerp(1, 0.55, toIcon)}
            sparkle={0.7}
          />
        </AbsoluteFill>
      </AbsoluteFill>

      {/* the cursor that summons it */}
      {curGone < 1 ? (
        <div style={{ position: "absolute", inset: 0, opacity: 1 - curGone }}>
          <Bloom x={960} y={540} r={90 + 60 * curPulse} o={0.35 * curPulse} />
          <Cursor x={960} y={540} scale={1.6 * (1 - 0.4 * curGone)} />
        </div>
      ) : null}

      {/* lock-up */}
      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: "960px 520px" }}>
        {t > LOCK - 0.1 && t < OUT + 0.9 ? (
          <Img
            src={staticFile("icons/iring.png")}
            style={{
              position: "absolute",
              left: iconX - ICON / 2,
              top: iconY - ICON / 2,
              width: ICON,
              height: ICON,
              opacity: clamp01(icon * 1.6) * (1 - ramp(t, OUT + 0.15, OUT + 0.45)),
              transform: `scale(${(0.6 + 0.4 * icon) * lerp(1, 0.47, iconToCenter)})`,
              filter: `drop-shadow(0 24px 50px rgba(0,0,0,0.6)) drop-shadow(0 0 ${36 * (1 - wordP)}px rgba(80,150,255,0.7))`,
            }}
          />
        ) : null}
        {t > LOCK && out < 1 ? (
          <div
            style={{
              position: "absolute",
              left: WORD_X,
              top: ICON_C.y - 98,
              fontFamily: FONT,
              ...TY.hero,
              fontSize: 176,
              letterSpacing: -5,
              whiteSpace: "nowrap",
              opacity: wordP * (1 - out),
              filter: `blur(${(1 - wordP) * 14 + out * 12}px)`,
              transform: `translateX(${(1 - wordP) * -36}px)`,
            }}
          >
            <SweepText text={copy.name} fontSize={176} letterSpacing={-5} sweep={sweepX / 100} band={0.1} glint="#9CC8FF" />
          </div>
        ) : null}
        {t > LOCK + 0.4 && out < 1 ? (
          <div style={{ position: "absolute", left: 0, right: 0, top: 640, display: "flex", justifyContent: "center", opacity: 1 - out, filter: `blur(${out * 12}px)` }}>
            <RevealLine text={copy.line} t={t} at={LOCK + 0.6} lang={lang} color={C.grey} style={{ ...TY.sub, fontSize: 48, letterSpacing: lang === "zh" ? 1 : -0.6 }} />
          </div>
        ) : null}
      </AbsoluteFill>

      {/* handoff: small glass ring at centre */}
      {t > OUT ? <GlassDonut cx={960} cy={540} r={90} s={0.6 + 0.4 * donut} o={clamp01(donut * 1.5)} /> : null}

      <Vignette o={0.5} />
    </AbsoluteFill>
  );
};

export const CUES: FilmCue[] = [
  { sfx: "ring_open", at: BLOOM, vol: 0.9 },
  { sfx: "impact", at: BLOOM, vol: 0.8 },
  { sfx: "shimmer", at: BLOOM + 0.1, vol: 0.5 },
  { sfx: "orbit", at: BLOOM + 0.35, vol: 0.55 },
  { sfx: "whoosh", at: LOCK - 0.35, vol: 0.45 },
  { sfx: "shimmer", at: LOCK, vol: 0.45 },
  { sfx: "lightsweep", at: LOCK + 0.55, vol: 0.45 },
  { sfx: "text_in", at: LOCK + 0.6, vol: 0.4 },
  { sfx: "whoosh_fast", at: OUT, vol: 0.35 },
  { sfx: "glass_flip", at: OUT + 0.12, vol: 0.35 },
];
void LEN;
