#!/usr/bin/env python3
"""Generates Glaze & Grind concept art + store/marketing graphics as SVG.

Run:  python3 tools/make_concept_art.py
Then: godot --headless --path . -s tools/svg_to_png.gd   (rasterizes every SVG to PNG)
"""
import math
import os
import random

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "concept")
MKT = os.path.join(os.path.dirname(__file__), "..", "assets", "marketing")
os.makedirs(OUT, exist_ok=True)
os.makedirs(MKT, exist_ok=True)

PINK = "#ff6f91"
PINK_D = "#e8457a"
CREAM = "#fff8ec"
INK = "#3a2a22"
BLUE = "#4f8cff"
GREEN = "#2fae6b"
YELLOW = "#ffd23f"
ORANGE = "#ff8a3d"
PURPLE = "#c45bff"
FONT = "font-family='Nunito, Poppins, Arial Rounded MT Bold, Helvetica, Arial, sans-serif'"

R = random.Random(7)


def svg(w, h, body, bg=None):
    bgr = f"<rect width='{w}' height='{h}' fill='{bg}'/>" if bg else ""
    return (f"<svg xmlns='http://www.w3.org/2000/svg' width='{w}' height='{h}' viewBox='0 0 {w} {h}'>"
            f"<defs>{DEFS}</defs>{bgr}{body}</svg>")


DEFS = f"""
<linearGradient id='sky' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#8fd3ff'/><stop offset='1' stop-color='#e6f6ff'/></linearGradient>
<linearGradient id='sunset' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#ff9a6b'/><stop offset='0.6' stop-color='#ffc79a'/><stop offset='1' stop-color='#ffe8cf'/></linearGradient>
<linearGradient id='pinkg' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#ff9fb5'/><stop offset='1' stop-color='{PINK_D}'/></linearGradient>
<linearGradient id='glass' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#d9f1ff' stop-opacity='0.9'/><stop offset='1' stop-color='#9fd8ff' stop-opacity='0.7'/></linearGradient>
<linearGradient id='steel' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#e7eef5'/><stop offset='1' stop-color='#9fb0c0'/></linearGradient>
<linearGradient id='oil' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#ffd36e'/><stop offset='1' stop-color='#c98a2f'/></linearGradient>
<radialGradient id='glow' cx='0.5' cy='0.5' r='0.5'><stop offset='0' stop-color='#fff3c4' stop-opacity='0.9'/><stop offset='1' stop-color='#fff3c4' stop-opacity='0'/></radialGradient>
<filter id='soft' x='-20%' y='-20%' width='140%' height='140%'><feDropShadow dx='0' dy='6' stdDeviation='6' flood-color='#000' flood-opacity='0.18'/></filter>
"""


def text(x, y, s, size=32, fill=INK, anchor="middle", weight=800, extra=""):
    return f"<text x='{x}' y='{y}' {FONT} font-size='{size}' font-weight='{weight}' fill='{fill}' text-anchor='{anchor}' {extra}>{s}</text>"


def donut(x, y, r, icing=PINK, dough="#f0b860", sprinkles=True, rot=0):
    s = f"<g transform='translate({x},{y}) rotate({rot})'>"
    s += f"<ellipse cx='0' cy='{r*0.12}' rx='{r}' ry='{r*0.92}' fill='#c98a3c'/>"
    s += f"<circle r='{r}' fill='{dough}'/>"
    # wavy icing
    pts = []
    for i in range(36):
        a = i / 36 * math.tau
        rr = r * (0.84 + 0.05 * math.sin(a * 7))
        pts.append(f"{rr*math.cos(a):.1f},{rr*math.sin(a):.1f}")
    s += f"<polygon points='{' '.join(pts)}' fill='{icing}'/>"
    s += f"<circle r='{r*0.3}' fill='#fff8ec'/><circle r='{r*0.3}' fill='none' stroke='{dough}' stroke-width='{r*0.08}'/>"
    if sprinkles:
        cols = [BLUE, YELLOW, GREEN, "#ffffff", PURPLE, ORANGE]
        rr = random.Random(int(x * 13 + y))
        for i in range(int(r / 3)):
            a = rr.random() * math.tau
            d = r * (0.42 + rr.random() * 0.36)
            px, py = d * math.cos(a), d * math.sin(a)
            ang = rr.random() * 180
            s += (f"<rect x='{px-r*0.08:.1f}' y='{py-r*0.025:.1f}' width='{r*0.16:.1f}' height='{r*0.05:.1f}' rx='{r*0.025:.1f}'"
                  f" fill='{cols[i % len(cols)]}' transform='rotate({ang:.0f} {px:.1f} {py:.1f})'/>")
    s += f"<ellipse cx='{-r*0.35}' cy='{-r*0.45}' rx='{r*0.22}' ry='{r*0.1}' fill='#fff' opacity='0.35' transform='rotate(-30 {-r*0.35} {-r*0.45})'/>"
    return s + "</g>"


def cup(x, y, h=60, color="#5a3520", iced=False, lid=True):
    w = h * 0.7
    s = f"<g transform='translate({x},{y})'>"
    body = "#ffffff" if not iced else "#e6f6ff"
    s += f"<path d='M{-w/2},0 L{w/2},0 L{w*0.38},{h} L{-w*0.38},{h} Z' fill='{body}' stroke='#d8d0c8' stroke-width='2'/>"
    if iced:
        s += f"<path d='M{-w*0.46},{h*0.25} L{w*0.46},{h*0.25} L{w*0.38},{h} L{-w*0.38},{h} Z' fill='{color}' opacity='0.85'/>"
        for i in range(3):
            s += f"<rect x='{-w*0.3 + i*w*0.22}' y='{h*0.3 + (i%2)*8}' width='{w*0.16}' height='{w*0.16}' fill='#fff' opacity='0.7' rx='3'/>"
        s += f"<rect x='{w*0.05}' y='{-h*0.45}' width='{w*0.08}' height='{h*0.7}' fill='{PINK}' rx='3'/>"
    else:
        s += f"<rect x='{-w*0.44}' y='{h*0.35}' width='{w*0.88}' height='{h*0.25}' fill='{PINK}'/>"
        s += f"<circle cx='0' cy='{h*0.475}' r='{h*0.09}' fill='#fff'/>"
    if lid:
        s += f"<rect x='{-w*0.56}' y='{-h*0.1}' width='{w*1.12}' height='{h*0.13}' rx='4' fill='{'#ffffff' if not iced else '#f2fbff'}' stroke='#d8d0c8' stroke-width='2'/>"
    return s + "</g>"


SKIN = ["#f5d0b5", "#e8b896", "#c68e6a", "#a26c4a", "#7a4e33"]
HAIR = ["#2b1d14", "#5a3a22", "#c88a3c", "#1d1d1d", "#8a2b1d"]


def person(x, y, s=1.0, body=BLUE, skin=None, hair=None, kind="customer", accessory=None, face="smile", facing=1):
    skin = skin or SKIN[R.randrange(len(SKIN))]
    hair = hair or HAIR[R.randrange(len(HAIR))]
    g = f"<g transform='translate({x},{y}) scale({s * facing},{s})'>"
    g += "<ellipse cx='0' cy='4' rx='30' ry='9' fill='#000' opacity='0.15'/>"
    g += "<rect x='-15' y='-30' width='11' height='32' rx='5' fill='#3b3b4f'/><rect x='4' y='-30' width='11' height='32' rx='5' fill='#3b3b4f'/>"
    g += f"<rect x='-24' y='-92' width='48' height='66' rx='18' fill='{body}'/>"
    if kind == "staff":
        g += f"<rect x='-16' y='-78' width='32' height='50' rx='8' fill='{CREAM}'/>"
        g += f"<circle cx='0' cy='-60' r='6' fill='{PINK}'/>"
    g += f"<rect x='-34' y='-86' width='12' height='46' rx='6' fill='{body}'/><rect x='22' y='-86' width='12' height='46' rx='6' fill='{body}'/>"
    g += f"<circle cx='-28' cy='-38' r='7' fill='{skin}'/><circle cx='28' cy='-38' r='7' fill='{skin}'/>"
    g += f"<circle cx='0' cy='-118' r='28' fill='{skin}'/>"
    g += f"<path d='M-28,-122 Q-26,-152 0,-150 Q26,-152 28,-122 Q20,-140 0,-138 Q-20,-140 -28,-122 Z' fill='{hair}'/>"
    if kind == "staff":
        g += f"<rect x='-30' y='-148' width='60' height='14' rx='6' fill='{PINK_D}'/><rect x='14' y='-140' width='26' height='8' rx='4' fill='{PINK_D}'/>"
    g += f"<circle cx='-10' cy='-118' r='3.6' fill='#2b1d14'/><circle cx='10' cy='-118' r='3.6' fill='#2b1d14'/>"
    if face == "smile":
        g += "<path d='M-9,-104 Q0,-96 9,-104' stroke='#2b1d14' stroke-width='3' fill='none' stroke-linecap='round'/>"
    elif face == "wow":
        g += "<ellipse cx='0' cy='-101' rx='5' ry='6' fill='#2b1d14'/>"
    else:
        g += "<path d='M-8,-100 L8,-102' stroke='#2b1d14' stroke-width='3' stroke-linecap='round'/>"
    g += "<circle cx='-17' cy='-108' r='4' fill='#ff8fa3' opacity='0.5'/><circle cx='17' cy='-108' r='4' fill='#ff8fa3' opacity='0.5'/>"
    if accessory == "tie":
        g += "<path d='M0,-90 L-5,-80 L0,-50 L5,-80 Z' fill='#c0392b'/>"
        g += "<rect x='32' y='-46' width='30' height='24' rx='4' fill='#5b3a1e'/><rect x='41' y='-52' width='12' height='8' rx='3' fill='none' stroke='#5b3a1e' stroke-width='3'/>"
    elif accessory == "backpack":
        g += f"<rect x='-46' y='-88' width='20' height='44' rx='8' fill='{YELLOW}'/>"
        g += "<rect x='30' y='-60' width='16' height='22' rx='3' fill='#fff'/><rect x='30' y='-66' width='16' height='8' fill='#e0457b'/>"
    elif accessory == "camera":
        g += "<path d='M-34,-150 L34,-150 L26,-138 L-26,-138 Z' fill='#ffd23f'/><rect x='-24' y='-170' width='48' height='22' rx='8' fill='#ffd23f'/>"
        g += "<rect x='-14' y='-74' width='28' height='18' rx='4' fill='#222'/><circle cx='0' cy='-65' r='6' fill='#555'/>"
    elif accessory == "phone":
        g += "<rect x='30' y='-112' width='18' height='30' rx='4' fill='#222'/><rect x='33' y='-108' width='12' height='22' fill='#7ad3ff'/>"
        g += f"<path d='M-30,-130 Q-34,-160 0,-156 Q34,-160 30,-118 Q36,-90 26,-80' stroke='#ff5fa2' stroke-width='10' fill='none' stroke-linecap='round'/>"
    elif accessory == "beret":
        g += "<ellipse cx='0' cy='-146' rx='30' ry='12' fill='#1d1d1d'/><circle cx='0' cy='-158' r='4' fill='#1d1d1d'/>"
        g += f"<rect x='-20' y='-122' width='40' height='6' rx='3' fill='{YELLOW}' opacity='0.8'/>"
        g += "<rect x='30' y='-64' width='24' height='30' rx='3' fill='#f5f0e1'/><line x1='35' y1='-56' x2='49' y2='-56' stroke='#999' stroke-width='2'/><line x1='35' y1='-48' x2='49' y2='-48' stroke='#999' stroke-width='2'/>"
    return g + "</g>"


def station_mixer(x, y, s=1.0):
    return (f"<g transform='translate({x},{y}) scale({s})' filter='url(#soft)'>"
            "<rect x='-90' y='-40' width='180' height='110' rx='14' fill='#b9c6d3'/><rect x='-90' y='-40' width='180' height='40' rx='14' fill='#e7eef5'/>"
            "<rect x='-30' y='-170' width='60' height='130' rx='16' fill='url(#steel)'/><rect x='-70' y='-170' width='120' height='34' rx='14' fill='#c9d4de'/>"
            "<ellipse cx='0' cy='-34' rx='56' ry='22' fill='#9fb0c0'/><ellipse cx='0' cy='-38' rx='46' ry='16' fill='#f3dcb0'/>"
            "<path d='M-10,-136 L0,-46 L10,-136' stroke='#5c6b7a' stroke-width='6' fill='none'/></g>")


def station_fryer(x, y, s=1.0, frying=True):
    g = f"<g transform='translate({x},{y}) scale({s})' filter='url(#soft)'>"
    g += "<rect x='-130' y='-40' width='260' height='120' rx='14' fill='#8f979f'/><rect x='-130' y='-40' width='260' height='30' rx='14' fill='#c7ccd1'/>"
    g += "<rect x='-110' y='-30' width='220' height='70' rx='8' fill='#3a3a3a'/><rect x='-102' y='-24' width='204' height='58' rx='6' fill='url(#oil)'/>"
    if frying:
        for i in range(6):
            g += donut(-72 + (i % 3) * 72, -8 + (i // 3) * 28, 17, icing="#e8a94f", sprinkles=False)
        for i in range(10):
            g += f"<circle cx='{-95 + i*20}' cy='{20 - (i%3)*12}' r='3' fill='#fff8d0' opacity='0.7'/>"
    g += "<rect x='-120' y='50' width='40' height='14' rx='4' fill='#e5383b'/><circle cx='100' cy='57' r='9' fill='#2fae6b'/></g>"
    return g


def station_glaze(x, y, s=1.0):
    g = f"<g transform='translate({x},{y}) scale({s})' filter='url(#soft)'>"
    g += "<rect x='-120' y='-30' width='240' height='100' rx='14' fill='#e8c9a0'/><rect x='-120' y='-30' width='240' height='36' rx='14' fill='#fff4e6'/>"
    g += "<rect x='-104' y='-24' width='208' height='26' rx='6' fill='#d9d9d9'/>"
    cols = ["#fff3d6", "#6b3a22", "#ff8fb4", "#b8732f", "#fff3d6", "#ff8fb4"]
    for i in range(6):
        g += donut(-86 + i * 34.5, -12, 14, icing=cols[i], sprinkles=cols[i] == "#ff8fb4")
    for i, c in enumerate(["#6b3a22", "#ff8fb4", "#fff3d6", "#b8732f"]):
        g += f"<ellipse cx='{-80 + i*52}' cy='42' rx='22' ry='12' fill='#ccc'/><ellipse cx='{-80 + i*52}' cy='40' rx='18' ry='8' fill='{c}'/>"
    return g + "</g>"


def espresso_machine(x, y, s=1.0, level=1):
    color = {1: "#c0392b", 2: "#2c3e50", 3: "#c9a227"}[level]
    g = f"<g transform='translate({x},{y}) scale({s})' filter='url(#soft)'>"
    g += f"<rect x='-110' y='-170' width='220' height='170' rx='22' fill='{color}'/>"
    g += "<rect x='-96' y='-156' width='192' height='36' rx='10' fill='#ecf0f1'/>"
    if level >= 2:
        g += "<rect x='-86' y='-150' width='70' height='24' rx='5' fill='#7ad3ff'/>"
        g += text(-51, -132, "SHOT", 14, "#1d4f73")
    for i in range(level):
        g += f"<circle cx='{60 - i*28}' cy='-138' r='9' fill='{YELLOW}'/>"
    groups = 1 if level == 1 else 2
    for k in range(groups):
        gx = 0 if groups == 1 else (-48 + k * 96)
        g += f"<rect x='{gx-26}' y='-96' width='52' height='22' rx='6' fill='#bdc3c7'/><rect x='{gx-6}' y='-74' width='12' height='18' fill='#7f8c8d'/>"
        g += cup(gx, -46, 40, lid=False)
    g += "<rect x='-120' y='0' width='240' height='18' rx='6' fill='#7f8c8d'/>"
    if level == 3:
        g += "<path d='M90,-170 Q120,-230 80,-260 Q60,-220 90,-170' fill='#fff' opacity='0.6'/>"
    g += "<path d='M-20,-176 Q-30,-210 -10,-240 M10,-176 Q0,-215 22,-245' stroke='#fff' stroke-width='6' opacity='0.5' fill='none' stroke-linecap='round'/>"
    return g + "</g>"


def awning(x, y, w, stripes=10, h=60):
    g = ""
    sw = w / stripes
    for i in range(stripes):
        c = PINK if i % 2 == 0 else "#ffffff"
        g += f"<path d='M{x + i*sw},{y} L{x + (i+1)*sw},{y} L{x + (i+1)*sw},{y+h} Q{x + (i+0.5)*sw},{y+h+22} {x + i*sw},{y+h} Z' fill='{c}'/>"
    g += f"<rect x='{x-10}' y='{y-12}' width='{w+20}' height='16' rx='8' fill='{PINK_D}'/>"
    return g


def frame_label(w, title, sub):
    return (f"<rect x='0' y='0' width='{w}' height='70' fill='{INK}' opacity='0.85'/>"
            + text(36, 46, title, 32, "#fff", "start")
            + text(w - 36, 44, sub, 18, "#ffd6e0", "end", 600))


# ---------------------------------------------------------------- scenes

def store_exterior():
    W, H = 1600, 900
    b = "<rect width='1600' height='900' fill='url(#sky)'/>"
    b += "<circle cx='1380' cy='140' r='70' fill='#fff3b0'/><circle cx='1380' cy='140' r='110' fill='url(#glow)'/>"
    for cx, cy, s in [(220, 150, 1.0), (600, 110, 0.7), (1100, 180, 0.85)]:
        b += f"<g transform='translate({cx},{cy}) scale({s})' fill='#fff' opacity='0.95'><circle r='40'/><circle cx='45' cy='10' r='32'/><circle cx='-45' cy='12' r='30'/><rect x='-75' y='10' width='150' height='34' rx='17'/></g>"
    # neighbours
    b += "<rect x='0' y='300' width='300' height='460' fill='#b8d8c8'/><rect x='1300' y='280' width='300' height='480' fill='#f2d4a8'/>"
    for i in range(3):
        for j in range(4):
            b += f"<rect x='{30 + i*90}' y='{340 + j*95}' width='60' height='60' rx='6' fill='#e6f6ff' opacity='0.8'/>"
            b += f"<rect x='{1330 + i*90}' y='{320 + j*100}' width='60' height='64' rx='6' fill='#e6f6ff' opacity='0.8'/>"
    # building
    b += "<rect x='300' y='250' width='1000' height='510' fill='#ffe3c2'/><rect x='300' y='230' width='1000' height='30' fill='#f2c99a'/>"
    # sign
    b += "<g filter='url(#soft)'><rect x='520' y='150' width='560' height='110' rx='55' fill='url(#pinkg)'/>"
    b += donut(575, 205, 44, icing="#fff3d6")
    b += text(850, 224, "GLAZE &amp; GRIND", 58, "#fff") + "</g>"
    b += awning(330, 380, 940, 14, 56)
    # windows
    for wx in [360, 960]:
        b += f"<rect x='{wx}' y='470' width='280' height='220' rx='12' fill='url(#glass)' stroke='#fff' stroke-width='10'/>"
    b += person(430, 680, 0.7, BLUE, accessory="backpack") + person(560, 680, 0.7, "#2fae6b")
    b += person(1040, 680, 0.7, "#3b4a63", accessory="tie", facing=-1) + person(1170, 680, 0.7, PINK, kind="staff")
    b += donut(470, 520, 26) + donut(530, 530, 22, icing="#6b3a22") + donut(1080, 520, 24, icing="#fff3d6")
    # door
    b += "<rect x='700' y='450' width='200' height='310' rx='14' fill='#8a5a36'/><rect x='716' y='466' width='168' height='200' rx='10' fill='url(#glass)'/>"
    b += "<circle cx='870' cy='620' r='8' fill='#ffd23f'/>" + text(800, 560, "OPEN", 34, PINK_D)
    # sidewalk + street
    b += "<rect x='0' y='760' width='1600' height='50' fill='#d9d2c8'/><rect x='0' y='810' width='1600' height='90' fill='#4a4a52'/>"
    for i in range(10):
        b += f"<rect x='{i*170 + 20}' y='850' width='90' height='10' rx='5' fill='#fff' opacity='0.8'/>"
    # a-frame chalkboard
    b += "<g transform='translate(1230,760)'><path d='M-50,0 L-30,-130 L30,-130 L50,0' fill='#3a2a22'/><rect x='-36' y='-120' width='72' height='100' fill='#2d3b2f'/>"
    b += text(0, -88, "TODAY", 16, "#fff") + text(0, -62, "Maple", 15, YELLOW) + text(0, -40, "Bar $2.29", 15, "#fff") + "</g>"
    # planters + trees
    for tx in [240, 1360]:
        b += f"<rect x='{tx-30}' y='720' width='60' height='40' rx='6' fill='#c98a5a'/><rect x='{tx-6}' y='600' width='12' height='120' fill='#8a5a36'/><circle cx='{tx}' cy='590' r='60' fill='#4caf6d'/><circle cx='{tx+30}' cy='560' r='40' fill='#5cc27e'/>"
    # scooter / car
    b += "<g transform='translate(140,840)'><rect x='0' y='-40' width='200' height='50' rx='20' fill='#4f8cff'/><rect x='30' y='-80' width='120' height='50' rx='18' fill='#7ab0ff'/><rect x='45' y='-72' width='40' height='32' rx='6' fill='#e6f6ff'/><rect x='95' y='-72' width='42' height='32' rx='6' fill='#e6f6ff'/><circle cx='45' cy='12' r='20' fill='#222'/><circle cx='155' cy='12' r='20' fill='#222'/></g>"
    b += frame_label(W, "Store Exterior", "Concept art · Main Street")
    return svg(W, H, b)


def store_interior():
    W, H = 1600, 900
    b = "<rect width='1600' height='900' fill='#ffe9d6'/>"
    b += "<rect y='0' width='1600' height='330' fill='#fff3e4'/>"
    # menu boards
    for i, (t, items) in enumerate([("DONUTS", ["Classic Glazed  1.79", "Chocolate  1.99", "Sprinkle  2.09", "Maple Bar  2.29"]),
                                    ("COFFEE", ["Hot Coffee  2.49", "Espresso  2.99", "Latte  4.29", "Cappuccino  4.19"]),
                                    ("COLD", ["Iced Coffee  3.49", "Refresher  3.79", "Frozen  4.99", "Tea  2.29"])]):
        x = 260 + i * 380
        b += f"<rect x='{x}' y='90' width='340' height='200' rx='14' fill='#2d3b2f' filter='url(#soft)'/>"
        b += text(x + 170, 130, t, 28, YELLOW)
        for j, it in enumerate(items):
            b += text(x + 24, 168 + j * 30, it, 19, "#fff", "start", 600)
    b += "<rect x='0' y='330' width='1600' height='14' fill='#e2a878'/>"
    # back stations
    b += espresso_machine(330, 520, 0.7, 2) + station_fryer(800, 520, 0.7) + station_glaze(1210, 520, 0.7)
    # staff
    b += person(560, 600, 0.75, PINK, kind="staff") + person(980, 600, 0.75, PINK, kind="staff", face="wow")
    # counter
    b += "<rect x='0' y='600' width='1600' height='150' fill='#c98a5a'/><rect x='0' y='600' width='1600' height='22' fill='#e2a878'/>"
    # display case
    b += "<rect x='560' y='560' width='480' height='170' rx='16' fill='url(#glass)' stroke='#fff' stroke-width='8' filter='url(#soft)'/>"
    cols = ["#fff3d6", "#6b3a22", PINK, "#b8732f"]
    for row in range(3):
        for i in range(8):
            b += donut(605 + i * 55, 600 + row * 44, 19, icing=cols[(i + row) % 4], sprinkles=(i + row) % 4 == 2)
    # register + pickup
    b += "<rect x='200' y='540' width='170' height='80' rx='12' fill='#ff6f91'/><rect x='230' y='490' width='110' height='70' rx='8' fill='#2c3e50'/><rect x='238' y='498' width='94' height='54' rx='4' fill='#7ad3ff'/>"
    b += "<rect x='1200' y='560' width='240' height='60' rx='12' fill='#ffb347'/>" + text(1320, 600, "PICKUP", 28, "#8a4b14")
    b += cup(1260, 530, 60) + cup(1330, 530, 60, "#e0457b", iced=True)
    # customers
    b += person(240, 860, 0.8, "#3b4a63", accessory="tie") + person(390, 880, 0.8, BLUE, accessory="backpack")
    b += person(860, 870, 0.8, "#2fae6b") + person(1300, 870, 0.8, PURPLE, accessory="phone", face="wow")
    # lights
    for lx in [300, 800, 1300]:
        b += f"<line x1='{lx}' y1='0' x2='{lx}' y2='40' stroke='#3a2a22' stroke-width='4'/><path d='M{lx-40},70 Q{lx},20 {lx+40},70 Z' fill='{YELLOW}'/><circle cx='{lx}' cy='90' r='90' fill='url(#glow)'/>"
    b += frame_label(W, "Store Interior", "Concept art · counter, case &amp; menu boards")
    return svg(W, H, b)


def workstation():
    W, H = 1600, 900
    b = "<rect width='1600' height='900' fill='#f4f6f8'/>"
    for x in range(0, 1600, 80):
        for y in range(0, 600, 80):
            if (x // 80 + y // 80) % 2 == 0:
                b += f"<rect x='{x}' y='{y}' width='80' height='80' fill='#e6eaee'/>"
    b += "<rect x='0' y='600' width='1600' height='300' fill='#7b5b45'/><rect x='0' y='600' width='1600' height='40' fill='#e9e2da'/>"
    b += espresso_machine(560, 620, 1.3, 2)
    # grinder
    b += "<g transform='translate(920,620)' filter='url(#soft)'><rect x='-50' y='-230' width='100' height='230' rx='18' fill='#34495e'/><path d='M-60,-230 L60,-230 L40,-320 L-40,-320 Z' fill='#d8b48a' opacity='0.9'/>"
    for i in range(14):
        b += f"<ellipse cx='{-25 + (i%5)*12}' cy='{-250 - (i//5)*20}' rx='6' ry='4' fill='#5a3520'/>"
    b += "</g>"
    # milk pitcher + steam
    b += "<g transform='translate(1120,610)'><path d='M-40,-120 L40,-120 L50,0 L-50,0 Z' fill='url(#steel)'/><path d='M40,-110 Q80,-90 46,-50' stroke='#9fb0c0' stroke-width='10' fill='none'/>"
    b += "<path d='M-10,-130 Q-30,-170 -5,-200 Q15,-230 -5,-260 M15,-130 Q0,-175 25,-205' stroke='#fff' stroke-width='10' fill='none' opacity='0.8' stroke-linecap='round'/></g>"
    # barista
    b += person(260, 640, 1.3, PINK, kind="staff")
    b += cup(1350, 600, 90, "#c99a6b")
    b += "<g transform='translate(1350,450)'><circle r='60' fill='#fff' filter='url(#soft)'/>" + text(0, -6, "LATTE", 22, PINK_D) + text(0, 22, "#12", 22, INK) + "</g>"
    # progress ring callout
    b += "<g transform='translate(260,300)'><circle r='44' fill='none' stroke='#ddd' stroke-width='10'/><path d='M0,-44 A44,44 0 1,1 -38,22' fill='none' stroke='#2fae6b' stroke-width='10' stroke-linecap='round'/>" + text(0, 10, "68%", 24, INK) + "</g>"
    b += frame_label(W, "Employee Workstation", "Concept art · coffee bar with grinder &amp; steam wand")
    return svg(W, H, b)


def production_line():
    W, H = 1800, 800
    b = "<rect width='1800' height='800' fill='#fff3e4'/>"
    b += "<rect x='0' y='560' width='1800' height='240' fill='#e6eaee'/>"
    steps = [("1 · MIX &amp; KNEAD", station_mixer, 210), ("2 · CUT &amp; FRY", station_fryer, 640), ("3 · ICE &amp; TOP", station_glaze, 1080)]
    for label, fn, x in steps:
        b += fn(x, 520, 1.0)
        b += f"<rect x='{x-130}' y='630' width='260' height='54' rx='27' fill='{PINK}'/>" + text(x, 667, label, 24, "#fff")
    # arrows
    for x in [400, 860, 1290]:
        b += f"<path d='M{x},420 L{x+70},420' stroke='{INK}' stroke-width='10' stroke-linecap='round'/><path d='M{x+70},400 L{x+100},420 L{x+70},440 Z' fill='{INK}'/>"
    # case
    b += "<g transform='translate(1560,520)' filter='url(#soft)'><rect x='-150' y='-200' width='300' height='240' rx='18' fill='url(#glass)' stroke='#fff' stroke-width='8'/>"
    cols = ["#fff3d6", "#6b3a22", PINK, "#b8732f"]
    for r_ in range(4):
        for i in range(5):
            b += donut(-110 + i * 55, -160 + r_ * 52, 21, icing=cols[r_], sprinkles=r_ == 2)
    b += "</g>"
    b += f"<rect x='1430' y='630' width='260' height='54' rx='27' fill='{PINK}'/>" + text(1560, 667, "4 · DISPLAY CASE", 24, "#fff")
    # timing bar callout
    b += "<g transform='translate(470,120)'><rect x='0' y='0' width='340' height='40' rx='8' fill='#f3d08a'/><rect x='170' y='0' width='70' height='40' fill='#2fae6b'/><rect x='240' y='0' width='100' height='40' fill='#b8732f'/><rect x='326' y='0' width='14' height='40' fill='#e5383b'/>"
    b += "<rect x='205' y='-10' width='8' height='60' fill='#fff' stroke='#000' stroke-width='2'/>" + text(170, -22, "Pull in the green = PERFECT", 22, INK) + "</g>"
    b += text(900, 760, "Batches of 6 · fry timing sets quality · par levels keep the case full", 26, "#8a7568", weight=700)
    b += frame_label(W, "Donut Production Line", "Concept art · mix → fry → glaze → case")
    return svg(W, H, b)


def coffee_machines():
    W, H = 1600, 800
    b = "<rect width='1600' height='800' fill='#f0e6dc'/><rect y='560' width='1600' height='240' fill='#7b5b45'/><rect y='560' width='1600' height='30' fill='#e9e2da'/>"
    for i, (lv, name, stat) in enumerate([(1, "Starter Espresso", "×1.00 speed"), (2, "Pro Twin-Group", "×1.55 speed · +8% quality"), (3, "Golden Barista X", "×1.90 speed · +12% quality")]):
        x = 300 + i * 500
        b += espresso_machine(x, 560, 1.15, lv)
        b += f"<rect x='{x-170}' y='620' width='340' height='120' rx='18' fill='#fff' filter='url(#soft)'/>"
        b += text(x, 665, f"Level {lv}", 22, PINK_D) + text(x, 700, name, 28, INK) + text(x, 728, stat, 18, "#8a7568", weight=600)
    b += frame_label(W, "Coffee Machines", "Concept art · equipment upgrade tiers")
    return svg(W, H, b)


def upgrade_shop():
    W, H = 1600, 900
    b = "<rect width='1600' height='900' fill='#ffe9d6'/>"
    b += donut(80, 120, 32) + text(130, 136, "Main Street · Day 12", 40, INK, "start") + text(1540, 136, "$4,812.40", 40, GREEN, "end")
    tabs = ["Restock", "Staff", "Upgrades", "Menu", "Stores", "Career"]
    for i, t in enumerate(tabs):
        sel = t == "Upgrades"
        b += f"<rect x='{50 + i*170}' y='180' width='160' height='52' rx='12' fill='{CREAM if sel else '#f2e3d3'}'/>"
        if sel:
            b += f"<rect x='{50 + i*170}' y='226' width='160' height='6' fill='{PINK}'/>"
        b += text(130 + i * 170, 214, t, 22, PINK_D if sel else "#8a7568")
    cards = [("Fryer", "Level 2 / 4", "Speed ×1.25 · Quality +3%", "Upgrade  $1,200.00", True, lambda x, y: station_fryer(x, y, 0.36)),
             ("Espresso Machine", "Level 3 / 4", "Speed ×1.55 · Quality +8%", "Upgrade  $3,800.00", False, lambda x, y: espresso_machine(x, y + 30, 0.36, 2)),
             ("Auto-Glazer", "Store improvement", "Finishes batches with no staff", "Buy  $2,500.00", True, lambda x, y: station_glaze(x, y, 0.36)),
             ("Second Register", "Store improvement", "Cuts the queue during rushes", "OWNED", None, lambda x, y: ""),
             ("Blender", "Store improvement", "Unlocks Frozen Coffee", "Buy  $700.00", True, lambda x, y: ""),
             ("Comfy Break Room", "Store improvement", "Staff recover 2× faster", "Buy  $600.00", True, lambda x, y: "")]
    for i, (name, lvl, desc, btn, ok, art) in enumerate(cards):
        x, y = 50 + (i % 2) * 760, 270 + (i // 2) * 200
        b += f"<rect x='{x}' y='{y}' width='740' height='180' rx='18' fill='#fff' filter='url(#soft)'/>"
        b += f"<rect x='{x+20}' y='{y+20}' width='140' height='140' rx='14' fill='#fff3e4'/>" + art(x + 90, y + 110)
        if art(0, 0) == "":
            b += donut(x + 90, y + 90, 40, icing=[PINK, "#6b3a22", "#fff3d6"][i % 3])
        b += text(x + 190, y + 66, name, 30, INK, "start") + text(x + 190, y + 100, lvl, 20, PINK_D, "start", 700)
        b += text(x + 190, y + 134, desc, 20, "#8a7568", "start", 600)
        col = GREEN if ok else ("#d9cfc7" if ok is False else "#ffffff")
        if ok is None:
            b += text(x + 650, y + 100, "OWNED", 26, GREEN)
        else:
            b += f"<rect x='{x+520}' y='{y+64}' width='200' height='56' rx='14' fill='{col}'/>" + text(x + 620, y + 100, btn.replace('Upgrade  ', '').replace('Buy  ', ''), 22, "#fff" if ok else "#8a7d74")
    b += frame_label(W, "Upgrade Shop", "Concept art · management phase")
    return svg(W, H, b)


def dashboard_ui():
    W, H = 1600, 900
    b = "<rect width='1600' height='900' fill='#2b2230'/>"
    b += text(60, 110, "Live Dashboard", 48, "#fff", "start")
    kpis = [("Revenue", "$412.80", GREEN), ("Customers", "58", BLUE), ("Happiness", "86%", PINK), ("Accuracy", "97%", YELLOW), ("Crew efficiency", "74%", PURPLE), ("Food waste", "$6.40", "#e5383b")]
    for i, (k, v, c) in enumerate(kpis):
        x = 60 + i * 250
        b += f"<rect x='{x}' y='150' width='230' height='120' rx='16' fill='#3a2f40'/>" + text(x + 20, 195, k, 20, "#c9b8d0", "start", 600) + text(x + 20, 248, v, 44, c, "start")

    def chart(x, y, w, h, title, vals, color, bars=False):
        s = f"<rect x='{x}' y='{y}' width='{w}' height='{h}' rx='16' fill='#3a2f40'/>" + text(x + 20, y + 40, title, 22, "#c9b8d0", "start", 700)
        px, py, pw, ph = x + 20, y + 60, w - 40, h - 80
        mx = max(vals)
        if bars:
            bw = pw / len(vals)
            for i, v in enumerate(vals):
                hh = v / mx * ph
                s += f"<rect x='{px + i*bw + 3:.1f}' y='{py + ph - hh:.1f}' width='{bw - 6:.1f}' height='{hh:.1f}' rx='4' fill='{color}'/>"
        else:
            pts = [(px + pw * i / (len(vals) - 1), py + ph - v / mx * ph) for i, v in enumerate(vals)]
            path = " ".join(f"{a:.1f},{c:.1f}" for a, c in pts)
            s += f"<polygon points='{path} {px+pw:.1f},{py+ph:.1f} {px:.1f},{py+ph:.1f}' fill='{color}' opacity='0.18'/>"
            s += f"<polyline points='{path}' fill='none' stroke='{color}' stroke-width='5' stroke-linejoin='round'/>"
            s += f"<circle cx='{pts[-1][0]:.1f}' cy='{pts[-1][1]:.1f}' r='8' fill='{color}'/>"
        return s
    rev = [0, 30, 85, 150, 190, 210, 240, 300, 320, 330, 345, 380, 400, 412]
    b += chart(60, 300, 720, 260, "Revenue today", rev, GREEN)
    b += chart(820, 300, 720, 260, "Revenue by hour", [38, 62, 55, 20, 18, 44, 40, 15, 12, 14, 30, 36, 20, 8], ORANGE, True)
    b += chart(60, 590, 470, 260, "Customer happiness", [70, 72, 65, 60, 74, 80, 82, 85, 84, 86], PINK)
    b += chart(560, 590, 470, 260, "Crew efficiency", [40, 66, 80, 85, 60, 55, 70, 75, 72, 74], PURPLE)
    b += chart(1060, 590, 480, 260, "Store rating", [3.0, 3.05, 3.1, 3.2, 3.18, 3.3, 3.4, 3.45, 3.5, 3.6], YELLOW)
    b += frame_label(W, "Dashboard UI", "Concept art · real-time stats")
    return svg(W, H, b)


def customer_types():
    W, H = 1800, 800
    b = "<rect width='1800' height='800' fill='#fff3e4'/><rect y='600' width='1800' height='200' fill='#f4d8b4'/>"
    people = [("Student", BLUE, "backpack", "Cheap &amp; iced · groups"), ("Business", "#3b4a63", "tie", "Impatient · big spender"),
              ("Family", GREEN, None, "Huge box orders"), ("Tourist", ORANGE, "camera", "Adventurous · tips well"),
              ("Influencer", PURPLE, "phone", "Can make you go viral"), ("Food Critic", "#262626", "beret", "Review counts ×5")]
    for i, (name, col, acc, desc) in enumerate(people):
        x = 160 + i * 296
        b += person(x, 560, 2.0, col, accessory=acc, face="wow" if name == "Influencer" else ("meh" if name == "Food Critic" else "smile"))
        if name == "Family":
            b += person(x + 90, 560, 1.1, YELLOW)
        b += f"<rect x='{x-130}' y='620' width='260' height='120' rx='18' fill='#fff' filter='url(#soft)'/>"
        b += text(x, 668, name, 30, INK) + text(x, 708, desc, 19, "#8a7568", weight=600)
        # mood pip
        b += f"<circle cx='{x-62}' cy='{560-330}' r='16' fill='{GREEN}'/>"
    b += frame_label(W, "Customer Types", "Concept art · six personalities")
    return svg(W, H, b)


# ---------------------------------------------------------------- marketing

def banner(w, h, name):
    b = f"<rect width='{w}' height='{h}' fill='url(#pinkg)'/>"
    rr = random.Random(3)
    cols = ["#fff3d6", "#6b3a22", "#ffb3c7", "#b8732f", "#7ad3ff"]
    for i in range(16):
        x, y = rr.random() * w, rr.random() * h
        b += f"<g opacity='0.35'>{donut(x, y, 20 + rr.random() * 40, icing=cols[i % 5], rot=rr.random()*360)}</g>"
    b += f"<rect x='{w*0.06}' y='{h*0.18}' width='{w*0.56}' height='{h*0.64}' rx='{h*0.08}' fill='#fff8ec' filter='url(#soft)'/>"
    b += text(w * 0.34, h * 0.44, "Glaze &amp; Grind", h * 0.14, PINK_D)
    b += text(w * 0.34, h * 0.57, "Donut &amp; Coffee Shop Tycoon", h * 0.055, INK, weight=700)
    b += text(w * 0.34, h * 0.70, "Run the rush · Train your crew · Build an empire", h * 0.04, "#8a7568", weight=600)
    b += donut(w * 0.80, h * 0.48, h * 0.26)
    b += cup(w * 0.69, h * 0.58, h * 0.3, "#c99a6b")
    return svg(w, h, b)


def app_icon(size):
    s = size / 256
    b = f"<rect width='{size}' height='{size}' rx='{56*s}' fill='url(#pinkg)'/>"
    b += donut(size / 2, size / 2 + 4 * s, 90 * s, icing="#fff3d6")
    return svg(size, size, b)


SCENES = {
    "store_exterior": store_exterior, "store_interior": store_interior, "employee_workstation": workstation,
    "donut_production_line": production_line, "coffee_machines": coffee_machines, "upgrade_shop": upgrade_shop,
    "dashboard_ui": dashboard_ui, "customer_types": customer_types,
}

if __name__ == "__main__":
    for name, fn in SCENES.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(fn())
    with open(os.path.join(MKT, "github_social_preview.svg"), "w") as f:
        f.write(banner(1280, 640, "social"))
    with open(os.path.join(MKT, "play_store_feature_graphic.svg"), "w") as f:
        f.write(banner(1024, 500, "feature"))
    with open(os.path.join(MKT, "steam_capsule.svg"), "w") as f:
        f.write(banner(920, 430, "capsule"))
    for sz in (512, 1024):
        with open(os.path.join(MKT, f"app_icon_{sz}.svg"), "w") as f:
            f.write(app_icon(sz))
    print("wrote", len(SCENES), "concept SVGs + marketing SVGs")
