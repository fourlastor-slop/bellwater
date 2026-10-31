"""Sky and distant parallax layers, painted in the full dawn palette the player only sees at the end."""
import numpy as np
from PIL import Image, ImageDraw
from artlib import hx

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def lerp_stops(stops, t):
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if t <= b:
            k = (t - a) / (b - a)
            return ca + (cb - ca) * k
    return stops[-1][1]


def sky():
    W, H = 320, 180
    stops = [(0.0, "4a6fa8"), (0.34, "7fb6c4"), (0.62, "f4dca8"), (0.82, "f7b27a"), (1.0, "ee8a6a")]
    stops = [(p, np.array(hx(c)[:3], dtype=float)) for p, c in stops]
    # quantise into bands, dithered across each boundary
    n = 14
    pal = [lerp_stops(stops, i / (n - 1)) for i in range(n)]
    out = np.zeros((H, W, 4), dtype=np.uint8)
    for y in range(H):
        t = y / (H - 1) * (n - 1)
        for x in range(W):
            i = int(t + BAYER[y % 4, x % 4] * 0.99)
            out[y, x, :3] = np.clip(pal[min(i, n - 1)], 0, 255)
    out[..., 3] = 255
    img = Image.fromarray(out, "RGBA")
    d = ImageDraw.Draw(img)
    # a big low sun-moon
    d.ellipse([214, 52, 274, 112], fill=hx("fff1cc"))
    d.ellipse([222, 60, 266, 104], fill=hx("fff8e4"))
    # long thin clouds
    rng = np.random.default_rng(4)
    for i in range(16):
        y = int(rng.integers(8, 120))
        x = int(rng.integers(-20, 300))
        ln = int(rng.integers(24, 90))
        d.line([(x, y), (x + ln, y)], fill=hx("ffffff") if y < 70 else hx("ffe8c8"))
        d.line([(x + 8, y + 1), (x + ln - 12, y + 1)], fill=hx("dcebe6") if y < 70 else hx("fcd6a8"))
    return img


def ridge(rng, W, base, amp, rough):
    xs = np.arange(W)
    y = np.zeros(W)
    for f, a in rough:
        y += np.sin(xs / W * 2 * np.pi * f + rng.random() * 6.28) * a
    return (base + y * amp).astype(int)


def far():
    """Horizon of dunes and sea stacks, tiling 640 wide."""
    W, H = 640, 260
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(11)
    r0 = ridge(rng, W, 176, 1.0, [(2, 7), (5, 3), (11, 1.5)])
    for x in range(W):
        d.line([(x, r0[x]), (x, H)], fill=hx("c7a487"))
    # sea stacks
    for sx, sw, sh in [(60, 26, 66), (92, 16, 40), (280, 34, 88), (322, 14, 34), (500, 22, 58), (560, 30, 44)]:
        top = r0[sx] - sh
        pts = [(sx, r0[sx] + 6)]
        for i in range(6):
            pts.append((sx + (i % 2) * 3 + i, top + sh * (5 - i) // 6))
        pts += [(sx + sw // 2, top), (sx + sw - 3, top + 8), (sx + sw, r0[sx] + 6)]
        d.polygon(pts, fill=hx("9b7f75"))
    r1 = ridge(rng, W, 196, 1.0, [(3, 6), (7, 2)])
    for x in range(W):
        d.line([(x, r1[x]), (x, H)], fill=hx("a98777"))
    return img


def near():
    """Town skyline on the cliff, tiling 800 wide: gables, chimneys, the belfry."""
    W, H = 800, 260
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(23)
    col = hx("6f6280")
    col2 = hx("5a4f6c")
    x = 0
    base = 210
    while x < W:
        w = int(rng.integers(26, 54))
        h = int(rng.integers(40, 110))
        top = base - h
        d.rectangle([x, top, x + w, H], fill=col)
        if rng.random() < 0.7:
            d.polygon([(x - 3, top), (x + w // 2, top - int(rng.integers(12, 26))), (x + w + 3, top)], fill=col)
        if rng.random() < 0.5:
            cx = x + int(rng.integers(4, w - 6))
            d.rectangle([cx, top - 20, cx + 4, top], fill=col)
        for wy in range(top + 8, base, 14):
            for wx in range(x + 5, x + w - 5, 11):
                if rng.random() < 0.3:
                    d.rectangle([wx, wy, wx + 3, wy + 5], fill=hx("f7d154") if rng.random() < 0.4 else col2)
        x += w + int(rng.integers(-4, 8))
    # the belfry, standing over the town
    bx = 380
    d.rectangle([bx, 40, bx + 34, H], fill=col2)
    d.polygon([(bx - 4, 40), (bx + 17, 6), (bx + 38, 40)], fill=col2)
    d.rectangle([bx + 10, 52, bx + 24, 74], fill=hx("c98a3a"))
    return img


def main():
    sky().save("assets/gfx/bg_sky.png")
    far().save("assets/gfx/bg_far.png")
    near().save("assets/gfx/bg_near.png")
    print("backdrop ok")


if __name__ == "__main__":
    main()
