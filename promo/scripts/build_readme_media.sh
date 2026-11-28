#!/bin/bash
# Render every README asset into ../docs/media.
set -euo pipefail
cd "$(dirname "$0")/.."
M=../docs/media
mkdir -p "$M" out/clips
for c in Switch Tile Resize Island; do
  npx remotion render "$c-EN" "out/clips/$c.mp4" --crf=16 --log=error
  lc=$(echo "$c" | tr '[:upper:]' '[:lower:]')
  FPS=24 scripts/encode_loop.sh "out/clips/$c.mp4" "out/clips/$lc" 800 >/dev/null
  cp "out/clips/$lc.webp" "$M/$lc.webp"
done
for L in EN ZH; do
  l=$(echo "$L" | tr '[:upper:]' '[:lower:]')
  npx remotion render "Hero-$L" "out/clips/hero-$l.mp4" --crf=16 --log=error
  FPS=30 scripts/encode_loop.sh "out/clips/hero-$l.mp4" "out/clips/hero-$l" 960 >/dev/null
  cp "out/clips/hero-$l.webp" "$M/hero-$l.webp"
  npx remotion still "VideoPoster-$L" "out/clips/video-poster-$l.png" --log=error
  ffmpeg -loglevel error -y -i "out/clips/video-poster-$l.png" -vf scale=1280:-1:flags=lanczos -q:v 3 "$M/video-poster-$l.jpg"
done
ls -lh "$M"
