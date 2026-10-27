# Duel des Cimes (dépôt montaigneview) — consignes pour Claude

Plusieurs Claude travaillent sur ce jeu (séances dans le cloud, téléphone, ordinateur).
**GitHub, branche `main`, est la seule version de référence.** Il n'existe qu'une version du jeu : le projet Godot dans `game/`.

## Synchronisation — à chaque séance

1. **Avant de travailler** : récupérer la dernière version (`git pull origin main`). Ne jamais partir d'une copie locale,
   d'un ancien fichier ou d'une page publiée sans avoir vérifié qu'elle correspond à `main`.
2. **Après avoir travaillé** : tout envoyer sur `main` (commit + push). Si une branche a été créée, la fusionner dans `main`.
3. **Ne jamais écraser une version** : si `main` a changé entre-temps, récupérer et fusionner ; `push --force` interdit.
4. **La page jouée en ligne doit correspondre à `main`** : après chaque changement du jeu, republier l'artefact
   (marche à suivre dans `docs/game-design.md`, parties « Le jeu dans l'artefact Claude » et « Images Higgsfield et jeu debout »).
5. À la fin, dire en une phrase ce qui a été envoyé sur GitHub et republié.

## Où sont les choses

- Jeu : `game/` (Godot **4.7.2 stable**). Code dans `game/scripts/`, images dans `game/art/`.
- Version jouable en ligne (artefact Claude) : https://claude.ai/artifact/8ZHppVb8s62V5codCvUcuv — page source `tools/artefact/`.
- Conception, étapes, décisions : `docs/game-design.md` ; idées : `docs/idees.md`.
- Anciennes versions (ne plus développer) : `docs/archives/` (prototype web Three.js, document « Les Deux Îles »).

## Images

- Les images, sons et modèles 3D passent par Git LFS (`.gitattributes`), **sauf** les petites images de `game/art/`
  et `tools/artefact/` (rangées directement dans Git : le service LFS n'est pas joignable depuis les séances cloud).
- Images créées avec Higgsfield : rester sur les générations gratuites (demande de l'utilisateur, 27/10/2026) ;
  ne jamais dépenser de crédits sans son accord.
