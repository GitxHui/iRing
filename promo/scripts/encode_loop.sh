#!/bin/bash
# Turn a rendered loop MP4 into README-ready GIF + animated WebP.
#   scripts/encode_loop.sh <loop.mp4> <out_prefix> [width]
set -euo pipefail
IN="$1"; OUT="$2"; WIDTH="${3:-960}"
P=$(mktemp -d)
ffmpeg -loglevel error -y -i "$IN" -vf "fps=${FPS:-30},scale=${WIDTH}:-1:flags=lanczos,palettegen=max_colors=${COLORS:-256}:stats_mode=diff" "$P/pal.png"
ffmpeg -loglevel error -y -i "$IN" -i "$P/pal.png" -lavfi "fps=${FPS:-30},scale=${WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle" -loop 0 "$OUT.gif"
mkdir -p "$P/f"
ffmpeg -loglevel error -y -i "$IN" -vf "fps=${FPS:-30},scale=${WIDTH}:-1:flags=lanczos" "$P/f/%05d.png"
python3 - "$P/f" "$OUT.webp" "${FPS:-30}" <<'PY'
import sys, glob
from PIL import Image
frames = [Image.open(f).convert("RGB") for f in sorted(glob.glob(sys.argv[1] + "/*.png"))]
frames[0].save(sys.argv[2], save_all=True, append_images=frames[1:], duration=round(1000 / float(sys.argv[3])), loop=0, quality=80, method=6)
PY
rm -rf "$P"
ls -lh "$OUT.gif" "$OUT.webp"
