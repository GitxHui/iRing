import React from "react";
import { Sequence, staticFile, useVideoConfig } from "remotion";
import { Audio } from "@remotion/media";
import { SCENE_START, PROMO_LEN } from "./timeline";
import { T } from "./scenes/Desktop";
import { R } from "./scenes/Reveal";
import { BENTO_AT } from "./scenes/Bento";
import { O } from "./scenes/Outro";
import { kf, easeInOut } from "./lib/anim";

type Cue = { src: string; at: number; vol: number };

const [HOOK, REVEAL, DESK, BENTO, OUTRO] = SCENE_START;

const sfx = (name: string) => `audio/sfx_${name}.wav`;

const buildCues = (): Cue[] => {
  const c: Cue[] = [];
  const add = (name: string, at: number, vol = 1) => c.push({ src: sfx(name), at, vol });

  // --- hook: windows piling up
  for (let i = 0; i < 9; i++) add(`window_${i % 3}`, HOOK + 0.05 + i * 0.16, 0.32 + 0.04 * (i % 3));
  add("whoosh", HOOK + 0.45, 0.45);
  add("riser", HOOK + 3.15, 0.75);

  // --- reveal
  add("key_down", REVEAL + 0.02, 0.8);
  add("ring_open", REVEAL + R.ring, 0.85);
  add("shimmer", REVEAL + R.sweepA, 0.5);
  {
    // a tick every time the sweeping wedge crosses an app
    const step = 360 / 11;
    let last = Math.floor((-90 + step / 2 + 90) / step);
    for (let s = R.sweepA; s <= R.sweepB; s += 1 / 120) {
      const p = kf(s, [R.sweepA, R.sweepB], [-90, 270], easeInOut);
      const k = Math.floor((p + step / 2 + 90) / step);
      if (k !== last) {
        add(k % 2 ? "tick" : "tick_hi", REVEAL + s, 0.45);
        last = k;
      }
    }
  }
  add("key_up", REVEAL + R.close - 0.1, 0.6);
  add("impact", REVEAL + R.logo, 1);
  add("whoosh_fast", REVEAL + R.word - 0.05, 0.35);

  // --- desktop demo
  const d = (x: number) => DESK + x;
  // switch
  add("key_down", d(T.altA), 0.8);
  add("ring_open", d(T.ringA), 0.6);
  add("tick", d(T.toGPT + 0.16), 0.55);
  add("tick_hi", d(T.toClaude + 0.14), 0.55);
  add("key_up", d(T.releaseA), 0.6);
  add("ring_close", d(T.releaseA), 0.5);
  add("select", d(T.releaseA + 0.03), 0.65);
  add("whoosh_fast", d(T.releaseA + 0.02), 0.4);
  // tile right
  add("key_down", d(T.altB), 0.8);
  add("ring_open", d(T.ringB), 0.5);
  add("key_down", d(T.tabB), 0.65);
  add("tick_hi", d(T.tabB + 0.05), 0.5);
  add("whoosh_fast", d(T.pointB + 0.1), 0.5);
  add("key_up", d(T.releaseB), 0.6);
  add("ring_close", d(T.releaseB), 0.45);
  add("snap", d(T.releaseB + 0.14), 0.8);
  // tile left
  add("key_down", d(T.altB2), 0.8);
  add("ring_open", d(T.ringB2), 0.45);
  add("key_down", d(T.tabB2), 0.65);
  add("tick_hi", d(T.tabB2 + 0.05), 0.5);
  add("whoosh_fast", d(T.pointB2 + 0.08), 0.5);
  add("key_up", d(T.releaseB2), 0.6);
  add("ring_close", d(T.releaseB2), 0.45);
  add("snap", d(T.releaseB2 + 0.14), 0.8);
  // resize
  add("key_down", d(T.altC), 0.8);
  add("ring_open", d(T.ringC), 0.45);
  add("tick", d(T.pointC + 0.15), 0.5);
  for (let s = 0; s < 0.85; s += 0.045 + s * 0.04) add("scroll_tick", d(T.scroll1 + s), 0.5);
  for (let s = 0; s < 0.6; s += 0.05 + s * 0.05) add("scroll_tick", d(T.scroll2 + s), 0.5);
  add("key_up", d(T.releaseC), 0.6);
  add("ring_close", d(T.releaseC), 0.45);
  add("snap", d(T.releaseC + 0.14), 0.75);
  // island
  add("whoosh", d(T.island - 0.1), 0.45);
  add("ring_open", d(T.expand), 0.4);
  for (let s = 0; s < 0.8; s += 0.16) add("scroll_tick", d(T.hover + 0.1 + s), 0.4);
  add("pop", d(T.badge), 0.8);
  add("whoosh", d(T.back - 0.1), 0.4);

  // --- bento
  add("whoosh", BENTO + 0.0, 0.35);
  BENTO_AT.forEach((at, i) => add(`tile_${i}`, BENTO + at, 0.7));

  // --- outro
  add("shimmer", OUTRO + O.logo, 0.55);
  add("whoosh_fast", OUTRO + O.word, 0.35);
  add("tile_1", OUTRO + O.pills, 0.45);
  add("tile_3", OUTRO + O.button, 0.5);
  add("click", OUTRO + O.click, 0.9);
  add("shimmer", OUTRO + O.click + 0.02, 0.45);

  return c.filter((q) => q.at >= 0 && q.at < PROMO_LEN);
};

export const CUES = buildCues();

export const Soundtrack: React.FC = () => {
  const { fps } = useVideoConfig();
  return (
    <>
      <Audio src={staticFile("audio/music.wav")} volume={0.5} />
      {CUES.map((q, i) => (
        <Sequence key={i} from={Math.round(q.at * fps)} layout="none">
          <Audio src={staticFile(q.src)} volume={q.vol} />
        </Sequence>
      ))}
    </>
  );
};
