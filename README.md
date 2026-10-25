# Les Deux Îles

Duel 1 contre 1 au fusil de précision entre deux îles, pour Steam. Nom de travail.
Moteur : **Godot 4.7.2 stable** (GDScript).

- **`CLAUDE.md`** : document maître de conception (à lire avant toute modification).
- **`docs/PLAN.md`** : étapes et décisions · **`docs/PROGRESS.md`** : ce qui fonctionne réellement ·
  **`docs/TEST_PLAN.md`** : tests · **`docs/DESIGN_DECISIONS.md`** : décisions durables.
- `docs/game-design.md` : historique de l'ancien prototype « Duel des Cimes ».

## Jouer au prototype

1. Ouvrir `game/project.godot` dans Godot 4.7.2.
2. **F5**. Commandes : ZQSD/WASD, souris, Maj (sprint), C (accroupi), Espace (saut),
   Échap (libérer la souris), Tab (changer d'île, outil de test), F1 (aide).

## Structure du projet Godot (`game/`)

- `scenes/main/game_root.tscn` : racine de la partie (scène lancée par F5)
- `scenes/arena/` : l'arène et l'île (posée deux fois, la seconde tournée de 180°)
- `scenes/player/` : le joueur et sa caméra
- `config/game_config.tres` : tous les réglages (vitesses, saut, caméra, distance des îles)
- `scenes/main.tscn` + `scripts/*.gd` à la racine de `scripts/` : ancien prototype « Duel des Cimes »
  (archipel, atelier de peinture), gardé pour plus tard

## Gros fichiers

Images, sons, vidéos et modèles 3D passent par **Git LFS** (`.gitattributes`). Lancer `git lfs install` une fois par ordinateur.
