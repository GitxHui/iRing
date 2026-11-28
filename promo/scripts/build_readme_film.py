"""README media from the keynote film (run from promo/ after rendering out/iring-film-*-1080p.mp4).

Outputs into ../docs/media/film/:
  hero-{lang}.webp        ~11 s highlight reel (autoplay demo under the banner)
  entries|switch|tile|resize|island|details-{lang}.webp   per-feature loops
  poster-{lang}.jpg       poster with a play pill (links to the full film)
"""
import os, subprocess, sys, tempfile, glob
from PIL import Image

OUT = "../docs/media/film"
os.makedirs(OUT, exist_ok=True)

HERO = [(9.3, 11.7), (17.1, 18.5), (19.6, 21.0), (22.1, 23.6), (33.2, 35.2), (45.6, 47.6), (57.0, 58.6)]
FEATURES = {
    "entries": [(16.3, 24.4)],
    "switch": [(25.4, 30.4)],
    "tile": [(31.3, 38.7)],
    "resize": [(39.3, 44.0)],
    "island": [(44.8, 51.6)],
    "details": [(52.2, 55.8)],
}

def run(*a):
    subprocess.run(a, check=True)

def reel(src, clips, width, fps, dst, quality, xf=0.35):
    """Cut clips, cross-fade them, write an animated WebP via Pillow."""
    tmp = tempfile.mkdtemp()
    args, fc, prev, acc = [], "", None, 0.0
    for i, (s, e) in enumerate(clips):
        d = e - s
        args += ["-ss", f"{s}", "-t", f"{d}", "-i", src]
        fc += f"[{i}:v]fps={fps},scale={width}:-2:flags=lanczos,setsar=1,format=yuv420p[v{i}];"
        if i == 0:
            prev, acc = "v0", d
        else:
            fc += f"[{prev}][v{i}]xfade=transition=fade:duration={xf}:offset={acc - xf:.3f}[x{i}];"
            prev, acc = f"x{i}", acc + d - xf
    run("ffmpeg", "-loglevel", "error", "-y", *args, "-filter_complex", fc.rstrip(";"), "-map", f"[{prev}]", f"{tmp}/%05d.png")
    frames = [Image.open(f).convert("RGB") for f in sorted(glob.glob(f"{tmp}/*.png"))]
    frames[0].save(dst, save_all=True, append_images=frames[1:], duration=round(1000 / fps), loop=0, quality=quality, method=6)
    print(f"{dst}: {len(frames)} frames, {os.path.getsize(dst) / 1e6:.2f} MB")

for lang in ("zh", "en"):
    src = f"out/iring-film-{lang}-1080p.mp4"
    if not os.path.exists(src):
        sys.exit(f"missing {src}")
    reel(src, HERO, 960, 20, f"{OUT}/hero-{lang}.webp", 72)
    for name, clips in FEATURES.items():
        reel(src, clips, 720, 18, f"{OUT}/{name}-{lang}.webp", 68)
    png = f"out/film-poster-{lang}.png"
    run("npx", "remotion", "still", f"FilmPoster-{lang.upper()}", png, "--log=error")
    run("ffmpeg", "-loglevel", "error", "-y", "-i", png, "-vf", "scale=1280:-1:flags=lanczos", "-q:v", "3", f"{OUT}/poster-{lang}.jpg")
print("done")
