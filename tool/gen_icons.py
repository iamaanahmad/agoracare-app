"""Generate AgoraCare heart launcher + splash icons (brand blue gradient + white heart)."""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Brand colors (match lib/core/theme.dart)
PRIMARY = (0x25, 0x63, 0xEB)      # #2563EB
PRIMARY_MID = (0x3B, 0x82, 0xF6)  # #3B82F6
WHITE = (255, 255, 255, 255)

SS = 4  # supersample factor for smooth edges


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_bg(size, radius_ratio=None):
    """Diagonal gradient (primaryMid -> primary), optionally rounded/circular mask."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    px = img.load()
    maxd = (big - 1) * 2
    for y in range(big):
        for x in range(big):
            t = (x + y) / maxd
            px[x, y] = lerp(PRIMARY_MID, PRIMARY, t) + (255,)
    # mask
    mask = Image.new("L", (big, big), 0)
    md = ImageDraw.Draw(mask)
    if radius_ratio is None:
        md.ellipse([0, 0, big - 1, big - 1], fill=255)
    else:
        r = int(big * radius_ratio)
        md.rounded_rectangle([0, 0, big - 1, big - 1], radius=r, fill=255)
    img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


def heart_mask(size, scale=0.56, cx=0.5, cy=0.5):
    """Return an L-mode mask of a filled heart centered in a size x size canvas."""
    big = size * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    pts = []
    n = 720
    s = big * scale
    ox, oy = big * cx, big * cy
    for i in range(n + 1):
        t = math.pi * 2 * i / n
        hx = 16 * math.sin(t) ** 3
        hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((ox + hx / 32 * s, oy - hy / 32 * s))
    d.polygon(pts, fill=255)
    return img.resize((size, size), Image.LANCZOS)


def full_icon(size, rounded=True):
    """Gradient background (rounded square) + centered white heart. Full-bleed launcher icon."""
    bg = gradient_bg(size, radius_ratio=0.22 if rounded else None)
    heart = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hm = heart_mask(size, scale=0.5, cy=0.52)
    white = Image.new("RGBA", (size, size), WHITE)
    heart = Image.composite(white, heart, hm)
    bg.alpha_composite(heart)
    return bg


def circle_icon(size):
    bg = gradient_bg(size, radius_ratio=None)
    hm = heart_mask(size, scale=0.46, cy=0.52)
    white = Image.new("RGBA", (size, size), WHITE)
    heart = Image.composite(white, Image.new("RGBA", (size, size), (0, 0, 0, 0)), hm)
    bg.alpha_composite(heart)
    return bg


def fg_heart(size):
    """Adaptive icon foreground: transparent + heart in central safe zone (~60%)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hm = heart_mask(size, scale=0.33, cy=0.5)  # small, within 66% safe zone
    white = Image.new("RGBA", (size, size), WHITE)
    return Image.composite(white, img, hm)


# Android mipmap launcher densities (px)
DENS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
# Adaptive foreground is drawn on 108dp canvas
FG_DENS = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def main():
    for folder, px in DENS.items():
        d = os.path.join(RES, folder)
        os.makedirs(d, exist_ok=True)
        full_icon(px).save(os.path.join(d, "ic_launcher.png"))
        circle_icon(px).save(os.path.join(d, "ic_launcher_round.png"))
    for folder, px in FG_DENS.items():
        d = os.path.join(RES, folder)
        fg_heart(px).save(os.path.join(d, "ic_launcher_foreground.png"))

    # Native splash: transparent-background white heart, centered over brand color window.
    draw_root = os.path.join(RES, "drawable")
    os.makedirs(draw_root, exist_ok=True)
    splash = Image.new("RGBA", (288, 288), (0, 0, 0, 0))
    sm = heart_mask(288, scale=0.72, cy=0.5)
    splash = Image.composite(Image.new("RGBA", (288, 288), WHITE), splash, sm)
    splash.save(os.path.join(draw_root, "splash_heart.png"))

    # Master 1024 (for reference / stores)
    full_icon(1024).save(os.path.join(ROOT, "tool", "app_icon_master.png"))
    print("Icons generated.")


if __name__ == "__main__":
    main()
