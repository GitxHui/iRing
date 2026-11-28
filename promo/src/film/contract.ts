/**
 * iRing keynote film — shared contract (owned by the lead; scene authors must not edit).
 * 16:9, 1920x1080 layout, 60 fps, rendered at 2x (4K). ~60 s.
 *
 * STORY LOGIC (two layers, building up):
 *   1. Problem  – windows everywhere; the cursor keeps travelling across the screen.
 *   2. Reveal   – what if everything happened where the cursor already is? -> the ring.
 *   3. Entries  – TWO equal ways in: hold ⌥ (keyboard) OR hold the middle mouse button (mouse).
 *                 Same ring either way.
 *   4-6. Inside the ring, gestures take over: point = switch, Tab / trackpad tap = tile,
 *                 two-finger swipe / wheel = resize. (Trackpad is the gesture layer, not a 3rd entry.)
 *   7. Island   – the apps you use most, right by the notch.
 *   8. Details  – multi-display, two looks, motion/particles, bilingual.
 *   9. Finale.
 */
export const FW = 1920;
export const FH = 1080;
export const FFPS = 60;
export const FBPM = 120; // beat 0.5 s, bar 2 s (downbeats at even seconds)

export const SCENES = {
  problem: { start: 0.0, len: 9.0 },
  reveal: { start: 9.0, len: 7.0 },
  entries: { start: 16.0, len: 9.0 },
  switch: { start: 25.0, len: 6.0 },
  tile: { start: 31.0, len: 8.0 },
  resize: { start: 39.0, len: 5.5 },
  island: { start: 44.5, len: 7.5 },
  details: { start: 52.0, len: 4.0 },
  finale: { start: 56.0, len: 4.5 },
} as const;
export type SceneId = keyof typeof SCENES;
export const FTOTAL = 60.5;

/**
 * HANDOFF STATES — the last frame of a scene must visually match the first frame of the next,
 * so hard cuts read as one continuous camera move.
 *  problem -> reveal : black frame, a single macOS cursor at canvas centre (960,540), scale 1.6.
 *  reveal  -> entries: black frame, small glass ring (outer radius ~90) centred at (960,540), no icons.
 *  entries -> switch : the ring centred at (960,540) on a dark backdrop; switch starts by pulling the
 *                      camera back to reveal the ring sits on a MacBook screen (match cut on the ring).
 *  switch -> tile -> resize : one continuous MacBook world (same device, same windows state).
 *  resize -> island  : camera on the MacBook, framing the full screen front-on; island tilts up to the notch.
 *  island -> details : the screen flips (rotateY 180) and becomes the first detail card.
 *  details -> finale : cards recede into black; finale starts on black.
 */

/** Musical anchors (absolute s) the audio author scores to. */
export const HITS = {
  question: 7.0, // "如果……" line lands, music drops out
  reveal: 9.5, // ring blooms (big hit)
  lockup: 12.0, // iRing wordmark
  keyPress: 17.5, // ⌥ pressed
  midPress: 20.0, // middle button pressed
  converge: 22.5, // both become one ring
  groove: 25.0, // features groove starts
  tileLift: 31.0,
  resize: 39.0,
  island: 44.5,
  details: 52.0,
  final: 56.0, // final hit
};

export type Lang = "zh" | "en";

/** ALL on-screen copy lives here. Keep it short — keynote voice. */
export const COPY = {
  problem: {
    zh: ["每天，你都在切换窗口。", "光标，在屏幕上来回奔波。", "如果，一切就在光标所在之处？"],
    en: ["Every day, you switch windows.", "Your cursor crosses the screen. Again and again.", "What if it all happened right where your cursor is?"],
  },
  reveal: {
    zh: { name: "iRing", line: "在光标处，掌控每一个窗口。" },
    en: { name: "iRing", line: "Every window. Right at your cursor." },
  },
  entries: {
    zh: { eyebrow: "两种入口", key: "按住 ⌥。", mouse: "或者，按住鼠标中键。", same: "同一个圆环，随叫随到。", bridge: "进入圆环，手势接管一切。" },
    en: { eyebrow: "Two ways in", key: "Hold ⌥.", mouse: "Or hold the middle mouse button.", same: "Same ring. Instantly.", bridge: "Inside the ring, gestures do the rest." },
  },
  switch: {
    zh: { eyebrow: "切换", title: "指向。松手。", sub: "应用即刻来到眼前。" },
    en: { eyebrow: "Switch", title: "Point. Release.", sub: "Your app, front and center." },
  },
  tile: {
    zh: { eyebrow: "分屏", title: "轻点，一甩到位。", sub: "按 Tab 或轻点触控板", modes: ["二分屏", "四分屏", "全屏"], note: "松手前，先预览。" },
    en: { eyebrow: "Tile", title: "Tap. Flick. Tiled.", sub: "Press Tab or tap the trackpad", modes: ["Halves", "Quarters", "Full screen"], note: "Preview before you let go." },
  },
  resize: {
    zh: { eyebrow: "缩放", title: "一滑，刚刚好。", sub: "双指滑动或滚动滚轮 · 45%–100%" },
    en: { eyebrow: "Resize", title: "Swipe. Just right.", sub: "Two fingers or the wheel · 45%–100%" },
  },
  island: {
    zh: { eyebrow: "灵动岛", title: "常用应用，就在刘海旁。", beats: ["收放自如", "数字键，按顺序直达", "拖到任意一边，自动吸附"] },
    en: { eyebrow: "Island", title: "Your apps, right by the notch.", beats: ["Expands. Tucks away.", "Number keys jump by slot", "Docks to any edge"] },
  },
  details: {
    zh: { title: "还有，更多细节。", cards: ["多屏友好", "Liquid Glass · 曜石黑", "粒子与动效，随心调", "中文 · English"] },
    en: { title: "And all the details.", cards: ["Multi-display aware", "Liquid Glass · Obsidian", "Particles & motion, tuned", "English · 中文"] },
  },
  finale: {
    zh: { name: "iRing", line: "在光标处，掌控每一个窗口。", meta: "免费公测 · macOS 15+ · Apple 芯片", cta: "GitHub 搜索 iRing" },
    en: { name: "iRing", line: "Every window. Right at your cursor.", meta: "Free public beta · macOS 15+ · Apple silicon", cta: "github.com/GitxHui/iRing" },
  },
} as const;

/** Sound cue: `sfx` is a file stem in public/audio/ (sfx_<sfx>.wav). Times LOCAL to the scene. */
export type FilmCue = { sfx: string; at: number; vol?: number };
export type FilmSceneProps = { lang: Lang };

/**
 * Available SFX stems (public/audio/sfx_<stem>.wav).
 * Existing: key_down key_up ring_open ring_close tick tick_hi select whoosh whoosh_fast snap scroll_tick
 *   pop riser impact shimmer click tile_0..3 window_0..2 slam boom glass_flip swipe drag_start dock_snap
 *   chip_0..3 lightsweep
 * New (made by the film audio author): orbit flip text_in mouse_down trackpad_tap sub_drop heartbeat
 *   cursor_whir
 */
export const SFX_STEMS = [
  "key_down", "key_up", "ring_open", "ring_close", "tick", "tick_hi", "select", "whoosh", "whoosh_fast", "snap",
  "scroll_tick", "pop", "riser", "impact", "shimmer", "click", "tile_0", "tile_1", "tile_2", "tile_3",
  "window_0", "window_1", "window_2", "slam", "boom", "glass_flip", "swipe", "drag_start", "dock_snap",
  "chip_0", "chip_1", "chip_2", "chip_3", "lightsweep",
  "orbit", "flip", "text_in", "mouse_down", "trackpad_tap", "sub_drop", "heartbeat", "cursor_whir",
] as const;
