"""Static decoration: packs everything into deco.png, and writes the region table for the game."""
import numpy as np
from PIL import Image, ImageDraw
from artlib import sprite, PAL, hx

ASCII = {
    "window": """
....kkkkkkkk....
..kknnnnnnnnkk..
.knnBBBBBBBBnnk.
.knBBBbBBBnBBnk.
.knBBBBBBBnBBnk.
knBBBBBBBBnBBBnk
knBbBBBBBBnBBBnk
knnnnnnnnnnnnnnk
knBBBBBBBBnBBBnk
knBBBBbBBBnBBBnk
knBBBBBBBBnBBBnk
knnnnnnnnnnnnnnk
kDDDDDDDDDDDDDDk
.kkkkkkkkkkkkkk.
""",
    "window_lit": """
....kkkkkkkk....
..kknnnnnnnnkk..
.knneeeeeeeennk.
.kneeeyeeeneenk.
.kneeeeeeeneenk.
kneeeeeeeeneeenk
kneyeeeeeeneeenk
knnnnnnnnnnnnnnk
kneeeeeeeeneeenk
kneeeeyeeeneeenk
kneeeeeeeeneeenk
knnnnnnnnnnnnnnk
kDDDDDDDDDDDDDDk
.kkkkkkkkkkkkkk.
""",
    "shutter": """
kkkkkkkkkkkk
kbkBBBBBBkbk
kbkBBBBBBkbk
kBkBBbBBBkBk
kbkBBBBBBkbk
kbkBBBBBBkbk
kBkkkkkkkkBk
kbkBBBBBBkbk
kbkBBBBBBkbk
kBkBBBBBBkBk
kkkkkkkkkkkk
nDDDDDDDDDDn
""",
    "door": """
.....kkkkkk.....
...kknnnnnnkk...
..knnNnnnnNnnk..
.knNnnNnnNnnNnk.
.knNnnNnnNnnNnk.
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNyyNnnk
knnNnnNnnNyyNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
knnNnnNnnNnnNnnk
kkkkkkkkkkkkkkkk
""",
    "awning": """
kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk
krrwwwrrrwwwrrrwwwrrrwwwrrrwwwrk
krrwwwrrrwwwrrrwwwrrrwwwrrrwwwrk
krrwwwrrrwwwrrrwwwrrrwwwrrrwwwrk
kRRgggRRRgggRRRgggRRRgggRRRgggRk
.rrr.www.rrr.www.rrr.www.rrr.ww.
..r...w...r...w...r...w...r...w.
""",
    "lantern": """
..kk..
..kk..
.kCCk.
kCccCk
keeeek
kekkek
keeeek
kCCCCk
.kkkk.
""",
    "crate": """
kkkkkkkkkkkk
kDDDDDDDDDDk
kDnDDDDDDnDk
kDDnDDDDnDDk
kDDDnDDnDDDk
kDDDDnnDDDDk
kDDDDnnDDDDk
kDDDnDDnDDDk
kDDnDDDDnDDk
kDnDDDDDDnDk
kDDDDDDDDDDk
kkkkkkkkkkkk
""",
    "barrel": """
..kkkkkk..
.knnDDDnk.
kGGGGGGGGk
knnDDDDnnk
knnDDDDnnk
knnDDDDnnk
knnDDDDnnk
knnDDDDnnk
knnDDDDnnk
kGGGGGGGGk
.knnDDDnk.
..kkkkkk..
""",
    "net": """
k.......k.......k.......
.d.....d.d.....d.d.....d
..d...d...d...d...d...d.
...d.d.....d.d.....d.d..
....k.......k.......k...
...d.d.....d.d.....d.d..
..d...d...d...d...d...d.
.d.....d.d.....d.d.....d
k.......k.......k.......
.d.....d.d.....d.d.....d
..d...d...d...d...d...d.
...d.d.....d.d.....d.d..
....k.......k.......k...
""",
    "anchor": """
.......kk.......
......kggk......
......kGGk......
.......kk.......
....kkkkkkkk....
....kgggggGk....
....kkkggkkk....
......kggk......
......kggk......
......kggk......
.k....kggk....k.
kgk...kggk...kGk
kggk..kggk..kGGk
.kggk.kggk.kGGk.
..kgggkggkGGGk..
...kkgggGGGkk...
.....kkkkkk.....
""",
    "shopsign": """
.......kk.......
.......kk.......
kkkkkkkkkkkkkkkk
knnnnnnnnnnnnnnk
knnnnaaaaknnnnnk
knnaaaaakaannaak
knaaaaaaaaaaaank
knnaaaaakaannaak
knnnnaaaaknnnnnk
knnnnnnnnnnnnnnk
kkkkkkkkkkkkkkkk
""",
    "bootsign": """
.......kk.......
.......kk.......
kkkkkkkkkkkkkkkk
knnnnnnnnnnnnnnk
knnnnnggggnnnnnk
knnnnggggggnnnnk
knnnggGkkGggnnnk
knnnggGkkGggnnnk
knnnngggggGnnnnk
knnnnnnnnnnnnnnk
kkkkkkkkkkkkkkkk
""",
    "coil": """
..kkkkkkkk..
.kdDdDdDdDk.
kDdDdDdDdDdk
kdDdkkkkDdDk
kDdDdDdDdDdk
.kkkkkkkkkk.
""",
    "fishbones": """
...........k........
.kk...k.k.k.k.k.kkk.
kwwk.kwkwkwkwkwkwwwk
.kwwwwwwwwwwwwwwwkwk
kwwk.kwkwkwkwkwkwwwk
.kk...k.k.k.k.k.kkk.
...........k........
""",
    "pipe": """
.kkkkkkkkkkkkkk.
kGGGGGGGGGGGGGGk
kGgggggggggggGGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGgkkkkkkkkkkgGk
kGGGGGGGGGGGGGGk
.kkkkkkkkkkkkkk.
""",
    "bucket": """
.kkkkkkk.
kgGGGGGgk
.kBBBBBk.
.kBBBBBk.
.kBBBBBk.
.kBBBBBk.
..kkkkk..
""",
    "flowerpot": """
..l.m.l..
.lmlmlml.
..mlmlm..
.rlrmrlr.
kkkkkkkkk
kOOOOOOOk
.kOOOOOk.
.kOOOOOk.
..kkkkk..
""",
    "gravestone": """
...kkkkkk...
..kggggggk..
.kgggggggGk.
.kggkkkggGk.
.kgggggggGk.
.kggkkkggGk.
.kgggggggGk.
.kgggggggGk.
.kgggggggGk.
kkkkkkkkkkkk
""",
    "brazier": """
...r.r.o....
..rorooryr..
..oyyooyyo..
kkkkkkkkkkkk
kCcCcCcCcCck
.kCcCcCcCck.
..kkkkkkkk..
.....kk.....
.....kk.....
.....kk.....
...kkkkkk...
""",
    "lifering": """
...kkkkkk...
..krrwwrrk..
.krrkkkkrrk.
krrk....krrk
kwwk....kwwk
kwwk....kwwk
krrk....krrk
.krrkkkkrrk.
..krrwwrrk..
...kkkkkk...
""",
    "laundry": """
kk....................................kk
kkddddddddddddddddddddddddddddddddddddkk
.k..wwwwww....rrrrrr....bbbbbbb.......k.
....wwwwww....rrrrrr....bbbbbbb.........
....wwwwww....rrrrrr....bbbbbbb.........
.....wwww.....rrrrrr....bbb.bbb.........
.....wwww.....rrrrrr....bbb.bbb.........
.....wwww.....RRRRRR....bbb.bbb.........
..............rrrrrr....BBB.BBB.........
""",
    "kelp_dry": """
...n....
..nN....
..n.n...
..n.nN..
.nN.n...
.n..nN..
.nN.n...
..n.n...
""",
}


def boat():
    """The player's home: a small fishing boat, tilted on the sand."""
    w, h = 84, 42
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    hull = [(0, 18), (83, 14), (78, 26), (70, 34), (16, 38), (6, 30)]
    d.polygon(hull, fill=hx("7a4d3a"))
    for y in range(18, 40, 4):
        d.line([(0, y + 1), (83, y - 3)], fill=hx("4f3030"))
    d.line([(0, 18), (83, 14)], fill=hx("efe6d0"), width=2)
    d.polygon([(4, 28), (79, 23), (74, 30), (9, 34)], fill=hx("a02c3e"))
    d.line(hull + [hull[0]], fill=hx("141826"))
    # wheelhouse
    d.rectangle([44, 2, 66, 16], fill=hx("efe6d0"), outline=hx("141826"))
    d.rectangle([48, 5, 54, 10], fill=hx("2f6fa3"), outline=hx("141826"))
    d.rectangle([57, 5, 63, 10], fill=hx("2f6fa3"), outline=hx("141826"))
    d.rectangle([42, 0, 68, 2], fill=hx("a02c3e"), outline=hx("141826"))
    # mast
    d.line([(26, 0), (26, 17)], fill=hx("453330"), width=2)
    return img


def wreck():
    """Ribs of a big old ship, half buried."""
    w, h = 120, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(4, 116, 13)):
        top = 6 + abs(i - 4) * 3
        bow = (i - 4) * 2
        d.line([(x + bow, top), (x + bow // 2, top + 18), (x, 63)], fill=hx("4f3030"), width=4)
        d.line([(x + bow + 2, top), (x + bow // 2 + 2, top + 18), (x + 2, 63)], fill=hx("a3704a"), width=1)
    d.line([(0, 30), (119, 26)], fill=hx("4f3030"), width=3)
    d.line([(0, 44), (119, 41)], fill=hx("4f3030"), width=3)
    return img


def ribs():
    """A whale's ribcage on the sand."""
    w, h = 72, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(6, 70, 11)):
        top = 4 + i * 3
        pts = [(x, 47), (x + 2, 28), (x + 8, top + 8), (x + 16, top)]
        d.line(pts, fill=hx("141826"), width=4, joint="curve")
        d.line(pts, fill=hx("efe6d0"), width=2, joint="curve")
    return img


def mast():
    w, h = 40, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([18, 0, 21, 79], fill=hx("4f3030"))
    d.line([(19, 0), (19, 79)], fill=hx("a3704a"))
    d.rectangle([2, 16, 37, 18], fill=hx("4f3030"))
    d.line([(2, 16), (19, 2)], fill=hx("453330"))
    d.line([(37, 16), (19, 2)], fill=hx("453330"))
    d.polygon([(19, 20), (34, 24), (30, 44), (21, 52)], fill=hx("c8bcb8"), outline=hx("6b5a70"))
    return img


def crane():
    w, h = 56, 92
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([34, 12, 41, 91], fill=hx("4f3030"), outline=hx("141826"))
    for y in range(20, 90, 12):
        d.line([(35, y), (40, y + 8)], fill=hx("a3704a"))
    d.line([(2, 8), (54, 4)], fill=hx("4f3030"), width=4)
    d.line([(2, 7), (54, 3)], fill=hx("a3704a"))
    d.line([(38, 30), (10, 9)], fill=hx("453330"), width=2)
    d.rectangle([28, 88, 47, 91], fill=hx("141826"))
    return img


def arch():
    w, h = 48, 56
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 47, 55], fill=hx("525a70"))
    d.pieslice([6, 4, 41, 40], 180, 360, fill=hx("141826"))
    d.rectangle([6, 22, 41, 55], fill=hx("141826"))
    d.arc([6, 4, 41, 40], 180, 360, fill=hx("8a93a6"))
    d.line([(6, 22), (6, 55)], fill=hx("8a93a6"))
    d.line([(41, 22), (41, 55)], fill=hx("8a93a6"))
    return img


def rope_tall():
    img = Image.new("RGBA", (6, 64), (0, 0, 0, 0))
    px = img.load()
    for y in range(64):
        px[2, y] = hx("e3c48a") if y % 4 < 2 else hx("b8935f")
        px[3, y] = hx("b8935f") if y % 4 < 2 else hx("7a5a44")
    return img


def main():
    items = {k: sprite(v) for k, v in ASCII.items()}
    items.update({"boat": boat(), "wreck": wreck(), "ribs": ribs(), "mast": mast(), "crane": crane(),
                  "arch": arch(), "bellrope": rope_tall()})
    # simple shelf packer
    W = 256
    placed = {}
    x = y = shelf = 0
    for name, im in sorted(items.items(), key=lambda kv: -kv[1].height):
        if x + im.width > W:
            x = 0
            y += shelf + 1
            shelf = 0
        placed[name] = (x, y, im.width, im.height)
        x += im.width + 1
        shelf = max(shelf, im.height)
    H = y + shelf
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for name, (px, py, _, _) in placed.items():
        atlas.alpha_composite(items[name], (px, py))
    atlas.save("assets/gfx/deco.png")
    with open("scripts/core/deco_data.gd", "w") as f:
        f.write("class_name DecoData\nextends RefCounted\n## Generated by tools/gen_deco.py\n\nconst REGIONS := {\n")
        for name, r in sorted(placed.items()):
            f.write(f'\t"{name}": [{r[0]}, {r[1]}, {r[2]}, {r[3]}],\n')
        f.write("}\n")
    print("deco", atlas.size, len(placed))


if __name__ == "__main__":
    main()
