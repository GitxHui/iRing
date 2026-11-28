/**
 * Film scene 3 — "Two ways in" (absolute 16.0–25.0, local 0–9).
 * ⌥ on the keyboard and the middle mouse button are presented as EQUAL entries that converge
 * into the same ring, then bridge into "inside the ring, gestures do the rest".
 */
import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { MacBook3D } from "../device/MacBook3D";
import { Mouse3D, wheelAnchor } from "../hardware/Mouse3D";
import { KeyCap3D } from "../hardware/KeyCap3D";
import { Beam, GlassDonut, PressBurst } from "../hardware/Fx";
import { Ring } from "../../components/Ring";
import { RING_APPS } from "../../lib/apps";
import { clamp01, easeIn, easeInOut, easeOut, kf, lerp, ramp, springAt, window01 } from "../../lib/anim";
import { COPY, FilmCue, FilmSceneProps } from "../contract";
import { Bloom, C, RevealLine, SP, T, TitleBlock, Vignette } from "../style";
import { FONT } from "../../theme";

// ---- timeline (local seconds) ----------------------------------------------------
const E = {
  kbIn: 0.45,
  keyPress: 1.5, // = HITS.keyPress (17.5)
  flipOut: 3.3,
  mouseIn: 3.45,
  midPress: 4.0, // = HITS.midPress (20.0)
  split: 5.85,
  beams: 6.05,
  converge: 6.5, // = HITS.converge (22.5)
  bridge: 8.0,
};

// screen anchors
const KEY_SCREEN = { x: 1150, y: 760 }; // where the ⌥ key sits after the dolly
const RING_SPOT = { x: 1420, y: 330 }; // where the ring blooms in both hardware shots
const MOUSE_POS = { x: 1250, y: 770 };
const CENTER = { x: 960, y: 540 };

/** press envelope: quick down, held, release */
const held = (t: number, a: number, b: number) => Math.min(ramp(t, a - 0.06, a, easeOut), 1 - ramp(t, b, b + 0.18, easeIn));

const KeyboardShot: React.FC<{ t: number }> = ({ t }) => {
  const dolly = springAt(t, E.kbIn, SP.soft);
  const cx = lerp(2160 + 760, 2160, dolly);
  const ry = lerp(-24, -10, dolly) + Math.sin(t * 0.7) * 0.6;
  const s = 2.4 + 0.08 * ramp(t, E.kbIn, E.flipOut, easeInOut);
  const opt = Math.max(held(t, E.keyPress, E.flipOut - 0.1) * 0.9, window01(t, E.keyPress - 0.06, E.keyPress + 0.12, 0.06, 0.25) * 1);
  const dev = (
    <MacBook3D
      cx={cx}
      cy={450}
      cam={{ rx: -70, ry, s }}
      lid={108}
      keyGlow={{ option: opt }}
      screen={<div style={{ width: 1920, height: 1080, background: "linear-gradient(180deg,#0A0B0E,#15171C)" }} />}
    />
  );
  return (
    <>
      {/* shallow depth of field: blurred plate + sharp plate masked around the focus point */}
      <div style={{ position: "absolute", inset: 0, filter: "blur(10px) brightness(0.7)" }}>{dev}</div>
      <div
        style={{
          position: "absolute",
          inset: 0,
          WebkitMaskImage: `radial-gradient(ellipse 620px 420px at ${KEY_SCREEN.x}px ${KEY_SCREEN.y - 40}px, #000 40%, transparent 100%)`,
          maskImage: `radial-gradient(ellipse 620px 420px at ${KEY_SCREEN.x}px ${KEY_SCREEN.y - 40}px, #000 40%, transparent 100%)`,
        }}
      >
        {dev}
      </div>
    </>
  );
};

export const Entries: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY.entries[lang];

  // ---- phase A: handoff donut -> light dot drifting left
  const a = ramp(t, 0.02, 0.55, easeInOut);
  const donutR = lerp(90, 5, a);
  const donutX = lerp(CENTER.x, 330, a);
  const donutO = 1 - ramp(t, 0.5, 0.75, easeIn);

  // ---- keyboard group (flips away)
  const kbVis = clamp01(ramp(t, E.kbIn - 0.05, E.kbIn + 0.35, easeOut));
  const flipK = ramp(t, E.flipOut, E.flipOut + 0.38, easeIn);

  // ---- mouse group (flips in, then becomes the right half of the split)
  const flipM = springAt(t, E.mouseIn, { response: 0.55, damping: 0.86 });
  const orbit = springAt(t, E.mouseIn + 0.05, { response: 0.6, damping: 0.9 });
  const split = springAt(t, E.split, SP.soft);
  const mPitch = lerp(80, 58, orbit) - 6 * split;
  const mYaw = lerp(-86, -30, orbit) + 6 * ramp(t, E.midPress, E.split, easeInOut) + 12 * split;
  const mScale = lerp(1.15, 0.82, split);
  const mX = lerp(MOUSE_POS.x, 1500, split);
  const mY = lerp(MOUSE_POS.y, 640, split);
  const midHeld = Math.max(held(t, E.midPress, E.split - 0.25) * 0.9, window01(t, E.midPress - 0.06, E.midPress + 0.12, 0.06, 0.25));
  const reGlow = window01(t, E.split + 0.12, E.converge + 0.15, 0.12, 0.35); // both glow again on the way to converge
  const mGlow = Math.max(midHeld, reGlow);
  const mPress = Math.max(midHeld, reGlow * 0.6);
  const outro = ramp(t, E.bridge - 0.1, E.bridge + 0.55, easeInOut); // hardware drifts away
  const wheel = wheelAnchor(mX, mY, mScale, mPitch, mYaw);

  // ---- converge: key cap enters on the left
  const keyIn = springAt(t, E.split, SP.soft);
  const keyX = lerp(-260, 420, keyIn) - outro * 260;
  const keyGlow = Math.max(reGlow, 0);

  const beamP = ramp(t, E.beams, E.converge, easeIn);
  const beamO = window01(t, E.beams, E.converge + 0.05, 0.05, 0.25);

  // ---- titles
  const eyebrowIn = springAt(t, 0.25, SP.ui);
  const eyebrowOut = ramp(t, E.split - 0.2, E.split + 0.15, easeIn);
  const bridgeOut = ramp(t, 8.6, 8.92, easeIn);

  // ring at converge: neutral (no wedge) by the last frame for the match cut into Switch
  const cEngage = window01(t, E.converge + 0.3, 8.35, 0.4, 0.45) * 0.7;
  const cPointer = -90 + 160 * ramp(t, E.converge + 0.3, 8.6, easeInOut);

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden", fontFamily: FONT }}>
      <Bloom x={1150} y={620} r={900} o={0.16 * (1 - split)} />
      <Bloom x={CENTER.x} y={CENTER.y} r={760} o={0.22 * ramp(t, E.beams, E.converge + 0.4)} />

      {/* phase A handoff */}
      {donutO > 0.01 ? (
        <>
          <GlassDonut x={donutX} y={CENTER.y} r={donutR} opacity={donutO * (1 - ramp(t, 0.35, 0.6))} glow={a} />
          <div
            style={{
              position: "absolute",
              left: donutX - 40,
              top: CENTER.y - 40,
              width: 80,
              height: 80,
              borderRadius: 40,
              background: "radial-gradient(closest-side, rgba(220,240,255,1), rgba(41,151,255,0.6) 40%, rgba(41,151,255,0))",
              opacity: donutO * ramp(t, 0.25, 0.5),
            }}
          />
        </>
      ) : null}

      {/* ---------------- keyboard segment ---------------- */}
      {t < E.flipOut + 0.45 ? (
        <div
          style={{
            position: "absolute",
            inset: 0,
            perspective: 2200,
            opacity: kbVis * (1 - flipK),
          }}
        >
          <div
            style={{
              position: "absolute",
              inset: 0,
              transformOrigin: "30% 50%",
              transform: `rotateY(${-72 * flipK}deg) translateX(${-260 * flipK}px)`,
              filter: flipK > 0.01 ? `blur(${flipK * 10}px)` : undefined,
            }}
          >
            <KeyboardShot t={t} />
            <PressBurst t={t} at={E.keyPress} x={KEY_SCREEN.x} y={KEY_SCREEN.y} />
            <Ring
              cx={RING_SPOT.x}
              cy={RING_SPOT.y}
              t={t}
              openAt={E.keyPress + 0.03}
              closeAt={E.flipOut - 0.05}
              pointer={kf(t, [E.keyPress + 0.3, E.flipOut], [-120, -30])}
              engage={window01(t, E.keyPress + 0.25, E.flipOut - 0.2, 0.3, 0.2) * 0.85}
              apps={RING_APPS}
              size={0.78}
              sparkle={0.3}
            />
          </div>
        </div>
      ) : null}

      {/* ---------------- mouse segment + right half of the split ---------------- */}
      {t > E.mouseIn - 0.02 ? (
        <div style={{ position: "absolute", inset: 0, perspective: 2200, opacity: clamp01(flipM * 1.6) * (1 - outro) }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              transformOrigin: "70% 50%",
              transform: `rotateY(${72 * (1 - flipM)}deg) translateX(${260 * (1 - flipM) + outro * 260}px)`,
              filter: flipM < 0.98 ? `blur(${(1 - flipM) * 10}px)` : undefined,
            }}
          >
            {/* desk light pool */}
            <div
              style={{
                position: "absolute",
                left: mX - 520,
                top: mY - 220,
                width: 1040,
                height: 520,
                borderRadius: "50%",
                background: "radial-gradient(closest-side, rgba(255,255,255,0.07), rgba(255,255,255,0))",
              }}
            />
            <Mouse3D x={mX} y={mY} scale={mScale} pitch={mPitch} yaw={mYaw} press={mPress} glow={mGlow} />
            <PressBurst t={t} at={E.midPress} x={wheel.x} y={wheel.y} />
            <Ring
              cx={RING_SPOT.x}
              cy={RING_SPOT.y}
              t={t}
              openAt={E.midPress + 0.03}
              closeAt={E.split - 0.12}
              pointer={kf(t, [E.midPress + 0.3, E.split], [-120, -30])}
              engage={window01(t, E.midPress + 0.25, E.split - 0.3, 0.3, 0.2) * 0.85}
              apps={RING_APPS}
              size={0.78}
              sparkle={0.3}
            />
          </div>
        </div>
      ) : null}

      {/* ---------------- converge ---------------- */}
      {t > E.split - 0.05 ? (
        <>
          <KeyCap3D x={keyX} y={640} size={200} pitch={50} yaw={16} press={reGlow * 0.6} glow={keyGlow} opacity={clamp01(keyIn * 1.5) * (1 - outro)} />
          <Beam id="beamL" x0={keyX + 10} y0={600} x1={CENTER.x - 20} y1={CENTER.y} p={beamP} o={beamO} />
          <Beam id="beamR" x0={wheel.x} y0={wheel.y} x1={CENTER.x + 20} y1={CENTER.y} p={beamP} o={beamO} />
          <PressBurst t={t} at={E.converge} x={CENTER.x} y={CENTER.y} size={1.3} />
          <Ring
            cx={CENTER.x}
            cy={CENTER.y}
            t={t}
            openAt={E.converge - 0.02}
            pointer={cPointer}
            engage={cEngage}
            apps={RING_APPS}
            size={1}
            sparkle={0.35 * (1 - ramp(t, 8.0, 8.8))}
          />
        </>
      ) : null}

      {/* ---------------- copy ---------------- */}
      <div
        style={{
          position: "absolute",
          left: 140,
          top: 112,
          color: C.blue,
          ...T.eyebrow,
          opacity: clamp01(eyebrowIn) * (1 - eyebrowOut),
          transform: `translateY(${(1 - eyebrowIn) * 12}px)`,
        }}
      >
        {c.eyebrow}
      </div>
      <TitleBlock t={t} at={0.95} lang={lang} title={c.key} y={168} exitAt={E.flipOut - 0.05} />
      <TitleBlock t={t} at={3.75} lang={lang} title={c.mouse} y={168} exitAt={E.split - 0.2} scale={lang === "en" ? 0.72 : 0.9} />
      <TitleBlock t={t} at={6.62} lang={lang} title={c.same} y={70} align="center" exitAt={7.85} scale={lang === "en" ? 0.72 : 0.78} />
      <div style={{ position: "absolute", left: 0, right: 0, top: 895, display: "flex", justifyContent: "center", opacity: 1 - bridgeOut, filter: `blur(${bridgeOut * 10}px)` }}>
        <RevealLine text={c.bridge} t={t} at={E.bridge + 0.02} lang={lang} style={{ ...T.sub, fontSize: 50, fontWeight: 600, letterSpacing: lang === "zh" ? 0 : -0.8 }} />
      </div>

      <Vignette o={0.55} />
    </AbsoluteFill>
  );
};

export const CUES: FilmCue[] = [
  { sfx: "whoosh", at: 0.05, vol: 0.45 },
  { sfx: "text_in", at: 0.25, vol: 0.3 },
  { sfx: "orbit", at: E.kbIn, vol: 0.4 },
  { sfx: "text_in", at: 0.95, vol: 0.4 },
  { sfx: "key_down", at: E.keyPress, vol: 0.9 },
  { sfx: "ring_open", at: E.keyPress + 0.03, vol: 0.7 },
  { sfx: "shimmer", at: E.keyPress + 0.1, vol: 0.45 },
  { sfx: "flip", at: E.flipOut + 0.05, vol: 0.6 },
  { sfx: "text_in", at: 3.75, vol: 0.4 },
  { sfx: "mouse_down", at: E.midPress, vol: 0.9 },
  { sfx: "ring_open", at: E.midPress + 0.03, vol: 0.7 },
  { sfx: "shimmer", at: E.midPress + 0.1, vol: 0.45 },
  { sfx: "whoosh", at: E.split, vol: 0.45 },
  { sfx: "lightsweep", at: E.beams, vol: 0.55 },
  { sfx: "impact", at: E.converge, vol: 0.85 },
  { sfx: "ring_open", at: E.converge, vol: 0.5 },
  { sfx: "text_in", at: 6.62, vol: 0.4 },
  { sfx: "text_in", at: E.bridge + 0.02, vol: 0.35 },
  { sfx: "whoosh_fast", at: 8.6, vol: 0.3 },
];

