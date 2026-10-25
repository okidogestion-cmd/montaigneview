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
- **25/10/2026 — Milestone 1 (terrain jouable)** : fait. Détail ci-dessous.

## Milestone 1 — ce qui fonctionne réellement (25/10/2026)

Scène principale : `scenes/main/game_root.tscn`. L'ancien prototype reste ouvrable : `scenes/main.tscn`.

Testé par une partie scriptée (scène de test temporaire qui appuie sur les vraies actions de l'Input Map,
puis vérifie positions et collisions), Godot 4.7.2, fenêtre 1280×720, RTX 3050 Ti portable :

| Vérification | Résultat |
|---|---|
| Les 12 actions de l'Input Map existent (déplacement, sprint, accroupi, saut, visée, tir, zoom, réarmer, pause…) | ✅ |
| Le joueur apparaît au sol, derrière la cabane | ✅ |
| Marche : 5,7 m en 1,5 s (≈ 4,5 m/s, accélération comprise) | ✅ |
| Sprint plus rapide que la marche : 6,6 m contre 4,2 m en 1 s | ✅ |
| Saut : ≈ +0,9 m, puis retour au sol | ✅ |
| Accroupi (capsule 1,15 m) puis relevé | ✅ |
| Le mur avant de la cabane bloque le joueur | ✅ |
| Chute à l'eau → retour au point d'apparition | ✅ |
| Points d'apparition A et B symétriques (même hauteur, même distance au centre) | ✅ |
| Spawn A invisible depuis 6 postes de l'île B (tour, éperon, ruine, plages) — test par rayons | ✅ |
| On monte sur la plate-forme de la tour par la rampe (y ≈ 6,9 m) | ✅ (joueur posé en haut, pas l'ascension complète) |
| Au sol sur l'île B après changement d'île (Tab) | ✅ |
| 60 images/s | ✅ |

### Non testé / limites
- **Pas joué à la main** : la souris (caméra), Échap et le clic pour reprendre n'ont pas été testés par une personne.
- L'ascension complète de la rampe de la tour n'a pas été testée (le joueur a été posé sur la plate-forme).
- Mannequin, rochers, palmiers, cabane : **placeholders** en formes simples, pas des assets finaux.
- L'accroupi « tasse » le mannequin (pas d'animation).
- Pas encore de son de vagues (prévu par `CLAUDE.md` §4, à ajouter).
- La planche de référence `reference_art/DA_Atoll_Concept_Board.png` n'est toujours pas disponible.
