"""Outil : fabrique le relief de la vallée (deux îles-montagnes et les montagnes du fond).

    python3 tools/relief.py /chemin/relief.bin
    python3 tools/relief.py /chemin/relief.bin sources/higgsfield   # îles de duel d'après les cartes Higgsfield

Écrit les hauteurs (float32) puis les zones (uint8), grille de (SEG + 1)² points comme dans world.gd ;
tools/relief_vers_godot.gd les range ensuite dans game/data/.

Étapes : massif de chaque montagne (forme irrégulière, sommets secondaires) + bruit en crêtes
(« ridged multifractal », avec déformation du domaine) ; puis érosion simulée : l'eau qui ruisselle
creuse des ravines (plus il y a d'eau qui passe, plus elle creuse) et les éboulis glissent jusqu'à
une pente d'équilibre. Les zones (neige, roche, herbe, forêt) dépendent de l'altitude, de la pente
et de l'eau qui ruisselle.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

S = 1400.0
SEG = 320
CELL = S / SEG
MZ = 230.0
WATER_Y = 26.0
W = SEG + 1
rng = np.random.default_rng(20261028)

xs = -S / 2 + np.arange(W) * CELL
X, Z = np.meshgrid(xs, xs)          # X[r, c] = x, Z[r, c] = z (r : ligne = z)


# ---------- Bruit ----------
_perm = rng.permutation(256)
_perm = np.concatenate([_perm, _perm])
_grad = rng.normal(size=(256, 2))
_grad /= np.linalg.norm(_grad, axis=1, keepdims=True)


def noise(x, z):
    """Bruit de gradient (Perlin) vectorisé, environ dans [-1, 1]."""
    xi = np.floor(x).astype(int)
    zi = np.floor(z).astype(int)
    xf = x - xi
    zf = z - zi
    xi &= 255
    zi &= 255

    def g(ix, iz, dx, dz):
        h = _perm[_perm[ix] + iz]
        gv = _grad[h]
        return gv[..., 0] * dx + gv[..., 1] * dz

    u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    v = zf * zf * zf * (zf * (zf * 6 - 15) + 10)
    n00 = g(xi, zi, xf, zf)
    n10 = g(xi + 1, zi, xf - 1, zf)
    n01 = g(xi, zi + 1, xf, zf - 1)
    n11 = g(xi + 1, zi + 1, xf - 1, zf - 1)
    return ((n00 * (1 - u) + n10 * u) * (1 - v) + (n01 * (1 - u) + n11 * u) * v) * 1.41


def fbm(x, z, octaves=5):
    s = 0.0
    a = 0.5
    for i in range(octaves):
        s = s + a * noise(x + i * 17.3, z - i * 9.1)
        x = x * 2.03
        z = z * 2.03
        a *= 0.5
    return s


def ridged(x, z, octaves=6):
    """Crêtes : 1 - |bruit|, chaque octave pondérée par la précédente (crêtes nettes, vallées douces)."""
    s = 0.0
    amp = 0.5
    weight = 1.0
    for i in range(octaves):
        n = 1.0 - np.abs(noise(x + i * 31.7, z + i * 12.9))
        n = n * n * weight
        weight = np.clip(n * 1.6, 0.0, 1.0)
        s = s + n * amp
        x = x * 2.05
        z = z * 2.05
        amp *= 0.5
    return s


# ---------- Massifs ----------
# Montagnes : x, z, hauteur, largeur, longueur de la ligne de crête, orientation (rad).
# Les deux premières sont les îles du duel : crête en travers de la vue (le long de x), donc l'adversaire
# voit une vraie ligne de sommets et de cols, pas un cône.
MASSIFS = [
    (0, -MZ, 205, 205, 280, 0.0), (0, MZ, 205, 205, 280, 0.0),
    (-290, -360, 150, 130, 180, 0.9), (310, -380, 170, 140, 220, -0.6),
    (-300, 330, 145, 130, 200, -0.8), (330, 350, 140, 120, 160, 0.5),
    (0, -600, 270, 200, 600, 0.05), (0, 600, 260, 200, 560, -0.05),
    (-580, 0, 230, 180, 420, 1.45), (580, 0, 230, 180, 420, 1.62),
]

# Domaine déformé : les formes ne sont plus régulières.
wx = X + fbm(X * 0.004 + 5.2, Z * 0.004 + 1.3, 4) * 70.0
wz = Z + fbm(X * 0.004 - 7.7, Z * 0.004 + 3.1, 4) * 70.0
rough = fbm(wx * 0.02, wz * 0.02, 4)

# Îles de duel d'après deux cartes de hauteurs générées avec Higgsfield (GPT Image 2.5) : relief_ile_nord.png
# (île ennemie, z < 0) et relief_ile_sud.png (île du joueur), 1024 × 512 px, noir = mer, blanc = sommets.
HF_DIR = sys.argv[2] if len(sys.argv) > 2 else None
HF_M_PER_PX_X = 0.85    # 1024 px = 870 m d'est en ouest
HF_M_PER_PX_Z = 0.72    # 512 px = 369 m du nord au sud (bras de mer d'environ 100 m entre les deux îles)
HF_DETAIL = 0.45        # part des petites crêtes et ravines de l'image (1 = toutes)
HF_FOOT = 150            # largeur du pied des montagnes (px de l'image, ≈ 110 m)
HF_COAST = 22.0         # valeur de gris du rivage
HF_PEAK = 125.0         # hauteur des plus hauts sommets au-dessus de la mer
HF_BACK = 45.0          # crête principale reculée de 45 m derrière le centre des cachettes (sinon elle cache la moitié de l'île)


def higgsfield_island(path, cz):
    """Hauteurs (grille du jeu) d'une île décrite par une carte de hauteurs ; -inf hors de l'image."""
    img = np.asarray(Image.open(path).convert("L")).astype(float)
    ih, iw = img.shape
    # Coordonnées image de chaque point de la grille (centre de l'image au centre de l'île).
    px = X / HF_M_PER_PX_X + iw / 2.0
    py = (Z - cz) / HF_M_PER_PX_Z + ih / 2.0
    inside = (px >= 0) & (px < iw - 1) & (py >= 0) & (py < ih - 1)
    # Lissage à l'échelle de la grille (4,4 m = 6 px) : moyenne d'un carré de 11 px (adoucit les pentes : on doit pouvoir y marcher), puis lecture bilinéaire.
    box = np.asarray(Image.open(path).convert("L").filter(ImageFilter.BoxBlur(5))).astype(float)
    x0 = np.clip(px.astype(int), 0, iw - 2)
    y0 = np.clip(py.astype(int), 0, ih - 2)
    fx = np.clip(px - x0, 0, 1)
    fy = np.clip(py - y0, 0, 1)
    v = (box[y0, x0] * (1 - fx) * (1 - fy) + box[y0, x0 + 1] * fx * (1 - fy)
         + box[y0 + 1, x0] * (1 - fx) * fy + box[y0 + 1, x0 + 1] * fx * fy)
    # Contour de l'île : l'image très floutée (carré de 51 px ≈ 40 m), pour que les vallées sombres
    # restent des vallées et ne deviennent pas des bras de mer.
    big = np.asarray(Image.open(path).convert("L").filter(ImageFilter.BoxBlur(25))).astype(float)
    s = (big[y0, x0] * (1 - fx) * (1 - fy) + big[y0, x0 + 1] * fx * (1 - fy)
         + big[y0 + 1, x0] * (1 - fx) * fy + big[y0 + 1, x0 + 1] * fx * fy)
    shore = np.clip((s - HF_COAST) / 25.0, 0, 1)          # 0 en mer, 1 à l'intérieur des terres
    shore = shore * shore * (3 - 2 * shore)
    # Grandes formes de l'image gardées entières, petites crêtes atténuées : à 1 400 m de jeu, les crêtes
    # de 50 m tous les 30 m cachaient tout (lignes de vue 5 % au lieu de 18 %).
    huge = np.asarray(Image.open(path).convert("L").filter(ImageFilter.BoxBlur(60))).astype(float)
    g = (huge[y0, x0] * (1 - fx) * (1 - fy) + huge[y0, x0 + 1] * fx * (1 - fy)
         + huge[y0 + 1, x0] * (1 - fx) * fy + huge[y0 + 1, x0 + 1] * fx * fy)
    form = g * 1.6 + HF_DETAIL * (v - g)     # grandes formes (carré de 120 px ≈ 100 m), un peu relevées
    relief = np.clip(form / 255.0, 0, 1) ** 0.8 * HF_PEAK
    # Pied des montagnes : le relief monte progressivement sur ~80 m depuis le rivage (sinon les îles sortent
    # de l'eau comme des murailles de 80 m).
    landimg = Image.fromarray(((big > HF_COAST) * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(HF_FOOT))
    lm = np.asarray(landimg).astype(float) / 255.0
    l = (lm[y0, x0] * (1 - fx) * (1 - fy) + lm[y0, x0 + 1] * fx * (1 - fy)
         + lm[y0 + 1, x0] * (1 - fx) * fy + lm[y0 + 1, x0 + 1] * fx * fy)
    ramp = np.clip((l - 0.5) * 2.0, 0, 1)
    ramp = ramp * ramp * (3 - 2 * ramp)
    h = -30.0 + shore * (WATER_Y + 30.0 + 4.0) + shore * ramp * relief
    return np.where(inside, h, -np.inf)


H = np.full_like(X, -30.0)
for i, (mx, mz, mh, mr, ml, ang) in enumerate(MASSIFS):
    if HF_DIR and i < 2:
        continue  # les deux îles de duel viennent des cartes Higgsfield
    ca, sa = np.cos(ang), np.sin(ang)
    u = (wx - mx) * ca + (wz - mz) * sa          # le long de la crête
    v = -(wx - mx) * sa + (wz - mz) * ca         # en travers
    t = np.clip(u / (ml / 2), -1, 1)
    along = np.abs(u) - ml / 2
    d = np.sqrt(np.maximum(along, 0) ** 2 + v * v) / (mr * 1.3)
    # Hauteur le long de la crête : plusieurs sommets et des cols.
    peaks = 0.62 + 0.38 * ridged(t * 2.6 + i * 3.1, np.full_like(t, i * 1.7), 3) / 0.8
    peaks *= 1.0 - 0.25 * t * t
    # Profil concave : raide sous la crête, de plus en plus doux vers le pied.
    base = mh * peaks * np.exp(-2.0 * d) * (1.0 - np.clip((d - 1.0) / 0.8, 0, 1))
    # Ravines et éperons qui descendent les versants (crêtes de bruit allongées dans le sens de la pente).
    gully = ridged(u * 0.0075 + rough * 0.6 + i * 7.0, v * 0.003 + i * 3.0, 4)
    small = ridged(wx * 0.008 + i, wz * 0.008 - i, 4)
    k = np.clip(base / mh, 0, 1)
    m = base * (0.76 + 0.32 * (gully - 0.42) * np.clip(d * 3.0, 0, 1) + 0.3 * (small - 0.42) * (0.3 + 0.7 * k))
    H = np.maximum(H, m) + np.clip(np.minimum(H, m), 0, None) * 0.3   # deux massifs qui se touchent : un col
HF_MASK = np.zeros_like(X, dtype=bool)
if HF_DIR:
    for name, cz in (("relief_ile_nord.png", -MZ - HF_BACK), ("relief_ile_sud.png", MZ + HF_BACK)):
        hi = higgsfield_island(HF_DIR + "/" + name, cz)
        HF_MASK |= hi > WATER_Y
        H = np.maximum(H, hi)
# Un bras de mer entre les deux îles du duel : la vallée est sous l'eau.
strait = np.exp(-((wz / 85.0) ** 2)) * (1.0 - np.clip((np.abs(X) - 380.0) / 120.0, 0, 1))
H = H - strait * np.clip(H + 20.0, 0, None) * 0.9
# Contreforts et collines, plus de petites bosses partout.
H += 9.0 * fbm(X * 0.008, Z * 0.008, 4) + 3.0 * rough
edge = np.maximum(np.abs(X), np.abs(Z))
t = np.clip((edge - 540.0) / 150.0, 0, 1)
t = t * t * (3 - 2 * t)
H = H * (1 - t) - 60.0 * t


# ---------- Érosion ----------
NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
DIST = np.array([np.hypot(a, b) for a, b in NB]) * CELL


def shifted(a, dr, dc):
    out = np.full_like(a, np.inf)
    rs = slice(max(dr, 0), W + min(dr, 0))
    rd = slice(max(-dr, 0), W + min(-dr, 0))
    cs = slice(max(dc, 0), W + min(dc, 0))
    cd = slice(max(-dc, 0), W + min(-dc, 0))
    out[rd, cd] = a[rs, cs]
    return out


def flow(h):
    """Écoulement : chaque point envoie son eau vers son voisin le plus bas (D8) ; renvoie le débit et la pente."""
    slopes = np.stack([(h - shifted(h, dr, dc)) / DIST[i] for i, (dr, dc) in enumerate(NB)])
    k = np.argmax(slopes, axis=0)
    s = np.max(slopes, axis=0)
    rr, cc = np.indices(h.shape)
    tr = np.clip(rr + np.array([n[0] for n in NB])[k], 0, W - 1)
    tc = np.clip(cc + np.array([n[1] for n in NB])[k], 0, W - 1)
    target = tr * W + tc
    order = np.argsort(-h, axis=None)
    acc = np.ones(W * W)
    tflat = target.ravel()
    sflat = s.ravel()
    for i in order:
        if sflat[i] > 0:
            acc[tflat[i]] += acc[i]
    return acc.reshape(h.shape), np.maximum(s, 0.0)


def thermal(h, talus, rate=0.2, it=8):
    for _ in range(it):
        out = np.zeros_like(h)
        inn = np.zeros_like(h)
        for i, (dr, dc) in enumerate(NB):
            nb = np.roll(np.roll(h, -dr, 0), -dc, 1)
            diff = h - nb - talus * DIST[i]
            move = np.clip(diff, 0, None) * rate / 8.0
            move[0, :] = move[-1, :] = 0
            move[:, 0] = move[:, -1] = 0
            out += move
            inn += np.roll(np.roll(move, dr, 0), dc, 1)
        h = h - out + inn
    return h


H_BEFORE = H.copy()
land = H > WATER_Y - 10
print("relief de départ : %.1f à %.1f m" % (H.min(), H.max()))
for step in range(60):
    acc, s = flow(H)
    # Puissance du courant : plus de débit et plus de pente = plus d'érosion (ravines, vallées).
    e = 0.011 * np.sqrt(acc * CELL * CELL) * np.minimum(s, 1.5) ** 1.1
    e = np.minimum(e, 3.0) * land
    H = H - e
    H = thermal(H, talus=0.85, rate=0.25, it=2)
    if step % 10 == 0:
        print("érosion %d/60 : débit max %.0f, creusé max %.2f m" % (step, acc.max(), e.max()))
H = thermal(H, talus=0.68, rate=0.3, it=12)
if HF_DIR:
    # Les cartes Higgsfield sont déjà érodées : l'érosion du jeu ne fait que creuser les ravines,
    # on garde surtout les hauteurs de l'image (sinon les sommets s'affaissent de 50 m).
    H = np.where(HF_MASK, 0.35 * H + 0.65 * H_BEFORE, H)
acc, s = flow(H)

# ---------- Zones ----------
ZN = {"neige": 0, "roche": 1, "herbe": 2, "foret": 3}
gz, gx = np.gradient(H, CELL)
slope = np.hypot(gx, gz)
n1 = fbm(X * 0.025 + 11.0, Z * 0.025 - 7.0, 3)
n2 = fbm(X * 0.018 - 40.0, Z * 0.018 + 90.0, 3)
wet = np.log1p(acc) / np.log1p(acc.max())
zones = np.full(H.shape, ZN["herbe"], np.uint8)
# Îles Higgsfield : plus hautes et plus raides ; on relève les seuils pour garder la même part de forêt
# (le couvert du jeu : arbres et rochers) et de roche qu'avec l'ancien relief.
ALT = 32.0 if HF_DIR else 0.0
SLO = 0.3 if HF_DIR else 0.0
forest = (n2 + wet * 0.45 > 0.05) & (H < 105 + ALT + n1 * 18) & (slope < 0.85 + SLO)
zones[forest] = ZN["foret"]
rock = (slope > 0.9 + SLO + n1 * 0.15) | (H > 118 + ALT + n1 * 18)
zones[rock] = ZN["roche"]
snow = (H > 128 + ALT + n1 * 16) & (slope < 1.25 + n1 * 0.2)
zones[snow] = ZN["neige"]
for k, v in ZN.items():
    print("zone %s : %.1f %%" % (k, 100.0 * np.mean(zones[H > WATER_Y] == v)))
print("relief final : %.1f à %.1f m ; pente moyenne (terre) %.2f" % (H.min(), H.max(), slope[H > WATER_Y].mean()))

with open(sys.argv[1], "wb") as f:
    f.write(H.astype(np.float32).tobytes())
    f.write(zones.tobytes())
