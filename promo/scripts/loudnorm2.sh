#!/bin/bash
# Two-pass loudness normalisation; copies video.  loudnorm2.sh <in> <out> [I] [TP]
set -euo pipefail
IN="$1"; OUT="$2"; I="${3:--14}"; TP="${4:--1.5}"
J=$(ffmpeg -hide_banner -i "$IN" -af "afade=t=in:d=0.03,loudnorm=I=$I:TP=$TP:LRA=11:print_format=json" -f null - 2>&1 | sed -n '/^{/,/^}/p')
g() { echo "$J" | python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }
ffmpeg -loglevel error -y -i "$IN" -c:v copy -af "afade=t=in:d=0.03,loudnorm=I=$I:TP=$TP:LRA=11:measured_I=$(g input_i):measured_TP=$(g input_tp):measured_LRA=$(g input_lra):measured_thresh=$(g input_thresh):offset=$(g target_offset):linear=true,alimiter=limit=$(python3 -c "print(10**(($TP-0.3)/20))"):level=false" -ar 48000 -c:a aac -b:a 256k -movflags +faststart "$OUT"
