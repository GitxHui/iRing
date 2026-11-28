/**
 * Shared contract for the vertical (Xiaohongshu / Douyin) cut.
 * Owned by the lead; scene authors import from here and must not edit it.
 */
export const VW = 1080;
export const VH = 1920;
export const VFPS = 60;

/** Platform UI safe zone: keep key content inside this box. */
export const SAFE = { top: 180, bottom: 1520, left: 60, right: 940 };

export const BPM = 120;
export const BEAT = 0.5; // seconds; downbeats every 2 s starting at 0

/** Scene windows in absolute seconds (scenes play back to back, no overlap). */
export const VSCENES = {
  hook: { start: 0.0, len: 2.5 },
  key: { start: 2.5, len: 3.0 }, // key press lands at absolute 4.0 (bass drop)
  equation: { start: 5.5, len: 6.0 }, // ⌥ and the middle mouse button get equal weight
  switch: { start: 11.5, len: 4.0 },
  tile: { start: 15.5, len: 6.0 }, // halves -> quarters -> full screen
  resize: { start: 21.5, len: 3.0 },
  island: { start: 24.5, len: 6.5 }, // expand -> Cmd+1..4 -> collapse -> drag to edges
  finale: { start: 31.0, len: 5.0 },
} as const;
export const VTOTAL = 36.0;

/**
 * Sound cue names (files public/audio/sfx_<name>.wav).
 * Existing: key_down key_up ring_open ring_close tick tick_hi select whoosh whoosh_fast snap
 *           scroll_tick pop riser impact shimmer click tile_0..3 window_0..2
 * New (made by the audio author): slam boom glass_flip swipe drag_start dock_snap chip_0..3 lightsweep
 */
export type SfxName =
  | "key_down" | "key_up" | "ring_open" | "ring_close" | "tick" | "tick_hi" | "select"
  | "whoosh" | "whoosh_fast" | "snap" | "scroll_tick" | "pop" | "riser" | "impact"
  | "shimmer" | "click" | "tile_0" | "tile_1" | "tile_2" | "tile_3"
  | "window_0" | "window_1" | "window_2"
  | "slam" | "boom" | "glass_flip" | "swipe" | "drag_start" | "dock_snap"
  | "chip_0" | "chip_1" | "chip_2" | "chip_3" | "lightsweep";

/** Each scene file exports `CUES: SceneCue[]` with times LOCAL to the scene. */
export type SceneCue = { sfx: SfxName; at: number; vol?: number };

/** Every vertical scene component takes these props. */
export type VSceneProps = { lang: "zh" | "en" };

/** Keynote palette for the vertical cut. */
export const KEY = {
  bg: "#05070D",
  ink: "#F5F7FC",
  dim: "rgba(245,247,252,0.62)",
  blue: "#0A6CF0",
  blueGlow: "#3D8BFF",
  gradText: "linear-gradient(180deg, #FFFFFF 0%, #C9D8FF 100%)",
  accentGrad: "linear-gradient(90deg, #5AA2FF 0%, #A58BFF 50%, #FF8BC2 100%)",
};
