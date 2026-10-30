# Proposition — Architecture technique V1 (étape 2)

Date : 30/10/2026. Base : `main` après l'audit (`docs/audit_architecture_v1.md`).
**Aucun code modifié à cette étape.** Ce document attend la validation avant développement (étape 3).

Décisions déjà prises (30/10/2026) : rendu Compatibility conservé pour le web/iPhone ; CameraRig en priorité ;
camouflage, arme, animations et optimisation **non modifiés** maintenant.

---

## 1. Architecture proposée

### Principe

Un seul nœud, **`CameraRig`**, possède la caméra du jeu et tout ce qui la déplace. Les autres systèmes ne touchent
plus jamais `Camera3D` directement : ils **demandent** un mode (`rig.set_mode(...)`) ou **lisent** une information
(`rig.aim_origin()`, `rig.yaw`). La caméra ne décide rien du jeu.

```
           demande un mode / transmet le regard           lit position et direction
main.gd ───────────────────────────────────────▶ CameraRig ◀──────────────────────── tir, herbe, vie, pinceau
hider.gd ◀── lit rig.yaw (direction de marche) ──┘     │
                                                       └── seul à écrire Camera3D (position, rotation, fov)
```

### Les modes de la caméra

| Mode | Phase du jeu | Comportement (identique à aujourd'hui sauf mention) |
|---|---|---|
| `MENU` | menu | Vue fixe sur la vallée, lent va-et-vient horizontal |
| `EXPLORE` | cachette | 3e personne à l'épaule (0,45 m), hauteur et distance selon la posture, collision **par `SpringArm3D`** (nouveau) |
| `PREVIEW` | cachette, clic droit / bouton « viser » maintenu | 1re personne à l'œil, fov 55 ; le corps est masqué ; **transition douce** (nouveau) |
| `WORKSHOP` | atelier camouflage | Orbite autour du sniper (glisser), pas de collision |
| `SCOPE` | révélation + tir + fin | 1re personne fixe à l'œil, zoom x1/x4/x10, balancement, souffle, recul ; regard limité à ±1,1 rad autour de l'axe de départ |

Transitions (nouveau) : position, orientation et fov glissent de l'ancienne vue à la nouvelle en 0,15 à 0,35 s
(courbe douce). Exceptions : arrivée en `SCOPE` (déjà masquée par le brouillard de la révélation) et `MENU` : coupure nette.
Changement de zoom : le fov glisse en 0,12 s au lieu de sauter.

### Ce qui reste hors de la caméra (inchangé)

- **Tir** (`main.shoot`) : il continue de partir exactement de la position et de la direction de la caméra, balancement
  et recul compris. Il les lit par `rig.aim_origin()` / `rig.aim_direction()`, qui renvoient les mêmes valeurs qu'aujourd'hui.
- **Souffle** (jauge, essoufflement) : ressource de jeu, reste dans `main.gd`. Le rig reçoit seulement
  « souffle retenu / essoufflé » pour régler l'amplitude du balancement (même formule qu'aujourd'hui).
- **Reflet de lunette, IA, détection, exposition** : aucun changement. Le reflet lit le niveau de zoom (`rig.zoom_level`)
  au lieu de `zoom_idx` : même valeur, simple lecture.
- **Interface** (cache de lunette, point central, étiquette du zoom) : reste dans `hud.gd`, piloté par `main.gd` comme aujourd'hui.

---

## 2. Schéma des scènes et nœuds Godot

Nouvelle scène `game/scenes/camera_rig.tscn` (réglages visibles dans l'éditeur Godot) :

```
CameraRig (Node3D)                         camera_rig.gd — modes, transitions, regard, zoom
├── Follow (Node3D)                        suit le sniper (position lissée) ; rotation = yaw
│   └── Pitch (Node3D)                     rotation = pitch
│       └── SpringArm3D                    longueur = cam_d de la posture ; forme : sphère 0,2 m ;
│           │                              masque de collision 1 (décor, comme le rayon actuel) ;
│           │                              axe tourné vers l'épaule droite (même trajet que le rayon actuel)
│           └── ThirdPersonPoint (Node3D)  point où la caméra 3e personne veut être
├── Camera3D                               LA caméra du jeu (position/rotation calculées, pas enfant du bras)
└── (référence) EnemyViewCamera            caméra du médaillon, reste dans hud.inset_viewport (SubViewport)
```

- `Camera3D` n'est pas enfant du bras : à chaque image, le rig calcule la pose voulue du mode actif, la mélange
  pendant une transition, ajoute balancement et recul en mode `SCOPE`, puis l'écrit dans `Camera3D`.
- Le `SpringArm3D` donne la distance libre ; le rig la lisse comme aujourd'hui (rapproche vite, recule lentement),
  garde le minimum de 0,6 m et le filet « jamais sous le sol + 0,4 m ».
- `scenes/main.tscn` : inchangé (Node3D + `main.gd`) ; `main.gd` instancie `camera_rig.tscn`.

---

## 3. Responsabilités de chaque script

| Script | Responsabilité après migration | Ne fait plus |
|---|---|---|
| `camera_rig.gd` (nouveau) | Possède `Camera3D`. Modes, transitions, regard (souris et tactile) selon le mode, zoom et fov, orbite atelier, 3e personne + `SpringArm3D`, caméra du médaillon, format portrait/paysage (`keep_aspect`). Expose `aim_origin()`, `aim_direction()`, `yaw`, `zoom_level`, `camera`. | — |
| `camera_effects.gd` (nouveau, petit) | Calculs purs : balancement (amplitude selon souffle retenu / essoufflé), recul (`kick`, amortissement), courbes de transition. Testable seul. | — |
| `main.gd` | Phases, entrées (que veut dire chaque touche), tir, IA, détection, sons, atelier, souffle. Appelle `rig.set_mode()`, `rig.look()`, `rig.cycle_zoom()`, `rig.kick()`. | Créer/placer la caméra, `aim_at`, `set_fov`, `_look`, `_place_workshop_camera`, rotation avec balancement |
| `hider.gd` | Corps physique, postures, marche orientée par `rig.yaw` (passé en paramètre à `physics_step`), position affichée, œil. | `place_camera`, `first_person`, `look`, `cam_yaw/cam_pitch/_cam_*` |
| `hud.gd`, `world.gd`, `paint.gd`, `life.gd`, `touch_controls.gd` | Inchangés. | — |

Ordre d'appel garanti à chaque image (dans `main._process`) : `hider.update_visual()` puis `rig.update(dt)`,
puis herbe et vie qui lisent la caméra. Le rig n'a pas de `_process` propre, donc pas d'image de retard.

---

## 4. Fichiers existants à modifier

| Fichier | Changement | Ampleur estimée |
|---|---|---|
| `game/scripts/main.gd` | Retirer la création et le placement de la caméra ; appels au rig ; `shoot()` lit `rig.aim_origin/aim_direction` | −≈ 90 lignes, +≈ 40 |
| `game/scripts/hider.gd` | Retirer les fonctions caméra ; `physics_step(dt, input, running, cam_yaw)` | −≈ 40 lignes, +≈ 3 |
| `docs/game-design.md` | Section « Caméra » | +≈ 30 lignes |
| `tools/artefact/donnees-pck.wasm` | Reconstruit (republication) | — |

Non modifiés : `hud.gd`, `world.gd`, `paint.gd`, `life.gd`, `touch_controls.gd`, `vegetation.gd`, shaders, assets, `project.godot`.

## 5. Nouveaux fichiers

| Fichier | Rôle |
|---|---|
| `game/scenes/camera_rig.tscn` | Scène du rig (nœuds ci-dessus) |
| `game/scripts/camera_rig.gd` | Le rig (≈ 280 lignes) |
| `game/scripts/camera_effects.gd` | Balancement, recul, transitions (≈ 60 lignes) |
| `tools/tests/test_camera.gd` | Tests automatiques sans écran (non-régression) |
| `tools/tests/captures_camera.gd` | Captures avant/après aux mêmes points de vue |
| `docs/audit/apres/*.jpg` | Captures après |

---

## 6. Stratégie de migration (sans casser le jeu)

Une étape = un commit **jouable**, testé, avant de passer à la suivante. Un seul système change : la caméra.

| Pas | Contenu | Le jeu doit être… |
|---|---|---|
| A | Créer le rig qui **possède** la caméra, mais en « passe-plat » : `main` et `hider` continuent de la placer comme avant via `rig.camera` | **identique au pixel près** (captures comparées) |
| B | Migrer `MENU` et `WORKSHOP` (les plus isolés) | identique |
| C | Migrer `SCOPE` : regard, zoom, balancement, recul ; `shoot()` lit le rig | identique ; **direction du tir identique** (test numérique) |
| D | Migrer `EXPLORE` et `PREVIEW` en recopiant la logique actuelle (rayon) ; `hider` reçoit `rig.yaw` | identique |
| E | Remplacer le rayon par `SpringArm3D` | même cadrage, collision plus sûre (sphère au lieu d'un rayon fin) |
| F | Transitions douces et glissement du zoom | nouveauté visible, à valider sur iPhone |
| G | Médaillon (vue ennemie) dans le rig | identique |

Pas A à D et G : aucun changement visible (refactorisation). Pas E et F : les seules nouveautés.
Envoi sur `main` et republication de l'artefact : après C (refactorisation déjà sûre), puis après F+G, pour que tu
testes sur iPhone. Si un pas casse quelque chose, on revient au commit précédent (historique conservé, pas de `--force`).

---

## 7. Risques techniques et tests de non-régression

### Risques

| Risque | Parade |
|---|---|
| La direction du tir change (balancement/recul calculés ailleurs) | Test numérique : pour des yaw/pitch/balancement/recul donnés, `aim_direction()` = ancienne formule à 10⁻⁶ près |
| Le `SpringArm3D` « saute » d'une image à l'autre | Lissage de la distance par le rig (comme aujourd'hui), pas de caméra enfant du bras |
| La sphère du bras accroche les buissons plus souvent que le rayon | Même masque de collision ; rayon de sphère réglable (0,15–0,25 m) ; test contre arbre/rocher |
| Pendant une transition, la caméra traverse la tête ou le sol | Corps masqué dès la moitié de la transition vers `PREVIEW` ; filet « jamais sous le sol » appliqué à la pose mélangée |
| Ordre des mises à jour (une image de retard, tremblement) | `rig.update()` appelé explicitement après `hider.update_visual()` |
| Tactile iPhone : regard et bouton « viser » | Même routage (`touch.consume_look()` → `rig.look()`), test sur iPhone avant validation |
| Le fov qui glisse change la sensibilité du regard au zoom | Sensibilité calculée sur le fov **cible** (comme aujourd'hui), pas sur le fov intermédiaire |
| Portrait / paysage | `keep_aspect` géré par le rig, testé dans les deux formats |
| Web (Compatibility) : `SpringArm3D` | Nœud standard, compatible ; coût négligeable (une forme par image) ; vérifié dans l'artefact |

### Tests automatiques (`tools/tests/test_camera.gd`, sans écran, à chaque pas)

1. Enchaînement complet menu → cachette → atelier → révélation → tir → fin → menu : aucune erreur, aucune valeur NaN.
2. Tir : position et direction identiques à l'ancienne formule (plusieurs angles, balancement, recul).
3. Zoom : 55 → 14 → 5,5 → 55 ; le reflet se déclenche toujours après 5 s au x10.
4. Limites du regard : tir ±1,1 rad autour de l'axe, pitch −0,9…0,7 ; cachette pitch −1,2…0,5 ; atelier −0,3…1,2.
5. Marche : avancer = direction horizontale de la caméra (comme aujourd'hui), dans les trois postures.
6. Collision : sniper dos à un rocher et à un arbre → caméra rapprochée, jamais à moins de 0,6 m, jamais dans le décor ni sous le sol.
7. Aperçu clic droit : caméra à l'œil, corps masqué ; relâché : retour à l'épaule.
8. Atelier : le clic au centre de l'écran touche toujours le sniper (`pick_part`).
9. Transitions : finies dans le temps prévu, aucune image sous le sol.

### Captures avant/après

Mêmes 4 vues que `docs/audit/avant/` + 2 nouvelles (caméra contre un arbre, milieu d'une transition), dans `docs/audit/apres/`.
Pas A à D : écart visuel nul attendu.

### Test sur iPhone (par toi)

Cachette (marche, postures, viser), atelier (orbite au doigt), tir (zoom, souffle, tir), en portrait et paysage.

---

## 8. Estimation

| Quoi | Volume |
|---|---|
| Nouveau code | ≈ 340 lignes (rig + effets) + ≈ 200 lignes de tests |
| Code modifié | `main.gd` −90/+40, `hider.gd` −40/+3 |
| Commits | 7 (pas A à G), 2 envois testables sur iPhone |
| Durée | une séance de travail |

---

## Annexe — Pistes notées pour plus tard (rien à développer maintenant)

**Configuration PC Steam (Forward+), à étudier.** Garder un seul projet : le rendu peut être choisi par plateforme
(réglage `rendering_method` par « feature tag » d'export, à vérifier sur 4.7.2) ; un préréglage d'export « PC » en Forward+,
le web reste en Compatibility. À vérifier avant : les shaders corrigent les couleurs à la main (`pow(2.2)`) pour Compatibility,
il faudra un réglage par plateforme. Le code de jeu reste commun.

**Vraie mesure du camouflage, à proposer plus tard.** Trois pièces séparées, sans toucher à `detect_rate()` :
1. *Description de la tenue* : couleurs dominantes, contraste et taille du motif, lus dans la texture (calculés une fois) ;
2. *Échantillon du terrain* : couleurs réelles autour du joueur (textures du sol de sa zone, végétation proche) ;
3. *Comparateur* : rend un score 0–1, au même format que la table actuelle, donc branché à la place de `match_zone` sans changer la détection.

**Arme et animations.** Le rig expose déjà le point de visée : l'arme 1re personne sera un enfant de `Camera3D`, visible
seulement en `SCOPE` / `PREVIEW`, et le fusil du dos masqué à ce moment (pas de doublon visible).

---

## Précisions demandées à la validation (30/10/2026)

### SpringArm3D : comment il commande vraiment la caméra (pas E)

Le bras n'est pas décoratif : **en mode `EXPLORE`, la distance de la caméra ne peut jamais dépasser la longueur libre
mesurée par le `SpringArm3D`.**
1. À chaque image, le rig place `Follow` sur le sniper et oriente `Pitch` et le bras vers l'épaule ; le bras lance sa
   sphère dans le décor et donne `get_hit_length()` (distance libre).
2. Le rig lisse la distance comme aujourd'hui, mais avec une règle stricte : on **recule lentement** vers la longueur
   libre, on **avance instantanément** si un obstacle apparaît (`distance = min(distance lissée, hit_length)`).
   Aujourd'hui, le rapprochement est rapide mais pas instantané (la caméra peut entrer d'une image dans un rocher) :
   ce sera corrigé au pas E.
3. La pose 3e personne = départ du bras + axe du bras × cette distance ; c'est elle que le rig écrit dans `Camera3D`.
4. Pendant une transition qui part de la 3e personne ou y arrive, la pose mélangée est elle aussi contrôlée par un
   lancer de forme depuis le sniper : elle ne traverse pas le décor.
5. Test du pas E : sniper dos à un rocher et à un arbre, la caméra n'est jamais dans le décor ni plus loin que le bras.

Pourquoi `Camera3D` n'est pas enfant du bras : la même caméra sert aux cinq modes ; si elle était fixée au bout du bras,
les modes 1re personne et atelier devraient la détacher et la rattacher, et les transitions sauteraient.
Au pas A, **aucun bras n'est créé** : il n'apparaîtra qu'au pas E, au moment où il commande la caméra.

### PREVIEW et SCOPE

| | `PREVIEW` (cachette, clic droit / « viser ») | `SCOPE` (révélation, tir, fin) |
|---|---|---|
| But | Regarder depuis sa cachette, à l'œil | Viser et tirer |
| Regard | **Le même** yaw/pitch que `EXPLORE` (en relâchant, on retrouve la même direction) ; limites −1,2…0,5 | Yaw/pitch propres, ±1,1 rad autour de l'axe de départ, pitch −0,9…0,7 ; sensibilité proportionnelle au zoom |
| Angle de vue | x1 fixe (55°) | x1 / x4 / x10 |
| Effets | aucun | balancement (selon le souffle), recul |
| Tir | impossible | `aim_origin()` / `aim_direction()` fournis au tir |
| Corps | masqué | masqué |

Pièces communes (sans mélange des rôles) : le calcul du point de vue à l'œil (`hider.eye()`), l'orientation
yaw/pitch → rotation (ordre YXZ) et le réglage de l'angle de vue. Chaque mode garde son propre état
(regard, zoom, effets) : entrer en `PREVIEW` ne touche jamais au zoom ni au recul du tir.

### Transitions

- Réglables dans `camera_rig.tscn` (propriétés exportées) : durée par passage (ex. `EXPLORE → PREVIEW` 0,15 s,
  `PREVIEW → EXPLORE` 0,25 s, `WORKSHOP → EXPLORE` 0,35 s), courbe, et un interrupteur général (0 s = coupure nette, comme aujourd'hui).
- Elles ne changent que **l'image** : `aim_origin()`, `aim_direction()` et `rig.yaw` (direction de marche) renvoient toujours
  la pose **logique** du mode, jamais la pose mélangée. L'arrivée en `SCOPE` reste une coupure (cachée par le brouillard),
  donc au moment où l'on peut tirer, l'image et la visée sont identiques.
- Le rig ne déplace jamais le personnage : il lit sa position, il ne l'écrit pas.

### Rendu

Inchangé : Compatibility, navigateur et iPhone comme aujourd'hui. Aucun pas ne touche `project.godot` ni le rendu.
