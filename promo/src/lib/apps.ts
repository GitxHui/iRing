export type AppDef = { id: string; name: string; running: boolean };

/** Ring order, clockwise from 12 o'clock. */
export const RING_APPS: AppDef[] = [
  { id: "safari", name: "Safari", running: true },
  { id: "claude", name: "Claude", running: true },
  { id: "chatgpt", name: "ChatGPT", running: true },
  { id: "wechat", name: "WeChat", running: true },
  { id: "chrome", name: "Chrome", running: true },
  { id: "vscode", name: "VS Code", running: true },
  { id: "lark", name: "Lark", running: false },
  { id: "notes", name: "Notes", running: false },
  { id: "obsidian", name: "Obsidian", running: false },
  { id: "music", name: "Music", running: false },
  { id: "cursor", name: "Cursor", running: false },
];

export const ringAngle = (i: number, n = RING_APPS.length) => -90 + (i * 360) / n;

export const DOCK_APPS = [
  "chatgpt",
  "vscode",
  "claude",
  "chrome",
  "safari",
  "wechat",
  "|",
  "gemini",
  "obsidian",
  "notes",
  "music",
];
export const DOCK_RUNNING = new Set(["chatgpt", "vscode", "claude", "chrome", "safari", "wechat"]);
