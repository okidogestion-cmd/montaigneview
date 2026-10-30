"""Textures du sol créées avec Higgsfield (sources/higgsfield/textures/) → cartes du jeu (game/art/).

  python3 tools/textures_higgsfield.py

- sol_*.jpg : « cartes de détail » lues par terrain.gdshader (moyenne 0,5 : la couleur moyenne reste celle
  de la zone, donc le camouflage ne change pas), rendues raccordables (aucune couture quand elles se répètent).
- relief_roche.jpg, relief_herbe.jpg : cartes de relief (normales) tirées des mêmes images.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "sources", "higgsfield", "textures")
OUT = os.path.join(ROOT, "game", "art")
SIZE = 512

# Texture du jeu ← image Higgsfield, force du contraste, part de couleur gardée
SOLS = {
    "roche": ("falaise", 1.0, 0.35),
    "herbe": ("herbe", 0.85, 0.55),
    "foret": ("foret", 0.9, 0.5),
    "neige": ("neige", 0.7, 0.2),
    "sable": ("eboulis", 0.8, 0.3),   # rivage : galets et graviers
}


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, name + ".jpg")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)).astype(float) / 255.0


def seamless(a):
    """Mélange l'image avec elle-même décalée d'une demi-taille : les bords se raccordent."""
    n = a.shape[0]
    t = np.minimum(np.arange(n), n - 1 - np.arange(n)) / (n / 2.0)       # 0 au bord, 1 au centre
    m = np.clip(np.minimum.outer(t, t) * 2.2, 0, 1)
    m = m * m * (3 - 2 * m)
    r = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    return a * m[..., None] + r * (1 - m[..., None]) if a.ndim == 3 else a * m + r * (1 - m)


def detail(a, contrast, color):
    lum = a @ np.array([0.299, 0.587, 0.114])
    rel_l = lum / lum.mean()
    rel_c = a / a.reshape(-1, 3).mean(0)
    rel = rel_l[..., None] * (1 - color) + rel_c * color
    return np.clip(0.5 + (rel - 1.0) * 0.5 * contrast, 0, 1)


def normal_map(a, strength):
    h = seamless(a @ np.array([0.299, 0.587, 0.114]))
    h = np.asarray(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255.0
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save(a, name):
    path = os.path.join(OUT, name)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(path, quality=88)
    print("%s : %d Ko" % (name, os.path.getsize(path) // 1024))


for game_name, (src, contrast, color) in SOLS.items():
    save(seamless(detail(load(src), contrast, color)), "sol_%s.jpg" % game_name)
save(normal_map(load("falaise"), 6.0), "relief_roche.jpg")
save(normal_map(load("herbe"), 4.0)[::2, ::2], "relief_herbe.jpg")
