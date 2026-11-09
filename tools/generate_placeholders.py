#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PHASE 0 - Platzhalter-Generator (nur selbst gezeichnete Pixel, keine Fremd-Assets).

Erzeugt alle Texturen unter res://assets/placeholders/.
Einheit: 1 Tile = 16x16 Texel. Sprites sind 16x16 (Vogel/Branch: 32x16 = 2 Tiles).
Ausnahme laut Master-Prompt: Himmel/Berge duerfen hoeher aufgeloest sein.

Aufruf:  python3 tools/generate_placeholders.py
Abhaengigkeit: Pillow (nur fuer die Generierung, nicht fuer das Spiel).
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

PX = 16
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "placeholders"
OUT.mkdir(parents=True, exist_ok=True)


# --------------------------------------------------------------------------- #
# Hilfsfunktionen
# --------------------------------------------------------------------------- #
def canvas(w: int = PX, h: int = PX, color=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (w, h), color)


def speckled(base, flecks, seed: int, n: int = 38) -> Image.Image:
    im = canvas(color=base)
    d = ImageDraw.Draw(im)
    r = random.Random(seed)
    for _ in range(n):
        d.point((r.randrange(PX), r.randrange(PX)), fill=r.choice(flecks))
    return im


def add_roots(im: Image.Image, seed: int) -> None:
    d = ImageDraw.Draw(im)
    r = random.Random(seed)
    for _ in range(3):
        x, y = r.randrange(2, 14), r.randrange(3, 12)
        d.line([(x, y), (x + 1, y + 2), (x + 1, y + 4)], fill=(44, 32, 24, 255))


def add_pebble(im: Image.Image, seed: int, cx: int = 8, cy: int = 8) -> None:
    d = ImageDraw.Draw(im)
    r = random.Random(seed)
    d.ellipse((cx - 4, cy - 3, cx + 4, cy + 3), fill=(118, 123, 127, 255),
              outline=(66, 70, 74, 255))
    d.point((cx - 1, cy - 1), fill=(156, 160, 162, 255))
    d.point((cx + 2, cy + 1), fill=(92, 96, 100, 255))
    for _ in range(5):
        d.point((r.randrange(1, 15), r.randrange(1, 15)), fill=(104, 98, 88, 255))


def add_cracks(im: Image.Image, seed: int) -> None:
    d = ImageDraw.Draw(im)
    r = random.Random(seed)
    for _ in range(3):
        x, y = r.randrange(2, 13), r.randrange(2, 12)
        d.line([(x, y), (x + 2, y + 3), (x + 1, min(y + 7, 15))],
               fill=(42, 46, 52, 255))


def ash_tile(seed: int, alt: bool = False) -> Image.Image:
    im = speckled((54, 50, 47, 255),
                  [(80, 75, 69, 255), (34, 32, 31, 255), (98, 92, 84, 255)],
                  seed, 46)
    d = ImageDraw.Draw(im)
    for x in range(PX):
        d.point((x, 0), fill=(110, 103, 93, 255) if (x + seed) % 3 else (64, 60, 56, 255))
    r = random.Random(seed + 999)
    for _ in range(3 if not alt else 5):
        x, h = r.randrange(1, 15), r.randrange(2, 5)
        d.line([(x, 3), (x, 3 - h)], fill=(27, 25, 24, 255))
    return im


# --------------------------------------------------------------------------- #
# 1) Boden-Atlas: 17 Slots a 16x16 -> 272x16 px
#    Slot 11 = Reservoir, 12 = Hoehle, 16 = ausgetrocknet (PHASE 2), 14/15 = spaeter.
# --------------------------------------------------------------------------- #
def build_soil_atlas() -> None:
    slots: list[Image.Image] = []

    slots.append(ash_tile(101))                                                    # 0  ASH
    slots.append(speckled((58, 45, 35, 255), [(74, 57, 42, 255), (42, 33, 27, 255)], 102))  # 1 HUMUS

    a = speckled((88, 63, 42, 255), [(68, 48, 33, 255), (104, 76, 50, 255)], 103)  # 2 TOPSOIL_A
    b = speckled((96, 69, 46, 255), [(74, 52, 36, 255), (112, 82, 55, 255)], 104)  # 3 TOPSOIL_B
    add_roots(a, 201)
    add_roots(b, 202)
    slots.extend([a, b])

    c = speckled((88, 63, 42, 255), [(68, 48, 33, 255)], 105)                    # 4 TOPSOIL_STONE
    add_pebble(c, 203)
    slots.append(c)

    a = speckled((116, 78, 52, 255), [(92, 61, 42, 255), (132, 92, 62, 255)], 106)  # 5 CLAY_A
    b = speckled((124, 84, 56, 255), [(98, 66, 45, 255), (140, 98, 66, 255)], 107)  # 6 CLAY_B
    slots.extend([a, b])
    c = speckled((116, 78, 52, 255), [(92, 61, 42, 255)], 108)                    # 7 CLAY_STONE
    add_pebble(c, 204)
    slots.append(c)

    a = speckled((84, 89, 96, 255), [(70, 75, 82, 255), (100, 105, 111, 255)], 109)  # 8 ROCK_A
    b = speckled((72, 77, 84, 255), [(58, 63, 70, 255), (90, 95, 101, 255)], 110)     # 9 ROCK_B
    c = speckled((54, 59, 66, 255), [(42, 47, 53, 255), (68, 73, 80, 255)], 111)      # 10 ROCK_DEEP
    for im, s in ((a, 301), (b, 302), (c, 303)):
        add_cracks(im, s)
    slots.extend([a, b, c])

    water = speckled((52, 108, 150, 255), [(72, 138, 178, 255), (38, 84, 122, 255)], 112, 24)  # 11 WATER (P2)
    d = ImageDraw.Draw(water)
    d.line([(2, 5), (6, 5)], fill=(146, 192, 214, 255))
    slots.append(water)

    cave = speckled((22, 24, 27, 255), [(32, 34, 37, 255), (14, 15, 17, 255)], 113, 20)  # 12 CAVE (P2)
    slots.append(cave)
    slots.append(ash_tile(114, alt=True))                                          # 13 ASH_ALT
    moss = speckled((58, 88, 50, 255), [(72, 104, 58, 255), (42, 68, 40, 255)], 115)  # 14 MOSS (P5)
    slots.append(moss)
    rooted = speckled((84, 60, 40, 255), [(66, 46, 32, 255)], 116)                # 15 ROOTED_SOIL (P1/2)
    add_roots(rooted, 205)
    add_roots(rooted, 206)
    slots.append(rooted)

    # 16 DRY_WATER: optisch deutlich heller als das nasse Reservoir (Slot 11)
    dry = speckled((163, 157, 132, 255), [(186, 180, 156, 255), (140, 134, 112, 255)], 117, 26)
    d = ImageDraw.Draw(dry)
    d.line([(2, 5), (6, 5)], fill=(206, 200, 176, 255))
    d.line([(3, 11), (11, 11)], fill=(120, 114, 96, 255))
    slots.append(dry)

    assert len(slots) == 17
    atlas = canvas(17 * PX, PX)
    for i, tile in enumerate(slots):
        atlas.paste(tile, (i * PX, 0))
    atlas.save(OUT / "soil_atlas.png", optimize=True)


# --------------------------------------------------------------------------- #
# 2) Objekt-Sprites (alle 16x16, ausser Vogel/Ast = 32x16 = 2 Tiles)
# --------------------------------------------------------------------------- #
def build_sprites() -> None:
    # Stamm: vertikal kachelbar
    im = speckled((76, 55, 38, 255), [(52, 38, 28, 255), (98, 71, 47, 255),
                                      (64, 46, 33, 255)], 401, 24)
    d = ImageDraw.Draw(im)
    for x in (1, 6, 11):
        d.line([(x, 0), (x, 15)], fill=(46, 33, 25, 255))
    d.line([(0, 0), (0, 15)], fill=(38, 28, 22, 255))
    d.line([(15, 0), (15, 15)], fill=(38, 28, 22, 255))
    im.save(OUT / "trunk.png", optimize=True)

    # Blatt
    im = canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((2, 3, 13, 13), fill=(78, 124, 58, 255), outline=(46, 84, 40, 255))
    d.ellipse((5, 1, 13, 8), fill=(96, 146, 68, 255))
    d.line([(3, 12), (12, 4)], fill=(50, 88, 42, 255))
    d.line([(7, 3), (7, 10)], fill=(132, 168, 92, 255))
    for xy in [(4, 6), (10, 9), (6, 11), (11, 5)]:
        d.point(xy, fill=(140, 178, 96, 255))
    im.save(OUT / "leaf.png", optimize=True)

    # Wurzel-Segment (transparent, fuer P1/P2). Heller Kern + dunkler Rand,
    # damit die Kette auch auf dunkler Erde / blauem Wasser lesbar bleibt.
    im = canvas()
    d = ImageDraw.Draw(im)
    dark = (54, 36, 24, 255)
    main = (196, 150, 90, 255)
    hi = (230, 196, 132, 255)
    d.line([(7, 0), (7, 12), (9, 15)], fill=dark, width=5)
    d.line([(7, 0), (7, 12), (9, 15)], fill=main, width=3)
    d.line([(7, 0), (7, 12)], fill=hi, width=1)
    for y in (4, 8, 11):
        d.line([(7, y), (3, y + 2)], fill=dark, width=3)
        d.line([(7, y), (3, y + 2)], fill=main, width=1)
        d.line([(8, y + 1), (13, y + 3)], fill=dark, width=3)
        d.line([(8, y + 1), (13, y + 3)], fill=main, width=1)
    im.save(OUT / "root.png", optimize=True)

    # Wurzelspitze (PHASE 2): noch heller, gut anklickbar / als Ghost erkennbar
    im = canvas()
    d = ImageDraw.Draw(im)
    d.line([(7, 0), (7, 12), (9, 15)], fill=dark, width=5)
    d.line([(7, 0), (7, 12), (9, 15)], fill=(232, 186, 108, 255), width=3)
    d.line([(7, 0), (7, 12)], fill=(248, 222, 158, 255), width=1)
    d.rectangle((5, 13, 11, 15), fill=(248, 226, 164, 255))
    for y in (4, 8, 11):
        d.line([(7, y), (3, y + 2)], fill=dark, width=3)
        d.line([(7, y), (3, y + 2)], fill=main, width=1)
        d.line([(8, y + 1), (13, y + 3)], fill=dark, width=3)
        d.line([(8, y + 1), (13, y + 3)], fill=main, width=1)
    im.save(OUT / "root_tip.png", optimize=True)

    # Eichel
    im = canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((4, 6, 11, 15), fill=(150, 104, 56, 255), outline=(96, 64, 36, 255))
    d.ellipse((3, 4, 12, 9), fill=(84, 58, 34, 255), outline=(54, 38, 25, 255))
    d.line([(7, 1), (8, 4)], fill=(54, 38, 25, 255))
    d.point((6, 11), fill=(182, 136, 78, 255))
    im.save(OUT / "acorn.png", optimize=True)

    # Vogel (32x16, P1 Scripted Event); Fluegel oben = Flugpose
    im = canvas(32, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(9, 8), (16, 2), (19, 8), (13, 10)], fill=(70, 66, 62, 255),
              outline=(38, 35, 33, 255))                            # Fluegel
    d.ellipse((10, 7, 22, 12), fill=(58, 54, 51, 255))             # Koerper
    d.ellipse((20, 5, 26, 10), fill=(66, 62, 58, 255))             # Kopf
    d.polygon([(26, 7), (31, 8), (26, 9)], fill=(196, 148, 62, 255))  # Schnabel
    d.polygon([(10, 9), (3, 6), (4, 11)], fill=(48, 45, 43, 255))  # Schwanz
    d.point((23, 7), fill=(232, 226, 210, 255))                     # Auge
    im.save(OUT / "bird.png", optimize=True)

    # Verkohlte Stuempfe: 3 Varianten, 16x32 = 2 Tiles (auf dem 16er-Raster)
    for v in range(3):
        im = canvas(16, 32)
        d = ImageDraw.Draw(im)
        top = (8, 6, 10)[v]
        d.rectangle((2, top, 13, 31), fill=(48, 39, 34, 255), outline=(24, 22, 21, 255))
        d.rectangle((1, 26, 3, 31), fill=(42, 34, 30, 255))  # Wurzelansatz links
        d.rectangle((12, 26, 14, 31), fill=(42, 34, 30, 255))  # Wurzelansatz rechts
        for x in range(2, 14):
            d.point((x, top + (v * 2 + x) % 3), fill=(24, 22, 21, 255))
        for x in (4, 7, 10, 12):
            d.line([(x, top + 2), (x, 31)], fill=(26, 23, 22, 255))
        r = random.Random(500 + v)
        for _ in range(34):
            d.point((r.randrange(2, 14), r.randrange(top, 32)),
                    fill=r.choice([(96, 90, 82, 255), (26, 23, 22, 255), (72, 60, 50, 255)]))
        # verkohlte Bruchkante + Wurzelauslaeufer
        for x in range(2, 14):
            d.point((x, top), fill=(18, 17, 16, 255) if x % 3 else (82, 76, 68, 255))
        d.line([(2, top + 1), (13, top + 1)], fill=(70, 64, 58, 255))
        d.line([(3, 31), (1, 31)], fill=(26, 23, 22, 255))
        d.line([(12, 31), (14, 31)], fill=(26, 23, 22, 255))
        im.save(OUT / f"stump_{'abc'[v]}.png", optimize=True)

    # Liegender verkohlter Ast (32x16)
    im = canvas(32, 16)
    d = ImageDraw.Draw(im)
    d.line([(1, 12), (30, 9)], fill=(38, 32, 29, 255), width=3)
    d.line([(1, 11), (30, 8)], fill=(62, 52, 44, 255))
    d.line([(9, 11), (12, 4)], fill=(38, 32, 29, 255))
    d.line([(21, 10), (24, 5)], fill=(38, 32, 29, 255))
    for xy in [(5, 11), (16, 10), (27, 9)]:
        d.point(xy, fill=(104, 98, 88, 255))
    im.save(OUT / "branch.png", optimize=True)

    # HUD-Icons (PHASE 1): Glucose-Kristall + Wassertropfen
    im = canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((3, 2, 12, 13), fill=(196, 214, 128, 255), outline=(116, 148, 72, 255))
    d.line([(8, 3), (8, 12)], fill=(232, 240, 178, 255))
    d.line([(4, 8), (12, 8)], fill=(232, 240, 178, 255))
    d.point((6, 5), fill=(240, 246, 200, 255))
    im.save(OUT / "glucose.png", optimize=True)

    im = canvas()
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (13, 8), (12, 12), (4, 12), (3, 8)],
              fill=(86, 152, 196, 255), outline=(44, 96, 138, 255))
    d.line([(6, 8), (6, 11)], fill=(164, 208, 232, 255))
    d.point((10, 6), fill=(164, 208, 232, 255))
    im.save(OUT / "water.png", optimize=True)

    # Projekt-Icon 64x64
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 36, 63, 63), fill=(84, 60, 40, 255))
    d.rectangle((0, 36, 63, 39), fill=(52, 48, 44, 255))
    d.line([(32, 36), (32, 16)], fill=(86, 118, 58, 255), width=3)
    d.ellipse((20, 10, 31, 19), fill=(96, 146, 68, 255))
    d.ellipse((33, 12, 44, 21), fill=(78, 128, 58, 255))
    im.save(OUT / "icon.png", optimize=True)


# --------------------------------------------------------------------------- #
# 3) Hintergrund (hoeher aufgeloest erlaubt): Gradient, Sonnen-Dunst, Berge
# --------------------------------------------------------------------------- #
def build_sky() -> None:
    w, h = 32, 540
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    stops = [(0.00, (0.68, 0.72, 0.72)),
             (0.55, (0.80, 0.80, 0.75)),
             (1.00, (0.89, 0.84, 0.73))]

    def color_at(t: float):
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t <= t1:
                k = (t - t0) / (t1 - t0)
                return tuple(c0[j] + (c1[j] - c0[j]) * k for j in range(3))
        return stops[-1][1]

    for y in range(h):
        c = tuple(int(v * 255) for v in color_at(y / (h - 1)))
        d.line([(0, y), (w, y)], fill=c)
    im.save(OUT / "sky_gradient.png", optimize=True)

    # Weicher Sonnen-Dunst (RGBA, radial)
    size = 256
    glow = canvas(size, size)
    px = glow.load()
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - 128, y - 128) / 128.0
            a = max(0.0, 1.0 - r) ** 2 * 92.0
            px[x, y] = (255, 238, 198, int(a))
    glow.save(OUT / "sun_haze.png", optimize=True)


def mountain_layer(path: str, height: int, fill, ridge_color, phase: float, amp: float) -> None:
    """Nahtlos kachelbare Silhouette (ganzzahlige Harmonische => links == rechts)."""
    width = 1024
    im = canvas(width, height)
    d = ImageDraw.Draw(im)
    ridge: list[float] = []
    for x in range(width):
        t = x / width
        v = (math.sin(2 * math.pi * 2 * t + phase) * 0.50
             + math.sin(2 * math.pi * 5 * t + phase * 1.7) * 0.27
             + math.sin(2 * math.pi * 11 * t + phase * 0.6) * 0.13)
        ridge.append(height * 0.46 + v * amp)
    pts = [(x, ridge[x]) for x in range(width)] + [(width - 1, height), (0, height)]
    d.polygon(pts, fill=fill)
    for x in range(width):
        d.point((x, int(ridge[x])), fill=ridge_color)
    im.save(OUT / path, optimize=True)


def build_mountains() -> None:
    mountain_layer("mountains_far.png", 240, (110, 116, 116, 150),
                   (134, 139, 136, 170), 0.4, 54.0)
    mountain_layer("mountains_near.png", 200, (72, 79, 79, 205),
                   (92, 98, 96, 220), 2.1, 44.0)


def build_seed_mound() -> None:
    """PHASE 3: kleiner Erd-Huegel ueber einer flach vergrabenen Eichel.

    Liegt auf der Oberflaeche, ist aber NICHT anklickbar einsammelbar:
    erst eine Wurzel in der Naehe legt die Eichel frei (Master-Punkt 7).
    """
    im = canvas()
    d = ImageDraw.Draw(im)
    # Halbrunder Huegel, unten bündig mit der Oberkante des Bodens.
    d.polygon([(0, 15), (1, 12), (3, 9), (5, 7), (8, 6),
               (11, 7), (13, 9), (15, 12), (15, 15)],
              fill=(74, 52, 36, 255), outline=(46, 33, 24, 255))
    d.line([(2, 13), (5, 10), (8, 8), (11, 10), (14, 13)],
           fill=(104, 76, 50, 255))
    for xy in [(3, 12), (6, 11), (9, 9), (12, 12), (7, 14), (11, 14)]:
        d.point(xy, fill=(128, 96, 64, 255))
    # Ein kleiner Spalt deutet die vergrabene Eichel an.
    d.line([(7, 14), (8, 12), (9, 14)], fill=(182, 136, 78, 255))
    im.save(OUT / "seed_mound.png", optimize=True)


if __name__ == "__main__":
    build_soil_atlas()
    build_sprites()
    build_seed_mound()
    build_sky()
    build_mountains()
    print(f"[placeholders] {len(list(OUT.glob('*.png')))} PNGs -> {OUT}")
