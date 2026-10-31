"""Shared helpers for the art generators: palette, ASCII sprites, sheets."""
from PIL import Image
import numpy as np


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


# Single-letter palette used by every ASCII sprite in the game.
PAL = {
    ".": (0, 0, 0, 0),
    "k": hx("141826"),  # outline
    "K": hx("2a2f45"),  # slate
    "w": hx("efe6d0"),  # bone
    "W": hx("ffffff"),
    "g": hx("8a93a6"),  # stone
    "G": hx("525a70"),  # dark stone
    "y": hx("f7d154"),  # yellow
    "o": hx("f29a4a"),  # orange
    "O": hx("b9602f"),  # dark orange
    "r": hx("e8514a"),  # red
    "R": hx("a02c3e"),  # dark red
    "s": hx("f2c9a1"),  # skin
    "S": hx("c9906d"),  # skin shade
    "b": hx("2f6fa3"),  # blue
    "B": hx("1c3f66"),  # dark blue
    "t": hx("2a8c8c"),  # teal
    "T": hx("1c5c6e"),  # dark teal
    "a": hx("5fcdbb"),  # aqua
    "f": hx("c8f5e0"),  # foam
    "n": hx("7a5a44"),  # brown
    "N": hx("453330"),  # dark brown
    "d": hx("e3c48a"),  # sand
    "D": hx("b8935f"),  # tan
    "p": hx("8a3f6a"),  # plum
    "P": hx("5a2a55"),  # dark plum
    "m": hx("4f8a4f"),  # moss
    "l": hx("8cc257"),  # leaf
    "c": hx("c98a3a"),  # brass
    "C": hx("8f5a22"),  # dark brass
    "e": hx("ffe9a8"),  # warm light
}


def sprite(text):
    """Build an RGBA image from a block of palette letters."""
    rows = [r.strip() for r in text.strip("\n").split("\n")]
    rows = [r for r in rows if r]
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in PAL:
                raise ValueError(f"bad palette char {ch!r} in row {y}: {r}")
            px[x, y] = PAL[ch]
    return img


def sheet(frames, fw, fh, cols=None, anchor="bottom"):
    """Lay frames out on a grid of fw*fh cells, bottom-centred by default."""
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    out = Image.new("RGBA", (fw * cols, fh * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        cx = (i % cols) * fw
        cy = (i // cols) * fh
        ox = (fw - f.width) // 2
        oy = fh - f.height if anchor == "bottom" else (fh - f.height) // 2
        out.alpha_composite(f, (cx + ox, cy + oy))
    return out


def overlay(base, top, x=0, y=0):
    out = base.copy()
    out.alpha_composite(top, (x, y))
    return out


def flip(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def recolor(img, mapping):
    """Swap palette letters: mapping {'r': 'b'} turns red into blue."""
    src = {PAL[a]: PAL[b] for a, b in mapping.items()}
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y] in src:
                px[x, y] = src[px[x, y]]
    return out


def preview(img, path, scale=6, bg=(58, 62, 84, 255)):
    canvas = Image.new("RGBA", img.size, bg)
    canvas.alpha_composite(img)
    canvas.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)


def arr(img):
    return np.array(img.convert("RGBA"))
