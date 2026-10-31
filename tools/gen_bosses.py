"""Boss parts. Bosses are paper dolls: a few big sprites moved and rotated in code."""
from PIL import Image, ImageDraw
from artlib import hx, sprite, sheet

OUT = "assets/gfx/"
K = hx("141826")


def lit(d, box, fill, shade, hi):
    d.ellipse(box, fill=shade, outline=K)
    x0, y0, x1, y1 = box
    d.ellipse([x0 + 2, y0 + 1, x1 - 5, y1 - 4], fill=fill)
    d.ellipse([x0 + 4, y0 + 3, x0 + (x1 - x0) // 2, y0 + (y1 - y0) // 3], fill=hi)


def bell_shape(w, h, body="c98a3a", shade="8f5a22", hi="f7d154"):
    """A big bell, lit from the left."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx = w / 2
    for y in range(h):
        t = y / (h - 1)
        half = (0.26 + 0.1 * t + 0.14 * t ** 4) * w
        half = min(half, w / 2 - 1)
        if t < 0.07:
            half = (t / 0.07) ** 0.5 * 0.25 * w
        for x in range(w):
            dx = (x - cx) / half if half else 9
            if abs(dx) < 1:
                c = body
                if dx < -0.45:
                    c = hi
                if dx > 0.45:
                    c = shade
                if abs(dx) > 0.92:
                    c = "141826"
                px[x, y] = hx(c)
    d = ImageDraw.Draw(img)
    d.rectangle([0, h - 3, w - 1, h - 1], fill=K)
    d.rectangle([3, h - 7, w - 4, h - 5], fill=hx(shade))
    d.line([(int(cx - 0.3 * w), int(h * 0.52)), (int(cx + 0.3 * w), int(h * 0.52))], fill=hx(shade))
    return img


def hermit():
    bell_shape(56, 44).save(OUT + "hermit_shell.png")
    frames = []
    for open_claw in (0, 1):
        im = Image.new("RGBA", (72, 30), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        # soft body
        d.rounded_rectangle([18, 6, 54, 28], 8, fill=hx("e8514a"), outline=K)
        d.rounded_rectangle([20, 18, 52, 26], 4, fill=hx("a02c3e"))
        # eye stalks
        for ex in (26, 44):
            d.rectangle([ex, 0, ex + 2, 8], fill=hx("a02c3e"), outline=K)
            d.ellipse([ex - 2, -2 + 0, ex + 4, 5], fill=hx("efe6d0"), outline=K)
            d.point([ex + 1, 2], fill=K)
        # claws
        for sx, flip in ((0, False), (52, True)):
            cl = Image.new("RGBA", (20, 22), (0, 0, 0, 0))
            c = ImageDraw.Draw(cl)
            c.ellipse([0, 4, 19, 21], fill=hx("e8514a"), outline=K)
            c.polygon([(2, 8), (10, 13 if open_claw else 9), (2, 2 if open_claw else 6)], fill=(0, 0, 0, 0))
            if flip:
                cl = cl.transpose(Image.FLIP_LEFT_RIGHT)
            im.alpha_composite(cl, (sx, 7))
        frames.append(im)
    sheet(frames, 72, 30).save(OUT + "hermit_body.png")
    wave = sprite("""
....ww....
...wWWw...
..wWfaaw..
.wWfaaatw.
wWfaaaTTtw
""")
    wave.save(OUT + "shock.png")


def conger():
    head = Image.new("RGBA", (34, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(head)
    d.polygon([(0, 7), (22, 1), (33, 7), (33, 12), (20, 12), (33, 16), (24, 21), (0, 16)], fill=hx("2a8c8c"), outline=K)
    d.polygon([(2, 12), (20, 13), (24, 20), (2, 16)], fill=hx("c8f5e0"))
    d.ellipse([20, 4, 25, 9], fill=hx("f7d154"), outline=K)
    for x in range(24, 33, 3):
        d.polygon([(x, 12), (x + 1, 15), (x + 2, 12)], fill=hx("efe6d0"))
    head.save(OUT + "conger_head.png")
    seg = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(seg)
    d.ellipse([0, 0, 15, 15], fill=hx("1c5c6e"), outline=K)
    d.ellipse([2, 2, 12, 9], fill=hx("2a8c8c"))
    d.ellipse([3, 3, 7, 6], fill=hx("5fcdbb"))
    seg.save(OUT + "conger_seg.png")


def albatross():
    frames = []
    for wing in (0, 1, 2):
        im = Image.new("RGBA", (100, 52), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        tip = [6, 18, 40][wing]
        # far wing
        d.polygon([(50, 28), (92, tip + 2), (96, tip + 6), (62, 34)], fill=hx("c8bcb8"), outline=K)
        # body
        d.ellipse([34, 22, 80, 42], fill=hx("efe6d0"), outline=K)
        d.polygon([(34, 30), (14, 28), (16, 36), (40, 37)], fill=hx("c8bcb8"), outline=K)
        # neck and head
        d.ellipse([70, 18, 86, 32], fill=hx("efe6d0"), outline=K)
        d.polygon([(84, 22), (99, 26), (84, 28)], fill=hx("f29a4a"), outline=K)
        d.point([80, 23], fill=K)
        # near wing
        d.polygon([(48, 30), (8, tip), (4, tip + 5), (40, 36)], fill=hx("ffffff"), outline=K)
        d.line([(10, tip + 2), (40, 33)], fill=hx("8a93a6"))
        frames.append(im)
    sheet(frames, 100, 52).save(OUT + "albatross.png")
    bell_shape(18, 16).save(OUT + "albatross_bell.png")
    salt = sprite("""
.wwww.
wwWWww
wWWwgw
wwwggw
.gggg.
""")
    salt.save(OUT + "saltbomb.png")


def drinker():
    # a vast mouth in the wall
    W, H = 96, 128
    frames = []
    for open_k in (0, 1, 2):
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([12, 2, W + 20, H - 3], 26, fill=hx("3a1c3f"), outline=K)
        d.rounded_rectangle([18, 10, W + 20, H - 12], 22, fill=hx("5a2a55"))
        for i in range(9):
            d.ellipse([70 + (i * 13) % 20, 8 + i * 13, 78 + (i * 13) % 20, 14 + i * 13], fill=hx("8a3f6a"))
        cy = H // 2 + 8
        gape = [10, 24, 38][open_k]
        d.ellipse([20, cy - gape, 70, cy + gape], fill=hx("0d0713"), outline=K)
        d.ellipse([28, cy - gape + 4, 72, cy + gape - 4], fill=hx("1c0a20"))
        # teeth around the rim
        import math
        for i in range(14):
            a = i / 14 * math.tau
            x = 45 + math.cos(a) * 25
            y = cy + math.sin(a) * gape
            ix = 45 + math.cos(a) * 18
            iy = cy + math.sin(a) * max(gape - 7, 3)
            d.polygon([(x - 3, y), (x + 3, y), (ix, iy)], fill=hx("efe6d0"), outline=K)
        # eye above the mouth
        d.ellipse([34, 12, 62, 34], fill=hx("efe6d0"), outline=K)
        d.ellipse([38, 16, 54, 32], fill=hx("e8514a"), outline=K)
        d.ellipse([40, 19, 49, 29], fill=K)
        d.point([43, 21], fill=hx("ffffff"))
        frames.append(im)
    sheet(frames, W, H).save(OUT + "drinker.png")
    tongue = Image.new("RGBA", (16, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(tongue)
    d.ellipse([0, 0, 15, 11], fill=hx("c86a8a"), outline=K)
    d.ellipse([2, 2, 9, 6], fill=hx("e8a0b0"))
    tongue.save(OUT + "drinker_tongue.png")


def greatbell():
    bell_shape(96, 80).save(OUT + "greatbell.png")


def icon():
    img = Image.new("RGBA", (64, 64), hx("1c3f66"))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 44, 63, 63], fill=hx("2a8c8c"))
    d.line([(0, 44), (63, 44)], fill=hx("c8f5e0"))
    b = bell_shape(40, 34)
    img.alpha_composite(b, (12, 8))
    img.resize((128, 128), Image.NEAREST).save(OUT + "icon.png")


if __name__ == "__main__":
    hermit()
    conger()
    albatross()
    drinker()
    greatbell()
    icon()
    print("bosses ok")
