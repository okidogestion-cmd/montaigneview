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

- Une vallée de 1,4 km de côté. Deux montagnes face à face à environ **460 m** l'une de l'autre,
  entourées d'autres sommets pour le décor.
- 15 cachettes par montagne (5 directions × 3 hauteurs).
- Décor : sapins, rochers, buissons, avec des clairières autour des cachettes.
- Lumière de jour, brouillard léger à l'horizon.
- **Style visuel :** low poly, couleurs franches (le prototype utilise des formes simples :
  cônes pour les sapins, polyèdres pour les rochers). À garder pour la version Steam : c'est lisible,
  rapide à produire, et ça va avec l'idée de « repérer une couleur qui détonne ».

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
| 1. Prototype Godot | Refaire le prototype web à l'identique dans Godot, avec des formes simples | Une partie complète jouable |
| 2. Sensations | Sons, recul, éclairs, brouillard, menus propres, réglages | Le jeu « fait » vrai |
| 3. Contenu | 3 cartes, tenues, progression | Assez pour 2 à 3 heures |
| 4. Steam | Page Steam, succès, manette, Steam Deck, démo | Page « Bientôt disponible » |
| 5. En ligne | Duel 1 contre 1 entre amis | Mise à jour après la sortie, ou à la sortie |

## 9. Questions encore ouvertes

- **Nom du jeu :** « Duel des Cimes » (le prototype) ou « Montaigneview » (le dépôt) ?
- **Langues :** français seulement, ou aussi anglais (indispensable pour vendre sur Steam) ?
- **Prix visé :** petit jeu (5 à 10 €) ?
- **Ton :** réaliste et tendu, ou plus léger et coloré ?
