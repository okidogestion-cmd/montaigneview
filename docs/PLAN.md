# PLAN — étapes et décisions

> Source de vérité : `CLAUDE.md` (racine du dépôt). Ce fichier suit les étapes et les décisions.
> Ce qui est réellement testé est dans `docs/PROGRESS.md`.

## Où en est-on

- **Milestone 0 — Inspection et base** : fait le 25/10/2026 (voir PROGRESS).
- **Milestone 1 — Terrain jouable** : fait le 25/10/2026 (voir PROGRESS).
- **Milestone 2 — Boucle de manche hors ligne** : prochaine étape (préparation 60 s, transition 3 s, duel 120 s, prolongation 30 s, meilleur des 5, cible d'entraînement).

## Écarts entre le prototype existant et `CLAUDE.md`

| Sujet | Prototype actuel | `CLAUDE.md` |
|---|---|---|
| Joueurs | Solo contre l'ordinateur | Multijoueur 1 contre 1 (LAN puis Steam) ; entraînement solo avec cible |
| Arène | 2 grandes montagnes procédurales à ~460 m | 2 petites îles construites à la main, **35–50 m** de diamètre, à **80–100 m**, symétriques en avantages |
| Décor | Sapins, arbres ronds, rochers, herbe | Tour de guet, ruine, cabane, palmiers, rochers/falaises, quai, fanions |
| Personnage | Pas de collisions, pas de saut | `CharacterBody3D` : marche, sprint, accroupi, saut, collisions |
| Commandes | Touches lues dans le code | Input Map Godot (WASD, Shift, C, Espace, E, clic droit visée, clic gauche tir, molette, R, Échap) |
| Lunette | x1 / x4 / x10, souffle, reflet | 2× / 4× / 6×, visée au clic droit, pas de dispersion |
| Règles | Une manche, l'ordinateur repère selon une jauge | Meilleur des 5, préparation 60 s, transition 3 s, duel 120 s, prolongation 30 s, manche nulle |
| Camouflage peint | Atelier de peinture + score | Non prévu (les cosmétiques sont hors périmètre) |
| Architecture | 5 gros scripts | Petites scènes (`player.tscn`, `island_arena.tscn`, `hud.tscn`…), autoloads `GameState`/`NetworkManager`… |
| Réglages | Constantes | `@export` ou ressource de configuration |
| Palette | Verts/gris « montagne » | Palette « Atoll peint » (`#73C7F2`, `#238EB6`, `#EBCB86`, `#78A957`…) |
| Nom | « Duel des Cimes » / dépôt `montaigneview` | « Les Deux Îles » (nom de travail) |

## Décisions

- **25/10/2026** — `CLAUDE.md` est placé à la racine du dépôt (le projet Godot est dans `game/`,
  donc il n'est pas dans `res://` comme dans l'arborescence indicative) : Claude Code le lit à la racine.
- **25/10/2026** — Les fichiers `.uid` créés par Godot 4.7 sont versionnés (recommandation Godot).

### Tranché avec l'utilisateur le 25/10/2026
1. **Arène :** reconstruite selon `CLAUDE.md` (deux petites îles symétriques à ~90 m).
   L'archipel procédural reste dans l'historique et dans l'ancienne scène `scenes/main.tscn`.
2. **Atelier de peinture :** gardé dans le code (`scripts/paint.gd`, `shaders/camo.gdshader`)
   mais **hors de la boucle principale** ; à rebrancher quand le 1v1 fonctionne.
3. **Entraînement :** une simple cible (Milestone 2), pas l'ennemi ordinateur du prototype.

## Stratégie technique proposée pour le Milestone 1

1. Nouvelle scène `scenes/arena/island_arena.tscn` (script `scripts/arena/island_arena.gd`) :
   deux îles blockout en meshes simples avec `StaticBody3D`, mer (shader existant réutilisé),
   ciel, deux `Marker3D` de spawn protégés, couverts (rochers, murets, palmiers, tour) avec collisions.
2. `scenes/player/player.tscn` : `CharacterBody3D` + `CollisionShape3D` (capsule),
   script `scripts/player/player_controller.gd` (marche, sprint, accroupi, saut, gravité, retour au spawn si chute à l'eau).
3. `scenes/player/player_camera_rig.tscn` : caméra 3e personne à l'épaule, `SpringArm3D` pour ne pas traverser les décors.
4. Input Map déclarée dans `project.godot`.
5. Réglages dans une ressource `GameConfig` (`.tres`) : vitesses, saut, sensibilité, distance des îles.
6. Le prototype actuel reste jouable (scène actuelle conservée) tant que la nouvelle arène n'est pas validée.
