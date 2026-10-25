# PROGRESS — ce qui fonctionne réellement

> Tenu à jour à chaque étape (règle de `CLAUDE.md`). On n'écrit ici que ce qui a été **testé**,
> et on précise comment.

## Environnement

- Godot **4.7.2.stable.official.ed1daf0bf** (version standard, pas .NET), installé dans
  `C:\Users\yaram\Downloads\Godot_v4.7.2-stable_win64.exe\` — vérifié avec `--version` le 25/10/2026.
- Projet Godot : dossier `game/` du dépôt. Rendu Forward+ (D3D12), physique Jolt.
- Tests faits jusqu'ici : vérification des scripts (`--headless --check-only`), lancement du jeu,
  et parties automatiques scriptées avec captures d'écran (scène de test temporaire, supprimée après).
  **Aucune partie jouée à la main par Claude** ; l'utilisateur a lancé le projet dans l'éditeur.

## État au 25/10/2026, avant l'arrivée de `CLAUDE.md` (Milestone 0)

Le dépôt contient déjà un prototype **solo contre l'ordinateur**, « Duel des Cimes »,
porté depuis un prototype web. Ce qui marche (testé en partie automatique + captures, 60 FPS sur RTX 3050 Ti portable) :

| Fonction | État | Où |
|---|---|---|
| Archipel procédural : 2 grandes îles-montagnes à ~460 m, mer jusqu'à l'horizon | ✅ testé | `scripts/world.gd` |
| Rendu cartoon (2 tons, ombres bleutées), ciel à nuages, mer à lignes blanches, herbe/fleurs/cailloux qui suivent la caméra | ✅ testé | `shaders/*.gdshader` |
| Atelier de peinture : peindre son sniper au pinceau en 3D, score de camouflage par terrain | ✅ testé | `scripts/paint.gd`, `shaders/camo.gdshader` |
| Cachette 60 s en 3e personne : marcher, courir, accroupi, couché, vue de tir au clic droit | ✅ testé | `scripts/hider.gd` |
| Calcul de l'exposition (rayons depuis l'île adverse) | ✅ testé | `scripts/main.gd` |
| Brouillard qui se lève (3 s), duel à la lunette x1/x4/x10, souffle, reflet, 5 balles | ✅ testé | `scripts/main.gd`, `scripts/hud.gd` |
| Ennemi ordinateur (jauge de repérage, tirs, choisit une cachette visible) | ✅ testé | `scripts/main.gd` |
| Écran de fin avec conseils | ✅ testé | `scripts/main.gd` |

### Limites connues
- Le personnage n'a **pas de collisions** : il traverse rochers et arbres, il ne saute pas.
- Pas d'Input Map Godot : les touches sont lues directement dans le code.
- Pas de valeurs `@export` ni de ressource de configuration : les réglages sont des constantes.
- `main.gd`, `world.gd` et `hud.gd` font chacun 700+ lignes : à découper (règle « pas de script géant »).
- Pas de manches (meilleur des 5), pas de prolongation, pas de manche nulle.
- Pas de multijoueur.
- La planche `reference_art/DA_Atoll_Concept_Board.png` citée par `CLAUDE.md` **n'est pas présente**
  (ni dans le dépôt, ni dans Téléchargements).

## Journal

- **25/10/2026 — Milestone 0** : `CLAUDE.md` ajouté à la racine du dépôt ; état existant documenté
  ici et dans `docs/PLAN.md` ; écarts avec `CLAUDE.md` listés dans `docs/PLAN.md`. Aucun code modifié.
