"""Masque de la peau du sniper : game/art/sniper_peau.png (blanc = peau : visage, cou, mains).

  python3 tools/masque_peau.py

La tenue de camouflage et la peinture ne vont que sur les vêtements : la peau garde la couleur de la texture
d'origine du modèle 3D (art/sniper_couleur.jpg, Higgsfield). La peau est la seule partie rosée de la texture.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
a = np.asarray(Image.open(os.path.join(ROOT, "game", "art", "sniper_couleur.jpg")).convert("RGB")).astype(float) / 255.0
r, g, b = a[..., 0], a[..., 1], a[..., 2]
skin = (r > g * 1.18) & (r > b * 1.15) & (r > 0.22)
m = Image.fromarray((skin * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
m = m.resize((512, 512), Image.LANCZOS)
out = os.path.join(ROOT, "game", "art", "sniper_peau.png")
m.save(out, optimize=True)
print("sniper_peau.png : %d Ko, peau %.1f %%" % (os.path.getsize(out) // 1024, skin.mean() * 100))
