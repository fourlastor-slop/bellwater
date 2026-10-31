"""Generate assets/gfx/tiles.png: every world tile, from texture functions.

Atlas layout (16 columns of 8x8 tiles, THEME_ROWS rows per theme):
  rows 0-7 : edge tiles, column = N/E/S/W neighbour mask, row = position variant
  row 8    : solid fill by depth; columns 0-3 d1, 4-7 d2, 8-11 d3, 12-15 unused
  row 9    : back wall; columns 0-7 plain, 8-15 alternate
"""
import sys
import numpy as np
from PIL import Image
from artlib import hx, sprite

THEMES = ["sand", "quay", "town", "roof", "cistern", "belfry", "sump", "wood"]
THEME_ROWS = 10
TW, TH = 32, 16  # seamless texture size

# outline, dark, mid, light, highlight, deep
RAMP = {
    "sand":    ["453330", "7a5a44", "b8935f", "e3c48a", "f7e8bd", "2b2230"],
    "quay":    ["1e2436", "3d4760", "5f6b85", "8a93a6", "bcc6d4", "141827"],
    "town":    ["33202c", "6a3f3f", "96604c", "c08a62", "e6bc8f", "20151f"],
    "roof":    ["3c1a24", "7a2f2f", "b24a3a", "dd7350", "f4a472", "2a1320"],
    "cistern": ["11162c", "232f55", "33477a", "4f6ca3", "86add2", "0a0d1f"],
    "belfry":  ["352b3d", "6b5a70", "9a8a96", "c8bcb8", "f1e9d6", "1d1825"],
    "sump":    ["1c0f26", "4a2450", "6d3468", "a04a7e", "e07a9a", "160b1e"],
    "wood":    ["2a1a1e", "4f3030", "7a4d3a", "a3704a", "cf9c68", "1c1216"],
}


def rgb(s):
    return np.array(hx(s)[:3], dtype=np.uint8)


def ramp(name):
    return [rgb(c) for c in RAMP[name]]


def tile_voronoi(rng, n, w=TW, h=TH):
    """Seamless Voronoi: returns (cell id, distance to border estimate)."""
    pts = np.stack([rng.uniform(0, w, n), rng.uniform(0, h, n)], axis=1)
    yy, xx = np.mgrid[0:h, 0:w]
    dx = np.abs(xx[..., None] - pts[:, 0])
    dy = np.abs(yy[..., None] - pts[:, 1])
    dx = np.minimum(dx, w - dx)
    dy = np.minimum(dy, h - dy)
    d = dx * dx + dy * dy
    order = np.argsort(d, axis=2)
    a = np.take_along_axis(d, order[..., :1], 2)[..., 0]
    b = np.take_along_axis(d, order[..., 1:2], 2)[..., 0]
    return order[..., 0], np.sqrt(b) - np.sqrt(a)


def tex_sand(rng):
    L = np.full((TH, TW), 2, dtype=int)
    for y in range(TH):
        for x in range(TW):
            wave = np.sin(x / TW * 2 * np.pi) * 1.4 + np.sin(x / TW * 4 * np.pi + 1) * 0.7
            yy = (y + wave) % 8
            if yy < 1:
                L[y, x] = 1
            elif yy < 3:
                L[y, x] = 3
    speck = rng.random((TH, TW))
    L[speck > 0.93] = 1
    L[speck < 0.05] = 3
    return L


def bricks(rng, bw, bh, offset, mortar=1, shades=(2, 2, 3, 1)):
    L = np.zeros((TH, TW), dtype=int)
    for row in range(TH // bh):
        off = offset if row % 2 else 0
        for b in range(TW // bw):
            shade = shades[rng.integers(len(shades))]
            for y in range(bh):
                for x in range(bw):
                    px = (b * bw + x + off) % TW
                    py = row * bh + y
                    if y < mortar or x < mortar:
                        L[py, px] = 1
                    else:
                        L[py, px] = shade
                        if y == mortar and x > mortar and shade >= 2:
                            L[py, px] = 3
    return L


def tex_quay(rng):
    L = bricks(rng, 16, 8, 8)
    speck = rng.random((TH, TW))
    L[(speck > 0.95) & (L >= 2)] = 1
    return L


def tex_town(rng):
    cell, edge = tile_voronoi(rng, 16)
    shade = rng.choice([2, 2, 3, 3, 1], size=16)
    L = shade[cell]
    L[edge < 1.0] = 1
    return L


def tex_roof(rng):
    L = np.zeros((TH, TW), dtype=int)
    for y in range(TH):
        for x in range(TW):
            row = y // 4
            ox = 4 if row % 2 else 0
            lx = (x + ox) % 8
            ly = y % 4
            v = 2
            if ly == 3 or lx == 0:
                v = 1
            elif ly == 0 and lx in (1, 2, 3):
                v = 3
            L[y, x] = v
    return L


def tex_cistern(rng):
    L = bricks(rng, 8, 4, 4, shades=(2, 2, 2, 3, 1))
    speck = rng.random((TH, TW))
    L[(speck > 0.97)] = 4
    return L


def tex_belfry(rng):
    L = bricks(rng, 24, 8, 12, shades=(2, 3, 3))
    speck = rng.random((TH, TW))
    L[(speck > 0.96) & (L >= 2)] = 2
    return L


def tex_sump(rng):
    cell, edge = tile_voronoi(rng, 7)
    shade = rng.choice([1, 2, 2, 3], size=7)
    L = shade[cell]
    L[edge < 1.2] = 0
    return L


def tex_wood(rng):
    L = np.zeros((TH, TW), dtype=int)
    for y in range(TH):
        plank = y // 4
        for x in range(TW):
            joint = (x + plank * 11) % 32 == 0
            v = 2 if (x * 3 + plank * 7) % 13 > 3 else 3
            if y % 4 == 3 or joint:
                v = 1
            L[y, x] = v
    return L


TEX = {
    "sand": tex_sand, "quay": tex_quay, "town": tex_town, "roof": tex_roof,
    "cistern": tex_cistern, "belfry": tex_belfry, "sump": tex_sump, "wood": tex_wood,
}


def paint(levels, r):
    """Levels index the ramp: 0 outline, 1 dark, 2 mid, 3 light, 4 hi."""
    out = np.zeros(levels.shape + (4,), dtype=np.uint8)
    pal = np.stack(r[:5])
    out[..., :3] = pal[np.clip(levels, 0, 4)]
    out[..., 3] = 255
    return out


def edge_tile(theme, tex_rgba, r, mask, v, rng):
    vx, vy = v % 4, v // 4
    t = tex_rgba[vy * 8:vy * 8 + 8, vx * 8:vx * 8 + 8].copy()
    N, E, S, W = bool(mask & 1), bool(mask & 2), bool(mask & 4), bool(mask & 8)
    outline, dark, mid, light, hi = r[:5]
    alpha_top = np.zeros(8, dtype=int)
    if not N:
        if theme == "sand":
            # organic dune crest: a little height variation per column
            lip = [0, 0, 1, 0, 0, 0, 1, 1] if v % 2 else [1, 0, 0, 0, 1, 0, 0, 0]
            alpha_top = np.array(lip)
        for x in range(8):
            a = alpha_top[x]
            t[:a, x, 3] = 0
            t[a, x, :3] = hi
            t[a + 1, x, :3] = light
            if a + 2 < 8 and x % 3 != 1:
                t[a + 2, x, :3] = light
    if not S:
        t[7, :, :3] = outline
        t[6, :, :3] = dark
    if not W:
        t[:, 0, :3] = outline if theme != "sand" else dark
        if not N:
            t[alpha_top[0] + 0, 0, :3] = light
    if not E:
        t[:, 7, :3] = outline if theme != "sand" else dark
        if not N:
            t[alpha_top[7] + 0, 7, :3] = light
    # rounded outer corners
    if not N and not W:
        t[0, 0, 3] = 0
    if not N and not E:
        t[0, 7, 3] = 0
    if not S and not W:
        t[7, 0, 3] = 0
    if not S and not E:
        t[7, 7, 3] = 0
    return t


def depth_tile(tex_rgba, r, depth, v, rng):
    vx, vy = v % 4, v // 2 % 2
    deep = r[5]
    t = tex_rgba[vy * 8:vy * 8 + 8, vx * 8:vx * 8 + 8].copy()
    k = {1: 0.42, 2: 0.14, 3: 0.0}[depth]
    t[..., :3] = (t[..., :3] * k + deep * (1 - k)).astype(np.uint8)
    return t


def back_pattern(theme, rng, r, alt=False):
    """Low contrast wall behind the action. Returns 16x32 RGBA."""
    deep = r[5].astype(float)
    mid = r[1].astype(float)
    if theme == "town":
        # plaster with timber framing
        L = np.zeros((TH, TW), dtype=float)
        n = rng.random((TH, TW))
        L += (n > 0.7) * 0.25
        if alt:
            for x in range(TW):
                L[0, x] = 1
                L[1, x] = 1
            for y in range(TH):
                L[y, 0] = 1
                L[y, 1] = 1
                L[y, 16] = 1
                L[y, 17] = 1
        base = np.array([0.0, 0.0, 0.0])
        out = np.zeros((TH, TW, 4), dtype=np.uint8)
        plaster = rgb("a98a72").astype(float) * 0.86
        beam = rgb("4a2f30").astype(float)
        for y in range(TH):
            for x in range(TW):
                c = beam if L[y, x] >= 1 else plaster * (1.0 + L[y, x] * 0.18)
                out[y, x, :3] = np.clip(c, 0, 255).astype(np.uint8)
        out[..., 3] = 255
        return out
    tex = TEX[{"sand": "sand", "roof": "town", "wood": "wood"}.get(theme, theme)](rng)
    k = {0: 0.08, 1: 0.2, 2: 0.48, 3: 0.68, 4: 0.85}
    if alt:
        k = {key: val * 0.55 for key, val in k.items()}
    out = np.zeros((TH, TW, 4), dtype=np.uint8)
    for y in range(TH):
        for x in range(TW):
            a = k[int(tex[y, x])]
            out[y, x, :3] = (deep * (1 - a) + mid * a * 1.25).clip(0, 255).astype(np.uint8)
    out[..., 3] = 255
    return out


PLANK = {
    "L": """
.ddddddd
nDDDnDDD
nnnnnnnn
.NNNNNNN
..Nk....
...k....
........
........
""",
    "M": """
dddddddd
DDDnDDDD
nnnnnnnn
NNNNNNNN
...k....
........
........
........
""",
    "R": """
ddddddd.
DnDDDDDn
nnnnnnnn
NNNNNNN.
....kN..
....k...
........
........
""",
    "S": """
.dddddd.
nDDnDDDn
nnnnnnnn
.NNNNNN.
..k..k..
........
........
........
""",
}
LADDER = ["""
.n....n.
.n....n.
.DddddD.
.nNNNNn.
.n....n.
.n....n.
.n....n.
.n....n.
""", """
.n....n.
.n....n.
.n....n.
.n....n.
.n....n.
.DddddD.
.nNNNNn.
.n....n.
"""]
CHAIN = """
...g....
..g.G...
..g.G...
...G....
...g....
..g.G...
..g.G...
...G....
"""
ROPE = """
...dD...
...Dd...
...dD...
...Dd...
...dD...
...Dd...
...dD...
...Dd...
"""
SAND = ["""
dddddddd
dDddddDd
dddwdddd
ddddddDd
dDdddddd
ddddwddd
ddDddddd
dddddDdd
""", """
ddwddddd
dddddddD
dDdddddd
dddddwdd
ddddDddd
dwdddddd
dddddDdd
Dddddddd
""", """
ddddDddd
dwdddddd
ddddddwd
dDdddddd
dddddDdd
dddwdddd
Dddddddd
dddddddw
""", """
dddddddd
ddDddwdd
dddddddd
wdddDddd
dddddddD
ddwddddd
dddddDdd
dDdddddd
"""]
CRACK = ["""
........
..k.....
...k....
...kk...
..k..k..
.....k..
........
........
""", """
........
.....k..
....k...
..kk....
.k..k...
.....k..
........
........
""", """
...k....
...k....
..k.k...
.k...k..
......k.
........
........
........
""", """
........
.k......
..k..k..
...kk...
...k....
..k.....
..k.....
........
"""]
SPIKES = ["""
...r....
...r..r.
.r.r..r.
.r.R.rR.
.RrR.rR.
rRRrRRRr
RPPRPPPR
PPPPPPPP
""", """
.....r..
..r..r..
..r.rR.r
.rR.rR.r
.rR.RrrR
rRRrRRRR
RPRPPPRP
PPPPPPPP
"""]
DOOR_TILES = ["""
kgGGGGgk
kGbbbbGk
kGbBBbGk
kGbBBbGk
kGbBBbGk
kGbBBbGk
kGbbbbGk
kgGGGGgk
""", """
kGGGGGGk
kGbbbbGk
kGbyybGk
kGbyybGk
kGbBBbGk
kGbBBbGk
kGbbbbGk
kGGGGGGk
"""]
RING = """
...kk...
..yckk..
.ykkkCk.
.ck..Ck.
.ck..Ck.
.Cck.Ck.
..CCCk..
...kk...
"""
TUFTS = ["""
........
........
........
........
...l....
.l.lm.l.
.mlmm.m.
.mmlmmm.
""", """
........
........
..t.....
..tT....
.tT.t...
.tT.tT..
..tTtT..
..tTT...
""", """
........
.....a..
..t..t..
..t.tT..
.tT.tT.t
.tT.tTtT
..TtTTtT
..TtTTT.
""", """
........
........
........
........
..r..r..
.rRrrRr.
.rRRRRr.
..RRRR..
""", """
........
........
........
........
........
...wW...
..wwgw..
.wgwgwg.
""", """
........
........
........
...p....
.p.pr.p.
.rpr..r.
..rRprR.
..RRRR..
"""]


def asc(text):
    return np.array(sprite(text))


def stamp(atlas, row, col, a):
    h, w = a.shape[:2]
    atlas[row * 8:row * 8 + h, col * 8:col * 8 + w] = a


def misc(atlas, base):
    for i, k in enumerate("LMRS"):
        stamp(atlas, base, i, asc(PLANK[k]))
    for i, l in enumerate(LADDER):
        stamp(atlas, base, 4 + i, asc(l))
    stamp(atlas, base, 6, asc(CHAIN))
    stamp(atlas, base, 7, asc(ROPE))
    for i, s in enumerate(SAND):
        stamp(atlas, base, 8 + i, asc(s))
    for i, c in enumerate(CRACK):
        stamp(atlas, base, 12 + i, asc(c))
    for i, s in enumerate(SPIKES):
        up = asc(s)
        stamp(atlas, base + 1, 0 + i, up)
        stamp(atlas, base + 1, 2 + i, np.flipud(up))
        stamp(atlas, base + 1, 4 + i, np.rot90(up, -1))
        stamp(atlas, base + 1, 6 + i, np.rot90(up, 1))
    for i, d in enumerate(DOOR_TILES):
        stamp(atlas, base + 1, 8 + i, asc(d))
    stamp(atlas, base + 1, 12, asc(RING))
    for i, t in enumerate(TUFTS):
        stamp(atlas, base + 2, i, asc(t))


def build():
    rows = len(THEMES) * THEME_ROWS + 3
    atlas = np.zeros((rows * 8, 16 * 8, 4), dtype=np.uint8)
    misc(atlas, len(THEMES) * THEME_ROWS)
    for ti, theme in enumerate(THEMES):
        rng = np.random.default_rng(1000 + ti)
        r = ramp(theme)
        tex = paint(TEX[theme](rng), r)
        y0 = ti * THEME_ROWS * 8
        for v in range(8):
            for mask in range(16):
                t = edge_tile(theme, tex, r, mask, v, rng)
                atlas[y0 + v * 8:y0 + v * 8 + 8, mask * 8:mask * 8 + 8] = t
        for d in (1, 2, 3):
            for v in range(4):
                t = depth_tile(tex, r, d, v, rng)
                x = ((d - 1) * 4 + v) * 8
                atlas[y0 + 64:y0 + 72, x:x + 8] = t
        for alt in (0, 1):
            pat = back_pattern(theme, rng, r, bool(alt))
            for v in range(8):
                vx, vy = v % 4, v // 4
                x = (alt * 8 + v) * 8
                atlas[y0 + 72:y0 + 80, x:x + 8] = pat[vy * 8:vy * 8 + 8, vx * 8:vx * 8 + 8]
    return Image.fromarray(atlas, "RGBA")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/gfx/tiles.png"
    img = build()
    img.save(out)
    print("wrote", out, img.size)
