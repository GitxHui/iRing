import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Ring } from "../../components/Ring";
import { RING_APPS } from "../../lib/apps";
import { clamp01, easeIn, easeInOut, easeOut, kf, lerp, ramp, springAt, window01 } from "../../lib/anim";
import { SceneCue, VSceneProps, VW } from "../contract";
import { Shockwave } from "../kinetic/primitives";
import { GlassKeyFace } from "../kinetic/GlassKey";
import { A, AppleBackdrop, Burst, Eyebrow, GRID_X, Line, flashAt } from "../kinetic/apple";
import { EQ_KEY, KEY_HERO } from "../kinetic/layout";

const PRESS = 1.5; // absolute 4.0 = music drop
const EXIT = 2.45;

export const CUES: SceneCue[] = [
  { sfx: "lightsweep", at: 0.42, vol: 0.55 },
  { sfx: "key_down", at: PRESS, vol: 1 },
  { sfx: "boom", at: PRESS, vol: 1 },
  { sfx: "impact", at: PRESS, vol: 0.6 },
  { sfx: "ring_open", at: PRESS + 0.05, vol: 0.8 },
  { sfx: "shimmer", at: PRESS + 0.12, vol: 0.5 },
  { sfx: "ring_close", at: EXIT, vol: 0.45 },
  { sfx: "whoosh_fast", at: EXIT + 0.05, vol: 0.5 },
];

const TEXT = {
  zh: { eye: "iRing", l1: "按住一个键，", l2: "圆环就在光标处。" },
  en: { eye: "iRing", l1: "Hold one key.", l2: "The ring meets your cursor." },
};

export const VKey: React.FC<VSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = TEXT[lang];

  // key arrives from depth
  const e = springAt(t, 0.0, { response: 1.0, damping: 0.88 });
  const z = -2400 * (1 - e);
  const rotX = lerp(58, 16, e) + Math.sin(t * 1.2) * 1.5;
  const rotY = lerp(-42, -10, e) + Math.sin(t * 0.8) * 2;
  const sweep = kf(t, [0.4, 1.25], [-0.6, 1.7], easeInOut);

  // press = music drop
  const press = clamp01(ramp(t, PRESS - 0.04, PRESS + 0.04, easeOut));
  const sink = window01(t, PRESS - 0.04, PRESS + 0.12, 0.04, 0.25);
  const flash = flashAt(t, PRESS, 7);

  // key steps back while the ring is open, then flies to the equation's left hero slot
  const into = ramp(t, PRESS + 0.05, PRESS + 0.4, easeInOut);
  const fly = springAt(t, EXIT, { response: 0.5, damping: 0.86 });
  const scale = lerp(lerp(1, 0.28, into), EQ_KEY.size / KEY_HERO.size, fly);
  const cx = lerp(KEY_HERO.x, EQ_KEY.x, fly);
  const cy = lerp(KEY_HERO.y, EQ_KEY.y, fly);
  const flat = Math.max(into, fly);

  const pointer = kf(t, [PRESS + 0.2, EXIT - 0.05], [-90, 270], easeInOut);
  const engage = window01(t, PRESS + 0.15, EXIT - 0.15, 0.15, 0.12);
  const textOut = ramp(t, EXIT - 0.1, EXIT + 0.3, easeIn);

  return (
    <AbsoluteFill style={{ background: A.bg, overflow: "hidden" }}>
      <AppleBackdrop t={t} glow={0.35 + 0.65 * e + 1.2 * flash} x={KEY_HERO.x} y={KEY_HERO.y} />
      <Burst x={KEY_HERO.x} y={KEY_HERO.y} amount={flash + 0.12 * press * (1 - fly)} />

      {/* headline, left grid */}
      <div style={{ position: "absolute", left: GRID_X, top: 300 }}>
        <Eyebrow text={c.eye} t={t} at={0.15} lang={lang} out={textOut} />
        <div style={{ height: 18 }} />
        <Line text={c.l1} t={t} at={0.3} size={lang === "zh" ? 92 : 82} lang={lang} out={textOut} />
        <Line text={c.l2} t={t} at={PRESS + 0.05} size={lang === "zh" ? 92 : 70} lang={lang} color={A.gray} out={textOut} />
      </div>

      <Shockwave t={t} at={PRESS} x={KEY_HERO.x} y={KEY_HERO.y} max={1100} dur={0.9} width={6} color="160,200,255" />

      <div style={{ position: "absolute", inset: 0, opacity: 1 - fly }}>
        <Ring
          cx={KEY_HERO.x}
          cy={KEY_HERO.y}
          t={t}
          openAt={PRESS + 0.03}
          closeAt={EXIT}
          pointer={pointer}
          engage={engage}
          apps={RING_APPS}
          size={1.38}
          sparkle={0.55}
        />
      </div>

      <div style={{ position: "absolute", inset: 0, perspective: 1800, perspectiveOrigin: `${VW / 2}px ${KEY_HERO.y}px` }}>
        <div
          style={{
            position: "absolute",
            left: cx - KEY_HERO.size / 2,
            top: cy - KEY_HERO.size / 2,
            width: KEY_HERO.size,
            height: KEY_HERO.size,
            transform: `translate3d(0, ${sink * KEY_HERO.size * 0.05}px, ${z}px) rotateX(${lerp(rotX, 0, flat)}deg) rotateY(${lerp(rotY, 0, flat)}deg) scale(${scale * (1 - 0.03 * sink)})`,
            transformStyle: "preserve-3d",
            opacity: clamp01(e * 2.5),
            filter: e < 0.98 ? `blur(${(1 - e) * 12}px)` : undefined,
          }}
        >
          <GlassKeyFace size={KEY_HERO.size} sweep={sweep} press={press} />
        </div>
      </div>

      <AbsoluteFill style={{ background: "#DCE8FF", opacity: 0.35 * flash, mixBlendMode: "screen" }} />
    </AbsoluteFill>
  );
};
