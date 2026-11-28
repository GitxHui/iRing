import { HOOK_LEN } from "./scenes/Hook";
import { REVEAL_LEN } from "./scenes/Reveal";
import { DESKTOP_LEN } from "./scenes/Desktop";
import { BENTO_LEN } from "./scenes/Bento";
import { OUTRO_LEN } from "./scenes/Outro";
import { FPS } from "./theme";

export const XFADE = 0.4;
const SCENES = [HOOK_LEN, REVEAL_LEN, DESKTOP_LEN, BENTO_LEN, OUTRO_LEN];

/** Absolute start time (seconds) of each scene in the cut: hook, reveal, desktop, bento, outro. */
export const SCENE_START = SCENES.reduce<number[]>((acc, _len, i) => {
  acc.push(i === 0 ? 0 : acc[i - 1] + SCENES[i - 1] - XFADE);
  return acc;
}, []);
export const PROMO_LEN = SCENE_START[SCENE_START.length - 1] + OUTRO_LEN;
export const PROMO_FRAMES = Math.round(PROMO_LEN * FPS);
