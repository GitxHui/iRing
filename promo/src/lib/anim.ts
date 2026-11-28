import { Easing, interpolate } from "remotion";

export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeIn = Easing.bezier(0.7, 0, 0.84, 0);

export const clamp01 = (v: number) => Math.max(0, Math.min(1, v));
export const lerp = (a: number, b: number, p: number) => a + (b - a) * p;

/** Keyframe interpolation in seconds, always clamped. */
export const kf = (
  t: number,
  times: number[],
  values: number[],
  easing: (n: number) => number = easeInOut,
) =>
  interpolate(t, times, values, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing,
  });

/** 0 → 1 between a and b. */
export const ramp = (t: number, a: number, b: number, easing = easeInOut) =>
  kf(t, [a, b], [0, 1], easing);

/** Fade in over [a, a+fin], hold, fade out over [b, b+fout]. */
export const window01 = (
  t: number,
  a: number,
  b: number,
  fin = 0.35,
  fout = 0.3,
) => Math.min(ramp(t, a, a + fin, easeOut), 1 - ramp(t, b, b + fout, easeIn));

export type SpringOpts = { response?: number; damping?: number };

/**
 * SwiftUI-style spring (response in seconds, damping fraction), time-based so it
 * renders identically at any fps. Returns 0 before `start`, settles at 1.
 */
export const springAt = (
  t: number,
  start: number,
  { response = 0.42, damping = 0.82 }: SpringOpts = {},
) => {
  const x = t - start;
  if (x <= 0) return 0;
  const w0 = (2 * Math.PI) / response;
  const z = Math.min(damping, 0.999);
  const wd = w0 * Math.sqrt(1 - z * z);
  const env = Math.exp(-z * w0 * x);
  return 1 - env * (Math.cos(wd * x) + ((z * w0) / wd) * Math.sin(wd * x));
};

/** Superposition of springs: value starts at stages[0][1] and springs to each later value at its time. */
export const track = (
  t: number,
  stages: Array<[number, number]>,
  opts?: SpringOpts,
) => {
  let v = stages[0][1];
  for (let i = 1; i < stages.length; i++) {
    v += (stages[i][1] - stages[i - 1][1]) * springAt(t, stages[i][0], opts);
  }
  return v;
};

export type Pt = [number, number];
export const trackPt = (
  t: number,
  stages: Array<[number, Pt]>,
  opts?: SpringOpts,
): Pt => [
  track(t, stages.map(([s, p]) => [s, p[0]]), opts),
  track(t, stages.map(([s, p]) => [s, p[1]]), opts),
];

export type Rect = { x: number; y: number; w: number; h: number };
export const trackRect = (
  t: number,
  stages: Array<[number, Rect]>,
  opts?: SpringOpts,
): Rect => ({
  x: track(t, stages.map(([s, r]) => [s, r.x]), opts),
  y: track(t, stages.map(([s, r]) => [s, r.y]), opts),
  w: track(t, stages.map(([s, r]) => [s, r.w]), opts),
  h: track(t, stages.map(([s, r]) => [s, r.h]), opts),
});

export const scaleRect = (r: Rect, s: number): Rect => ({
  x: r.x + (r.w * (1 - s)) / 2,
  y: r.y + (r.h * (1 - s)) / 2,
  w: r.w * s,
  h: r.h * s,
});

/** Deterministic pseudo-random in [0,1). */
export const rand = (seed: number) => {
  const s = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return s - Math.floor(s);
};

export const smoothstep = (e0: number, e1: number, x: number) => {
  const u = clamp01((x - e0) / (e1 - e0));
  return u * u * (3 - 2 * u);
};

export const angDiff = (a: number, b: number) => {
  let d = ((a - b) % 360 + 540) % 360 - 180;
  return d;
};
