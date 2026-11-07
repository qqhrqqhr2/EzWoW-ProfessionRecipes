#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Profession Recipes (docs/images/ui_*.png, settings_*.png).

The recipe window, item tooltips and the settings window are rebuilt from the sizes,
coordinates, colours and strings in the addon code (UI/RecipeBrowser.lua,
UI/OptionsWindow.lua, Modules/RecipeStatus.lua, Core/Locales.lua), in game pixels x scale.
Icons are simplified drawings; character names are made up.

usage: python scripts/make_readme_images.py .
Renders with a local headless Chrome (set CHROME=<path> if it is not found).
"""
import base64
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PAGE_W = 1600

# ---------------------------------------------------------------------------
# Small readers for the Lua code
# ---------------------------------------------------------------------------


def read(root, rel):
    return (root / rel).read_text(encoding="utf-8")


def find_file(root, *names):
    """First existing file of names (case-insensitive on every system)."""
    for name in names:
        p = root / name
        if p.exists():
            return p
        parent = p.parent
        if parent.exists():
            for q in parent.iterdir():
                if q.name.lower() == p.name.lower():
                    return q
    raise FileNotFoundError(names)


def rgb_list(body):
    return [float(v) for v in body.split(",") if v.strip()]


def lua_table(src, start_pattern):
    """Text of the Lua table that starts at start_pattern (balanced braces)."""
    m = re.search(start_pattern, src)
    if not m:
        raise ValueError(start_pattern)
    i = src.index("{", m.start())
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i + 1:j]
    raise ValueError("unbalanced " + start_pattern)


def lua_strings(block):
    """key = "value" pairs of a Lua table body (plain keys and ["keys"])."""
    out = {}
    for k1, k2, v in re.findall(r'(?:^|[\s,{])(?:(\w+)|\["((?:[^"\\]|\\.)*)"\])\s*=\s*"((?:[^"\\]|\\.)*)"', block, re.M):
        out[k1 or k2] = unlua(v)
    return out


def unlua(v):
    return v.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def toc_version(root):
    for p in root.glob("*.toc"):
        m = re.search(r"^## Version:\s*(\S+)", p.read_text(encoding="utf-8"), re.M)
        if m:
            return m.group(1)
    return ""


def css(c, alpha=None, mul=1.0):
    r, g, b = (round(min(1, v * mul) * 255) for v in c[:3])
    a = alpha if alpha is not None else (c[3] if len(c) > 3 else 1)
    return f"rgba({r},{g},{b},{a:.2f})"


def hexc(c):
    return "#%02x%02x%02x" % tuple(round(v * 255) for v in c[:3])


def esc(s):
    return html.escape(str(s), quote=False)


def wow(s):
    """Game text -> HTML: |cffRRGGBB..|r colours, |n / \\n line breaks, icons dropped."""
    s = esc(s)
    s = re.sub(r"\|T[^|]*\|t", "", s)
    s = re.sub(r"\|A[^|]*\|a", "", s)
    out, depth = [], 0
    pos = 0
    for m in re.finditer(r"\|c[0-9a-fA-F]{2}([0-9a-fA-F]{6})|\|r", s):
        out.append(s[pos:m.start()])
        if m.group(0) == "|r":
            if depth:
                out.append("</span>")
                depth -= 1
        else:
            out.append(f'<span style="color:#{m.group(1)}">')
            depth += 1
        pos = m.end()
    out.append(s[pos:])
    out.append("</span>" * depth)
    return "".join(out).replace("|n", "<br>").replace("\n", "<br>")


# ---------------------------------------------------------------------------
# Page parts (game px x S -> page px)
# ---------------------------------------------------------------------------
S = 1.3


def px(v):
    return f"{v * S:.2f}px"


OUTLINE = "text-shadow:-1px 0 #000,1px 0 #000,0 -1px #000,0 1px #000,0 0 2px #000;"
SHADOW = "text-shadow:1px 1px 0 #000,0 0 2px rgba(0,0,0,.8);"

# client colours used by several mock-ups
QUALITY = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee", 5: "#ff8000"}
CLASS_HEX = {"WARRIOR": "#c69b6d", "PALADIN": "#f48cba", "HUNTER": "#aad372", "ROGUE": "#fff468", "PRIEST": "#ffffff",
             "SHAMAN": "#0070dd", "MAGE": "#3fc7eb", "WARLOCK": "#8788ee", "DRUID": "#ff7c0a"}
GOLD = "#ffd100"

THEME = {
    "bg": (0.071, 0.094, 0.122, 0.97), "bgSub": (0.114, 0.157, 0.192, 0.96), "border": (0.204, 0.298, 0.357, 1),
    "text": (0.929, 0.957, 0.969, 1), "muted": (0.655, 0.725, 0.773, 1), "accent": (0.5, 0.8, 0.9, 1),
}


def page_css(call):
    return f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: {PAGE_W}px; overflow: hidden; }}
body {{ background: #0e141a; font-family: 'Noto Sans KR','Malgun Gothic',sans-serif; color: #edf4f7; position: relative; }}
.sky {{ position: absolute; left: 0; top: 0; width: {PAGE_W}px; height: 100%;
  background: radial-gradient(ellipse at 25% 0%, #1d2b38 0%, #151f28 45%, #10171d 75%, #0c1115 100%); }}
.hills {{ position: absolute; left: 0; bottom: 0; width: {PAGE_W}px; height: 260px; }}
.page {{ position: relative; padding: 34px 50px 0; }}
h1 {{ color: {call}; font-size: 40px; font-weight: 700; letter-spacing: .3px; display: flex; align-items: center; gap: 14px; }}
h1 .badge {{ font-size: 15px; background: {call}; color: #10161c; padding: 2px 9px; border-radius: 5px; }}
.lead {{ color: #d5dde2; font-size: 19px; margin-top: 6px; }}
.abs {{ position: absolute; }}
.t {{ position: absolute; white-space: nowrap; line-height: 1.15; }}
.call {{ position: absolute; width: 30px; height: 30px; border-radius: 50%; background: {call}; color: #10161c; font-weight: 700;
  font-size: 16px; display: flex; align-items: center; justify-content: center; border: 2px solid #10161c; box-shadow: 0 0 0 2px {call}55; z-index: 60; }}
.notes {{ position: absolute; }}
.note {{ display: flex; gap: 12px; margin-bottom: 11px; font-size: 16px; line-height: 1.5; color: #dfe6ea; }}
.note .n {{ flex: none; width: 28px; height: 28px; border-radius: 50%; background: {call}; color: #10161c; font-weight: 700;
  font-size: 15px; display: flex; align-items: center; justify-content: center; }}
.note b {{ color: #fff; }}
.foot {{ position: absolute; color: #7d8d98; font-size: 13.5px; line-height: 1.5; }}
.fit {{ display: inline-block; white-space: nowrap; }}
.tip {{ position: absolute; z-index: 30; }}
.tip .row {{ display: flex; justify-content: space-between; gap: 18px; white-space: nowrap; }}
"""


HILLS = ('<svg class="hills" viewBox="0 0 1600 260" preserveAspectRatio="none">'
         '<path d="M0 150 C 220 70 420 90 640 140 C 860 190 1060 60 1300 80 C 1440 92 1540 120 1600 130 V260 H0 Z" fill="#141c23" opacity=".9"/>'
         '<path d="M0 210 C 260 160 520 170 800 205 C 1080 240 1340 170 1600 190 V260 H0 Z" fill="#0b1014"/></svg>')

FIT_JS = """
<script>
document.querySelectorAll('[data-fit]').forEach(function (e) {
  var max = parseFloat(e.dataset.fit), min = parseFloat(e.dataset.min || 8);
  var fs = parseFloat(getComputedStyle(e).fontSize);
  while (e.scrollWidth > max && fs > min) { fs -= 0.25; e.style.fontSize = fs + 'px'; }
  if (e.scrollWidth > max) { e.style.maxWidth = max + 'px'; e.style.overflow = 'hidden'; e.style.textOverflow = 'ellipsis'; }
});
// place the footnote under the lowest element, then record the page height
var bottom = 0;
document.querySelectorAll('.page *, body > .abs, body > .notes, body > .call, body > .tip').forEach(function (e) {
  var r = e.getBoundingClientRect(); if (r.height > 0 && r.bottom > bottom) bottom = r.bottom;
});
var foot = document.querySelector('.foot');
if (foot) { foot.style.top = (bottom + 26) + 'px'; bottom = foot.getBoundingClientRect().bottom; }
document.body.setAttribute('data-h', Math.ceil(bottom + 34));
document.body.style.height = Math.ceil(bottom + 34) + 'px';
</script>
"""


def box(x, y, w, h, style="", inner=""):
    return f'<div class="abs" style="left:{px(x)};top:{px(y)};width:{px(w)};height:{px(h)};{style}">{inner}</div>'


def text(x, y, s, size, color="#fff", anchor="left", style="", fit=None, shadow=SHADOW):
    """Font string; y is the vertical centre (game px)."""
    tr = {"left": "translate(0,-50%)", "right": "translate(-100%,-50%)", "center": "translate(-50%,-50%)"}[anchor]
    inner = s if fit is None else f'<span class="fit" data-fit="{fit * S:.1f}" data-min="{size * 0.7 * S:.1f}">{s}</span>'
    return (f'<div class="t" style="left:{px(x)};top:{px(y)};font-size:{px(size)};color:{color};'
            f'transform:{tr};{shadow}{style}">{inner}</div>')


def text_top(x, y, s, size, color="#fff", width=None, style="", shadow=SHADOW):
    """Font string anchored at its top-left (TOPLEFT points)."""
    w = f"width:{px(width)};white-space:normal;" if width else ""
    return (f'<div class="t" style="left:{px(x)};top:{px(y)};font-size:{px(size)};color:{color};line-height:1.3;'
            f'{w}{shadow}{style}">{s}</div>')


class Window:
    """A flat EzWoW style window: header strip, accent line, icon, title, sub title, close box."""

    def __init__(self, th, w, h, title, sub="", icon=None, header=56, close=22, close_off=10, title_color=None):
        self.th, self.w, self.h = th, w, h
        self.p = []
        acc = css(th["accent"], 1)
        if header:
            self.p.append(box(1, 1, w - 2, header, f"background:{css(th['bgSub'], .98)}"))
            self.p.append(box(1, header - 1, w - 2, 2, f"background:{acc}"))
            if icon:
                self.p.append(f'<img class="abs" src="{icon}" style="left:{px(14)};top:{px(14)};width:{px(28)};height:{px(28)}">')
            self.p.append(text_top(48, 10, esc(title), 16, title_color or acc))
            if sub:
                self.p.append(text_top(48, 32, sub, 10, css(th["muted"]), width=w - 120))
            if close:
                self.button(w - 1 - close_off - close, close_off + 1, close, close, "X", size=12)

    def add(self, s):
        self.p.append(s)

    def section(self, x, y, label, width=None, line_dy=18):
        acc = css(self.th["accent"], 1)
        self.p.append(text_top(x, y, label, 13, acc))
        w = width if width else self.w - x - 20
        self.p.append(box(x, y + line_dy, w, 1, f"background:{css(self.th['border'], .85)}"))

    def check(self, x, y, label, on, size=24, label_w=180, font=12, disabled=False, color=None):
        mark = (f'<div class="t" style="left:{px(size * 0.1)};top:{px(-size * 0.12)};font-size:{px(size * 0.9)};color:#ffd200;'
                f'text-shadow:0 0 1px #000,1px 1px 0 #6b4a00">&#10004;</div>') if on else ""
        b = size * 0.72
        o = (size - b) / 2
        alpha = ";opacity:.55" if disabled else ""
        self.p.append(box(x + o, y + o, b, b, f"border:1px solid #6d6a5d;background:#191919;border-radius:2px;overflow:visible{alpha}", mark))
        col = color or css(self.th["muted"] if disabled else self.th["text"])
        self.p.append(text(x + size + 4, y + size / 2, label, font, col, fit=label_w))

    def radio(self, x, y, label, on, size=22, label_w=150, font=12):
        dot = box(size * .32, size * .32, size * .36, size * .36, "border-radius:50%;background:#ffd200;box-shadow:0 0 3px #ffb000") if on else ""
        self.p.append(box(x + 2, y + 2, size - 4, size - 4, "border:1px solid #7a7a7a;border-radius:50%;background:#151515", dot))
        self.p.append(text(x + size + 4, y + size / 2, label, font, css(self.th["text"]), fit=label_w))

    def button(self, x, y, w, h, label, accent=False, size=12, color=None, bg=None, border=None):
        th = self.th
        bgc = bg or css(th["bgSub"])
        bd = border or (css(th["accent"]) if accent else css(th["border"]))
        col = color or (css(th["accent"]) if accent else css(th["text"]))
        self.p.append(box(x, y, w, h, f"background:{bgc};border:1px solid {bd};display:flex;align-items:center;justify-content:center",
                          f'<span class="fit" data-fit="{(w - 10) * S:.1f}" data-min="{size * .7 * S:.1f}" '
                          f'style="font-size:{px(size)};color:{col};{SHADOW}">{label}</span>'))

    def stepper(self, x, y, label, value, minus_dx, plus_dx, bw=25, bh=25, label_dy=6, label_w=84, value_color=None, font=12):
        self.p.append(text_top(x, y + label_dy, f'<span class="fit" data-fit="{label_w * S:.1f}" data-min="{9 * S:.1f}">{label}</span>',
                               font, css(self.th["text"])))
        self.button(x + minus_dx, y, bw, bh, "-", size=14)
        self.button(x + plus_dx, y, bw, bh, "+", size=14)
        cx = x + minus_dx + bw / 2 + (plus_dx - minus_dx) / 2
        self.p.append(text(cx, y + bh / 2, value, font, value_color or css(self.th["text"]), anchor="center"))

    def html(self, ox, oy, extra_style=""):
        th = self.th
        return (f'<div class="abs" style="left:{ox}px;top:{oy}px;width:{px(self.w)};height:{px(self.h)};background:{css(th["bg"])};'
                f'border:1px solid {css(th["border"])};box-shadow:0 10px 40px rgba(0,0,0,.45);{extra_style}">' + "".join(self.p) + "</div>")


def tooltip(x, y, lines, border="#344c5b", width=None, pad=10, bg="rgba(18,24,31,.95)", gloss=True, bar=None, font=12,
            title_size=14, left_pad=0, z=30, extra=""):
    """A tooltip card at page px (x, y). lines: list of str | (left, right) | ("gap",); first line is the title.
    Strings are already HTML. bar: (fraction, colour, label) drawn along the bottom."""
    rows = []
    for i, ln in enumerate(lines):
        fs = title_size if i == 0 else font
        if ln == ("gap",):
            rows.append(f'<div style="height:{px(font * .7)}"></div>')
        elif isinstance(ln, tuple):
            rows.append(f'<div class="row" style="font-size:{px(fs)};line-height:1.42"><span>{ln[0]}</span><span>{ln[1]}</span></div>')
        else:
            rows.append(f'<div style="font-size:{px(fs)};line-height:1.42;white-space:nowrap">{ln}</div>')
    w = f"width:{px(width)};" if width else ""
    glo = (f'<div class="abs" style="left:0;right:0;top:0;height:{px(26)};background:linear-gradient(to bottom,rgba(255,255,255,.07),'
           f'rgba(255,255,255,0))"></div>') if gloss else ""
    bar_h = ""
    bottom_pad = pad
    if bar:
        frac, col, label = bar
        bottom_pad = pad + 10
        bar_h = (f'<div class="abs" style="left:{px(1)};right:{px(1)};bottom:{px(1)};height:{px(8)};background:rgba(0,0,0,.6)">'
                 f'<div class="abs" style="left:0;top:0;bottom:0;width:{frac * 100:.1f}%;background:{col}"></div>'
                 f'<div class="abs" style="inset:0;display:flex;align-items:center;justify-content:center;font-size:{px(7.5)};color:#fff;{OUTLINE}">{label}</div></div>')
    return (f'<div class="tip" style="left:{x:.0f}px;top:{y:.0f}px;{w}background:{bg};border:1px solid {border};'
            f'padding:{px(pad)} {px(pad)} {px(bottom_pad)} {px(pad + left_pad)};{SHADOW}z-index:{z};{extra}">'
            f'{glo}{"".join(rows)}{bar_h}</div>')


def callouts(points):
    return "".join(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>' for i, (x, y) in enumerate(points, 1))


def notes_html(notes, start=1):
    return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{esc(a)}</b> — {b}</div></div>'
                   for i, (a, b) in enumerate(notes))


def notes_block(x, y, w, notes, start=1):
    return f'<div class="notes" style="left:{x:.0f}px;top:{y:.0f}px;width:{w:.0f}px">{notes_html(notes, start)}</div>'


def heading(title, lead, badge=None):
    b = f' <span class="badge">{esc(badge)}</span>' if badge else ""
    return f'<div class="page"><h1>{esc(title)}{b}</h1><div class="lead">{lead}</div></div>'


def icon_data(path):
    return "data:image/png;base64," + base64.b64encode(Path(path).read_bytes()).decode()


# simple square icon art (stands in for game icons)
ICON_ART = {
    "potion": ("#3a1418", '<path d="M40 14 H60 V34 C76 40 82 54 82 64 A32 26 0 0 1 18 64 C18 54 24 40 40 34 Z" fill="#d8323c"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "mana": ("#121e3e", '<path d="M40 14 H60 V34 C76 40 82 54 82 64 A32 26 0 0 1 18 64 C18 54 24 40 40 34 Z" fill="#3d7cf0"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "elixir": ("#14301e", '<path d="M44 12 H56 V40 L74 80 H26 L44 40 Z" fill="#5fd05a"/><rect x="40" y="8" width="20" height="8" fill="#b08860"/>'),
    "stone": ("#1c2a1c", '<path d="M50 12 L80 40 L62 86 H38 L20 40 Z" fill="#62e07a"/><path d="M50 12 L62 40 L50 86 L38 40 Z" fill="#a8f5b4"/>'),
    "helm": ("#2a2a30", '<path d="M18 64 C18 30 34 16 50 16 C66 16 82 30 82 64 L72 80 H28 Z" fill="#a8adb8"/><rect x="30" y="50" width="40" height="10" fill="#2a2a30"/>'),
    "glove": ("#2a2420", '<path d="M30 86 V44 L26 22 H36 L40 40 V16 H48 V40 V12 H56 V40 V16 H64 V44 L74 34 L80 40 L66 62 V86 Z" fill="#b58a5a"/>'),
    "ring": ("#2a2418", '<circle cx="50" cy="56" r="24" fill="none" stroke="#e8c050" stroke-width="10"/><path d="M42 26 L50 14 L58 26 L50 34 Z" fill="#6ad0ff"/>'),
    "sword": ("#202830", '<path d="M70 14 L84 16 L86 30 L44 72 L30 58 Z" fill="#cfd8e0"/><path d="M26 54 L46 74 L40 80 L20 60 Z" fill="#b08040"/><path d="M28 72 L18 82" stroke="#806030" stroke-width="8"/>'),
    "food": ("#3a2412", '<ellipse cx="50" cy="58" rx="30" ry="20" fill="#c87838"/><circle cx="64" cy="40" r="12" fill="#f0e0c0"/>'),
    "drink": ("#14283a", '<path d="M30 20 H70 L64 84 H36 Z" fill="#8fd0f0" opacity=".85"/><rect x="30" y="20" width="40" height="10" fill="#e0f4ff"/>'),
    "bandage": ("#2c2c2c", '<rect x="18" y="38" width="64" height="26" rx="12" fill="#e8e0d0" transform="rotate(-35 50 50)"/>'),
    "hearth": ("#1a2a3a", '<circle cx="50" cy="50" r="26" fill="#7fd0ff"/><circle cx="50" cy="50" r="12" fill="#e0f6ff"/>'),
    "pet": ("#2a2018", '<ellipse cx="50" cy="62" rx="26" ry="18" fill="#d8a060"/><circle cx="66" cy="38" r="14" fill="#d8a060"/><path d="M60 26 L62 14 L70 24 Z M72 28 L80 18 L80 32 Z" fill="#a06a30"/><circle cx="70" cy="38" r="3" fill="#201008"/>'),
    "pick": ("#2a2a2a", '<path d="M20 30 C40 14 64 14 82 30 L76 36 C62 26 42 26 26 36 Z" fill="#bcc4cc"/><rect x="46" y="28" width="8" height="58" fill="#8a6030"/>'),
    "herb": ("#1c3018", '<path d="M50 86 V40" stroke="#5a9040" stroke-width="6"/><ellipse cx="36" cy="44" rx="14" ry="8" fill="#70c050" transform="rotate(-30 36 44)"/><ellipse cx="64" cy="40" rx="14" ry="8" fill="#70c050" transform="rotate(30 64 40)"/><circle cx="50" cy="28" r="10" fill="#e070d0"/>'),
    "fire": ("#3a1a0a", '<path d="M50 12 C62 34 80 44 70 70 A22 22 0 0 1 30 70 C22 50 40 40 42 26 C48 36 50 30 50 12 Z" fill="#ff8a2a"/><path d="M50 46 C58 58 62 64 56 76 A10 10 0 0 1 42 74 C40 64 48 58 50 46 Z" fill="#ffe070"/>'),
    "holy": ("#3a3010", '<circle cx="50" cy="50" r="20" fill="#ffe680"/><path d="M50 10 V30 M50 70 V90 M10 50 H30 M70 50 H90 M22 22 L36 36 M64 64 L78 78 M22 78 L36 64 M64 36 L78 22" stroke="#ffe680" stroke-width="6"/>'),
    "shield": ("#1e2836", '<path d="M50 10 L84 22 C84 56 72 78 50 90 C28 78 16 56 16 22 Z" fill="#7aa4d8"/><path d="M50 22 L72 30 C72 54 64 70 50 78 Z" fill="#b8d4f4"/>'),
    "shadow": ("#1e1430", '<circle cx="50" cy="50" r="28" fill="#8a5ad8"/><circle cx="50" cy="50" r="14" fill="#2a1840"/>'),
    "frost": ("#14283a", '<path d="M50 12 V88 M17 31 L83 69 M17 69 L83 31" stroke="#bfe6ff" stroke-width="9" stroke-linecap="round"/>'),
    "nature": ("#203a1c", '<path d="M50 84 C20 70 18 36 50 14 C82 36 80 70 50 84 Z" fill="#7cd060"/><path d="M50 84 V30" stroke="#2a5a1c" stroke-width="5"/>'),
    "arcane": ("#2a1840", '<path d="M50 14 L58 42 L86 50 L58 58 L50 86 L42 58 L14 50 L42 42 Z" fill="#d79cff"/>'),
    "claw": ("#3a1414", '<path d="M25 80 L45 20 M45 82 L62 22 M65 84 L80 28" stroke="#ff6a5a" stroke-width="9" stroke-linecap="round"/>'),
    "bear": ("#2e2014", '<circle cx="50" cy="56" r="26" fill="#8a5a30"/><circle cx="30" cy="30" r="10" fill="#8a5a30"/><circle cx="70" cy="30" r="10" fill="#8a5a30"/><circle cx="42" cy="52" r="4" fill="#1a0a00"/><circle cx="58" cy="52" r="4" fill="#1a0a00"/>'),
    "cat": ("#3a2a1a", '<path d="M24 82 L24 34 L36 18 L44 34 L56 34 L64 18 L76 34 L76 82 Z" fill="#c9965a"/><circle cx="40" cy="50" r="5" fill="#2a1a0a"/><circle cx="60" cy="50" r="5" fill="#2a1a0a"/>'),
    "heal": ("#14301e", '<rect x="40" y="18" width="20" height="64" fill="#8cf08c"/><rect x="18" y="40" width="64" height="20" fill="#8cf08c"/>'),
    "book": ("#2a1e14", '<rect x="20" y="16" width="60" height="70" rx="4" fill="#8a4a2a"/><rect x="28" y="16" width="6" height="70" fill="#5a2a14"/><rect x="40" y="30" width="30" height="6" fill="#e8c890"/>'),
    "scroll": ("#2e2616", '<rect x="24" y="22" width="52" height="56" fill="#e8d8a8"/><rect x="18" y="16" width="64" height="10" rx="5" fill="#b89860"/><rect x="18" y="74" width="64" height="10" rx="5" fill="#b89860"/><path d="M34 40 H66 M34 52 H66 M34 64 H56" stroke="#8a6a3a" stroke-width="4"/>'),
    "flask": ("#2a1a3a", '<circle cx="50" cy="60" r="24" fill="#b070f0"/><rect x="42" y="14" width="16" height="26" fill="#b070f0"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "thread": ("#1a2840", '<rect x="34" y="16" width="32" height="68" rx="6" fill="#d8b070"/><rect x="30" y="30" width="40" height="40" fill="#3a78d8"/>'),
    "hammer": ("#2a2a2a", '<rect x="22" y="18" width="56" height="22" rx="3" fill="#a0a8b0"/><rect x="45" y="40" width="10" height="46" fill="#8a6030"/>'),
    "fish": ("#10304a", '<path d="M14 50 C30 26 62 26 74 50 C62 74 30 74 14 50 Z" fill="#7fb8e0"/><path d="M74 50 L90 34 V66 Z" fill="#7fb8e0"/><circle cx="30" cy="46" r="4" fill="#0a1a2a"/>'),
    "gear": ("#26303a", '<circle cx="50" cy="50" r="22" fill="none" stroke="#c0c8d0" stroke-width="12" stroke-dasharray="9 6"/><circle cx="50" cy="50" r="10" fill="#c0c8d0"/>'),
    "bolt": ("#24204a", '<path d="M56 10 L26 56 H48 L40 90 L76 40 H54 Z" fill="#ffe14a"/>'),
    "chest": ("#2a1e10", '<rect x="18" y="38" width="64" height="42" fill="#9a6a30"/><path d="M18 38 C18 18 82 18 82 38 Z" fill="#b8843c"/><rect x="44" y="44" width="12" height="14" fill="#e8c050"/>'),
    "arrow": ("#2a2418", '<path d="M18 82 L72 28" stroke="#c8a870" stroke-width="7"/><path d="M64 20 L84 16 L80 36 Z" fill="#c0c8d0"/><path d="M18 82 L26 66 M18 82 L34 74" stroke="#e8e0d0" stroke-width="5"/>'),
    "kick": ("#2e1c14", '<path d="M30 20 L48 20 L54 56 L80 64 L78 80 L34 80 Z" fill="#c9965a"/>'),
    "stealth": ("#1a1a24", '<circle cx="50" cy="50" r="30" fill="#4a4a6a"/><path d="M26 50 C38 34 62 34 74 50 C62 66 38 66 26 50 Z" fill="#1a1a24"/><circle cx="50" cy="50" r="8" fill="#9aa0d0"/>'),
}


def icon_svg(kind):
    bg, shape = ICON_ART[kind]
    return (f'<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="display:block">'
            f'<defs><linearGradient id="sh_{kind}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".18"/>'
            f'<stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient></defs>'
            f'<rect width="100" height="100" fill="{bg}"/>{shape}<rect width="100" height="100" fill="url(#sh_{kind})"/></svg>')


def icon_box(x, y, size, kind, border="#000", style=""):
    return box(x, y, size, size, f"border:1px solid {border};overflow:hidden;{style}", icon_svg(kind))


# ---------------------------------------------------------------------------
# Rendering (local headless Chrome)
# ---------------------------------------------------------------------------
def find_chrome():
    cands = [os.environ.get("CHROME"), r"C:\Program Files\Google\Chrome\Application\chrome.exe",
             r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
             shutil.which("chrome"), shutil.which("google-chrome"), shutil.which("chromium")]
    for c in cands:
        if c and Path(c).exists():
            return c
    sys.exit("Chrome not found (set CHROME=<path to chrome>)")


def chrome_args(chrome, tmp):
    return [chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
            f"--user-data-dir={Path(tmp) / 'chrome_profile'}", "--virtual-time-budget=3000"]


def render(chrome, body, call, out_png, tmp):
    doc = (f'<!doctype html><html><head><meta charset="utf-8"><style>{page_css(call)}</style></head>'
           f'<body><div class="sky"></div>{HILLS}{body}{FIT_JS}</body></html>')
    page = Path(tmp) / (out_png.stem + ".html")
    page.write_text(doc, encoding="utf-8")
    # pass 1: let the page measure itself, pass 2: screenshot at that height
    dom = subprocess.run(chrome_args(chrome, tmp) + ["--window-size=1600,4000", "--dump-dom", page.as_uri()],
                         check=True, capture_output=True, timeout=120).stdout.decode("utf-8", "replace")
    m = re.search(r'data-h="(\d+)"', dom)
    height = int(m.group(1)) if m else 1200
    subprocess.run(chrome_args(chrome, tmp) + [f"--window-size={PAGE_W},{height}", f"--screenshot={out_png}", page.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    return height


def run_pages(root, pages, call):
    """pages: list of (file stem, function returning page body html)."""
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    chrome = find_chrome()
    tmp = tempfile.mkdtemp(prefix="ezwow_readme_")
    try:
        for stem, fn in pages:
            png = out / f"{stem}.png"
            h = render(chrome, fn(), call, png, tmp)
            print("wrote", png, h)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# EzWoW - Profession Recipes
# ---------------------------------------------------------------------------
TITLE = "EzWoW - Profession Recipes"


def load(root):
    init = read(root, "Core/Init.lua")
    loc = read(root, "Core/Locales.lua")
    rb = read(root, "UI/RecipeBrowser.lua")
    ow = read(root, "UI/OptionsWindow.lua")
    style = {k: rgb_list(v) for k, v in re.findall(r"(\w+)\s*=\s*\{\s*([\d.,\s]+)\}", lua_table(init, r"ns\.Style = \{"))}
    L = {"en": lua_strings(lua_table(loc, r"local L_EN = \{")), "ko": lua_strings(lua_table(loc, r"local L_KO = setmetatable\(\{"))}
    for lang, code in (("en", "en"), ("ko", "ko")):
        for k, v in re.findall(rf'^LOCALE_TABLES\.{code}\["(\w+)"\] = "((?:[^"\\]|\\.)*)"', loc, re.M):
            L[lang][k] = unlua(v)
    for k, v in L["en"].items():
        L["ko"].setdefault(k, v)
    dflt = dict(re.findall(r"(\w+) = (true|false|\"\w+\")", lua_table(loc, r"local DEFAULTS = \{")))
    rh = re.search(r"local ROW_H, NUM_ROWS = (\d+), (\d+)", rb)
    size = re.search(r"windowFrame:SetSize\((\d+), (\d+)\)", rb[rb.index("function RecipeBrowserWindow.buildProfessionBrowserWindow"):])
    osize = re.search(r"windowFrame:SetSize\((\d+), (\d+)\)", ow[ow.index("function SettingsDialog.buildSettings"):])
    saved = int(re.search(r"local LANG_ROWS_SAVED = (\d+)", ow).group(1))
    return {"th": {"bg": style["bg"], "bgSub": style["bgSub"], "border": style["border"], "text": style["text"],
                   "muted": style["muted"], "accent": style["accent"]},
            "cyan": style["cyan"], "L": L, "dflt": dflt, "ROW_H": int(rh.group(1)), "W": int(size.group(1)), "H": int(size.group(2)),
            "oW": int(osize.group(1)), "oH": int(osize.group(2)), "saved": saved,
            "icon": icon_data(find_file(root, "Icon.png"))}


T = {
    "ko": {
        "lead": "12개 전문 기술의 제조법 재료 · 숙련도 · 배우는 곳을 보여 주는 도감 (배우지 않은 기술도 열람)",
        "prof": "연금술",
        "cats": [("비약", 28, False), ("물약", 16, True), ("회복 물약", 6, True), ("재료", 5, True)],
        "rows": [("최하급 신비의 비약", 1, False), ("최하급 완력의 비약", 1, False), ("최하급 정신력의 비약", 15, True),
                 ("최하급 마법사의 피 비약", 25, True), ("최하급 성직자의 비약", 45, True), ("최하급 방어의 비약", 1, False),
                 ("최하급 힘의 비약", 55, False), ("최하급 트롤의 피 비약", 15, False), ("하급 정신력의 비약", 65, True),
                 ("최하급 민첩의 비약", 50, False), ("최하급 인내의 비약", 50, False)],
        "sel": "하급 정신력의 비약",
        "where": ["[A] 조제법 · 상인 (붉은마루 산맥 10.8, 72.5) 판매 · 상인의 호의 45",
                  "[H] 조제법 · 상인 (불모의 땅 49.8, 29.6) 판매 · 상인의 호의 45"],
        "reag": [("야생 철쭉", 2, "herb"), ("마법초 꽃잎", 1, "herb"), ("유리 약병", 1, "flask")],
        "tipReag": "마법초 꽃잎", "tipReagType": "제작 재료", "prof2": "요리",
        "tipRecipe": "조제법: 하급 정신력의 비약", "tipRecipeType": "조제법", "tipReq": "요구 사항: 연금술 (65)",
        "known": [("블루셰이드 모래바람", "PALADIN"), ("들꽃노래 은빛방패", "DRUID")],
        "notes": [
            ("전문 기술 전환 바", "12개 전문 기술 사이를 오갑니다. 기본 전문 기술 창을 열면 같은 탭이 창 옆에 붙고, 두루마리 탭은 열린 전문 기술에서 안 배운 제조법만 모아 줍니다."),
            ("검색", "한 · 영 제조법 이름, 재료, 배우는 지역, 주문/아이템 ID로 찾습니다."),
            ("필터", "포에버 신규만, 숙련 225 이하만, 다른 진영 숨기기, 모든 전문 기술에서 검색(안 배운 제조법 탭에서는 배운 것 숨기기 · 지금 배울 수 있는 것만)."),
            ("제조법 목록", "분류별로 접고 펼칩니다. 오른쪽 숫자는 필요 숙련도, * 는 포에버 신규."),
            ("상세 정보", "숙련 단계(주황 · 노랑 · 초록 · 회색), 제작 수량, 배우는 곳(진영별 상인 · 좌표 · 평판, 전문가, 퀘스트), 재료와 개수."),
            ("지도에서 찾기", "EzWoW - Map Finder로 상인 · 전문가 · 퀘스트 위치를 찾습니다. 목록이나 재료를 우클릭해도 됩니다."),
            ("재료 툴팁", "그 재료를 쓰는 제조법 수를 전문 기술별로(Shift: 이름 목록). 이 줄이 나오면 EzWoW - Tooltip은 같은 줄을 생략합니다."),
            ("제조법 아이템 툴팁", "배움 · 배울 수 있음(숙련 N 필요) · 숙련 부족과, 이미 배운 내 다른 캐릭터(이름 성, 직업 색)."),
        ],
        "foot": "애드온 코드의 창 크기 · 좌표 · 색상 · 문구로 재현한 예시 화면입니다. 캐릭터 이름은 지어낸 예시이고 아이콘은 단순화했습니다.",
        "sLead": "/ezpr config · 언어, 전문기술 창 탭 위치와 크기, 재료 툴팁, 가방 아이템 빠른 실행 키",
        "sTitle": "설정창",
        "sNotes": [
            ("언어", "상자를 눌러 목록에서 자동(게임 언어) 또는 8개 언어를 고릅니다. 게임과 다른 문자의 언어를 고르면 일부 글자가 안 보일 수 있습니다."),
            ("탭 부착 위치", "기본 전문 기술 창의 왼쪽 / 아래 / 오른쪽."),
            ("탭 아이콘 크기", "16~48 (기본 30)."),
            ("재료 툴팁", "가방 · 상점 아이템 툴팁에 사용처 개수 표시(Shift로 상세)."),
            ("빠른 실행 키", "이 키를 누른 채 가방 아이템을 좌클릭하면 마력 추출 · 자물쇠 따기 · 해골 열쇠 · 잠금 해제 두루마리 · 포에버 두루마리 해독 · 야수 먹이 주기를 바로 실행."),
            ("설정 초기화 · 후원", ""),
        ],
        "sFoot": "애드온 코드의 창 크기 · 좌표 · 색상 · 문구로 재현한 예시 화면입니다. 선택 상태는 기본값입니다.",
    },
    "en": {
        "lead": "A recipe book for all 12 professions: reagents, skill and where to learn, even for professions you do not have",
        "prof": "Alchemy",
        "cats": [("Elixir", 28, False), ("Potion", 16, True), ("Healing Potion", 6, True), ("Reagent", 5, True)],
        "rows": [("Elixir of Minor Fortitude", 1, False), ("Elixir of Lion's Strength", 1, False), ("Elixir of Minor Spirit", 15, True),
                 ("Elixir of Minor Mageblood", 25, True), ("Elixir of the Acolyte", 45, True), ("Elixir of Minor Defense", 1, False),
                 ("Elixir of Minor Strength", 55, False), ("Elixir of Minor Troll Blood", 15, False), ("Elixir of Lesser Spirit", 65, True),
                 ("Elixir of Minor Agility", 50, False), ("Elixir of Minor Endurance", 50, False)],
        "sel": "Elixir of Lesser Spirit",
        "where": ["[A] Recipe · vendor (Redridge Mountains 10.8, 72.5) · Friendly 45",
                  "[H] Recipe · vendor (The Barrens 49.8, 29.6) · Friendly 45"],
        "reag": [("Wild Azalea", 2, "herb"), ("Magebloom Petal", 1, "herb"), ("Empty Vial", 1, "flask")],
        "tipReag": "Magebloom Petal", "tipReagType": "Trade Goods", "prof2": "Cooking",
        "tipRecipe": "Recipe: Elixir of Lesser Spirit", "tipRecipeType": "Recipe", "tipReq": "Requires Alchemy (65)",
        "known": [("Blueshade Sandwind", "PALADIN"), ("Wildsong Silvershield", "DRUID")],
        "notes": [
            ("Profession bar", "Switch between the 12 professions. Opening the default profession window docks the same tabs next to it; the scroll tab lists the recipes you have not learned in the open profession."),
            ("Search", "Korean/English recipe names, reagents, zones, spell/item IDs."),
            ("Filter", "Forever new only, skill 225 or less, hide other faction, search all professions (on the not-learned tab: hide learned, learnable now only)."),
            ("Recipe list", "Fold by category. The number on the right is the required skill; * marks Forever-new recipes."),
            ("Details", "Skill colours (orange, yellow, green, grey), amount made, where to learn (vendors per faction with coordinates and reputation, trainers, quests), reagents and counts."),
            ("Find on map", "Finds vendors, trainers and quests with EzWoW - Map Finder. Right-click a recipe or reagent for the same."),
            ("Reagent tooltips", "How many recipes use the item, per profession (Shift: names). When these lines show, EzWoW - Tooltip leaves out its own."),
            ("Recipe item tooltips", "Learned / can learn (requires skill N) / skill too low, and your other characters who know it (first name and surname, class colour)."),
        ],
        "foot": "Mock-ups rebuilt from the window sizes, coordinates, colours and strings in the addon code. Character names are made up; icons are simplified.",
        "sLead": "/ezpr config · language, tab position and size, reagent tooltips, quick-action key",
        "sTitle": "Settings",
        "sNotes": [
            ("Language", "Click the box and pick Auto (game language) or one of 8 languages from the list. A language with a different script than your client may miss some characters."),
            ("Tab position", "Left / bottom / right of the default profession window."),
            ("Tab icon size", "16–48 (default 30)."),
            ("Reagent tooltips", "Recipe counts on bag and vendor item tooltips (details with Shift)."),
            ("Quick-action key", "Hold it and left-click a bag item to disenchant, pick a lock, use a skeleton key or unlocking scroll, decipher a Forever scroll or feed your pet."),
            ("Reset settings · support", ""),
        ],
        "sFoot": "Mock-up rebuilt from the window size, coordinates, colours and strings in the addon code. The selections show the defaults.",
    },
}

PROF_ICONS = ["flask", "hammer", "arcane", "gear", "bear", "thread", "pick", "fire", "bandage", "herb", "claw", "fish"]
SKILL_COL = ["#ff8040", "#ffff00", "#40bf40", "#808080"]


def skill_color(need):
    return "#ff8040" if need >= 45 else ("#ffff00" if need >= 25 else ("#40bf40" if need >= 10 else "#808080"))


def ui_page(lang, ctx):
    global S
    S = 1.12
    t, L, th = T[lang], ctx["L"][lang], ctx["th"]
    acc = css(th["accent"])
    W, H, R = ctx["W"], ctx["H"], ctx["ROW_H"]
    win = Window(th, W, H, "", header=0)
    win.add(box(1, 1, W - 2, 2, f"background:{acc}"))
    win.add(text(W / 2, 22, f'{esc(t["prof"])} <span style="color:#808080">({esc(L["notLearned"])})</span>', 12, GOLD, anchor="center"))
    win.button(W - 4 - 22, 4, 22, 22, "X")
    # left list panel (12, 62) .. bottom 28, width 300
    lh = H - 62 - 28
    win.add(box(12, 62, 300, lh, f"background:{css(th['bgSub'])};border:1px solid {css(th['border'])}"))
    win.add(text_top(14, 40, esc(L["search"]), 10, "#808080"))
    win.add(box(72, 36, 300 - 60 - 90, 22, f"background:rgba(12,17,22,.96);border:1px solid {acc}",
                f'<div class="t" style="left:{px(6)};top:50%;transform:translateY(-50%);font-size:{px(12)};color:#fff">{"비약" if lang == "ko" else "elixir"}</div>'))
    win.button(72 + 300 - 150 + 6, 36, 84, 22, esc(L["filter"]) + " (1) ▼", size=10)
    y = 62 + 6
    rx = 12 + 6
    rw = 300 - 6 - 22
    cat, n, _ = t["cats"][0]
    win.add(box(rx, y, rw, R, "background:rgba(235,168,106,.16)"))
    win.add(text(rx + 18, y + R / 2, f'{esc(cat)} <span style="color:#a7b9c5">({n})</span>', 10, acc))
    win.add(text(rx + 6, y + R / 2, "−", 10, "#fff", anchor="center"))
    y += R
    sel_y = None
    for name, need, new in t["rows"]:
        if name == t["sel"]:
            win.add(box(rx, y, rw, R, "background:rgba(235,168,106,.24)"))
            sel_y = y
        win.add(text(rx + 18, y + R / 2, esc(name) + (" *" if new else ""), 10, QUALITY[2], fit=rw - 18 - 34))
        win.add(text(rx + rw - 4, y + R / 2, str(need), 10, skill_color(need), anchor="right"))
        y += R
    for cat, n, collapsed in t["cats"][1:]:
        win.add(box(rx, y, rw, R, "background:rgba(235,168,106,.16)"))
        win.add(text(rx + 6, y + R / 2, "+", 10, "#fff", anchor="center"))
        win.add(text(rx + 18, y + R / 2, f'{esc(cat)} <span style="color:#a7b9c5">({n})</span>', 10, acc))
        y += R
    win.add(box(12 + 300 - 5 - 12, 62 + 8, 12, lh - 16, "background:rgba(18,24,31,.7)",
                box(0, 0, 12, 60, "background:#8a6a40;border-radius:3px")))
    # detail panel
    dx, dy = 12 + 300 + 8, 62
    dw, dh = W - 12 - dx, H - 28 - 62
    win.add(box(dx, dy, dw, dh, f"background:{css(th['bgSub'])};border:1px solid {css(th['border'])}"))
    win.add(icon_box(dx + 16, dy + 16, 48, "elixir", border=QUALITY[2]))
    win.button(dx + dw - 14 - 102, dy + 14, 102, 22, esc(L["findOnMap"]), size=10)
    win.add(text_top(dx + 76, dy + 18, esc(t["sel"]), 16, QUALITY[2]))
    win.add(text_top(dx + 76, dy + 42, f'<span style="color:{acc}">{esc(L["newTag"])}</span> · {esc(L["book"])}', 10, "#fff"))
    sk = " ".join(f'<span style="color:{c}">{v}</span>' for c, v in zip(SKILL_COL, (65, 70, 73, 75)))
    win.add(text_top(dx + 16, dy + 76, f'{esc(L["skill"])} {sk}', 12, "#fff"))
    win.add(text_top(dx + 16 + 160, dy + 76, esc(L["makes"].replace("%d", "1")), 12, "#fff"))
    for i, w in enumerate(t["where"]):
        col = "#4f8cff" if w.startswith("[A]") else "#ff4f4f"
        win.add(text_top(dx + 16, dy + 100 + i * 16, f'<span style="color:{col}">{esc(w[:3])}</span> {esc(w[4:])}', 10, "#fff"))
    ry = dy + 100 + 2 * 16 + 10 + 30
    win.add(text_top(dx + 16, ry, esc(L["reagents"]), 12, GOLD))
    for i, (nm, cnt, ic) in enumerate(t["reag"]):
        cx, cy = dx + 16 + (i % 2) * 245, ry + 20 + (i // 2) * 40
        win.add(icon_box(cx, cy, 34, ic))
        win.add(text(cx + 40, cy + 17, f'{esc(nm)} <span style="color:#a7b9c5">x{cnt}</span>', 10, "#fff"))
    win.add(text_top(dx + 16, dy + dh - 26, esc(L["rightClickFindReagent"]), 10, "#808080"))
    info = (esc(L["results"].replace("%d", "181", 1).replace("%d", "2232", 1)) + '   <span style="color:#ff8040">■</span> <span style="color:#ffff00">■</span> '
            '<span style="color:#40bf40">■</span> <span style="color:#808080">■</span>   ' + f'<span style="color:#a7b9c5">{esc(L["source"])}</span>')
    win.add(text(22, H - 9 - 6, info, 10, "#fff"))

    ox, oy = 110, 168
    parts = [heading(TITLE, esc(t["lead"])), win.html(ox, oy)]
    # profession switcher left of the window
    sx = ox - 8 - 32 * S - 10
    sw = "".join(icon_box(0, i * 36, 32, k, border="#555") for i, k in enumerate(PROF_ICONS))
    sw += icon_box(0, len(PROF_ICONS) * 36 + 6, 32, "gear", border="#555")
    parts.append(f'<div class="abs" style="left:{sx:.0f}px;top:{oy + 20}px">{sw}</div>')
    # filter menu (open)
    # the filter menu, opened, drawn beside the window so it does not hide the details
    fx = ox + W * S + 24
    fy = oy + 420
    keys = ["onlyNew", "cap", "hideOtherFaction", "searchAll"]
    mh = 16 + len(keys) * 24
    menu = []
    for i, k in enumerate(keys):
        on = ctx["dflt"].get(k) == "true"
        mark = f'<div class="t" style="left:{px(1)};top:{px(-4)};font-size:{px(19)};color:#ffd200">&#10004;</div>' if on else ""
        menu.append(box(8 + 3, 8 + i * 24 + 3, 16, 16, "border:1px solid #6d6a5d;background:#191919;overflow:visible", mark))
        menu.append(text(8 + 26, 8 + i * 24 + 11, esc(L[k]), 12, "#fff"))
    parts.append(f'<div class="abs" style="left:{fx:.0f}px;top:{fy:.0f}px;width:{px(220)};height:{px(mh)};background:rgba(18,24,31,.96);'
                 f'border:1px solid {css(th["border"])};z-index:40">{"".join(menu)}</div>')
    # tooltips on the right
    tx = ox + W * S + 24
    rlines = [f'<span style="color:#fff">{esc(t["tipReag"])}</span>', f'<span style="color:#66bbff">{esc(t["tipReagType"])}</span>', ("gap",),
              f'<span style="color:#66ccff">{esc(L["usedIn"])}</span>',
              f'<span style="color:#ffd100">{esc(L["usedInLine"].replace("%s", t["prof"]).replace("%d", "11"))}</span>',
              f'<span style="color:#ffd100">{esc(L["usedInLine"].replace("%s", t["prof2"]).replace("%d", "1"))}</span>',
              f'<span style="color:#808080">{esc(L["shiftForList"])}</span>']
    parts.append(tooltip(tx, oy + 10, rlines, gloss=False, bg="rgba(8,12,18,.96)", border="#5d6d7a"))
    names = ", ".join(f'<span style="color:{CLASS_HEX[c]}">{esc(n)}</span>' for n, c in t["known"])
    clines = [f'<span style="color:{QUALITY[2]}">{esc(t["tipRecipe"])}</span>', f'<span style="color:#fff">{esc(t["tipRecipeType"])}</span>',
              f'<span style="color:#fff">{esc(t["tipReq"])}</span>',
              f'<span style="color:#ffd100">{esc(L["recipeCanLearn"].replace("%d", "65"))}</span>',
              f'<span style="color:#a6bac7;white-space:normal">{esc(L["recipeKnownBy"].replace("%s", "§"))}</span>'.replace("§", names)]
    parts.append(tooltip(tx, oy + 220, clines, gloss=False, bg="rgba(8,12,18,.96)", border=QUALITY[2], width=(PAGE_W - 40 - tx) / S))
    calls = [(sx - 4, oy + 26), (ox + 72 * S - 4, oy + 36 * S - 6), (fx, fy), (ox + 300 * S, oy + 64 * S),
             (ox + dx * S - 4, oy + 150 * S), (ox + (dx + dw - 14 - 102) * S - 6, oy + 14 * S), (tx, oy + 10), (tx, oy + 220)]
    parts.append(callouts(calls))
    ny = oy + H * S + 30
    parts.append(notes_block(50, ny, 730, [(a, esc(b_)) for a, b_ in t["notes"][:4]]))
    parts.append(notes_block(820, ny, 730, [(a, esc(b_)) for a, b_ in t["notes"][4:]], start=5))
    parts.append(f'<div class="foot" style="left:50px;width:1500px">{esc(t["foot"])}</div>')
    return "".join(parts)


def settings_page(lang, ctx):
    global S
    S = 1.3
    t, L, th, d = T[lang], ctx["L"][lang], ctx["th"], ctx["dflt"]
    W, H, sv = ctx["oW"], ctx["oH"], ctx["saved"]
    win = Window(th, W, H, TITLE, esc(L["settings"]), ctx["icon"], header=56, close=22, close_off=10)
    win.section(20, 70, esc(L["language"]))
    win.button(20, 96, 240, 24, esc(L["langAuto"]) + " ▼")
    win.add(text_top(22, 124, esc(L["langNote"]), 10, css(th["muted"]), width=W - 44))
    win.section(20, 252 - sv, esc(L["tabPosLabel"]))
    for i, (k, v) in enumerate((("posLeftL", "left"), ("posBottomL", "bottom"), ("posRightL", "side"))):
        win.radio(20 + i * 132, 276 - sv, esc(L[k]), d.get("tabPos") == f'"{v}"', label_w=104)
    win.add(text_top(22, 312 - sv, esc(L["iconSizeLabel"].replace("%d", "30")), 12, css(th["text"])))
    win.button(W - 20 - 32 - 6 - 32, 308 - sv, 32, 22, "-")
    win.button(W - 20 - 32, 308 - sv, 32, 22, "+")
    win.check(18, 342 - sv, esc(L["reagentTooltip"]), d.get("reagentTooltip") == "true", label_w=360)
    win.section(20, 378 - sv, esc(L["quickActionLabel"]))
    for i, (k, v) in enumerate((("quickAlt", "ALT"), ("quickCtrl", "CTRL"), ("quickShift", "SHIFT"), ("quickOff", "OFF"))):
        win.radio(20 + (i % 2) * 190, 402 - sv + (i // 2) * 26, esc(L[k]), d.get("quickModifier") == f'"{v}"', label_w=158)
    win.button(20, H - 32 - 28, 184, 28, esc(L["resetSettings"]))
    win.button(W - 20 - 184, H - 32 - 28, 184, 28, esc(L["donate"]), accent=True, bg="rgba(59,42,24,.96)")
    win.add(f'<div class="t" style="right:{px(20)};bottom:{px(10)};font-size:{px(10)};color:{css(th["muted"])};{SHADOW}">EzWoW - Profession Recipes · /ezpr</div>')
    ox, oy = 60, 150
    spans = [(70, 150), (252 - sv, 300 - sv), (308 - sv, 330 - sv), (342 - sv, 366 - sv), (378 - sv, 456 - sv), (H - 60, H - 32)]
    calls = [(ox + W * S + 22, oy + (a + b_) / 2 * S) for a, b_ in spans]
    nx = ox + W * S + 70
    notes = [(a, esc(b_)) for a, b_ in t["sNotes"]]
    return (heading(TITLE, esc(t["sLead"]), t["sTitle"]) + win.html(ox, oy) + callouts(calls)
            + notes_block(nx, oy + 6, PAGE_W - nx - 40, notes).replace(" — </div>", "</div>")
            + f'<div class="foot" style="left:50px;width:1500px">{esc(t["sFoot"])}</div>')


def main(root: Path):
    ctx = load(root)
    call = hexc(ctx["th"]["accent"])
    run_pages(root, [(f"{n}_{lang}", (lambda n=n, lang=lang: (ui_page if n == "ui" else settings_page)(lang, ctx)))
                     for lang in ("ko", "en") for n in ("ui", "settings")], call)


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve())
