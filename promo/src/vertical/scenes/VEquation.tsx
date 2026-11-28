import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { Sparkles } from "../../components/Sparkles";
import { clamp01, easeIn, easeInOut, easeOut, lerp, ramp, springAt, window01 } from "../../lib/anim";
import { FONT } from "../../theme";
import { SceneCue, VSceneProps } from "../contract";
import { Shockwave } from "../kinetic/primitives";
import { GlassKeyFace, GlassMouse } from "../kinetic/GlassKey";
import { A, AppleBackdrop, Burst, Eyebrow, GRID_X, Line, flashAt } from "../kinetic/apple";
import { EQ_HEAD_Y, EQ_KEY, EQ_MOUSE } from "../kinetic/layout";

/**
 * 6.0 s. Act 1 (0–2.5): ⌥ and the middle mouse button as two equal heroes.
 * Act 2 (2.5–4.6): both become the left side of the formula; four terms land on the beat.
 * Act 3 (4.6–6.0): closing line, then exit to dark.
 */
const T = {
  title1: 0.1,
  title2: 0.75,
  mouseIn: 0.55,
  mousePress: 1.2,
  merge: 2.5,
  terms: [2.95, 3.45, 3.95, 4.45],
  close: 4.95,
  exit: 5.6,
};

export const CUES: SceneCue[] = [
  { sfx: "swipe", at: 0.05, vol: 0.45 },
  { sfx: "glass_flip", at: T.mouseIn, vol: 0.6 },
  { sfx: "click", at: T.mousePress, vol: 0.9 },
  { sfx: "impact", at: T.mousePress, vol: 0.75 },
  { sfx: "shimmer", at: T.mousePress + 0.08, vol: 0.5 },
  { sfx: "whoosh", at: T.merge, vol: 0.45 },
  { sfx: "chip_0", at: T.terms[0], vol: 0.75 },
  { sfx: "chip_1", at: T.terms[1], vol: 0.75 },
  { sfx: "chip_2", at: T.terms[2], vol: 0.75 },
  { sfx: "chip_3", at: T.terms[3], vol: 0.75 },
  { sfx: "slam", at: T.close, vol: 0.7 },
  { sfx: "whoosh", at: T.exit, vol: 0.45 },
];

const COPY = {
  zh: {
    eye: "两种入口",
    t1: "键盘 ⌥，",
    t2: "或鼠标中键。",
    keyLab: "按住左 ⌥",
    mouseLab: "按住鼠标中键",
    or: "或",
    terms: [
      ["切屏", "指向即切换"],
      ["分屏", "二分 · 四分 · 全屏"],
      ["缩放", "45%～100% 连续调节"],
      ["Dock", "灵动岛 · ⌘1～9 直达"],
    ],
    close: "两种入口，同一个圆环。",
  },
  en: {
    eye: "Two ways in",
    t1: "⌥ on the keyboard.",
    t2: "Or the middle mouse button.",
    keyLab: "Hold left ⌥",
    mouseLab: "Hold the wheel",
    or: "or",
    terms: [
      ["Switch", "point to switch"],
      ["Tile", "halves · quarters · full"],
      ["Resize", "45%–100%, continuous"],
      ["Dock", "island · ⌘1–9 jumps"],
    ],
    close: "Two ways in. One ring.",
  },
} as const;

const HEAD_S = 118; // hero size in the formula header
const HEAD_KEY_X = GRID_X + HEAD_S / 2 - 6;
const HEAD_MOUSE_X = HEAD_KEY_X + 196;

export const VEquation: React.FC<VSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY[lang];

  const merge = springAt(t, T.merge, { response: 0.62, damping: 0.88 });
  const titleOut = ramp(t, T.merge - 0.15, T.merge + 0.2, easeIn);
  const exit = ramp(t, T.exit, 6.0, easeIn);

  // --- heroes
  const keyIdle = Math.sin(t * 1.4) * 1.5;
  const keyPress = window01(t, 0.02, 0.35, 0.04, 0.25) * 0.35; // settles from the VKey cut
  const keyX = lerp(EQ_KEY.x, HEAD_KEY_X, merge);
  const keyY = lerp(EQ_KEY.y, EQ_HEAD_Y, merge);
  const keyS = lerp(1, HEAD_S / EQ_KEY.size, merge);

  const mIn = springAt(t, T.mouseIn, { response: 0.62, damping: 0.84 });
  const mPress = clamp01(ramp(t, T.mousePress - 0.04, T.mousePress + 0.04, easeOut)) * (1 - ramp(t, T.mousePress + 0.5, T.mousePress + 0.9));
  const mFlash = flashAt(t, T.mousePress, 7);
  const mouseX = lerp(lerp(EQ_MOUSE.x + 380, EQ_MOUSE.x, mIn), HEAD_MOUSE_X, merge);
  const mouseY = lerp(EQ_MOUSE.y, EQ_HEAD_Y, merge);
  const mouseS = lerp(1, (HEAD_S * 1.12) / EQ_MOUSE.size, merge);
  const mRotY = lerp(-70, 0, mIn) + (1 - merge) * Math.sin(t * 1.1) * 3;
  const mSweep = ramp(t, T.mousePress + 0.15, T.mousePress + 0.85, easeInOut) * 2.4 - 0.6;

  // labels under the heroes (act 1)
  const labA = clamp01(ramp(t, 0.35, 0.8, easeOut)) * (1 - titleOut);
  const labB = clamp01(ramp(t, T.mousePress - 0.1, T.mousePress + 0.35, easeOut)) * (1 - titleOut);
  const orA = clamp01(ramp(t, T.mouseIn, T.mouseIn + 0.4, easeOut)) * (1 - titleOut);

  // formula operators
  const slash = clamp01(ramp(t, T.merge + 0.15, T.merge + 0.5, easeOut));
  const eq = clamp01(ramp(t, T.merge + 0.3, T.merge + 0.65, easeOut));

  return (
    <AbsoluteFill style={{ background: A.bg, overflow: "hidden" }}>
      <AppleBackdrop t={t + 5} glow={0.6 + 1.1 * mFlash} x={lerp(500, 400, merge)} y={lerp(1000, 900, merge)} />
      <Burst x={EQ_MOUSE.x} y={EQ_MOUSE.y} amount={mFlash * (1 - merge)} size={1300} />

      <AbsoluteFill style={{ opacity: 1 - exit, filter: exit > 0.001 ? `blur(${exit * 16}px)` : undefined, transform: `scale(${1 + 0.06 * exit})` }}>
        {/* act 1 headline */}
        <div style={{ position: "absolute", left: GRID_X, top: 300 }}>
          <Eyebrow text={c.eye} t={t} at={0.0} lang={lang} out={titleOut} />
          <div style={{ height: 18 }} />
          <Line text={c.t1} t={t} at={T.title1} size={lang === "zh" ? 104 : 76} lang={lang} out={titleOut} />
          <Line text={c.t2} t={t} at={T.title2} size={lang === "zh" ? 104 : 76} lang={lang} out={titleOut} gradient={A.accentGrad} />
        </div>

        {/* act 1: the thin "or" between the heroes */}
        <div
          style={{
            position: "absolute",
            left: (EQ_KEY.x + EQ_MOUSE.x) / 2 - 60,
            width: 120,
            top: EQ_KEY.y - 40,
            textAlign: "center",
            fontFamily: FONT,
            fontSize: 56,
            fontWeight: 300,
            color: A.gray,
            opacity: orA,
          }}
        >
          {c.or}
        </div>

        {/* labels */}
        {[
          { x: EQ_KEY.x, text: c.keyLab, o: labA },
          { x: EQ_MOUSE.x, text: c.mouseLab, o: labB },
        ].map((l) => (
          <div
            key={l.text}
            style={{
              position: "absolute",
              left: l.x - 220,
              width: 440,
              top: EQ_KEY.y + EQ_KEY.size * 0.6,
              textAlign: "center",
              fontFamily: FONT,
              fontSize: 36,
              fontWeight: 500,
              color: A.gray,
              opacity: l.o,
              transform: `translateY(${(1 - l.o) * 10}px)`,
            }}
          >
            {l.text}
          </div>
        ))}

        <Shockwave t={t} at={T.mousePress} x={EQ_MOUSE.x} y={EQ_MOUSE.y} max={900} dur={0.85} width={6} color="160,200,255" />
        <div style={{ position: "absolute", left: EQ_MOUSE.x, top: EQ_MOUSE.y, opacity: 1 - merge }}>
          <Sparkles t={t} angle={-90 + (t - T.mousePress) * 160} spread={200} radius={170} intensity={window01(t, T.mousePress, T.merge - 0.3, 0.1, 0.4)} count={60} seed={41} />
        </div>

        {/* heroes */}
        <div style={{ position: "absolute", inset: 0, perspective: 1600 }}>
          <div
            style={{
              position: "absolute",
              left: keyX - EQ_KEY.size / 2,
              top: keyY - EQ_KEY.size / 2,
              width: EQ_KEY.size,
              height: EQ_KEY.size,
              transform: `rotateY(${keyIdle * (1 - merge)}deg) scale(${keyS})`,
            }}
          >
            <GlassKeyFace size={EQ_KEY.size} press={keyPress} />
          </div>
          <div
            style={{
              position: "absolute",
              left: mouseX - EQ_MOUSE.size / 2,
              top: mouseY - EQ_MOUSE.size / 2,
              width: EQ_MOUSE.size,
              height: EQ_MOUSE.size,
              opacity: clamp01(mIn * 2),
              transform: `rotateY(${mRotY}deg) scale(${mouseS * (1 - 0.03 * mPress)})`,
              filter: mIn < 0.98 ? `blur(${(1 - mIn) * 12}px)` : undefined,
            }}
          >
            <GlassMouse size={EQ_MOUSE.size} glow={0.5} press={mPress} sweep={mSweep} />
          </div>
        </div>

        {/* act 2: formula */}
        <div
          style={{
            position: "absolute",
            left: (HEAD_KEY_X + HEAD_MOUSE_X) / 2 - 30,
            width: 60,
            top: EQ_HEAD_Y - 52,
            textAlign: "center",
            fontFamily: FONT,
            fontSize: 84,
            fontWeight: 200,
            color: A.gray,
            opacity: slash,
          }}
        >
          /
        </div>
        <div
          style={{
            position: "absolute",
            left: HEAD_MOUSE_X + 110,
            top: EQ_HEAD_Y - 66,
            fontFamily: FONT,
            fontSize: 112,
            fontWeight: 200,
            color: A.ink,
            opacity: eq,
            transform: `translateX(${(1 - eq) * -16}px)`,
          }}
        >
          =
        </div>

        <div style={{ position: "absolute", left: GRID_X, top: EQ_HEAD_Y + 150, width: 860 }}>
          {c.terms.map(([term, note], i) => {
            const at = T.terms[i];
            const p = clamp01(ramp(t, at, at + 0.5, easeOut));
            const plus = clamp01(ramp(t, at - 0.1, at + 0.25, easeOut));
            return (
              <div key={term} style={{ position: "relative", height: 150 }}>
                {i > 0 ? (
                  <div
                    style={{
                      position: "absolute",
                      left: 0,
                      top: -32,
                      width: 860,
                      height: 1,
                      background: A.hair,
                      transformOrigin: "0 50%",
                      transform: `scaleX(${plus})`,
                    }}
                  />
                ) : null}
                <div
                  style={{
                    position: "absolute",
                    left: 0,
                    top: 8,
                    fontFamily: FONT,
                    fontSize: 54,
                    fontWeight: 200,
                    color: A.gray,
                    opacity: i > 0 ? plus : 0,
                  }}
                >
                  +
                </div>
                <div
                  style={{
                    position: "absolute",
                    left: 64,
                    top: 0,
                    display: "flex",
                    alignItems: "baseline",
                    gap: 26,
                    opacity: p,
                    transform: `translateY(${(1 - p) * 18}px)`,
                    filter: p < 0.999 ? `blur(${(1 - p) * 10}px)` : undefined,
                  }}
                >
                  <span
                    style={{
                      fontFamily: FONT,
                      fontSize: 92,
                      fontWeight: 600,
                      color: A.ink,
                      letterSpacing: lang === "zh" ? 1 : -2,
                      lineHeight: 1,
                    }}
                  >
                    {term}
                  </span>
                  <span style={{ fontFamily: FONT, fontSize: 32, fontWeight: 500, color: A.gray }}>{note}</span>
                </div>
              </div>
            );
          })}
        </div>

        {/* act 3: closing line */}
        <div style={{ position: "absolute", left: GRID_X, top: EQ_HEAD_Y + 150 + 4 * 150 + 10 }}>
          <Line text={c.close} t={t} at={T.close} size={lang === "zh" ? 64 : 58} lang={lang} gradient={A.accentGrad} per={lang === "zh" ? 0.03 : 0.07} />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
