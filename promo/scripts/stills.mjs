// Usage: node scripts/stills.mjs <compId> <outDir> <sec> [sec...]
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import path from "node:path";
import fs from "node:fs";

const [compId, outDir, ...secs] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });
const serveUrl = await bundle({ entryPoint: path.resolve(process.env.ENTRY ?? "src/index.ts") });
const composition = await selectComposition({ serveUrl, id: compId, chromiumOptions: { gl: "angle" } });
for (const s of secs) {
  const frame = Math.min(composition.durationInFrames - 1, Math.round(Number(s) * composition.fps));
  const output = path.join(outDir, `${compId}-${String(s).replace(".", "_")}.jpg`);
  await renderStill({ composition, serveUrl, frame, output, imageFormat: "jpeg", jpegQuality: 85, scale: 0.5, chromiumOptions: { gl: "angle" } });
  console.log("wrote", output);
}
