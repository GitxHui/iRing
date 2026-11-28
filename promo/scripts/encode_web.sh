#!/bin/bash
# Encode GitHub-friendly deliverables from rendered masters.
#   scripts/encode_web.sh <master.mp4> <out_prefix>
# -> <out_prefix>-release.mp4 (video copied, audio loudness-normalised) for GitHub Releases
# -> <out_prefix>-github.mp4  (H.264, 2-pass, fits GitHub's 10 MB inline-video limit)
set -euo pipefail
IN="$1"; OUT="$2"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
# 9.6 MB budget minus 128 kbps audio
VBR=$(python3 -c "print(int((9.6*8*1024*1024/$DUR - 128000)/1000))")
echo "duration ${DUR}s -> video ${VBR} kbps"
LN="loudnorm=I=-16:TP=-1.5:LRA=11"
ffmpeg -loglevel error -y -i "$IN" -c:v copy -af "$LN" -ar 48000 -c:a aac -b:a 256k -movflags +faststart "$OUT-release.mp4"
P=$(mktemp -d)
ffmpeg -loglevel error -y -i "$IN" -vf "scale=1920:1080:flags=lanczos" -c:v libx264 -preset slower -tune animation -b:v ${VBR}k -maxrate $((VBR*2))k -bufsize $((VBR*4))k -pass 1 -passlogfile "$P/pl" -an -f mp4 /dev/null
ffmpeg -loglevel error -y -i "$IN" -vf "scale=1920:1080:flags=lanczos" -c:v libx264 -preset slower -tune animation -b:v ${VBR}k -maxrate $((VBR*2))k -bufsize $((VBR*4))k -pass 2 -passlogfile "$P/pl" -pix_fmt yuv420p -af "$LN" -ar 48000 -c:a aac -b:a 128k -movflags +faststart "$OUT-github.mp4"
rm -rf "$P"
ls -lh "$OUT-release.mp4" "$OUT-github.mp4"
