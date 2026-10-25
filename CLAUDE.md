# CLAUDE.md — Projet de jeu Steam « Les Deux Îles »

> **Document maître de conception et de développement.** Claude Code doit lire ce fichier avant toute modification du projet et s'y référer comme source de vérité. Le nom « Les Deux Îles » est un nom de travail et pourra changer.

## 0. Instructions impératives à Claude Code

### Ta mission
Construire progressivement un jeu PC 3D multijoueur 1 contre 1 sous **Godot 4.7.2 stable**, écrit en **GDScript**, destiné à Steam. Deux joueurs apparaissent chacun sur une île distincte. Ils disposent d'un temps pour se déplacer, observer et se cacher. Lorsque le compte à rebours se termine, le duel au fusil de précision commence : ils cherchent à repérer l'adversaire et à l'éliminer.

### Avant de coder
1. Inspecte l'arborescence actuelle, le fichier `project.godot`, les scènes, scripts, assets et éventuels documents de règles existants.
2. Ne remplace jamais un projet ou un fichier existant sans l'avoir inspecté. Si le dépôt est déjà commencé, adapte-toi à son architecture.
3. Vérifie la version exacte de Godot disponible dans l'environnement. La cible de référence est Godot **4.7.2 stable** ; ne passe pas à Godot 4.8 bêta pour ce projet.
4. Crée ou mets à jour `docs/PLAN.md` et `docs/PROGRESS.md` pour noter les étapes, les décisions, les tests réellement effectués et les problèmes restants.
5. Propose une courte stratégie technique, puis réalise la première tranche jouable. Ne génère pas tout le jeu en une seule opération.

### Règles de développement
- Le jeu doit rester **jouable à chaque étape importante**. Priorité à une petite boucle de jeu fonctionnelle avant le contenu secondaire.
- Utilise GDScript typé lorsque cela améliore la lisibilité. Évite C# et les dépendances externes pour le premier prototype.
- Préfère des scènes petites, réutilisables et bien nommées. Évite un script géant qui gère tout le jeu.
- Utilise les ressources natives de Godot et des meshes simples comme placeholders tant qu'aucun asset final n'est fourni. Ne prétends jamais qu'un placeholder est un asset final.
- Centralise les valeurs modifiables dans des variables `@export` ou des ressources de configuration : durées, vitesse, dégâts, sensibilité, zoom et distance des îles.
- N'ajoute pas de plugin uniquement « au cas où ». Toute dépendance doit avoir une raison, une compatibilité vérifiée avec Godot 4.7.2 et une procédure d'installation documentée.
- Aucun asset, personnage, symbole, carte, musique, interface ou modèle appartenant à Nintendo ou à un autre détenteur de droits ne doit être copié. L'inspiration porte sur des principes généraux — couleurs franches, silhouettes simples, ombres en aplats, environnement marin lisible — et non sur la reproduction de *The Legend of Zelda: The Wind Waker*.
- Ne présente pas le multijoueur comme fonctionnel avant d'avoir testé deux instances réelles du jeu. Ne présente pas la connexion Steam comme fonctionnelle avant un test via Steam.
- Après chaque étape : lance les vérifications possibles, corrige les erreurs introduites et écris dans `docs/PROGRESS.md` ce qui fonctionne réellement. Si Godot n'est pas disponible dans l'environnement, indique-le clairement et ne prétends pas avoir exécuté le jeu.
- Si une décision importante n'est pas spécifiée, choisis la solution la plus simple, réversible et cohérente avec ce document. Note la décision dans `docs/PLAN.md` au lieu de bloquer le travail pour une question mineure.

### Ordre de priorité
1. Boucle de jeu jouable et agréable.
2. Lisibilité et équité du duel.
3. Multijoueur 1 contre 1 fiable.
4. Direction artistique cohérente.
5. Menus, progression, options et intégration Steam.
6. Contenu secondaire et polish.

---

## 1. Vision du jeu

### Pitch
Deux tireurs se retrouvent face à face sur deux petites îles séparées par un lagon. Avant que les armes ne parlent, chacun dispose d'un court temps pour choisir son poste, trouver un abri, observer les reliefs et préparer son angle de tir. À la fin du compte à rebours, le silence est rompu : les deux joueurs tentent de repérer l'autre et de placer le tir décisif.

### Piliers de conception
1. **Cache-cache tactique :** choisir où se placer est aussi important que bien viser.
2. **Duel lisible :** les joueurs doivent pouvoir comprendre pourquoi ils ont été repérés ou touchés.
3. **Îles expressives :** des environnements compacts, mémorables et riches en silhouettes, sans surcharge de détails.
4. **Tension courte :** des manches faciles à relancer, avec un vrai crescendo entre la préparation et le duel.
5. **Équité avant le spectacle :** les deux îles offrent les mêmes avantages tactiques, même si leurs détails visuels diffèrent.

### Format cible
- Plateforme de lancement : PC via Steam.
- Genre : duel multijoueur 1v1, tactique, sniper, cache-cache.
- Caméra : troisième personne pendant l'exploration ; visée au fusil avec une vue à lunette dédiée.
- Nombre de joueurs par manche : exactement 2.
- Cible de performance : 60 FPS en 1080p sur un PC de milieu de gamme, à confirmer par profilage.
- Langue du prototype : français pour les interfaces provisoires ; préparer les textes pour la localisation.
- Ton : aventure estivale, légèrement espiègle, contemplative avant le duel et tendue pendant celui-ci. La violence reste stylisée, sans gore.

### Ce que le jeu n'est pas
- Pas un battle royale.
- Pas un jeu de tir militaire réaliste.
- Pas un jeu coopératif PvE.
- Pas un jeu de survie avec inventaire complexe.
- Pas une copie de Zelda ou d'un autre univers existant.

---

## 2. Boucle de jeu et règles d'une manche

### Structure d'une partie
Une partie est un duel au meilleur des **5 manches** : le premier joueur à gagner 3 manches remporte le match. Chaque manche utilise la même arène, avec une variation légère d'ambiance et de placement décoratif, sans modifier l'équilibre des postes de tir.

### Phase A — Préparation et dissimulation
- Durée par défaut : **60 secondes**.
- Les joueurs apparaissent chacun sur leur île.
- Déplacement, exploration, observation et choix d'un poste sont autorisés.
- Aucun tir ne peut infliger de dégâts pendant cette phase.
- Chaque joueur peut se baisser et utiliser les rochers, ruines, palmiers, cabanes ou reliefs pour casser sa silhouette et sa ligne de vue.
- Le sprint doit être plus rapide mais moins discret : il peut produire un effet visuel bref (sable soulevé, feuilles remuées) et des sons localisés. Ces indices ne doivent pas révéler automatiquement une position exacte à travers toute la carte.
- Les joueurs peuvent observer l'île adverse à l'œil nu. Les jumelles ou la lunette peuvent être utilisées pour examiner les silhouettes, mais aucun contour d'ennemi, marqueur à travers les murs ou radar omniscient ne doit être affiché.
- À 10 secondes de la fin, un signal visuel et sonore prévient du passage au duel.

### Transition
- Durée par défaut : **3 secondes**.
- Afficher un bref message central : « LE DUEL COMMENCE ».
- Bloquer les tirs pendant la transition, puis activer la phase de duel sur l'autorité de la partie.
- Le changement d'état doit arriver au même moment chez les deux joueurs, même si leurs animations d'interface sont légèrement différentes.

### Phase B — Duel au fusil de précision
- Durée cible : **120 secondes** avant prolongation.
- Les tirs sont autorisés.
- Chaque joueur possède un fusil de précision et **5 munitions par manche** au premier prototype. Les paramètres pourront être ajustés après les tests.
- Un tir touche si la ligne de visée atteint le personnage adverse, sans obstacle bloquant entre le tireur et la cible.
- Pour le prototype, **un tir confirmé élimine** l'adversaire. Ne pas créer de barre de vie, de dégâts aléatoires ni de dispersion artificielle avant les essais de jeu.
- La trajectoire de tir peut être simulée comme un raycast instantané, accompagné d'une trace visuelle et d'un son. Le système doit rester simple et cohérent avec une distance de duel courte.
- Le tir doit être bloqué si le joueur est en préparation, en transition, éliminé, sans munition ou encore en délai de réarmement.
- Un tir raté consomme une munition. Prévoir un court délai de réarmement pour éviter le spam.
- La lunette offre plusieurs niveaux de zoom réglables. Le zoom ne doit pas permettre de regarder à travers les obstacles.
- Ne pas intégrer une balistique compliquée, une déviation aléatoire ou un système de vent influant sur la précision dans le premier prototype. Ces options pourront être testées plus tard, uniquement si elles rendent le duel plus intéressant.

### Fin de manche et prolongation
- Dès qu'un joueur est éliminé, interrompre immédiatement les tirs et afficher le résultat.
- Si les 120 secondes s'écoulent sans élimination, démarrer une prolongation de **30 secondes**. Les postes de tir deviennent plus exposés via un événement d'ambiance lisible et symétrique (par exemple un feu de signalisation visible sur les deux îles), sans révéler directement les joueurs.
- Si personne n'est éliminé à la fin de la prolongation, la manche est déclarée nulle : aucun point n'est attribué et les joueurs relancent une manche. Éviter qu'une égalité réinitialise le score ou le match entier.
- Afficher le vainqueur, les tirs tentés, les tirs réussis et le nombre de manches gagnées, sans transformer le jeu en tableau de statistiques complexe.

### Contrat d'équité
- Les îles sont symétriques en matière d'avantages : mêmes hauteurs utiles, même quantité de couvert, mêmes lignes de tir principales et mêmes distances de tir.
- L'habillage peut varier : couleur du fanion, orientation de quelques plantes, détails de cabane, rochers secondaires. Ces variations ne doivent pas affecter les collisions ou le gameplay.
- Aucun joueur ne doit pouvoir tirer avant le signal de début du duel.
- Un tir est évalué par l'autorité de la partie, pas par une déclaration du client indiquant qu'il a touché.
- Les éléments bloquant les tirs doivent avoir une collision fiable. Les feuillages décoratifs peuvent être traversables ou bloquants, mais le choix doit être cohérent et lisible ; par défaut, les troncs, rochers, murs et ruines bloquent les tirs, les petites feuilles ne les bloquent pas.

---

## 3. Direction artistique

### Nom de travail de la direction artistique : « Atoll peint »

Le monde doit sembler fabriqué à la main : volumes simples, couleurs franches, formes généreuses et paysages immédiatement lisibles. La référence visuelle fournie est disponible dans `reference_art/DA_Atoll_Concept_Board.png`.

La référence sert à cadrer l'ambiance générale, pas à copier pixel pour pixel. Le rendu final doit conserver une identité propre.

### Principes visuels
- 3D stylisée avec cel-shading léger ou matériaux mats, ombres propres et contrastes graphiques.
- Formes simples, silhouettes lisibles à grande distance.
- Reliefs en volumes distincts : falaises, plages, chemins, plateaux, ruines et petites constructions.
- Végétation en groupes lisibles plutôt qu'en milliers de petites feuilles.
- Océan vivant mais calme, avec bandes de couleur, vagues discrètes et reflets stylisés.
- Ciel bleu riche, grands nuages volumineux et éclairage chaud en fin d'après-midi.
- Textures peintes ou procédurales très simples. Pas de réalisme photographique, pas de PBR lourd, pas de textures bruitées omniprésentes.
- Les contours ne doivent pas nécessairement être dessinés partout : privilégier les silhouettes, les valeurs et la séparation des plans.
- Les personnages peuvent être légèrement caricaturaux, avec une tête et des accessoires lisibles même à distance. Éviter les proportions ou costumes identifiables d'une licence existante.

### Palette de départ
Utiliser cette palette comme point de départ, pas comme une règle impossible à changer.

| Usage | Nom | Couleur |
|---|---|---|
| Ciel lumineux | Bleu ciel | `#73C7F2` |
| Océan principal | Bleu lagon | `#238EB6` |
| Eau peu profonde | Turquoise | `#55D3D0` |
| Écume / nuages | Ivoire nuage | `#FFF3D8` |
| Plage | Sable chaud | `#EBCB86` |
| Herbe | Vert île | `#78A957` |
| Feuillage ombragé | Vert profond | `#426D4D` |
| Bois | Bois miel | `#A97047` |
| Accent joueur A | Bleu outremer | `#347BC1` |
| Accent joueur B | Corail | `#E96C52` |
| UI sombre | Encre bleue | `#243743` |
| UI claire | Ivoire | `#FFF8E9` |

### Lumière et ambiance
- Ambiance par défaut : soleil de fin d'après-midi, ombres douces mais suffisamment nettes pour lire les formes.
- Le ciel et l'océan dominent l'image ; les îles occupent une proportion généreuse du cadre.
- Quelques variantes météo peuvent être prévues dans l'architecture, mais la première version n'a besoin que d'une ambiance jour ensoleillé.
- Une variante coucher de soleil et une variante nocturne sont des objectifs de polish, pas des prérequis du prototype.
- Le changement d'ambiance ne doit jamais rendre les adversaires impossibles à repérer ni donner un avantage caché à une île.

### Personnages
- Silhouette simple et expressive, proportions légèrement stylisées.
- Tenue d'aventurier maritime générique, tissu, ceinture, sac léger et foulard ou bande de couleur.
- Les accents bleu/corail identifient l'appartenance aux deux camps, sans devenir des marqueurs lumineux visibles à travers les obstacles.
- Le fusil doit être stylisé, crédible visuellement et lisible de loin ; éviter le look d'arme militaire moderne hyperréaliste.
- Animations nécessaires : repos, marche, sprint, accroupissement, visée, tir, réarmement, élimination.
- Au départ, utiliser un mannequin placeholder construit à partir de meshes simples si aucun personnage animé n'est disponible.

### Décors et silhouettes prioritaires
1. Une tour de guet en bois.
2. Une petite ruine de pierre envahie par la végétation.
3. Une cabane ou un abri.
4. Des palmiers et buissons de tailles variées.
5. Des rochers et falaises offrant des vrais couverts.
6. Un petit quai, quelques caisses et cordages.
7. Des fanions de couleur servant à identifier l'île depuis le large.
8. Des oiseaux lointains et effets marins, uniquement décoratifs dans le prototype.

### Lisibilité en jeu
- À l'échelle réelle du gameplay, un personnage debout doit être identifiable sur l'île opposée lorsqu'il est sur un emplacement exposé.
- Les couverts doivent casser clairement la silhouette et la ligne de tir.
- Les objets purement décoratifs ne doivent pas ressembler à un couvert si les tirs les traversent.
- La lunette doit aider à lire les détails sans remplacer le choix du bon poste.
- La végétation ne doit pas couvrir la moitié de l'écran, masquer le réticule ou générer des clignotements visuels.

### À ne pas faire
- Ne pas copier Link, les personnages de Nintendo, les symboles, les icônes, les menus ou le design exact de *Wind Waker*.
- Ne pas rendre l'eau photoréaliste.
- Ne pas ajouter un million de détails aux falaises : le terrain doit rester lisible depuis la lunette.
- Ne pas faire du style « pixel art » : la cible est une 3D stylisée.
- Ne pas utiliser des effets d'écran qui cachent la cible ou rendent la visée injuste.

---

## 4. Arène et level design

### Arène du prototype : « Le Lagon des Deux Fanions »
Une petite île à gauche et une petite île à droite, séparées par un lagon ouvert. Depuis la plupart des points de l'île A, l'île B est visible, et inversement, mais les couverts et les hauteurs empêchent de voir tous les postes en permanence.

### Échelle indicative
- Distance entre les zones centrales des îles : environ **80 à 100 mètres Godot**, à ajuster avec le test de lisibilité de la lunette.
- Diamètre jouable de chaque île : environ **35 à 50 mètres**.
- Au moins 3 postes de cachette viables par île.
- Au moins 2 hauteurs distinctes par île.
- Au moins 2 lignes de tir longues et 2 lignes de tir partiellement bloquées par île.
- Zone de jeu limitée naturellement par les falaises et l'eau ; si un joueur tombe à l'eau, réapparition à son point d'apparition ou retour au sol après une courte pénalité, sans avantage pour l'adversaire.

Ces mesures sont des paramètres de départ, pas des valeurs rigides. Tester la taille réelle des personnages et les distances avant de figer la carte.

### Équilibre spatial
- Miroiter la structure des îles de façon à ce que les postes équivalents soient à la même hauteur et à distance comparable.
- Éviter qu'une tour de guet permette de surveiller tous les couverts sans risque.
- Prévoir des routes accessibles pour rejoindre les postes élevés, mais suffisamment exposées pour constituer un choix risqué.
- Le départ ne doit pas laisser un joueur visible immédiatement depuis un poste de tir optimal adverse.
- Les points d'apparition doivent être protégés par un relief ou un couvert pendant la préparation.
- Les objets de décor ne doivent pas créer de point de tir qui traverse les murs ou les falaises.

### Eau et bordures
- L'eau est un obstacle visuel et physique ; le joueur ne peut pas nager jusqu'à l'autre île.
- Ajouter un son doux de vagues et une petite animation de surface.
- Éviter une simulation d'océan coûteuse. Un shader simple ou une grande surface avec un matériau animé suffit au prototype.

---

## 5. Commandes et sensations

Prévoir une configuration remappable à terme ; pendant le prototype, définir les actions suivantes dans l'Input Map de Godot.

| Action | Commande par défaut | Règle |
|---|---|---|
| Se déplacer | `W A S D` | Déplacement relatif à la caméra |
| Regarder | Souris | Sensibilité configurable |
| Sprint | `Shift` | Disponible seulement hors de la visée |
| S'accroupir | `C` | Réduit la silhouette et la vitesse |
| Sauter | `Espace` | Petit saut, sans parkour complexe |
| Interagir | `E` | Réservé aux interactions futures, sans obligation dans le premier prototype |
| Viser / quitter la lunette | Clic droit maintenu | Passe à la caméra de visée |
| Tirer | Clic gauche | Fonctionne uniquement pendant la phase Duel |
| Zoom | Molette | Change le niveau de zoom pendant la visée |
| Réarmer | `R` | Réarme après le tir ou lance le rechargement si nécessaire |
| Jumelles (option ultérieure) | `Q` | Ne pas implémenter avant que la boucle principale fonctionne |
| Pause | `Échap` | Ouvre le menu pause sans interrompre la partie réseau pour l'adversaire |

### Sensations
- Accélération et freinage légers ; le personnage ne doit pas glisser comme sur de la glace.
- Déplacements lisibles sur sable, herbe, pierre et bois via des effets audio différents.
- Visée précise, sans recul incontrôlable.
- Le passage en lunette doit être rapide et clair ; ne pas imposer un zoom lent qui enlève le contrôle au joueur.
- Quand le joueur tire, ajouter recul visuel mesuré, flash de bouche stylisé, trace ou impact, animation de réarmement et retour sonore.
- Les effets doivent confirmer l'action, pas la rendre spectaculaire au détriment de la lisibilité.

---

## 6. Fusil, visée et tirs

### Modes de caméra
1. **Exploration :** caméra troisième personne au-dessus de l'épaule, qui garde le personnage et les couverts visibles.
2. **Visée :** caméra de lunette proche du point de vue du personnage, avec FOV plus faible et masque circulaire de lunette.

### Lunette
- Trois zooms de départ : 2×, 4× et 6×.
- Afficher un réticule stable et fin, des repères simples et un léger assombrissement autour du cercle de vision.
- Pas d'indicateur qui suit automatiquement le joueur adverse.
- Si la caméra est en visée, le personnage tourne graduellement vers la direction visée. La direction envoyée pour le tir doit correspondre à la caméra et être vérifiée côté autorité.
- À la sortie de visée, restaurer la caméra d'exploration et la sensibilité normale sans saut visuel.

### Règles de tir du prototype
- Utiliser un `RayCast3D` ou un raycast physique lancé depuis la caméra de visée, avec une distance maximale configurable.
- Les collisions doivent distinguer clairement l'environnement et les personnages.
- La logique du serveur/hôte doit valider phase de jeu, munition restante, cadence, distance et ligne de vue avant de confirmer un tir.
- Le client demande de tirer ; il n'envoie jamais seulement « j'ai touché l'adversaire ».
- Un tir raté doit consommer la munition uniquement si la partie accepte réellement le tir.
- Les tirs reçus hors phase Duel doivent être ignorés par l'autorité et journalisés en développement.
- La première version ne requiert ni vent, ni chute de balle, ni dégâts par zone corporelle.

### Retour visuel des tirs
- Impact sur pierre : petite poussière et son sec.
- Impact sur bois : éclat discret et son mat.
- Impact dans l'eau : éclaboussure visible depuis les deux îles.
- Élimination : animation courte, son distinct et arrêt des actions de jeu.
- Ne pas montrer la position exacte de l'adversaire après un tir raté. L'orientation du son peut donner un indice, mais pas une flèche HUD omnisciente.

---

## 7. Interface utilisateur et écrans

### Menu principal
- Fond 3D vivant montrant les deux îles au coucher du soleil.
- Nom de travail : « LES DEUX ÎLES ».
- Boutons : `Jouer`, `Entraînement`, `Paramètres`, `Quitter`.
- Design minimaliste : grands boutons lisibles, marges généreuses, typographie sans empattement, couleurs de la palette et accents inspirés de panneaux peints.
- Pas de surcharge, de faux éléments décoratifs ou de menus minuscules.

### Lobby
- État de connexion clair : hors ligne, création de partie, en attente d'un adversaire, connecté, déconnecté.
- Deux emplacements visuels, un pour chaque joueur, avec son accent de couleur.
- Boutons `Créer une partie`, `Rejoindre une partie` et `Prêt` selon le mode réseau disponible.
- Pour le prototype, proposer un mode Entraînement solo et un mode réseau local/hôte. L'intégration des lobbies Steam viendra après la validation du réseau de base.

### HUD — préparation
- Compte à rebours principal au centre-haut.
- Petit indicateur de phase : `PRÉPAREZ-VOUS`.
- Indication courte des commandes au démarrage de la première manche uniquement.
- Aucun marqueur affichant les positions ennemies.

### HUD — duel
- Compte à rebours ou temps restant.
- Munitions restantes.
- Indicateur d'état de la lunette / niveau de zoom.
- Indication de réarmement si nécessaire.
- Score des manches, discret dans un coin.
- Ne pas afficher de barre de vie si l'élimination reste instantanée.

### Écran de résultat
- `MANCHE GAGNÉE`, `MANCHE PERDUE` ou `ÉGALITÉ`.
- Score du match mis à jour.
- Statistiques sobres : tirs tentés, tirs réussis, précision, durée de la manche.
- Boutons `Manche suivante` et `Retour au menu`, ou compte à rebours automatique si les deux joueurs sont d'accord.

### Paramètres
- Sensibilité souris.
- Inversion verticale.
- Volume général, musique et effets.
- Mode fenêtré / plein écran et résolution via les paramètres d'affichage Godot.
- Qualité des ombres / effets graphiques quand cela sera utile.
- Options d'accessibilité de base : taille du réticule, contraste de l'interface et niveau de tremblement de caméra.
- Les valeurs doivent persister entre les sessions avec `ConfigFile`.

---

## 8. Audio et ambiance

Le son doit accompagner les phases et fournir des indices utiles sans remplacer l'observation.

### Priorités audio
1. Ambiance océan / vent / oiseaux lointains.
2. Pas distincts sur sable, herbe, pierre et bois.
3. Froissement de végétation quand un joueur traverse des buissons.
4. Signal annonçant la fin de la préparation.
5. Mécanisme du fusil, tir et réarmement.
6. Impacts différenciés sur pierre, bois et eau.
7. Son de résultat de manche.

### Règles
- Réduire légèrement l'ambiance pendant la visée, sans couper tous les sons du monde.
- Éviter le son directionnel exagéré qui permettrait de connaître une position précise sans l'avoir vue.
- Les volumes de l'ambiance, des effets et de la musique doivent être séparés dans les paramètres.
- Les assets temporaires peuvent être de simples sons libres ou générés pour le test, mais tout son utilisé dans une version commerciale doit disposer de droits adaptés et être documenté.

---

## 9. Architecture Godot recommandée

Les noms sont des recommandations de départ. Si le projet existant utilise déjà une architecture saine, ne pas la remplacer artificiellement.

### Moteur et paramètres
- Godot **4.7.2 stable**, version standard, pas .NET.
- Langage : GDScript.
- Type de jeu : 3D.
- Renderer initial : Forward+ ; profiler et simplifier les effets avant de baisser la qualité visuelle.
- Plateforme d'abord : Windows 64 bits, puis tester Linux et Steam Deck si le scope du projet le permet.
- Résolution UI de référence : 1920×1080, avec adaptation aux autres résolutions et ratios.

### Arborescence indicative

```text
res://
├── project.godot
├── CLAUDE.md
├── README.md
├── docs/
│   ├── PLAN.md
│   ├── PROGRESS.md
│   ├── DESIGN_DECISIONS.md
│   └── TEST_PLAN.md
├── autoload/
│   ├── game_state.gd
│   ├── network_manager.gd
│   ├── settings_manager.gd
│   └── audio_manager.gd
├── scenes/
│   ├── main/
│   │   ├── main_menu.tscn
│   │   └── game_root.tscn
│   ├── lobby/
│   │   └── lobby.tscn
│   ├── arena/
│   │   ├── island_arena.tscn
│   │   ├── island_half.tscn
│   │   └── water.tscn
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player_camera_rig.tscn
│   │   └── sniper_rifle.tscn
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── scope_overlay.tscn
│   │   ├── pause_menu.tscn
│   │   └── results_screen.tscn
│   └── props/
│       ├── palm_tree.tscn
│       ├── rock_cover.tscn
│       ├── watchtower.tscn
│       └── ruin_wall.tscn
├── scripts/
│   ├── game/
│   │   ├── match_controller.gd
│   │   └── round_rules.gd
│   ├── player/
│   │   ├── player_controller.gd
│   │   ├── player_camera_rig.gd
│   │   └── sniper_rifle.gd
│   ├── arena/
│   │   └── island_arena.gd
│   ├── ui/
│   │   ├── hud.gd
│   │   └── results_screen.gd
│   └── network/
│       └── network_player.gd
└── assets/
    ├── materials/
    ├── meshes/
    ├── textures/
    ├── audio/
    ├── fonts/
    └── shaders/
```

Ne crée pas des fichiers vides « pour faire joli ». Ajoute un fichier seulement lorsqu'il sert réellement à une fonctionnalité.

### Autoloads
- `GameState` : état global de la partie, phase courante, score et transitions de manche. Ne doit pas contenir tous les comportements de gameplay.
- `NetworkManager` : création/join/arrêt de connexion, attribution des joueurs, gestion des déconnexions et abstraction du transport réseau.
- `SettingsManager` : lecture/sauvegarde des options via `ConfigFile`.
- `AudioManager` : mixage général et déclenchement des événements audio communs.

N'ajoute un autoload que si plusieurs scènes en ont réellement besoin.

### Scènes principales
- `main_menu.tscn` : menu de démarrage.
- `lobby.tscn` : création/rejoindre une partie et attente du second joueur.
- `game_root.tscn` : racine de la partie, instancie arène, joueurs, contrôleur de manche et HUD.
- `island_arena.tscn` : deux îles, mer, ciel, couvertures et positions d'apparition.
- `player.tscn` : personnage, collisions, mouvement et point d'attache de l'arme.
- `player_camera_rig.tscn` : caméra d'exploration, caméra de visée et gestion du zoom.
- `sniper_rifle.tscn` : état de l'arme, munitions, cadence, tir et effets.
- `hud.tscn` : phase, compte à rebours, score et munitions.
- `results_screen.tscn` : résultat de manche et actions suivantes.

### Contrats entre systèmes
- `MatchController` est responsable de l'état de la manche et du score.
- Le contrôleur de joueur est responsable du mouvement et des entrées locales.
- Le fusil formule une demande de tir ; l'autorité réseau confirme ou refuse le résultat.
- Le HUD affiche l'état reçu et ne décide pas des règles.
- La scène d'arène gère le décor et les positions de spawn, pas les règles de victoire.
- Les paramètres ne sont pas disséminés dans les scènes : exposer les valeurs utiles ou utiliser une ressource de configuration.

---

## 10. Multijoueur : stratégie et sécurité

### Étape réseau 1 — prototype local
Avant Internet, permettre de tester l'arène et la boucle de jeu sans service externe. Prévoir un mode entraînement avec une cible de test ou un second joueur de test pour valider le tir.

### Étape réseau 2 — LAN avec ENet
Utiliser l'API multijoueur haut niveau de Godot et `ENetMultiplayerPeer` pour le premier réseau fonctionnel : un joueur crée la partie, l'autre rejoint via adresse IP et port configurables. ENet utilise UDP ; documenter les conditions nécessaires au test sur le réseau local.

- Limiter la partie à deux joueurs humains.
- Gérer l'arrivée, le départ et la déconnexion d'un joueur.
- Si l'hôte quitte la partie, terminer proprement la manche et afficher un message plutôt que de laisser un état bloqué.
- Le changement de phase, le score, les éliminations et la validation des tirs sont décidés par l'hôte/autorité de la partie.
- Les clients envoient les intentions nécessaires (mouvement/entrée, visée, demande de tir) et reçoivent l'état validé.
- Interpoler les mouvements distants pour limiter les saccades.
- Ne pas envoyer des RPC à haute fréquence pour chaque élément de décoration.
- Ajouter des garde-fous sur les RPC : vérifier l'expéditeur, l'état de partie, les valeurs et la fréquence des actions.
- Un client ne peut pas choisir librement le résultat d'un tir ni attribuer un point à lui-même.

### Étape réseau 3 — Steam
L'intégration Steam ne commence qu'après la stabilité du mode LAN et des tests à deux instances.

- Garder la couche transport derrière `NetworkManager`, afin de pouvoir changer le transport sans réécrire les règles de jeu.
- Étudier un plugin/transport Steam compatible avec **Godot 4.7.2** au moment de l'intégration ; ne pas choisir une dépendance uniquement parce qu'un tutoriel ancien l'utilise.
- Documenter la version du plugin, son dépôt officiel, les licences, les prérequis SDK et les instructions de compilation/export.
- Implémenter d'abord créer/rejoindre un lobby Steam, puis connexion, départ d'un joueur et retour au menu.
- Tester avec deux comptes Steam et deux environnements réellement séparés avant de déclarer cette étape terminée.
- Les fonctions Steamworks (lobbies, invitations, présence, achievements) sont hors du premier prototype ; les intégrer seulement quand la boucle de jeu réseau fonctionne.

### Limites de sécurité
Le mode hôte-joueur est adapté au prototype et aux parties entre amis, mais ne garantit pas une protection anti-triche de niveau compétitif. Avant une sortie publique avec classement, évaluer un serveur dédié ou une architecture plus autoritaire. Ne pas prétendre qu'une validation côté hôte empêche toute triche lorsque l'hôte contrôle la partie.

---

## 11. Phases de réalisation et critères de validation

### Milestone 0 — Inspection et base du projet
**À faire :** inspecter le dépôt, confirmer la version de Godot, établir l'arborescence utile, définir les premières tâches et les tests.

**Acceptation :** projet ouvrable dans Godot ; documentation de travail créée ; aucune partie existante écrasée sans raison.

### Milestone 1 — Prototype de terrain jouable
**À faire :** créer les deux îles avec des meshes simples, mer, ciel, collision, reliefs, couverts et deux points de spawn. Ajouter le déplacement, saut, accroupissement et caméra troisième personne.

**Acceptation :** on peut se déplacer sur chaque île, tester les hauteurs et couverts, voir l'île opposée et tomber/être bloqué par les limites de façon cohérente. La scène fonctionne sans erreurs critiques.

### Milestone 2 — Boucle de manche hors ligne
**À faire :** compte à rebours de préparation, transition de 3 secondes, phase Duel, fin de manche, score au meilleur des 5 et bouton de relance. Ajouter une cible d'entraînement pour tester les tirs.

**Acceptation :** le jeu ne permet aucun tir létal avant le début du duel ; les états s'enchaînent dans le bon ordre ; les scores se mettent à jour correctement ; les manches nulles ne bloquent pas le match.

### Milestone 3 — Fusil et lunette
**À faire :** arme de précision, caméra de visée, zoom, réticule, munitions, tir par raycast, obstacles et feedback d'impact.

**Acceptation :** la visée correspond au réticule ; les murs/rochers bloquent le tir ; un tir confirmé élimine la cible ; les munitions sont exactes ; tir et réarmement sont impossibles dans les phases non autorisées.

### Milestone 4 — Premier multijoueur LAN 1v1
**À faire :** host/join ENet, spawn des deux joueurs sur leurs îles respectives, synchronisation des états et validation des tirs par l'autorité.

**Acceptation :** deux instances séparées peuvent jouer une manche complète ; l'une gagne et l'autre voit le même résultat ; déconnexion et retour au menu sont gérés proprement ; aucun joueur ne peut tirer pendant la préparation.

### Milestone 5 — Passe artistique et interface
**À faire :** appliquer palette, matériaux, éclairage, éléments de décor, HUD, menu, lobby et résultats. Remplacer les placeholders au fur et à mesure que des assets adaptés sont disponibles.

**Acceptation :** les deux îles sont lisibles, différenciées visuellement mais équitables ; le personnage est reconnaissable à distance ; les couverts sont compréhensibles ; le HUD est lisible en 1080p.

### Milestone 6 — Intégration Steam
**À faire :** choisir et documenter le transport Steam compatible, créer/rejoindre les lobbies et tester des sessions Internet.

**Acceptation :** deux comptes Steam distincts peuvent créer/rejoindre une partie sans saisie d'adresse IP, terminer un match et revenir au menu ; une déconnexion inattendue est gérée ; la procédure d'export est documentée.

### Milestone 7 — Préparation d'une démo Steam
**À faire :** correction des bugs, paramètres, sauvegarde locale, contrôles de base, optimisation, test de lancement sans l'éditeur et préparation des captures/texte de présentation.

**Acceptation :** la build exportée démarre sur un PC cible, la boucle complète est testée, aucun blocage critique connu n'est caché, et les limites restantes sont documentées.

---

## 12. Plan de tests minimal

Tenir une liste à jour dans `docs/TEST_PLAN.md`.

### Gameplay
- Le joueur se déplace, saute et s'accroupit sans traverser le sol.
- Une collision de couvert empêche un tir.
- Une surface décorative qui ne bloque pas la balle est visuellement différente d'un mur solide.
- Le temps de préparation atteint zéro une seule fois et déclenche le duel.
- Un tir pendant la préparation ne fait aucun dégât et ne consomme pas de munition.
- Un tir pendant le duel consomme une munition et réarme selon la règle configurée.
- Un tir accepté sur un joueur provoque une élimination et un seul point de manche.
- Un tir hors portée ou bloqué ne touche pas la cible.
- Le match est remporté à trois manches gagnées.
- Une égalité après prolongation ne modifie pas le score.

### Multijoueur
- L'hôte et le client reçoivent le même état de manche et le même score.
- Aucun joueur n'est créé deux fois après une reconnexion ou une transition.
- Un client ne peut pas déclencher une élimination via un RPC arbitraire.
- Le départ d'un joueur affiche un état propre pour l'autre.
- Le joueur A n'obtient aucun avantage de spawn sur le joueur B.

### Interface et accessibilité
- Les textes restent lisibles en 1920×1080 et en 16:9 plus petit.
- Le curseur souris est capturé pendant le gameplay et libéré dans les menus.
- Échap ouvre/ferme le menu pause sans casser la session de l'adversaire.
- Les paramètres survivent au redémarrage.
- Les couleurs bleu et corail restent différenciables avec un réticule et des symboles, pas seulement par la couleur.

### Performance
- Mesurer la fréquence d'images sur l'arène complète et en vue de lunette.
- Limiter le nombre de lumières avec ombres, les matériaux transparents et les particules.
- Ne pas optimiser prématurément au détriment de la lisibilité. Profiler avant de complexifier les shaders.

---

## 13. Hors périmètre du premier prototype

Ne pas implémenter avant d'avoir validé la boucle 1v1 :
- plusieurs cartes ou génération procédurale d'îles ;
- progression, niveaux, boutique, cosmétiques ou battle pass ;
- classement compétitif, matchmaking classé et anti-triche complet ;
- plusieurs fusils, accessoires, arbres de compétences ou inventaire ;
- météo dynamique qui modifie la précision ;
- bateaux pilotables ou déplacement entre les îles ;
- bots complexes ;
- éditeur de carte ;
- campagne solo ;
- intégration d'achievements ou d'autres fonctions Steam avancées.

Ces idées ne sont pas interdites à long terme : elles sont simplement exclues tant que la boucle centrale n'est pas amusante et stable.

---

## 14. Organisation du travail avec Claude Code

### À chaque session
1. Lire `CLAUDE.md`, puis `docs/PROGRESS.md` et `docs/PLAN.md` s'ils existent.
2. Inspecter les fichiers concernés avant toute modification.
3. Indiquer les objectifs précis de la session en quelques lignes.
4. Modifier un groupe cohérent de fichiers, éviter les refontes sans rapport.
5. Lancer les vérifications disponibles. Pour les contrôles headless, utiliser le binaire Godot réellement installé ; par exemple, tester une importation/parse avec une commande Godot headless adaptée à la version installée. Ne suppose pas que la commande existe si elle n'est pas accessible.
6. Corriger les erreurs introduites avant d'ajouter de nouvelles fonctionnalités.
7. Mettre à jour `docs/PROGRESS.md` et noter les décisions durables dans `docs/DESIGN_DECISIONS.md`.
8. Terminer par un rapport bref : fichiers changés, fonctionnalités fonctionnelles, tests exécutés et problèmes restants.

### Quand quelque chose échoue
- Lire la première erreur utile et la corriger à sa source.
- Ne pas cacher une erreur en désactivant une fonctionnalité sans explication.
- Si une fonctionnalité ne peut pas être testée faute de service externe, fournir une procédure de test reproductible et marquer la validation comme « non testée ».
- Garder une version jouable de la dernière étape validée.

### Première tâche précise
**Commence par le Milestone 0, puis implémente uniquement le Milestone 1.** Inspecte d'abord le projet. Si le dépôt est vide, crée le projet Godot et sa structure minimale. Réalise deux îles blockout, déplacement du personnage, caméra, couvertures et collisions. Ne commence pas encore le matchmaking Steam. Une fois cette étape validée, prépare le Milestone 2.

---

## 15. Prompt de démarrage à envoyer à Claude Code

Copie ce texte dans Claude Code à la racine du projet :

> Lis intégralement `CLAUDE.md` avant de modifier quoi que ce soit. Inspecte le projet et les fichiers existants. Suis les règles de ce document et ne remplace aucun fichier sans inspection préalable. Commence par documenter l'état existant dans `docs/PLAN.md` et `docs/PROGRESS.md`, puis réalise uniquement le Milestone 1 : arène 3D blockout avec deux îles équitables, océan simple, collisions, deux points d'apparition, personnage contrôlable, caméra troisième personne, marche/sprint/accroupissement/saut. Utilise Godot 4.7.2 stable et GDScript. Pour l'instant, n'implémente ni Steam ni les fonctionnalités des milestones suivants. Teste ce qui est possible, corrige les erreurs que tu introduis et termine par un rapport clair indiquant ce qui fonctionne, les fichiers créés/modifiés et les tests réellement effectués.

---

## 16. Références techniques officielles

- Godot — téléchargement officiel et versions stables : https://godotengine.org/download/archive/
- Godot — politique de publication et de support : https://docs.godotengine.org/en/stable/about/release_policy.html
- Godot — API multijoueur de haut niveau : https://docs.godotengine.org/fr/4.x/tutorials/networking/high_level_multiplayer.html
- Godot — `ENetMultiplayerPeer` : https://docs.godotengine.org/fr/stable/classes/class_enetmultiplayerpeer.html

À la date de préparation de ce document (25 octobre 2026), la version stable recommandée est Godot **4.7.2** ; Godot 4.8 est en bêta. Vérifier de nouveau la page officielle si le développement commence beaucoup plus tard.
