# montaigneview

Jeu vidéo en préparation, destiné à une sortie sur **Steam**.
Moteur : **Godot 4**.

## Structure

- `game/` : le projet Godot (ouvrir `game/project.godot` dans Godot une fois le projet créé)
- `docs/` : idées, game design, notes
- `steam/store-assets/` : images de la page Steam (capsules, captures, bannières)

## Démarrer

1. Installer [Godot 4](https://godotengine.org/download).
2. Dans Godot : *Importer* → `game/project.godot`, puis **F5** pour jouer au prototype « Duel des Cimes ».
   Le code du jeu est dans `game/scripts/` (`main.gd` la partie, `world.gd` la vallée, `hud.gd` l'interface).
3. Après chaque séance de travail : `git add -A`, `git commit -m "..."`, `git push`.

## Gros fichiers

Les fichiers lourds (images, sons, vidéos, modèles 3D) passent par **Git LFS**
(voir `.gitattributes`). Lancer une fois `git lfs install` sur chaque ordinateur.

## Steam

Pour publier : compte [Steamworks](https://partner.steamgames.com/), frais Steam Direct,
puis envoi des builds avec SteamPipe. L'intégration Steam dans Godot peut se faire
avec [GodotSteam](https://godotsteam.com/).
