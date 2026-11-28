"""Generate the animated SVGs used by README.md / README.en.md.

Run from the repository root:  python3 docs/tools/readme_svgs.py

GitHub renders SVGs referenced by <img> with their internal <style>/@keyframes,
but never loads external resources from them, so app icons are embedded as
data URIs and text uses the system font stack.
"""

import base64
import io
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "media")
ICONS = os.path.join(ROOT, "promo", "public", "icons")
os.makedirs(os.path.join(OUT, "nav"), exist_ok=True)

FONT = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'PingFang SC', 'Helvetica Neue', sans-serif"
BLUE = "#0A84FF"

THEMES = {
    "dark": {
        "bg0": "#05070D",
        "bg1": "#0E1630",
        "ink": "#F5F5F7",
        "dim": "#86868B",
        "ring": "rgba(246,247,250,0.94)",
        "well": "#1B2336",
        "rim": "rgba(255,255,255,0.10)",
        "glow": "0.55",
        "card": "rgba(255,255,255,0.06)",
    },
    "light": {
        "bg0": "#FBFBFD",
        "bg1": "#EEF2FA",
        "ink": "#1D1D1F",
        "dim": "#6E6E73",
        "ring": "#FFFFFF",
        "well": "#E7ECF5",
        "rim": "rgba(0,0,0,0.06)",
        "glow": "0.28",
        "card": "rgba(0,0,0,0.035)",
    },
}

COPY = {
    "zh": {
        "eyebrow": "iRing for macOS",
        "tokens": ["⌥ / 中键", " = ", "切屏", " + ", "分屏", " + ", "缩放", " + ", "Dock"],
        "sub": "在光标处，掌控每一个窗口。",
        "sub2": "二分屏 · 四分屏 · 全屏 · 连续缩放 · 灵动岛",
        "dl": "下载 macOS Beta",
        "dl_sub": "免费 · macOS 15+ · Apple 芯片",
    },
    "en": {
        "eyebrow": "iRing for macOS",
        "tokens": ["⌥ / middle click", " = ", "switch", " + ", "tile", " + ", "resize", " + ", "dock"],
        "sub": "Every window. Right at your cursor.",
        "sub2": "Halves · Quarters · Full screen · Resize · Dynamic dock",
        "dl": "Download the Mac beta",
        "dl_sub": "Free · macOS 15+ · Apple silicon",
    },
}

RING_ICONS = ["safari", "claude", "chatgpt", "wechat", "chrome", "vscode", "notes", "music"]


def icon_uri(name, size=88):
    im = Image.open(os.path.join(ICONS, f"{name}.png")).convert("RGBA").resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def sector(cx, cy, ro, ri, a0, a1):
    r = math.pi / 180
    p = lambda rad, a: f"{cx + math.cos(a * r) * rad:.2f} {cy + math.sin(a * r) * rad:.2f}"
    return f"M {p(ro, a0)} A {ro} {ro} 0 0 1 {p(ro, a1)} L {p(ri, a1)} A {ri} {ri} 0 0 0 {p(ri, a0)} Z"


STAR = "M0,-1 C0.12,-0.12 0.12,-0.12 1,0 C0.12,0.12 0.12,0.12 0,1 C-0.12,0.12 -0.12,0.12 -1,0 C-0.12,-0.12 -0.12,-0.12 0,-1Z"


def hero(lang, theme):
    T = THEMES[theme]
    C = COPY[lang]
    W, H = 1640, 640
    cx, cy = 1235, 320
    ro, ri, orbit = 118, 56, 212
    icons = {n: icon_uri(n) for n in RING_ICONS}
    n = len(RING_ICONS)

    # slogan tokens — fade in one by one (fill-opacity works on <tspan>)
    tspans = []
    for i, tok in enumerate(C["tokens"]):
        accent = tok.strip() in ("=", "+")
        fill = T["dim"] if accent else T["ink"]
        if i == 0:
            fill = "url(#accent)"
        tspans.append(
            f'<tspan class="tok" style="animation-delay:{0.35 + i * 0.12:.2f}s" fill="{fill}">{tok.replace(" ", "&#160;")}</tspan>'
        )

    orbit_imgs = []
    for i, name in enumerate(RING_ICONS):
        a = -90 + i * 360 / n
        x = cx + math.cos(math.radians(a)) * orbit
        y = cy + math.sin(math.radians(a)) * orbit
        # each icon pops when the sweeping wedge passes (wedge period 8 s)
        delay = (i / n) * 8.0
        orbit_imgs.append(
            f'<g class="orb" style="animation-delay:{0.2 + i * 0.07:.2f}s"><g class="pop" style="transform-origin:{x:.1f}px {y:.1f}px;animation-delay:{delay:.2f}s">'
            f'<image href="{icons[name]}" x="{x - 38:.1f}" y="{y - 38:.1f}" width="76" height="76" filter="url(#ish)"/></g></g>'
        )

    stars = []
    for k in range(18):
        a = -90 + k * 20 + (k % 3) * 7
        rr = ro + 18 + (k * 37 % 70)
        x = cx + math.cos(math.radians(a)) * rr
        y = cy + math.sin(math.radians(a)) * rr
        s = 4 + (k * 13 % 7)
        col = "#FFFFFF" if (theme == "dark" and k % 3 == 0) else BLUE
        stars.append(
            f'<path class="star" d="{STAR}" transform="translate({x:.1f} {y:.1f}) scale({s})" fill="{col}" style="animation-delay:{(k * 0.37) % 3:.2f}s"/>'
        )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="iRing — {C['tokens'][0]}">
<style>
  text {{ font-family: {FONT}; }}
  .tok {{ fill-opacity: 0; animation: tokIn .7s cubic-bezier(.16,1,.3,1) forwards; }}
  @keyframes tokIn {{ to {{ fill-opacity: 1; }} }}
  .fade {{ opacity: 0; animation: fadeUp 1s cubic-bezier(.16,1,.3,1) forwards; }}
  @keyframes fadeUp {{ from {{ opacity: 0; transform: translateY(14px); }} to {{ opacity: 1; transform: none; }} }}
  .ring {{ transform-origin: {cx}px {cy}px; animation: ringIn 1.2s cubic-bezier(.2,1.4,.4,1) both; }}
  @keyframes ringIn {{ from {{ transform: scale(.6); opacity: 0; }} to {{ transform: scale(1); opacity: 1; }} }}
  .wedge {{ transform-origin: {cx}px {cy}px; animation: spin 8s cubic-bezier(.45,0,.2,1) infinite; }}
  @keyframes spin {{
    0% {{ transform: rotate(0deg); }} 12.5% {{ transform: rotate(45deg); }} 25% {{ transform: rotate(90deg); }}
    37.5% {{ transform: rotate(135deg); }} 50% {{ transform: rotate(180deg); }} 62.5% {{ transform: rotate(225deg); }}
    75% {{ transform: rotate(270deg); }} 87.5% {{ transform: rotate(315deg); }} 100% {{ transform: rotate(360deg); }} }}
  .orb {{ opacity: 0; animation: fadeIn .8s ease-out forwards; }}
  @keyframes fadeIn {{ to {{ opacity: 1; }} }}
  .pop {{ animation: pop 8s ease-in-out infinite; }}
  @keyframes pop {{ 0%, 9%, 100% {{ transform: scale(1); }} 2.5% {{ transform: scale(1.22); }} 6% {{ transform: scale(1.12); }} }}
  .star {{ opacity: 0; animation: twinkle 3s ease-in-out infinite; }}
  @keyframes twinkle {{ 0%, 100% {{ opacity: 0; }} 40% {{ opacity: .95; }} 70% {{ opacity: .2; }} }}
  .key {{ animation: keyA 6s ease-in-out infinite; }}
  .mouse {{ animation: keyB 6s ease-in-out infinite; }}
  @keyframes keyA {{ 0%, 42% {{ opacity: 1; }} 50%, 92% {{ opacity: 0; }} 100% {{ opacity: 1; }} }}
  @keyframes keyB {{ 0%, 42% {{ opacity: 0; }} 50%, 92% {{ opacity: 1; }} 100% {{ opacity: 0; }} }}
  .sheen {{ animation: sheen 6s ease-in-out infinite; }}
  @keyframes sheen {{ 0%, 55% {{ transform: translateX(-700px); }} 85%, 100% {{ transform: translateX({W + 200}px); }} }}
</style>
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{T['bg0']}"/><stop offset="1" stop-color="{T['bg1']}"/>
  </linearGradient>
  <radialGradient id="glow"><stop offset="0" stop-color="#2E7BFF" stop-opacity="{T['glow']}"/><stop offset="1" stop-color="#2E7BFF" stop-opacity="0"/></radialGradient>
  <radialGradient id="glow2"><stop offset="0" stop-color="#9A7BFF" stop-opacity="{float(T['glow']) * 0.6:.2f}"/><stop offset="1" stop-color="#9A7BFF" stop-opacity="0"/></radialGradient>
  <linearGradient id="accent" x1="0" x2="1"><stop offset="0" stop-color="#2997FF"/><stop offset="1" stop-color="#7A6CFF"/></linearGradient>
  <linearGradient id="wedgeG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#0A5AD6"/><stop offset="1" stop-color="#2A8BFF"/></linearGradient>
  <linearGradient id="sheenG" x1="0" x2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity="{'0.07' if theme == 'dark' else '0.5'}"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <filter id="ish" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="6" stdDeviation="7" flood-color="#0A1A3C" flood-opacity="{'0.45' if theme == 'dark' else '0.18'}"/></filter>
  <filter id="rsh" x="-40%" y="-40%" width="180%" height="180%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#0A1A3C" flood-opacity="{'0.55' if theme == 'dark' else '0.16'}"/></filter>
  <filter id="soft"><feGaussianBlur stdDeviation="8"/></filter>
  <clipPath id="frame"><rect width="{W}" height="{H}" rx="44"/></clipPath>
</defs>
<g clip-path="url(#frame)">
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <ellipse cx="{cx}" cy="{cy}" rx="520" ry="380" fill="url(#glow)"/>
  <ellipse cx="260" cy="40" rx="520" ry="320" fill="url(#glow2)"/>
  <g fill="none" stroke="{T['rim']}" stroke-width="1.5">
    <circle cx="{cx}" cy="{cy}" r="{orbit + 70}"/><circle cx="{cx}" cy="{cy}" r="{orbit + 140}"/>
  </g>

  <!-- copy -->
  <text class="fade" x="112" y="168" font-size="28" font-weight="600" fill="url(#accent)" letter-spacing="0.5" style="animation-delay:.05s">{C['eyebrow']}</text>
  <text class="fade" x="106" y="300" font-size="{150 if lang == 'zh' else 150}" font-weight="700" fill="{T['ink']}" letter-spacing="-5" style="animation-delay:.15s">iRing</text>
  <text x="112" y="388" font-size="{50 if lang == 'zh' else 46}" font-weight="600" letter-spacing="{0 if lang == 'zh' else -1}">{''.join(tspans)}</text>
  <text class="fade" x="112" y="452" font-size="{29 if lang == 'zh' else 26}" font-weight="400" fill="{T['dim']}" style="animation-delay:1.4s">{C['sub']}</text>
  <text class="fade" x="112" y="500" font-size="{25 if lang == 'zh' else 23}" font-weight="500" fill="{T['dim']}" letter-spacing="0.3" style="animation-delay:1.6s">{C['sub2']}</text>

  <!-- ring -->
  <g class="ring">
    <circle cx="{cx}" cy="{cy}" r="{ro}" fill="{T['ring']}" filter="url(#rsh)"/>
    <g class="wedge">
      <path d="{sector(cx, cy, ro + 8, ri - 4, -112.5, -67.5)}" fill="#2A8BFF" opacity=".35" filter="url(#soft)"/>
      <path d="{sector(cx, cy, ro, ri, -112.5, -67.5)}" fill="url(#wedgeG)"/>
    </g>
    <circle cx="{cx}" cy="{cy}" r="{ri}" fill="{T['well']}"/>
    <circle cx="{cx}" cy="{cy}" r="{ro - 0.8}" fill="none" stroke="#fff" stroke-opacity=".9" stroke-width="1.5"/>
    <!-- centre: ⌥ key, then the middle mouse button -->
    <g class="key">
      <rect x="{cx - 34}" y="{cy - 34}" width="68" height="68" rx="16" fill="#1C2A4D"/>
      <text x="{cx}" y="{cy + 15}" text-anchor="middle" font-size="40" font-weight="500" fill="#fff">⌥</text>
    </g>
    <g class="mouse">
      <rect x="{cx - 24}" y="{cy - 36}" width="48" height="72" rx="24" fill="#FFFFFF" stroke="#C9D2E3" stroke-width="2"/>
      <line x1="{cx}" y1="{cy - 36}" x2="{cx}" y2="{cy - 6}" stroke="#C9D2E3" stroke-width="2"/>
      <rect x="{cx - 5}" y="{cy - 26}" width="10" height="18" rx="5" fill="{BLUE}"/>
    </g>
  </g>
  {''.join(orbit_imgs)}
  {''.join(stars)}
  <g class="sheen"><rect x="0" y="0" width="420" height="{H}" fill="url(#sheenG)" transform="skewX(-18)"/></g>
</g>
<rect x="0.75" y="0.75" width="{W - 1.5}" height="{H - 1.5}" rx="43.5" fill="none" stroke="{T['rim']}" stroke-width="1.5"/>
</svg>"""
    path = os.path.join(OUT, f"hero-{lang}-{theme}.svg")
    with open(path, "w") as f:
        f.write(svg)
    return path


def button(lang):
    C = COPY[lang]
    W, H = 640, 120
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W // 2}" height="{H // 2}" role="img" aria-label="{C['dl']}">
<style>
  text {{ font-family: {FONT}; }}
  .sheen {{ animation: sheen 4s ease-in-out infinite; }}
  @keyframes sheen {{ 0%, 60% {{ transform: translateX(-260px); }} 100% {{ transform: translateX({W + 60}px); }} }}
  .arrow {{ animation: bob 2s ease-in-out infinite; }}
  @keyframes bob {{ 0%, 100% {{ transform: translateY(0); }} 50% {{ transform: translateY(5px); }} }}
</style>
<defs>
  <linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2A8BFF"/><stop offset="1" stop-color="#0060DF"/></linearGradient>
  <linearGradient id="s" x1="0" x2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".35"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <clipPath id="c"><rect x="2" y="2" width="{W - 4}" height="{H - 4}" rx="{(H - 4) / 2}"/></clipPath>
</defs>
<g clip-path="url(#c)">
  <rect x="2" y="2" width="{W - 4}" height="{H - 4}" fill="url(#b)"/>
  <g class="sheen"><rect x="0" y="0" width="200" height="{H}" fill="url(#s)" transform="skewX(-20)"/></g>
</g>
<rect x="2.5" y="2.5" width="{W - 5}" height="{H - 5}" rx="{(H - 5) / 2}" fill="none" stroke="#fff" stroke-opacity=".28"/>
<g class="arrow" stroke="#fff" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <path d="M74 38v32m0 0l-13-13m13 13l13-13M56 84h36"/>
</g>
<text x="120" y="{H / 2 + 12}" font-size="{38 if lang == 'zh' else 34}" font-weight="600" fill="#fff">{C['dl']}</text>
</svg>"""
    path = os.path.join(OUT, f"btn-download-{lang}.svg")
    with open(path, "w") as f:
        f.write(svg)


def text_width(s, size):
    w = 0
    for ch in s:
        if ord(ch) > 0x2E80:
            w += size
        elif ch == " ":
            w += size * 0.28
        elif ch.isupper():
            w += size * 0.66
        else:
            w += size * 0.56
    return w


NAV = {
    "zh": [("film", "影片"), ("features", "核心功能"), ("details", "更多细节"), ("install", "下载安装"), ("faq", "常见问题")],
    "en": [("film", "Film"), ("features", "Features"), ("details", "Details"), ("install", "Install"), ("faq", "FAQ")],
}


def nav(lang):
    for key, label in NAV[lang]:
        size = 26
        w = int(text_width(label, size) + 60)
        h = 60
        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w // 2}" height="{h // 2}" role="img" aria-label="{label}">
<style>text {{ font-family: {FONT}; }}</style>
<rect x="1" y="1" width="{w - 2}" height="{h - 2}" rx="{(h - 2) / 2}" fill="{BLUE}" fill-opacity=".10" stroke="{BLUE}" stroke-opacity=".32" stroke-width="1.5"/>
<text x="{w / 2}" y="{h / 2 + 9}" text-anchor="middle" font-size="{size}" font-weight="600" fill="{BLUE}">{label}</text>
</svg>"""
        with open(os.path.join(OUT, "nav", f"{lang}-{key}.svg"), "w") as f:
            f.write(svg)


def divider():
    W, H = 1640, 40
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="820" height="20" role="presentation">
<style>
  .g {{ animation: glide 5s cubic-bezier(.45,0,.2,1) infinite; }}
  @keyframes glide {{ 0% {{ transform: translateX(-500px); }} 100% {{ transform: translateX({W + 100}px); }} }}
</style>
<defs>
  <linearGradient id="l" x1="0" x2="1"><stop offset="0" stop-color="#8E8E93" stop-opacity="0"/><stop offset=".5" stop-color="#8E8E93" stop-opacity=".45"/><stop offset="1" stop-color="#8E8E93" stop-opacity="0"/></linearGradient>
  <linearGradient id="h" x1="0" x2="1"><stop offset="0" stop-color="{BLUE}" stop-opacity="0"/><stop offset=".5" stop-color="{BLUE}" stop-opacity="1"/><stop offset="1" stop-color="{BLUE}" stop-opacity="0"/></linearGradient>
</defs>
<rect x="0" y="{H / 2 - 1}" width="{W}" height="2" fill="url(#l)"/>
<rect class="g" x="0" y="{H / 2 - 1.5}" width="400" height="3" rx="1.5" fill="url(#h)"/>
</svg>"""
    with open(os.path.join(OUT, "divider.svg"), "w") as f:
        f.write(svg)


if __name__ == "__main__":
    for lang in ("zh", "en"):
        for theme in ("dark", "light"):
            print(hero(lang, theme), os.path.getsize(os.path.join(OUT, f"hero-{lang}-{theme}.svg")) // 1024, "KB")
        button(lang)
        nav(lang)
    divider()
    print("done")
