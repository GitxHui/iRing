// node src/vertical/kinetic/stills.mjs <outDir> <comp:sec,sec,...> [comp:sec,...]
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import path from "node:path";
import fs from "node:fs";

const [outDir, ...specs] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });
const serveUrl = await bundle({ entryPoint: path.resolve("src/vertical/preview/kinetic.tsx") });
for (const spec of specs) {
  const [id, list] = spec.split(":");
  const composition = await selectComposition({ serveUrl, id, chromiumOptions: { gl: "angle" } });
  for (const s of list.split(",")) {
    const frame = Math.min(composition.durationInFrames - 1, Math.round(Number(s) * composition.fps));
    const output = path.join(outDir, `${id}-${s.replace(".", "_")}.jpg`);
    await renderStill({ composition, serveUrl, frame, output, imageFormat: "jpeg", jpegQuality: 85, scale: 0.5, chromiumOptions: { gl: "angle" } });
  }
  console.log("done", id);
}
