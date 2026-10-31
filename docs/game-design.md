# Duel des Cimes — document de game design

> Version 0.1 — 25/10/2026. Tiré du prototype web « Duel des Cimes » (artefact Claude),
> à refaire en 3D dans Godot 4.7 pour une sortie sur Steam.
> Nom de travail du dépôt : `montaigneview`.

## 1. Le pitch

**Deux montagnes, deux snipers. Le premier qui trouve l'autre a gagné.**

Un jeu de cache-cache tactique en 3D : on se cache sur sa montagne en se fondant
dans le paysage, puis on fouille la montagne d'en face à la lunette. Chaque tir raté
trahit sa position. C'est un jeu d'observation et de patience, pas un jeu d'action.

- **Genre :** duel d'observation / sniper tactique, parties courtes (2 à 4 minutes)
- **Plateforme :** PC (Windows d'abord), sur Steam
- **Joueurs :** solo contre l'ordinateur (version 1), puis duel en ligne 1 contre 1
- **Inspirations :** les chapitres « sniper duel » de Metal Gear Solid 3 (The End), *Where's Waldo*,
  les jeux de cache-cache à la Prop Hunt

## 2. La boucle de jeu (une partie)

| Phase | Durée | Ce que fait le joueur |
|---|---|---|
| 1. Cachette | 45 s | Regarde sa propre montagne depuis la position ennemie, choisit une cachette parmi les repères, choisit une tenue (Neige, Roche, Herbe, Forêt). Une petite fenêtre « lunette ennemie » montre comment on le voit. |
| 2. Brouillard | 3 s | Le brouillard se lève sur la vallée. Pause de tension. |
| 3. Duel | jusqu'à la fin | Fouille la montagne d'en face à la lunette, retient son souffle, tire. L'ennemi le repère petit à petit et tire aussi. |
| 4. Fin | — | Révélation de l'ennemi dans la lunette, résumé et conseils (« ta tenue se voyait sur la roche »). Rejouer. |

## 3. Les mécaniques

### 3.1 Camouflage
- Le terrain a 4 zones : **Neige** (sommets), **Roche**, **Herbe**, **Forêt**.
- Chaque cachette se trouve dans une zone et a son couvert (rocher, buisson, sapin).
- Tenue qui correspond au terrain = l'ennemi te repère **3 fois moins vite**.

**Se cacher soi-même (fait le 25/10/2026) :** pendant la cachette (60 s), on marche sur son île
en 3e personne (ZQSD + souris, Maj pour courir) et on se met **debout**, **accroupi** (C) ou
**couché** (X) où l'on veut. Clic droit maintenu = vue de tir depuis la cachette, pour vérifier
qu'on voit encore l'île d'en face. L'ennemi repère plus ou moins vite selon :
- le camouflage peint (voir ci-dessous) ;
- la posture (debout ×1,8, accroupi ×1, couché ×0,55 ; couché dans l'herbe ×0,7 en plus) ;
- ce qu'il voit vraiment de ton corps (rayons depuis sa cachette : à couvert ×0,35, à découvert ×1).

**Se peindre soi-même (fait le 25/10/2026) :** après « Jouer », un atelier sur ton île. On peint
directement le sniper en 3D (16 couleurs, pinceau petit / moyen / gros, taches, remplir, annuler),
en tournant autour au clic droit ; la peinture suit le corps dans les trois postures.
Un score par terrain dit à quel point on s'y fond : des points répartis sur le corps sont comparés aux
teintes du terrain (claire, normale, ombre), avec **+12 %** si l'on mélange au moins deux teintes
du même terrain (la silhouette se casse). Pendant le duel, la vitesse de repérage passe de
« bonne tenue » à « mauvaise tenue » selon ce score sur le terrain où l'on se cache.

### 3.2 Visée
- 3 zooms : **x1** (vue libre avec point de visée), **x4** et **x10** (lunette ronde avec réticule).
- La visée oscille légèrement (respiration).
- **Retenir son souffle** (Maj) : la visée devient presque immobile, mais le souffle se vide en environ 3,5 s.
  À zéro : essoufflement de 2 s, la visée tremble 2 fois plus.
- **Reflet de lunette :** rester plus de 5 s au zoom x10 fait briller la lunette au soleil,
  et l'ennemi te repère plus vite.

### 3.3 Tir
- **5 balles**, 1,3 s entre deux tirs.
- La balle met du temps à arriver (distance ÷ 900 m/s) : un petit délai avant de savoir si c'est touché.
- Un tir raté fait un nuage de poussière à l'impact **et** fait monter la jauge « L'ennemi te repère ».
- Plus de balles : l'ennemi accélère ses tirs.

### 3.4 L'ennemi (IA)
- Une jauge **« L'ennemi te repère »** monte en continu (plus vite si mauvaise tenue,
  si la lunette brille, et à chaque tir raté).
- Il tire à intervalles réguliers. Sa chance de toucher = jauge × précision.
- Un tir manqué de sa part arrive d'autant plus près que la jauge est haute
  (« Un tir a frappé à 8 m de toi ! ») : c'est l'indice de danger.
- Son tir fait un **éclair de canon** et de la fumée : c'est l'indice pour le trouver.
- Il choisit une cachette d'où il est réellement visible (pas de triche) et une tenue
  qui correspond plus ou moins bien selon la difficulté.

### 3.5 Niveaux de difficulté (valeurs du prototype)

| | Facile | Normal | Difficile |
|---|---|---|---|
| Premier tir ennemi | 22 s | 16 s | 11 s |
| Intervalle entre ses tirs | 9–13 s | 7–10 s | 5–8 s |
| Repérage / s (bonne tenue) | 0,6 % | 1 % | 1,5 % |
| Repérage / s (mauvaise tenue) | 2 % | 3 % | 4,5 % |
| Précision | 60 % | 75 % | 90 % |
| Chance qu'il soit bien camouflé | 35 % | 75 % | 100 % |
| Repérage en plus par tir raté | 18 % | 25 % | 32 % |

## 4. Le monde

- **Un archipel** (choisi le 25/10/2026) : deux îles-montagnes face à face à environ **460 m**
  l'une de l'autre, séparées par la mer, entourées d'autres îles pour le décor. La mer s'étend
  jusqu'à l'horizon (bleu profond, turquoise près des côtes, lignes blanches qui bougent, écume sur les plages).
- 15 cachettes par île pour l'ennemi (5 directions × 3 hauteurs) ; le joueur, lui, se cache où il veut.
- Décor : sapins, rochers, buissons, avec des clairières autour des cachettes.
- Lumière de jour, brouillard léger à l'horizon.
- **Style visuel : façon Zelda Wind Waker** (choisi le 25/10/2026). Ombrage cartoon à deux tons
  avec ombres bleutées, contours noirs sur le décor proche (qui s'effacent au loin pour ne pas
  trahir les snipers), ciel peint avec gros nuages, herbe qui bouge au vent, fleurs, cailloux,
  mer avec écume dessinée, arbres ronds et sapins à étages. Ça va avec l'idée de « repérer une couleur qui détonne ».

## 5. Commandes (PC)

| Action | Clavier / souris | Manette |
|---|---|---|
| Viser | Souris | Stick droit |
| Tirer | Clic gauche ou Espace | Gâchette droite |
| Retenir son souffle | Maj (maintenu) | Gâchette gauche (maintenue) |
| Changer de zoom | Molette ou Z | Bouton Y / Triangle |
| Pause | Échap | Start |

Le support manette compte pour le badge **Steam Deck** (à viser dès le début).

## 6. Ce qu'il faut ajouter pour Steam (au-delà du prototype)

Par ordre de priorité :

1. **Plusieurs cartes** : montagne d'été (le prototype), montagne enneigée, falaises au coucher du soleil, forêt de pins.
2. **Météo et heure** : brouillard qui va et vient, neige qui tombe, contre-jour (le soleil gêne la visée d'un côté).
3. **Progression** : nouvelles tenues, lunettes, cartes à débloquer en gagnant.
4. **Mode campagne** : une série de duels contre des snipers aux personnalités différentes
   (le patient, le nerveux, le tricheur qui change de cachette).
5. **Duel en ligne 1 contre 1** avec des amis Steam (via le réseau Steam).
6. **Succès Steam** et **classements** (temps le plus court pour gagner, gagner avec 1 seule balle…).

## 7. Organisation dans Godot

```
game/
  scenes/
    main_menu.tscn       menu, choix difficulté
    duel.tscn            la partie (terrain + snipers + HUD)
    terrain.tscn         relief, zones de couleur, décor
    hiding_spot.tscn     une cachette (couvert + repère)
    sniper.tscn          un personnage (tenue, fusil, zone touchable)
    hud/                 écrans : cachette, duel, fin
  scripts/
    game_state.gd        (autoload) phases de la partie, difficulté
    enemy_ai.gd          jauge de repérage, tirs
    scope_camera.gd      zoom, oscillation, souffle, recul
  data/
    difficulty.tres      les valeurs du tableau 3.5
  assets/                modèles, textures, sons (Git LFS)
```

- **Relief :** généré à partir d'un bruit (`FastNoiseLite`) comme dans le prototype, ou sculpté
  à la main avec l'extension gratuite **Terrain3D**.
- **Tir :** `RayCast3D` / `PhysicsRayQueryParameters3D` depuis la caméra.
- **Steam :** extension **GodotSteam** pour les succès, les classements et le multijoueur.

## 8. Étapes de développement

| Étape | Contenu | Résultat |
|---|---|---|
| 1. Prototype Godot | Refaire le prototype web à l'identique dans Godot, avec des formes simples | Une partie complète jouable ✅ |
| 1b. Décors Wind Waker | Ombrage cartoon, ciel, herbe, fleurs, lac, arbres | La vallée donne envie ✅ |
| 1c. Se cacher soi-même | Déplacement libre en 3e personne, debout / accroupi / couché, vue de tir | On choisit sa cachette au mètre près ✅ |
| 1d. Se peindre soi-même | Atelier de peinture au pinceau sur le sniper, score de camouflage par terrain | Camouflage unique à chaque partie ✅ |
| 2. Sensations | Sons, recul, éclairs, brouillard, menus propres, réglages | Le jeu « fait » vrai |
| 3. Contenu | 3 cartes, tenues, progression | Assez pour 2 à 3 heures |
| 4. Steam | Page Steam, succès, manette, Steam Deck, démo | Page « Bientôt disponible » |
| 5. En ligne | Duel 1 contre 1 entre amis | Mise à jour après la sortie, ou à la sortie |

## 9. Questions encore ouvertes

- **Nom du jeu :** « Duel des Cimes » (le prototype) ou « Montaigneview » (le dépôt) ?
- **Langues :** français seulement, ou aussi anglais (indispensable pour vendre sur Steam) ?
- **Prix visé :** petit jeu (5 à 10 €) ?
- **Ton :** réaliste et tendu, ou plus léger et coloré ?

## 10. Cible : application Android et iOS (décidé le 25/10/2026)

Le jeu devient une **appli mobile** (même jeu : cachette, peinture, duel), plus un jeu Steam.

- Rendu Godot « Mobile » ; ombres courtes (2 tranches, 90 m), anticrénelage 2×, pas d'occlusion ambiante,
  pas de contours ; décor découpé en zones de 175 m ; herbe sur 40 m autour de la caméra.
- Relief précalculé dans `game/data/relief_320_*.res` (lu au lancement : ~1,3 s au lieu de ~8 s).
  À regénérer (supprimer ces fichiers puis lancer le jeu depuis Godot) si le relief change.
- Étapes suivantes : commandes tactiles (joystick, glisser pour viser, boutons), export Android,
  puis iOS (nécessite un Mac pour compiler et publier).

### Commandes tactiles (faites le 25/10/2026)
- **Cachette :** joystick sous le pouce gauche (poussé à fond : course), glisser à droite pour regarder,
  boutons ronds Accroupi, Couché, Viser (maintenu : vue de tir), PRÊT.
- **Peinture :** un doigt sur le sniper peint, un doigt à côté tourne autour, deux doigts zooment.
- **Duel :** glisser pour viser, boutons TIRER, Zoom, Souffle (maintenu).
- Appli en paysage (capteur). Sur PC, le mode tactile s'active avec l'argument `-- --tactile`
  (la souris fait office de doigt). Code : `game/scripts/touch_controls.gd`.

### Version web pour iPhone (25/10/2026)
- L'utilisateur a un iPhone : on essaie d'abord la **version web** dans Safari (pas de Mac nécessaire).
- Export « Web » (préréglage dans `game/export_presets.cfg`, sans threads : marche sans en-têtes spéciaux),
  rendu « Compatibility » (WebGL 2). La peinture passe par une petite texture (limites des shaders sur iPhone).
- Construire : `godot --headless --path game --export-release "Web" ../build/web/index.html`
- Essayer sur le téléphone (même Wi-Fi) : `node tools/serveur_web.js`, puis ouvrir l'adresse affichée dans Safari.
- Le mode tactile s'active seul sur iPhone / Android ; message « Tourne ton téléphone » en portrait.

### Le jeu dans l'artefact Claude « Duel des Cimes » (26/10/2026)
- Lien : https://claude.ai/artifact/8ZHppVb8s62V5codCvUcuv (privé par défaut ; partage via le menu Partager).
- Page : `tools/artefact/duel-des-cimes.html`. Fichiers publiés à côté : `index.js`, les deux worklets audio,
  `donnees-pck.wasm` (= `index.pck`) et `moteur-gz.wasm` (= `index.wasm` compressé en gzip, ~10 Mo :
  un artefact accepte 15 Mo par fichier et ne sert ni `.pck` ni `.gz`). La page redirige les requêtes de Godot
  vers ces fichiers et décompresse le moteur dans le navigateur.
- Pour mettre à jour : exporter la version web, compresser `index.wasm` en gzip, puis republier la page
  avec ces fichiers sur le même lien (mettre à jour la taille de `index.pck` dans GODOT_CONFIG).
- Vérifié par l'utilisateur le 26/10/2026 : le jeu démarre dans l'artefact.

### Images Higgsfield et jeu debout (27/10/2026)
- Trois images créées avec Higgsfield dans `game/art/` : `ciel.jpg` (panorama du lever de soleil, répété en miroir
  autour de l'horizon par `shaders/sky.gdshader`), `brume.jpg` (deux nappes qui s'écartent quand le brouillard se lève,
  `hud.gd` → `set_fog_amount`), `menu.jpg` (derrière le menu, et derrière l'écran de chargement de l'artefact).
- Le jeu se joue **téléphone debout ou couché** : `hud.gd` → `_apply_orientation` passe la base de l'interface en
  720 × 1280 debout, replace la carte du menu, les panneaux de l'atelier et la lunette ennemie ; la caméra règle
  son angle de vue sur la largeur (`main.gd` → `_on_orientation`). Orientation de l'appli : capteur (`orientation=6`).
- Mise à jour de l'artefact : seul `donnees-pck.wasm` change (`godot --headless --path game --export-pack "Web" index.pck`),
  le moteur publié reste le même tant que la version de Godot (4.7.2) ne change pas.

### Textures du décor (27/10/2026)
- Cinq textures de sol peintes, créées avec Higgsfield (≈ 1,25 crédit) : `game/art/sol_{herbe,foret,roche,neige,sable}.jpg`.
  Elles sont enregistrées en **cartes de détail** (gris 0,5 = couleur de la zone inchangée) : la couleur moyenne du sol
  reste celle de la zone, donc le score de camouflage ne change pas.
- Sol : `shaders/terrain.gdshader` (poids des terrains dans UV / UV2, roche projetée aussi sur les falaises).
  Rochers : `toon.gdshader` avec `use_detail` (paramètre `detail` de `world.toon()`).

### Nouveau sniper (27/10/2026)
- Le chapeau de cowboy est remplacé par une **capuche** ; ajout des yeux, du cou, des mains (gants), d'un gilet à deux
  poches, d'une ceinture, de semelles, d'un tapis roulé sur le sac, et d'un vrai fusil (boîtier, canon, frein de bouche,
  lunette, crosse en bois, chargeur, bipied).
- `world.gd` → `PARTS` : une pièce peut avoir une **pièce parente** (7e valeur) ; elle n'a alors que la pose « debout »,
  donnée dans le repère de sa parente, et la suit dans toutes les poses et la marche.
- Tenue de départ (`paint.gd` → `_set_default`) : capuche olive, visage, pantalon olive, bottes, sac.

### Personnage 3D (27/10/2026)
- Le sniper est maintenant un **modèle 3D** fait par l'utilisateur avec Higgsfield (Tripo), via ChatGPT :
  original 65 Mo / 1,9 million de triangles, allégé à **8 700 triangles** (`game/art/sniper.glb`, 280 Ko)
  + texture couleur 1024 px (`game/art/sniper_couleur.jpg`). Le modèle d'origine reste sur le Google Drive de l'utilisateur.
- Pas de squelette dans le modèle : `world.gd` lui en ajoute un de 6 os (buste avec bras et fusil, tête, deux cuisses,
  deux tibias avec genoux) avec des poids calculés selon la position des sommets (`_model_arrays`) : les pieds suivent
  toujours le tibia ; plus haut, seuls les sommets proches de l'axe de la jambe la suivent (le canon du fusil reste au buste).
  Poses : `FIG_POSES` (hanche, bascule du buste, angle de chaque cuisse et tibia, tête relevée). Accroupi = tireur à
  genou (genou gauche au sol, pied droit devant). Marche : la cuisse se balance et le genou plie quand la jambe recule.
- Peinture : le pinceau vise le vrai maillage (`TriangleMesh`, `pick_part`) ; le score de camouflage se mesure sur
  2 400 points répartis sur le corps (`figure_samples`). Tant que rien n'est peint, on voit la tenue d'origine
  (`tex_mix` du shader camo) ; la peinture garde les plis du vêtement.
- Les anciennes pièces (`PARTS`) sont supprimées.
- *28/10/2026 : le squelette de 6 os est remplacé par un vrai squelette animé, voir ci-dessous.*

### Direction artistique réaliste, façon jeux PS3 (28/10/2026)
- **Éclairage doux** (Lambert) à la place des deux tons cartoon : terrain, rochers, sniper, herbe.
  Étalonnage commun du sol et de la peinture (`shaders/grade.gdshaderinc`) : verts plus naturels, sans fausser
  le camouflage (la même couleur est corrigée de la même façon sur le sol et sur le sniper).
- **Végétation** (`scripts/vegetation.gd`, `shaders/foliage.gdshader`) : épicéas à 13 étages de branches (deux cartes
  d'aiguilles en V par branche), feuillus et buissons en bouquets de feuilles, troncs d'écorce, touffes d'herbe et de
  fleurs des champs en cartes. Textures dessinées par programme : `art/vege_*.png`, `art/vege_ecorce.jpg`.
  *28/10/2026 : arbres et buissons remplacés par les arbres photo du « tree pack », voir plus bas.*
- **Les arbres ne bouchent pas la vue** : ils s'effacent en tramage près de la caméra (`world.set_near_fade`) :
  4 m à l'atelier, 5 m en cachette (3e personne), 35 m en vue de tir. Les balles traversent les arbres effacés
  (`main.gd` → `shoot`). Arbres et buissons ont leur propre corps physique (`is_foliage`).
- **Roche et terre réalistes** : photo de roche et sa carte de relief, terre avec feuillage, venues du pack « Hills »
  fourni par l'utilisateur (`art/sol_roche.jpg`, `art/sol_foret.jpg`, `art/relief_*.jpg`). Licence du pack à vérifier
  avant une sortie sur Steam. Les collines du pack (low-poly) ne sont pas utilisées : la carte reste celle du jeu.
- **Mer réaliste** (`shaders/water.gdshader`) : vagues calculées, reflet du ciel (Fresnel) et du soleil, écume légère.
- Nuages du ciel plus vaporeux et plus rares ; rochers plus fins et arrondis ; cailloux plus sombres.

### Sniper animé (28/10/2026)
*Remplacé le jour même par le nouveau sniper sans arme, voir « Nouveau sniper, fusil dans le dos » plus bas.*
- Squelette (65 os) et animations de la **« Universal Animation Library » de Quaternius** (licence CC0, libre pour Steam),
  fournie par l'utilisateur : `sources/UAL1_Standard.glb` (+ `UAL1_License.txt`).
- `tools/sniper_anime.gd` (à lancer une fois, voir l'en-tête du fichier) pose ce squelette sur `art/sniper.glb` et
  enregistre `art/sniper_anime.scn` (maillage, os, animations). Chaque sommet du sniper prend les poids des sommets
  voisins du mannequin ; bras, mains et fusil suivent le buste (le sniper tient son fusil, le mannequin a les bras
  écartés), les jambes suivent les jambes. `sniper.glb` ne sert plus qu'à cet outil (exclu de l'export).
- Animations gardées : `Idle_Loop` (respiration), `Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Crouch_Idle_Loop`,
  `Crouch_Fwd_Loop`, `Death01` (l'ennemi touché tombe). La bibliothèque n'a pas de position couchée : l'outil la
  fabrique à partir de la pose debout (`Prone_Idle_Loop` : à plat ventre, buste un peu relevé, regard devant ;
  `Prone_Crawl_Loop` : reptation, un genou remonte sur le côté).
- `world.gd` → `FIG_ANIMS` : animation de chaque posture et sa vitesse au sol ; `animate_figure` choisit marche,
  course ou sprint selon la vitesse du joueur (m/s) et règle la cadence pour que les pieds ne glissent pas ;
  changement d'allure en douceur, au même moment de la foulée. Accroupi un peu plus lent (1,8 m/s au lieu de 2,2).
- Atelier : la pose est figée (`set_stance`) ; le pinceau vise le maillage dans la pose affichée, calculée comme la
  carte graphique (`_skinned`), et la peinture reste posée dans le repère debout (CUSTOM0). L'éclair du tir ennemi
  part du bout de son canon (`muzzle`).

### Ciel avec de vrais nuages (28/10/2026)
- Les nuages calculés sont remplacés par ceux du ciel de jour **« PSX Daysky HDRI » de StarkCrafts** (fourni par
  l'utilisateur) : moitié haute du panorama 360°, convertie en image de clarté des nuages (`art/ciel_nuages.jpg`, 130 Ko),
  teintée aux couleurs du lever de soleil dans `shaders/sky.gdshader`. Le panorama Higgsfield reste à l'horizon.
  Licence du pack à vérifier avant une sortie sur Steam.
- Pour plus tard : le ciel de nuit du même auteur (`PSX Nightsky HDRI`) pourrait servir à un mode de nuit.
  Le pack « PSX Forest » (modèles façon PlayStation 1, textures de 128 px) n'est pas utilisé : trop simple pour le
  rendu visé.

### Arbres photo (28/10/2026)
- Arbres et buissons du **« tree pack 1.1 »** fourni par l'utilisateur (`sources/tree_pack_1.1/` : 36 arbres et 8 buissons,
  chacun un tronc et quatre cartes croisées avec la photo de l'arbre, 52 triangles). Licence à vérifier avant Steam.
- Gardés pour la montagne (`game/art/arbres/`, `world.gd` → `PACK_TREES`) : 3 sapins (`tree07`, `tree09`, `tree12`) dans
  la forêt, 2 feuillus (`tree19`, `tree24`) dans l'herbe, 2 buissons (`bush02`, `bush06`), aussi pour les cachettes.
  Chaque arbre du décor prend l'un des modèles de sa sorte (choix fixé par sa position). Les arbres d'automne
  (orange, rouge, jaune) ne sont pas utilisés.
- Photos de 128 px agrandies à 256 px aux contours adoucis (moins de « pixels » de près), luminosité égalisée.
  Feuillage avec normales « en boule » et bas plus sombre (`_pack_tree`), effacement près de la caméra comme avant.
- Plus réalistes que les arbres dessinés par programme, surtout dans la lunette, et bien plus légers (52 triangles au
  lieu d'environ 300 pour un sapin). Les anciens arbres (`VEG.spruce`, `broadleaf`, `bush`) et leurs textures sont retirés.

### Nouveau sniper, fusil dans le dos (28/10/2026)
- Retour de l'utilisateur : genoux et jambes « ça va pas du tout » (bosses aux genoux, couché sur le fusil, pieds en
  l'air). Cause : l'ancien modèle tenait son fusil soudé aux mains et n'avait pas de squelette ; ses poids étaient
  devinés d'après le mannequin.
- L'utilisateur a généré sur Higgsfield un **sniper sans arme, en A-pose, avec son propre squelette** (24 os) et le
  **fusil seul**. Allégés dans le bac à sable Higgsfield (13 300 triangles, texture couleur 1024 px ; fusil 2 400
  triangles) : `sources/sniper_higgsfield.glb`, `sources/fusil_higgsfield.glb`.
- `tools/sniper_anime.gd` refait : le squelette des animations Quaternius est **ajusté aux articulations du sniper**
  (longueur et direction de chaque os : hanches, genoux, chevilles, épaules, coudes, poignets ; écart nul), et le sniper
  garde **ses propres poids de peau** (os du modèle → os des animations). Le bassin des animations est remis à la
  hauteur du modèle. Les bras sont libres : ils bougent avec les animations (balancement en marchant, course…).
- **Fusil dans le dos**, en travers (canon vers le haut derrière l'épaule gauche), rigide avec le haut du buste, dans
  le même maillage : la peinture le recouvre aussi. L'éclair du tir ennemi part devant sa tête.
- Couché refait : coudes posés devant, mains sous le menton, jambes allongées ; en rampant, le coude opposé au genou
  qui remonte avance. Le corps couché suit la pente dans sa longueur et sur le côté (`hider.gd` → `_apply`).
- Shader camo : faces affichées des deux côtés (capuche en une seule épaisseur). L'ancien `art/sniper.glb` est retiré.

### Vraies montagnes (28/10/2026)
- Retour de l'utilisateur : la carte « fait pas du tout naturel », « pas juste un triangle ». L'ancien relief était
  une somme de bosses rondes (une par montagne) : chaque île était un cône.
- Nouveau relief fabriqué hors du jeu par `tools/relief.py` (Python + numpy), puis rangé dans `game/data/` par
  `tools/relief_vers_godot.gd` (voir l'en-tête des deux fichiers) ; le jeu ne fait que le lire.
  1. Chaque montagne est une **ligne de crête** avec plusieurs sommets et des cols (pour les deux îles du duel, en
     travers de la vue : l'adversaire voit une vraie ligne de sommets) ; profil concave (raide sous la crête, doux au
     pied) ; formes irrégulières (domaine déformé par du bruit).
  2. **Ravines et éperons** qui descendent les versants, petites crêtes partout (bruit en crêtes).
  3. **Érosion simulée** : l'eau qui ruisselle creuse les vallées (60 passes), les éboulis glissent jusqu'à une pente
     d'équilibre (reste praticable à pied).
  4. Un bras de mer sépare les deux îles. **Zones** selon l'altitude, la pente et l'eau : roche sur les crêtes et
     les pentes raides, neige au sommet, forêt au fond des vallons, herbe ailleurs.
- Textures du sol : au loin, la grande échelle l'emporte (plus de rayures de répétition sur la roche).

### Accessoires Higgsfield, herbe, tenues de camouflage (28/10/2026)
- **Accessoires** de la scène 3D Jutsu « Sniper Arena » de l'utilisateur (`sources/arena_higgsfield.glb`), sortis par
  `tools/accessoires.gd` dans `game/art/accessoires/` (sacs de sable, petit muret, tour de tireur avec filet de
  camouflage, caisse de munitions, fût, tronc) ; matières du jeu posées dans `world.gd` → `PROP_MATS`.
  - Une cachette sur quatre est un **nid de sacs de sable** (muret sur deux hauteurs, retours, caisse et fût).
  - Une **tour de tireur** par île, sur le versant face à l'autre île, à l'endroit le plus plat (poste visible).
  - **Troncs couchés** en forêt (dans la scène d'origine ils étaient debout).
- **Herbe qui clignotait** : le tirage au sort de chaque touffe dépendait de sa position recalculée depuis la caméra ;
  sur téléphone, les arrondis changeaient le tirage d'une image à l'autre. Tirage maintenant fixe (`grass.gdshader`) ;
  au loin la transparence est renforcée selon la taille de l'image utilisée (les brins ne scintillent plus).
- **Peinture remplacée par des tenues** (la peinture libre reviendra dans un mode à part : `main.gd` → `PAINT_MODE`).
  À l'atelier « Camouflage » on choisit une tenue (`paint.gd` → `OUTFITS` : Forêt, Herbe, Pierre, Neige, Olive), avec
  un motif de taches aux teintes du terrain, et on peut ajouter la **tenue de feuillage (ghillie)** : 260 touffes
  d'herbe accrochées au corps, qui suivent les os (`world.gd` → `set_ghillie`), bonus de camouflage +10 %.
  L'ennemi porte aussi une tenue (et parfois le feuillage).
- *29/10/2026* : les tenues prennent les **quatre motifs de camouflage donnés par l'utilisateur** (`art/camo_woodland.jpg`,
  `camo_terrain_sec.jpg`, `camo_arctique.jpg`, `camo_digital_olive.jpg`, rendus raccordables par miroir), plaqués sur le
  corps par le shader camo (`camo_tex`). Le camouflage de chaque tenue sur chaque terrain est réglé dans
  `paint.gd` → `OUTFITS` ; l'ennemi prend la tenue de son terrain (`ZONE_OUTFIT`). Les nids de sacs de sable sont
  retirés des cachettes (de loin, ils ressemblaient à des tas de pierres) ; le muret reste disponible (`_make_cover("sacs")`).

### Vrai son de sniper (29/10/2026)
- Enregistrement de Kar98k fourni par l'utilisateur (`sources/k98_pixabay.mp3`, Pixabay, auteur sovetsky_rastov72 :
  licence Pixabay, utilisable dans un jeu vendu ; à revérifier sur la page du son avant Steam).
- `tools/sons_k98.sh` (ffmpeg) le découpe : `art/son_tir.ogg` = premier tir puis la culasse qu'on réarme ;
  `art/son_loin.ogg` = second tir, étouffé et avec plus d'écho (le tir de l'ennemi, entendu de l'autre île, arrive
  avec le retard du son). La balle qui passe tout près (`art/son_impact.wav`) reste calculée par `tools/sons.py`.

### CameraRig, pas A (30/10/2026)
- Architecture caméra : `docs/audit_architecture_v1.md` (audit), `docs/proposition_architecture_v1.md` (proposition validée, migration en 7 pas).
- Pas A : `scenes/camera_rig.tscn` + `scripts/camera_rig.gd` possèdent la seule caméra du jeu (création, caméra active,
  angle de vue, portrait/paysage). `main.gd` (`rig`, `camera = rig.camera`) et `hider.gd` la placent encore comme avant.
  Aucun changement visible ni de jeu.
- Tests : `tools/tests/test_camera.gd` (toutes les phases, 46 vérifications) et `tools/tests/captures_camera.gd`
  (6 vues à hasard fixé : deux versions identiques donnent les mêmes pixels). Les deux demandent un affichage (xvfb),
  pas `--headless` (le jeu attend la première image avant de construire l'archipel).

### CameraRig, pas B (30/10/2026)
- Le rig pilote maintenant la caméra du **menu** (vue de la vallée, lent va-et-vient) et de l'**atelier** (orbite autour
  du sniper : glisser à la souris ou au doigt, molette, pincer ; 1,4 à 6 m ; hauteur selon la posture).
  `camera_rig.gd` : modes `MENU`, `WORKSHOP`, et `EXTERNAL` (cachette et tir, encore placés par `hider.gd` et `main.gd`).
- `main.gd` garde la lecture des entrées (quel bouton, quel doigt, panneau touché) et appelle `rig.orbit()`,
  `rig.orbit_wheel()`, `rig.orbit_pinch()` ; `_workshop_center()` donne le point regardé.
- Vérifié : trace chiffrée de la caméra image par image identique avant/après (`tools/tests/trace_camera.gd`),
  11 captures identiques au pixel près, 70 vérifications automatiques, version web dans Chromium.

### CameraRig, pas C (30/10/2026)
- Le rig pilote la **caméra de tir** (mode `SCOPE` : révélation, tir, fin) : position à l'œil, regard limité à ±1,1 rad
  autour de l'axe de départ (plus fin quand on zoome), zoom x1/x4/x10 (`ZOOM_FOV`), balancement, recul.
- Le **tir** lit `rig.aim_origin()` / `rig.aim_direction()` : exactement la caméra affichée, balancement et recul compris.
  Sa logique (rayon, arbres traversés, temps de vol, dégâts) ne change pas.
- La **jauge de souffle** reste dans `main.gd` (ressource de jeu) ; le rig reçoit seulement « souffle retenu / à bout
  de souffle » (`rig.sway()`), avec la même formule de balancement. Le **reflet** lit `rig.zoom_level`.
- Recul : `rig.recoil_kick()` (tir, 0,012 rad), `rig.recoil_flinch()` (balle ennemie tout près, −0,006), `rig.reset_recoil()`.
- Reste en mode `EXTERNAL` : la cachette (pas D).
- Vérifié : trace chiffrée (179 relevés : regard, butées, zoom, reflet après 5 s au x10, souffle retenu puis
  essoufflement, recul, sursaut, fin) identique avant/après ; captures avant/après ; 84 vérifications automatiques.

### Compteur de performances ?perf (30/10/2026)
- Ajouter `?perf` (ou `#perf`) à l'adresse de la version web, ou lancer avec `-- --perf` sur PC : un petit encadré
  affiche, sur chaque demi-seconde, les images par seconde, la durée moyenne et la pire durée d'une image, le nombre de
  saccades (images de plus de 20 ms), le temps de process, le temps de rendu CPU/GPU (GPU : « n/d » si le navigateur
  ne le donne pas), les appels de dessin et les triangles. Sans ce mot, `main.gd` ne crée pas le compteur : aucun coût.
- `scripts/perf_overlay.gd` ; test : `tools/tests/test_perf.gd` (présent avec `--perf`, absent sans).

### Cailloux du champ d'herbe allégés (30/10/2026)
- Les ≈ 2 700 cailloux gris et mottes de neige du champ d'herbe (dessinés à chaque image) utilisent `_pebble_mesh` :
  même bruit et même forme que les rochers (`_rock_shape`), sphère de départ 10 × 7 au lieu de 14 × 9,
  soit 160 triangles au lieu de 280. Mêmes places, mêmes tailles ; les rochers du décor ne changent pas.
- Mesuré (vue de tir vers l'île d'en face) : 1 212 000 → 890 000 triangles (−27 %) ; vue sur la végétation proche :
  1 037 000 → 715 000. Essai à 96 triangles écarté : facettes visibles à 2 m dans l'atelier.
- Comparaison avant/après : `docs/audit/perf/cailloux_*.png` (à gauche avant, à droite après).
- Choix définitif (30/10/2026) : 160 triangles. Comparé à 280 et 96 sur 14 vues (atelier à 3 m et 1,4 m,
  cachette sous 6 angles, marche, tir) : 96 gagnerait encore ≈ 170 000 triangles mais les cailloux deviennent
  anguleux de près et l'écart avec l'original est 1,5 fois plus grand partout. Planches : `cailloux_280_160_96_*.png`.

### Terrain affiché en 64 morceaux (30/10/2026)
- `_build_terrain` : l'affichage du terrain est découpé en 8 × 8 morceaux (`TERRAIN_CHUNKS`, `_terrain_chunk`) qui
  recopient tels quels les sommets, normales, couleurs, poids des textures et le découpage des triangles ; même matériau.
  La collision reste le terrain entier d'un seul bloc (`create_trimesh_shape` sur le maillage complet).
- Effet : les morceaux hors de la vue ne sont plus dessinés, et seuls les morceaux à moins de 90 m (zone des ombres)
  sont redessinés dans les ombres, au lieu du terrain entier deux fois.
- Mesuré (moyennes par groupe de vues, triangles vus + ombres) : cachette 1 280 000 → 765 000 (−40 %) ; tir
  1 209 000 → 662 000 (−45 %) ; vues des deux îles −36 % ; vue ennemie −47 %. Ombres : −86 à −98 %.
  Appels de dessin : +10 à +15 %.
- Vérifié : 300 rayons de visée et de tir entre les deux îles et la marche du sniper identiques au chiffre près ;
  38 vues comparées (deux îles sous 4 angles, crêtes x1/x4/x10, cachette, ombres, vue ennemie, 15 vues de référence) :
  au plus 0,06 % de pixels différents, des pixels isolés sur le bord des ombres et sur la ligne où l'eau touche la
  plage (cadrage des ombres et ordre de dessin) ; rien sur les personnages. Planches : `docs/audit/perf/terrain_*.jpg`.

### Forêt alpine : composition du décor (30/10/2026)
- `_scatter` ne sème plus des points au hasard sur toute la carte : grille de 4,6 m légèrement décalée, et pour chaque
  point une **carte de densité** (bruit à grande échelle + bords irréguliers) selon la zone, la pente et l'altitude.
  Forêts, bosquets, clairières et lisières ; forêt dense en bas, rare sur les pentes raides, absente au-dessus de la
  limite des arbres (≈ 104 m ± 15) ; arbres jusqu'à 18 m en bas, de plus en plus petits en montant, puis pins rabougris
  (et sapin givré) à la limite ; quelques arbres isolés dans les prés (feuillus en bas) ; espacement minimal entre arbres.
- **Peuplements** en grandes taches : épicéas (`tree07`, `tree12`, `tree05`), pins et mélèzes (`tree01`, `tree11`,
  `tree04`), sapins (`tree09`, `tree10`) ; `tree06` givré vers la limite ; feuillus `tree19`, `tree24`, `tree22` ;
  buissons `bush02`, `bush06`, `bush04` (9 modèles ajoutés depuis `sources/tree_pack_1.1`, préparés comme les autres :
  photo 128 px agrandie à 256 px). Chaque arbre a sa nuance (`_tree_tint`, couleur par instance du MultiMesh).
- **Rochers** en amas (`_rock_cluster` : beaucoup de petits, quelques gros), une forme par versant (`_rock_region`,
  trois formes légères dont une à facettes), nuance par endroit (`_rock_tint`). Les cailloux du champ d'herbe de la zone
  de roche sont plus sombres, plats et petits (ils ressemblaient à des œufs blancs).
- **Gameplay inchangé** : dans la zone de jeu (210 m autour du centre de chaque île) la forêt est réglée pour garder le
  couvert d'avant (`PLAY_FILL`) ; au-delà, forêt pleine (`FOREST_FILL`). Grands arbres, buissons hauts (≥ 1,2 m) et
  rochers gardent leur collision (taille de collision proportionnelle au modèle) ; buissons bas et petits cailloux
  (< 1,1 m) sont du décor sans collision ; cachettes dégagées (12 m) comme avant.
  Mesuré (800 lignes de vue entre les îles, exposition du joueur en 400 endroits × 3 postures) : lignes de vue dégagées
  17,8 % → 17,5 % ; exposition moyenne −1 à −2 %.
- Coût mesuré : triangles +2 à +9 %, appels de dessin +1 à +8 % (chaque zone de 175 m n'utilise que 2 ou 3 modèles
  d'arbres et 1 ou 2 formes de rocher) ; construction du monde 0,7–0,9 s → 1,2 s (sur ordinateur).
- Planches avant/après : `docs/audit/foret/`.

### Tours et rondins retirés (30/10/2026)
- Demande de l'utilisateur : les tours de tireur (une par île) et les rondins couchés en forêt, tirés de la scène
  Higgsfield, sont retirés du jeu (`_build_towers` et la pose des rondins supprimés de `world.gd`). Les fichiers
  `game/art/accessoires/` restent dans le dépôt (non utilisés). Comparaison avant/après : `docs/audit/pour_gpt/`.

### Îles Higgsfield, heure dorée, feuillages (30/10/2026)
- **Relief** : la forme des deux îles vient d'une carte de hauteurs générée par Higgsfield (`sources/higgsfield/relief_ile_*.png`,
  crêtes, ravines et côtes de l'image). `python3 tools/relief.py relief.bin sources/higgsfield` puis `relief_vers_godot.gd`.
  Réglages (`HF_*` en tête de `relief.py`) : grandes formes gardées, petites crêtes atténuées (`HF_DETAIL`), pied des montagnes
  en pente (`HF_FOOT`), sommets à 125 m (`HF_PEAK`), crête principale reculée de 45 m derrière les cachettes (`HF_BACK`, sinon
  elle cache la moitié de l'île). Seuils des zones relevés pour ces îles (même part de forêt et de roche), limite des arbres
  relevée dans `world.gd` (forêt jusqu'à 140 m).
- **Jouabilité mesurée** (avant → après) : lignes de vue entre îles 17,5 % → 17,2 % ; exposition debout 0,277 → 0,254 ;
  endroits bien cachés 61,5 % → 65,2 % ; surface de couvert 21 900 → 24 900 m².
- Départ du joueur et petite lunette ennemie posés sur le relief (`main._shore_start`) au lieu de positions fixes.
- **Textures du sol** : 5 textures Higgsfield (`sources/higgsfield/textures/`) → `game/art/sol_*.jpg` et `relief_*.jpg`
  par `python3 tools/textures_higgsfield.py` (raccordables, moyenne 0,5 : le camouflage ne change pas).
- **Ciel et lumière** : ciel d'heure dorée Higgsfield (`art/ciel.jpg`, sans le disque du soleil), soleil bas (25°) et doré,
  halo autour du soleil, nuages teintés, brume chaude.
- **Feuillages** : planches Higgsfield découpées (`art/vege_*.png`) : grandes herbes, fleurs alpines (gentianes, edelweiss,
  arnica), gazon ras sur l'herbe, fougères en forêt, bruyère entre les rochers (décor seulement, sans collision).
- Essais non retenus : îles en 3D Meshy (maquettes rondes, détail trop faible à 870 m) ; faune Meshy en attente (bouquetin
  et aigle réussis, chamois et pin nain ratés).

### Viseur de sniper, souffle, caméra embarquée, départ en hauteur (31/10/2026)
- **Viseur** (`SCOPE_SHADER` dans `hud.gd`) : verre rond cerné d'un épais tube noir, bords du verre assombris, réticule fin
  avec gros traits à gauche, à droite et en bas, points de repère (mil-dots) autour du centre, point rouge central.
  Le x1 garde sa petite croix.
- **Respiration** (retirée le 31/10) : `art/son_souffle.wav` (synthétisée par code, aucun crédit ; boucle de 4,6 s, inspiration puis expiration).
  Elle joue quand on vise (lunette x4 / x10, ou clic droit pendant la cachette), s'étouffe quand on retient son souffle,
  devient plus rapide et plus forte à bout de souffle (`main._breath_sound`).
- **Angle de vue** : cachette 62° → 70° (`HIDE_FOV`), +9° en courant (`RUN_FOV_KICK`, progressif).
- **Caméra embarquée** (`hider._apply_bob`) : en marchant et en courant, la caméra rebondit à chaque pas, penche et plonge
  un peu ; plus fort en courant ; nul à l'arrêt.
- **Départ en hauteur** (`main._high_start`) : 70 m au-dessus de la mer, sur un endroit dégagé avec vue libre vers l'île
  d'en face ; le joueur redescend chercher sa cachette.

### Réglages de sensibilité souris / tactile (31/10/2026)
- Demande de l'utilisateur : au doigt, il fallait balayer l'écran plusieurs fois pour chercher à la lunette.
- Menu principal → bouton « Réglages » : deux lignes (souris, tactile) avec − / + par pas de 0,25, de ×0,25 à ×5.
  Valeurs par défaut : souris ×1 (comme avant), tactile ×2 (deux fois plus de rotation qu'avant). Le multiplicateur
  s'applique au regard à la lunette et au regard pendant la cachette. Enregistré dans `user://reglages.cfg`
  (conservé d'une séance à l'autre quand le navigateur le permet).
- Test : `tools/tests/test_reglages.gd`.

### Artefact version 22 (31/10/2026)
- Publié : îles Higgsfield, textures, ciel d'heure dorée, feuillages, nouveau viseur, respiration, caméra embarquée,
  départ en hauteur, réglages de sensibilité. `index.pck` = 12,47 Mo (limite 15 Mo par fichier).
- Décision de l'utilisateur : on n'exécute plus le long test de caméra (`tools/tests/test_camera.gd`, ~10 min) à chaque
  changement. Les vérifications rapides (`test_reglages.gd`, mesures de jouabilité, captures) restent à la demande.

### Saut, caméra rapprochée, pentes raides ; respiration retirée (31/10/2026)
- Respiration retirée (demande de l'utilisateur : le son ne ressemblait pas à une respiration) : `son_souffle.wav` supprimé.
- Caméra de la cachette rapprochée, par-dessus l'épaule : distance 4,2 → 2,2 m debout (2,0 accroupi, 1,9 couché),
  décalage d'épaule 0,45 → 0,55 m.
- Pentes : le personnage gravit jusqu'à 64° (avant 50°) ; on peut sauter (Espace, bouton « Sauter » au doigt),
  ≈ 0,9 m de haut. Animations Jump_Start / Jump_Loop / Jump_Land de la bibliothèque Quaternius (déjà utilisée pour la
  marche, CC0), ajoutées à `sniper_anime.scn` par `tools/sniper_anime.gd` (aucun crédit Higgsfield). États dans
  `hider._update_air` : impulsion, en l'air, réception (une petite descente de moins de 0,3 s ne déclenche rien).

### Bande son forêt, caméra de course adoucie (31/10/2026)
- Bande son : ambiance de forêt fournie par l'utilisateur (La Sonothèque, « AMBForst Forêt ID 0100 », sons libres de droits,
  lasonotheque.fr), mise en boucle sans coupure (fin fondue dans le début sur 3 s) → `game/art/son_foret.ogg` (700 Ko).
  Remplace les vagues et le vent synthétisés (`life.gd`) ; les cris de mouettes restent.
- Caméra embarquée adoucie (demande : « trop brutal ») : balancement ÷ 3 environ (rebond 1,6 cm, roulis 0,4°),
  montée en douceur ; élargissement de l'angle en courant 9° → 5°, plus progressif.

### Artefact version 23 (31/10/2026)
- Publié : saut animé, caméra rapprochée, pentes à 64°, respiration retirée, bande son forêt, caméra de course adoucie.
  `index.pck` = 13,37 Mo (limite 15 Mo par fichier : il reste ≈ 1,6 Mo de marge).

### Gadgets dans des caisses, zoom en double tape, mouette retirée (31/10/2026)
- Cri de mouette retiré (demande de l'utilisateur).
- **Caisses** (`scripts/gadgets.gd`) : 3 par partie sur ton île, entre 25 et 110 m du départ, avec un faisceau orange
  pour les repérer. Textures Higgsfield (`art/caisse.jpg` : face « MATÉRIEL », dessus à poignées, côté ; ≈ 1 crédit pour
  les 4 images avec les icônes `art/gadgets_icones.png`). On ramasse en passant dessus ; on porte 2 gadgets au plus.
- **Gadgets** (touches 1 / 2, ou boutons à gauche au doigt, visibles seulement quand on porte un gadget) :
  - Viseur thermique (pendant le tir) : 6 s, monde sombre en palette « fer chaud », le corps de l'ennemi brille
    (atténué s'il porte la tenue de feuillage) ; la lunette brille 2 fois plus vite pendant ce temps.
  - Écho de tir (pendant le tir) : 30 s, chaque tir ennemi laisse un repère rouge (à ± 12 m) visible à travers le décor.
  - Leurre (pendant la cachette) : un sniper accroupi posé là où tu es ; les 2 tirs ennemis suivants le visent.
  - Couverture de survie (cachette ou tir) : 20 s, l'ennemi te repère 2,5 fois moins vite.
- **Zoom au doigt** : double tape sur la vue de tir (le bouton Zoom est retiré).

### Artefact version 24 (31/10/2026)
- Publié : gadgets et caisses, zoom en double tape, mouette retirée. `index.pck` = 13,60 Mo (limite 15 Mo : ≈ 1,4 Mo de marge).

### Thermique visible, ordinateur ralenti, caisses face à l'ennemi (31/10/2026)
- Thermique : en plus du filtre, une tache de chaleur (au moins 26 × 44 px à l'écran) marque l'ennemi à travers les
  feuillages, jamais à travers le relief (`gadgets._update_heat`, tracé contre la carte des hauteurs) ; plus faible
  s'il porte la tenue de feuillage. Monde un peu moins sombre (luminosité 0,45).
- Ordinateur ralenti (`LEVELS`) : premier tir 16 → 26 s (normal), tirs espacés de 10 à 14 s, repérage ≈ 45 % plus lent.
- Caisses seulement sur le versant face à l'ennemi (pas plus de 12 m derrière le point de départ).

### Nouvelles tenues et tenues de feuillage (31/10/2026)
- 6 tenues Higgsfield remplacent les 4 anciennes (`paint.gd` → `OUTFITS`, motifs dans `sources/higgsfield/camouflage/`) :
  Forêt alpine, Prairie, Granit, Neige et roche, Multi-alpin, Bruyère, chacune avec sa ressemblance par terrain.
  L'ennemi porte la tenue du terrain qu'il a choisi (`ZONE_OUTFIT`).
- 5 tenues de feuillage au choix au lieu d'une (`GHILLIES`) : Herbes hautes, Fougères, Branches de pin, Bruyère,
  Lichen et neige (planches Higgsfield ; pin et lichen nouveaux, ≈ 0,5 crédit). Le bonus dépend du terrain
  (ex. pin +15 % en forêt, lichen +14 % sur la neige) au lieu de +10 % partout. L'ennemi en porte une sur deux.

### Artefact version 25 et poids allégé (31/10/2026)
- Publié : nouvelles tenues et feuillages, thermique avec tache de chaleur, ordinateur ralenti, caisses face à l'ennemi.
- Poids : `index.pck` était monté à 14,9 Mo (limite 15 Mo). Les images JPG du jeu sont maintenant importées en
  compression « avec perte » (WebP, qualité 0,82 ; `compress/mode=1` dans les `.import`) au lieu de « sans perte » :
  `index.pck` = 8,4 Mo, rendu vérifié sur captures. Garder ce réglage pour toute nouvelle image JPG.

### Interface DUSKLINE (31/10/2026)
- Le jeu s'appelle **DUSKLINE** (titre de l'accueil, page de chargement de l'artefact).
- Accueil refait façon jeu de tir moderne : photo `menu.jpg` en plein écran, dégradé sombre à droite, titre en grandes
  capitales, boutons biseautés (`hud._tac_button`, `StyleBoxFlat.skew`). Police **Barlow Condensed** (licence OFL,
  `art/police_600.woff`, `police_800.woff`, `police_LICENCE_OFL.txt`) pour toute l'interface.
- Boutons tactiles : cercles sombres translucides, liseré fin, icône (Higgsfield, `art/commandes_icones.png`, ≈ 0,25 crédit)
  et libellé court. Boutons de gadgets avec l'icône du gadget.
- Gadgets portés : deux cases avec icône et touche (1 / 2) en haut à gauche (au doigt, les boutons portent l'icône).
- Petite lunette ennemie retirée de la cachette (plus de deuxième rendu de la scène).

### Artefact version 26 (31/10/2026)
- Publié : interface DUSKLINE (accueil, police, boutons à icônes, cases de gadgets), lunette ennemie retirée. `index.pck` = 8,44 Mo.

### Sons de menu, balles qui traversent les feuillages (31/10/2026)
- Sons de l'interface tirés du même enregistrement du Kar98k (`tools/sons_k98.sh`) : clic de culasse sur chaque bouton
  (`son_ui_clic.ogg`), cycle complet de la culasse (balle chambrée) sur JOUER (`son_ui_culasse.ogg`).
- Tir : la balle traverse les feuillages (buissons, houppiers) à toute distance ; seuls les troncs (à moins de 0,35 m
  de l'axe, `world.hits_trunk`), les rochers et le relief l'arrêtent. Avant, la boîte du buisson d'une cachette en forêt
  arrêtait la balle : 3 cachettes en forêt sur 11 étaient impossibles à toucher alors que l'ennemi était visible.

### Bruits de pas et d'équipement (31/10/2026)
- Sons créés avec Higgsfield (≈ 15 crédits) : trois vidéos Seedance 2.0 Mini de 10 s avec son (bottes dans l'herbe,
  bottes sur feuilles et brindilles, frottement de la tenue et du sac en courant), dont on ne garde que le son.
  Pas détectés et découpés automatiquement : `son_pas_herbe_1..4.ogg`, `son_pas_feuilles_1..4.ogg` (0,35 s chacun) ;
  `son_equipement.ogg` : boucle de 6,5 s (fondu enchaîné, pics écrêtés).
- `hider.gd` : un pas à chaque appui (deux par foulée, au rythme du balancement de la caméra), feuilles en forêt et herbe
  ailleurs, 4 variantes avec hauteur et volume tirés au hasard (`AudioStreamRandomizer`) ; plus fort en courant, plus
  doux accroupi, rien couché ; un pas appuyé à la réception d'un saut. Équipement : muet à l'arrêt, léger en marchant,
  net en courant. Tout se tait à la fin de la cachette (`hider.silence`).

### Artefact version 27 (31/10/2026)
- Publié : bruits de pas et d'équipement, sons de culasse dans le menu, balles qui traversent les feuillages. `index.pck` = 8,60 Mo.
- Correction (31/10/2026, « plusieurs sons de course se superposent ») : la boucle d'équipement contenait aussi les pas
  du soldat filmé ; elle est filtrée (passe-haut à 1,8 kHz, transitoires écrasés : il ne reste que le froissement),
  original gardé dans `sources/higgsfield/son_equipement_brut.ogg`, et jouée plus bas (−15 dB en courant). Un seul pas
  à la fois (`max_polyphony = 1`).

### Artefact version 28 (31/10/2026)
- Publié : correction des sons de course superposés. `index.pck` = 8,60 Mo.

### Vraie lunette, écran titre lisible, chargement assorti ; frottement retiré (31/10/2026)
- Frottement de l'équipement retiré (on garde seulement les pas).
- Lunette (`SCOPE_SHADER`) : tube vu de l'intérieur. Oculaire et objectif sont deux cercles ; l'objectif se décale
  (parallaxe, `hud.set_scope_parallax`, calculée dans `main.gd` selon le balancement, le recul et les mouvements du
  regard, puis revient au centre). Entre les deux, l'intérieur sombre du tube, éclairé d'en haut ; verre assombri sur les
  bords, frange colorée discrète, réticule fin à gros traits et mil-dots, liseré de l'oculaire.
- Écran titre : titre, accroche et texte sur une plaque sombre à filet orange, capitales grasses bordées de noir
  (`_title(..., outline)`), lisible sur le ciel et au téléphone debout.
- Page de chargement de l'artefact : même direction artistique (Barlow Condensed via Google Fonts, plaque à filet
  orange, titre DUSKLINE, barre biseautée orange).

### Artefact version 29 (31/10/2026)
- Publié : vraie lunette, écran titre lisible, chargement assorti, frottement retiré. `index.pck` = 8,54 Mo.

### Écran titre façon Call of Duty (31/10/2026)
- Demande : « c'est moche, avant c'était plus beau, inspire-toi de Call of Duty ». Plus de plaque de texte : la photo
  `menu.jpg` en plein écran assombrie comme au cinéma (haut, bas, bords), le **logo DUSKLINE** créé avec Higgsfield
  (`art/logo.png` et `tools/artefact/logo.png` : capitales usées, viseur orange dans le K, « DUEL DE SNIPERS », filet
  orange ; ≈ 0,5 crédit) au centre, avec des bandes « glitch » orange et noires derrière qui scintillent, puis trois
  choix : JOUER (orange), ADVERSAIRE : NORMAL (appuyer change de niveau), RÉGLAGES ; les aides en petit en bas.
- Page de chargement de l'artefact refaite à l'identique (même logo, mêmes bandes animées en CSS, barre fine biseautée).

### Artefact version 30 (31/10/2026)
- Publié : écran titre et chargement façon Call of Duty (logo `logo.png` publié à côté de la page). `index.pck` = 8,82 Mo.
- Correction (31/10/2026, « deux pas qui se chevauchent, on dirait un cheval au galop ») : chaque son de pas contenait deux
  impacts (le pied filmé et le suivant, ou un petit coup avant le principal). Chaque son est recoupé sur son seul impact
  principal (0,16 s) ; les deux qui gardaient un second coup sont remplacés par des sons propres (la hauteur au hasard
  les rend différents).

### Artefact version 31 (31/10/2026)
- Publié : pas à un seul impact (plus de galop). `index.pck` = 8,81 Mo.
- Nouveaux pas (31/10/2026, « on dirait des talons ; mets le frottement de l'équipement dans le même son ») : deux vidéos
  Higgsfield (10 crédits) d'un sniper en bottes souples, foulée lente, appuis espacés, frottement de la tenue et des
  sangles à chaque appui. Chaque son = un seul appui avec son frottement (herbe ≈ 0,4 s, feuilles ≈ 0,2 s), silence
  du début retiré pour que le pas tombe pile au bon moment.
- Bandes de l'écran titre et du chargement : fixes (plus de clignotement).

### Artefact version 32 (31/10/2026)
- Publié : pas avec frottement d'équipement, bandes du titre fixes. `index.pck` = 8,82 Mo.

### Thermique bridé, bruitages des gadgets, changer de cachette, impacts violents (31/10/2026)
- **Thermique** (« cheaté ») : plus de point précis. Une grande zone de chaleur floue (≈ 16 m), décalée au hasard
  jusqu'à 7 m du corps à chaque allumage : on sait où chercher, pas où tirer (`gadgets.HEAT_ZONE`, `HEAT_OFFSET`).
- **Bruitages des gadgets** : ramassage (deux notes, façon Metal Gear), thermique allumé / éteint (sifflement qui monte
  / descend), écho (bip radio) — synthétisés (`tools/sons_gadgets.py`) ; couverture de survie (papier alu froissé) et
  leurre (corps lourd posé dans l'herbe) — vidéo Higgsfield (5 crédits).
- **Changer de cachette pendant le tir** (R, ou BOUGER au doigt) : 15 s pour se déplacer comme pendant la cachette
  (marcher, courir, sauter, poser un leurre) ; l'ennemi continue de tirer et te repère 3 fois plus vite. R / LUNETTE
  (ou la fin des 15 s) pour reprendre la lunette là où tu es (`main.start_move`, `end_move`, `_process_move`).
- **Impacts violents** : éclair, gros nuages de poussière de la couleur du sol (fumée douce tournée vers la caméra),
  éclats de roche projetés qui retombent et rebondissent, son d'impact sur la roche (vidéo Higgsfield, 5 crédits) qui
  arrive avec le retard du son. **Les rochers des cachettes se détruisent** : 3 balles et le rocher vole en éclats,
  l'ennemi derrière est à découvert (`world.damage_cover`) ; ils reviennent à chaque partie (`restore_covers`).

### Artefact version 33 (31/10/2026)
- Publié : thermique en zone floue, bruitages des gadgets, changer de cachette, impacts violents, rochers destructibles. `index.pck` = 8,96 Mo.

### Étalonnage de l'image, feuillages moins éclairés (31/10/2026)
- Un « filtre » unique sur toute l'image (`main._build_environment`) : saturation 0,82, contraste 1,08 et courbes par
  couleur (LUT 1D, `adjustment_color_correction`) : ombres légèrement bleu-vert, lumières dorées. Unifie le ciel,
  le relief, les feuillages et le personnage.
- Feuillages trop clairs par rapport au sol : planches d'herbe, de fleurs, de fougères et de bruyère ramenées à 75 %
  (photos Higgsfield plus claires que le sol) et éclairage plafonné ; arbres à 85 % avec un contre-jour adouci.

### Artefact version 34 (31/10/2026)
- Publié : étalonnage de l'image, feuillages ramenés au niveau du sol. `index.pck` = 8,96 Mo.
- Réglage final choisi par l'utilisateur (31/10/2026) : la version la plus sombre — planches d'herbe et de fleurs à 60 %,
  arbres à 78 %, contraste 1,14, ombres profondes bleu-vert (courbe 0 → 0,015 / 0,03 / 0,05 ; 0,25 → 0,21 / 0,24 / 0,26).

### Artefact version 35 (31/10/2026)
- Publié : étalonnage sombre choisi par l'utilisateur. `index.pck` = 8,96 Mo.
- Correction (31/10/2026, « tu as mis de l'ombre, je veux juste étalonner les couleurs ») : plantes remises presque à
  leur luminosité (herbe et fleurs 90 %, arbres 92 %), et le filtre ne fait plus que teinter sans assombrir : courbes
  proches de l'identité (ombres à peine bleutées, lumières dorées), contraste 1,04, saturation 0,86.

### Artefact version 36 (31/10/2026)
- Publié : étalonnage des couleurs seulement, plantes à leur luminosité. `index.pck` = 8,96 Mo.

### Couché sur les rochers, champs de lavande, coin enneigé (31/10/2026)
- Bug : couché sur un rocher très raide, le corps se tordait. Inclinaison du corps couché bornée à ≈ 23°
  (`hider.MAX_PRONE_TILT`) ; impossible de se coucher sur une pente de plus de ≈ 37° (`MAX_PRONE_SLOPE`, message).
- Champs de lavande : la planche de bruyère teintée lavande, dense, en grandes taches dans les prairies
  (`grass.gdshader` → `patch` : bruit à grande échelle et seuil).
- Coin enneigé : le haut du versant est de chaque île passe en zone neige (`tools/relief.py`, bord irrégulier ;
  hauteurs inchangées). Neige ≈ 14 % des îles. Jouabilité inchangée : lignes de vue 17,6 %, exposition 0,256.

### Artefact version 37 (31/10/2026)
- Publié : couché sur les rochers corrigé, champs de lavande, coin enneigé. `index.pck` = 8,96 Mo.

### Le soleil se couche pendant la partie, faux rayons de lumière (31/10/2026)
- Coucher de soleil (`main._set_dusk`, `DUSK_TIME` = 240 s depuis le début de la cachette) : soleil de 25° à 6°,
  lumière dorée → orange, plus faible, ambiance et brume plus roses, bas du ciel qui rougit et haut qui s'assombrit
  (`sky.gdshader` → `dusk`). Tout le décor (herbe, fleurs, arbres) suit la lumière du soleil : rien à régler à part.
  Retour à l'heure dorée au menu et à chaque partie.
- Faux rayons de lumière (« god rays », `RAYS_SHADER`) : à l'écran, on remonte de chaque pixel vers le soleil en
  additionnant les parties très claires (ciel, bords des nuages) ; la lumière fuit entre les arbres et les nuages,
  plus orange au coucher. Seulement quand le soleil est à l'écran ou juste à côté, pas à la lunette ni au thermique.
  16 lectures de l'écran par pixel : à surveiller au compteur `?perf` sur iPhone.

### Artefact version 38 (31/10/2026)
- Publié : coucher de soleil pendant la partie, faux rayons de lumière. `index.pck` = 8,97 Mo.
- Correction des rayons (31/10/2026, « le soleil est super fort et le côté lumineux bouge ») : seul le ciel tout près
  du soleil (≈ 30 % de l'écran autour) envoie des rayons, plus les nuages lointains ; force plafonnée à un léger voile,
  coupée dès que le soleil sort de l'écran, et qui varie en douceur quand on tourne.

### Artefact version 39 (31/10/2026)
- Publié : rayons de lumière plus doux et stables. `index.pck` = 8,97 Mo.

### Sniper : couleurs d'origine du modèle 3D (31/10/2026)
- Demande : « sa tenue, son visage et son sniper sont de la même couleur, on reprend le fichier 3D de base ».
- La tenue de camouflage et la peinture ne vont plus que sur les **vêtements** :
  - peau (visage, cou, mains) : masque `game/art/sniper_peau.png` (parties rosées de la texture d'origine,
    `tools/masque_peau.py`), qui garde la texture d'origine `sniper_couleur.jpg` ;
  - fusil : il reprend **sa propre texture** (`game/art/fusil_couleur.jpg`, tirée de `sources/fusil_higgsfield.glb`),
    lissée dans le shader (la texture générée est brouillée de près). `tools/sniper_anime.gd` garde les UV du fusil
    et marque ses sommets (CUSTOM0.w = 1) ; le fusil reste froid au viseur thermique.
- Artefact version 40 : publié. `index.pck` = 9,07 Mo.
- Fusil à plat contre le dos, de profil (31/10/2026, « faudrait le voir sur la longueur ») : la lunette ne pointe plus
  vers l'arrière, elle est dans le plan du dos (vers le bas à gauche) ; le fusil est collé à 2 cm du dos et se voit
  sur toute sa longueur de derrière. Artefact version 41 : publié.
- Caméra plus proche du personnage (31/10/2026) : distance derrière l'épaule 1,7 m debout (avant 2,2),
  1,5 m accroupi (2,0), 1,45 m couché (1,9) — `hider.gd` → `cam_d`. Artefact version 42 : publié.
