#!/bin/bash
# README assets for the vertical (Douyin / Xiaohongshu) film.
#   scripts/build_readme_vertical.sh            # run from promo/
# Inputs : out/iring-vertical-{zh,en}-master.mp4, out/iring-vertical-{zh,en}-social.mp4
# Outputs: ../docs/media/vertical-preview-{zh,en}.webp  (360 px, 20 fps, looping highlight reel)
#          ../docs/media/vertical-poster-{zh,en}.jpg    (closing frame)
#          out/release-assets/iRing-promo-vertical-{zh,en}.mp4 (copies of the social cut, for the Release)
# Highlight windows (seconds in the master) can be overridden: CLIPS="4.0:7.0 15.5:18.5 26.0:28.0"
set -euo pipefail
cd "$(dirname "$0")/.."
M=../docs/media
mkdir -p "$M" out/release-assets
CLIPS=${CLIPS:-"4.0:7.0 15.5:18.5 26.0:28.0"}
POSTER_AT=${POSTER_AT:-33.0}
XF=0.3
for l in zh en; do
  IN=out/iring-vertical-$l-master.mp4
  [ -f "$IN" ] || { echo "missing $IN" >&2; exit 1; }
  # build an xfade chain over the highlight clips
  args=(); fc=""; i=0; prev=""; acc=0
  for c in $CLIPS; do
    s=${c%%:*}; e=${c##*:}
    args+=(-ss "$s" -t "$(python3 -c "print($e-$s)")" -i "$IN")
    fc+="[$i:v]fps=20,scale=360:-2:flags=lanczos,setsar=1,format=yuv420p[v$i];"
    d=$(python3 -c "print($e-$s)")
    if [ $i -eq 0 ]; then prev="v0"; acc=$d; else
      off=$(python3 -c "print(round($acc-$XF,3))")
      fc+="[$prev][v$i]xfade=transition=fade:duration=$XF:offset=$off[x$i];"
      prev="x$i"; acc=$(python3 -c "print($acc+$d-$XF)")
    fi
    i=$((i+1))
  done
  fc=${fc%;}
  T=$(mktemp -d)
  ffmpeg -loglevel error -y "${args[@]}" -filter_complex "$fc" -map "[$prev]" -an "$T/reel.mp4"
  mkdir -p "$T/f"
  ffmpeg -loglevel error -y -i "$T/reel.mp4" "$T/f/%05d.png"
  python3 - "$T/f" "$M/vertical-preview-$l.webp" <<'PY'
import sys, glob
from PIL import Image
fr = [Image.open(f).convert("RGB") for f in sorted(glob.glob(sys.argv[1] + "/*.png"))]
fr[0].save(sys.argv[2], save_all=True, append_images=fr[1:], duration=50, loop=0, quality=78, method=6)
PY
  ffmpeg -loglevel error -y -ss "$POSTER_AT" -i "$IN" -frames:v 1 -vf "scale=720:-2:flags=lanczos" -q:v 3 "$M/vertical-poster-$l.jpg"
  rm -rf "$T"
  [ -f out/iring-vertical-$l-social.mp4 ] && cp out/iring-vertical-$l-social.mp4 out/release-assets/iRing-promo-vertical-$l.mp4
done
ls -lh "$M"/vertical-* out/release-assets/
