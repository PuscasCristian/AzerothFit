"""Project logo for CurseForge (400x400 PNG, original art, no game assets).

    python3 -I tools/art/logo.py   ->  docs/logo.png
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import figure  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "docs", "logo.png")
FONT = "/usr/share/fonts/noto/NotoSerifDisplay-Black.ttf"
SIZE = 400
S = 3  # supersampling
GOLD = (238, 204, 128)
GOLD_DARK = (150, 112, 52)


def background(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c * 0.85) / (size * 0.75)
            t = max(0.0, min(1.0, d))
            px[x, y] = (int(34 - 22 * t), int(30 - 19 * t), int(36 - 20 * t))
    return img


def main():
    big = SIZE * S
    img = background(big).convert("RGBA")
    d = ImageDraw.Draw(img)

    # Gold ring with a soft glow
    cx, cy, r = big / 2, big * 0.42, big * 0.31
    glow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=GOLD + (110,), width=int(26 * S))
    glow = glow.filter(ImageFilter.GaussianBlur(10 * S))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=GOLD_DARK, width=int(9 * S))
    d.ellipse([cx - r + 3 * S, cy - r + 3 * S, cx + r - 3 * S, cy + r - 3 * S], outline=GOLD, width=int(4 * S))

    # Stick figure flexing (front view), drawn with the same renderer as the animations.
    # Both sides in the bright color so the pose reads symmetric.
    figure.FAR = figure.NEAR
    fy = cy + r * 0.66  # floor line
    fsize = int(r * 1.62)
    figure.FRAME = fsize // figure.SS
    layer = Image.new("RGBA", (figure.FRAME * figure.SS, figure.FRAME * figure.SS), (0, 0, 0, 0))
    fd = ImageDraw.Draw(layer)
    P = figure.pose(hip=(50, 44), torso=0, lthigh=-15, lshin=-11, rthigh=15, rshin=11, ground="lowest",
                    larm=-90, lfore=-176, rarm=90, rfore=176)
    # Double-biceps: give the figure shoulders by moving each arm outward.
    for side, dx in (("l", -5), ("r", 5)):
        for joint in ("elbow", "hand"):
            x, y = P.p[side + joint]
            P.p[side + joint] = (x + dx, y - 2)
    figure.draw_figure(fd, P)
    layer = layer.resize((fsize, fsize), Image.LANCZOS)
    feet = (figure.FLOOR + 1.5) / 100  # feet sit this high in the layer
    top = int(fy + feet * fsize - fsize)
    img.alpha_composite(layer, (int(cx - fsize / 2), top))
    d = ImageDraw.Draw(img)
    d.line([(cx - r * 0.5, fy), (cx + r * 0.5, fy)], fill=GOLD_DARK, width=int(5 * S))

    # Title
    font = ImageFont.truetype(FONT, int(44 * S))
    text = "AZEROTH FIT"
    w = d.textlength(text, font=font)
    ty = big * 0.805
    d.text(((big - w) / 2 + 3 * S, ty + 3 * S), text, font=font, fill=(0, 0, 0, 200))
    d.text(((big - w) / 2, ty), text, font=font, fill=GOLD)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
