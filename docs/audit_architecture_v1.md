# Audit — Architecture technique V1 (étape 1)

Date : 30/10/2026. État audité : `main` au commit `236f137` (son Kar98k), artefact version 16.
**Aucune modification du jeu dans cette étape.** Captures « avant » : `docs/audit/avant/`.

## 1. Moteur et rendu

| Point | État actuel | Écart avec le brief |
|---|---|---|
| Version | Godot 4.7.2 stable | OK (Godot 4) |
| Rendu | `rendering_method="mobile"` dans `project.godot` ; l'artefact web tourne en **Compatibility (WebGL 2)** | Brief : Forward+/Vulkan. **Forward+ n'existe pas sur le web** : passer en Forward+ casserait l'artefact et le test sur iPhone. |
| Physique | Jolt Physics | OK |
| Résolution / AA | fenêtre 1280×720, MSAA 2x, ombres 2048 | Brief : 1080p / 60 FPS PC |
| Shaders | couleurs corrigées à la main (`pow(2.2)`) réglées pour Compatibility | À revérifier si on change de rendu |

## 2. Scènes et scripts

- Une seule scène : `scenes/main.tscn` (Node3D + `main.gd`). **Tout le reste est construit par le code** (pas de scène joueur, arme, caméra).
- Scripts (3 706 lignes) :

| Script | Lignes | Rôle |
|---|---|---|
| `main.gd` | 952 | **Objet central** : phases (menu, atelier, cachette, révélation, tir), entrées, caméra, tir, IA, sons, atelier camouflage |
| `world.gd` | 1 071 | Terrain, eau, végétation, accessoires, cachettes, **personnages** (animation, postures, ghillie), sprites |
| `hud.gd` | 823 | Interface (menus, atelier, lunette, barres) |
| `life.gd` | 254 | Vie du décor (oiseaux, etc.) |
| `paint.gd` | 233 | Camouflage : peinture (mode à part) + tenues |
| `hider.gd` | 190 | Déplacement du joueur en phase cachette + caméra 3e personne |
| `touch_controls.gd` | 136 | Commandes tactiles |
| `vegetation.gd` | 47 | Petits utilitaires de végétation |

## 3. Personnage

- Modèle Higgsfield animé avec la Universal Animation Library (`game/art/sniper_anime.scn`, fabriqué par `tools/sniper_anime.gd`), fusil rigide sur le dos.
- Postures : debout / accroupi / couché (`hider.set_stance`, `world.set_stance`), animations choisies par vitesse (`world.animate_figure`).
- **Pas de postures « visée » ni « tir » sur le modèle** : en phase de tir, le corps n'est plus utilisé, seule la caméra compte.
- Déplacement (`hider.physics_step`) et visuel (`hider._apply`, `update_visual`) sont déjà séparés ; l'animation est dans `world.gd`.

## 4. Caméra actuelle

| Situation | Où | Comment |
|---|---|---|
| Cachette (3e personne) | `hider.place_camera` | Caméra au-dessus de l'épaule (décalage 0,45 m), hauteur/distance par posture, **rayon** contre le décor + lissage. Pas de `SpringArm3D`. |
| Aperçu clic droit | `hider.first_person` | Bascule instantanée à l'œil (coupure, pas de transition) |
| Tir | `main._process`, `aim_at`, `_look`, `cycle_zoom` | Caméra fixe à `hider.eye()`, zoom x1 / x4 / x10 (`FIRE_FOV` 55 / 14 / 5,5), balancement, souffle, recul |
| Atelier | `main._place_workshop_camera` | Orbite autour du personnage |
| Médaillon | `main` (SubViewport + 2e Camera3D) | Vue de l'adversaire |

**Constat** : une seule `Camera3D` pilotée par trois endroits (`main.gd`, `hider.gd`, atelier). La caméra **ne commande pas** le tir ni la détection (le tir part de `camera` mais l'IA et la détection n'en dépendent pas), mais en cachette la direction de marche suit `cam_yaw` (`hider.forward`).

## 5. Tir

- `main.shoot()` : tir instantané (rayon), temps de vol = distance / 900, 5 balles, 1,3 s entre deux tirs, recul.
- Tir ennemi : `main.ai_shoot()`, flash à `world.muzzle()`, son retardé distance / 343.
- **Pas d'arme visible en vue de tir** (ni modèle 1re personne, ni lunette 3D) : la lunette est un cache d'interface (`hud.set_scope`). Donc **pas de doublon d'arme** aujourd'hui.

## 6. Camouflage et détection

- Détection (`main.detect_rate`) = score de camouflage × posture × exposition (rayons depuis les cachettes ennemies) + reflet de la lunette.
- Tenues (`paint.gd`, `OUTFITS`) : 4 motifs (Woodland, Terrain sec, Arctique, Digital olive) avec **une table de pourcentages par zone fixée à la main**, + 0,1 pour le ghillie.
- **Écart avec le brief** (« ne pas remplacer par un simple pourcentage arbitraire ») : c'est exactement ce que fait la table des tenues. La mesure couleur-contre-terrain existe toujours mais seulement pour le mode peinture (`PAINT_MODE = false`).
- Type de terrain : zones `neige / roche / herbe / foret` précalculées dans `game/data/relief_320_*.res`.

## 7. Interface

- `hud.gd` construit toute l'interface en code (pas de scènes UI). Réticule, cache de lunette, barres (souffle, œil ennemi), atelier « Camouflage ».

## 8. Monde et performances

- Relief 1 400 m (grille 321²) calculé hors jeu (`tools/relief.py`), collision en **maillage complet** 321².
- Végétation en MultiMesh par carrés de 175 m ; **ni LOD, ni distance de visibilité, ni occultation** ; herbe recyclée autour de la caméra.
- Arbres : 7 modèles du pack ; accessoires Higgsfield ; ciel peint + nuages.

## 9. Organisation des assets

- `game/art/` 5 Mo, `game/data/` 512 Ko, `sources/` 13 Mo, outils de fabrication dans `tools/`.
- Images, sons, 3D : Git LFS sauf les exceptions de `.gitattributes` (LFS injoignable depuis le cloud).

## 10. Points à trancher à l'étape 2 (proposition)

1. **Rendu** : Forward+ casse la version web/iPhone. Proposition : garder Compatibility pour l'artefact et préparer un export PC Forward+ à part (même code, réglages graphiques par plateforme).
2. **`main.gd` trop gros** : sortir la caméra en premier (`CameraRig` : 3e personne `SpringArm3D` + 1re personne + transitions), sans toucher au tir, à l'IA ni à la détection.
3. **Caméra éparpillée** (main / hider / atelier) : la regrouper dans le `CameraRig`.
4. **Pourcentages des tenues** : à remplacer plus tard par une mesure (couleur et motif de la tenue contre le terrain réel autour du joueur) — c'est un changement de gameplay, donc seulement avec ton accord.
5. **Pas d'arme en 1re personne ni de postures visée/tir** : à ajouter après la caméra.
6. **Pas de LOD ni d'occultation** : distances de visibilité et LOD sur la végétation, collision simplifiée.
