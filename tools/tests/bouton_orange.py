# Centre du plus grand bouton orange de la capture (JOUER, PRÊT) : x y
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
w, h = im.size
px = im.load()
pts = [(x, y) for y in range(0, h, 2) for x in range(0, w, 2)
       if (lambda r, g, b: r > 200 and 90 < g < 150 and b < 80)(*px[x, y])]
# garder la ligne d'orange la plus basse (le bouton, pas le titre)
if not pts:
    print(w // 2, h // 2); sys.exit()
ys = sorted(set(y for _, y in pts))
groups, cur = [], [ys[0]]
for y in ys[1:]:
    if y - cur[-1] <= 4: cur.append(y)
    else: groups.append(cur); cur = [y]
groups.append(cur)
g = max(groups, key=lambda g: sum(1 for p in pts if p[1] in set(g)))
sel = [p for p in pts if p[1] in set(g)]
print(sum(p[0] for p in sel) // len(sel), sum(p[1] for p in sel) // len(sel))
