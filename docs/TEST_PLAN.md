# TEST_PLAN — liste des tests

> Basé sur `CLAUDE.md` §12. ✅ = vérifié (comment : voir PROGRESS), ⬜ = pas encore testé ou pas encore codé.

## Milestone 1 — terrain
- ✅ Le joueur se déplace, saute et s'accroupit sans traverser le sol (partie scriptée).
- ✅ Les murs bloquent le joueur (mur avant de la cabane).
- ✅ Chute à l'eau → retour au point d'apparition.
- ✅ Spawns symétriques et cachés des postes adverses (rayons).
- ⬜ Caméra à la souris, Échap / clic pour reprendre : à tester à la main.
- ⬜ Monter toute la rampe de la tour à pied.

## Gameplay (milestones suivants)
- ⬜ Une collision de couvert empêche un tir.
- ⬜ Une surface décorative qui ne bloque pas la balle est visuellement différente d'un mur solide.
- ⬜ Le temps de préparation atteint zéro une seule fois et déclenche le duel.
- ⬜ Un tir pendant la préparation ne fait aucun dégât et ne consomme pas de munition.
- ⬜ Un tir pendant le duel consomme une munition et réarme selon la règle configurée.
- ⬜ Un tir accepté sur un joueur provoque une élimination et un seul point de manche.
- ⬜ Un tir hors portée ou bloqué ne touche pas la cible.
- ⬜ Le match est remporté à trois manches gagnées.
- ⬜ Une égalité après prolongation ne modifie pas le score.

## Multijoueur
- ⬜ L'hôte et le client reçoivent le même état de manche et le même score.
- ⬜ Aucun joueur n'est créé deux fois après une reconnexion ou une transition.
- ⬜ Un client ne peut pas déclencher une élimination via un RPC arbitraire.
- ⬜ Le départ d'un joueur affiche un état propre pour l'autre.
- ⬜ Le joueur A n'obtient aucun avantage de spawn sur le joueur B.

## Interface et accessibilité
- ⬜ Textes lisibles en 1920×1080 et en 16:9 plus petit.
- ⬜ Curseur capturé en jeu, libéré dans les menus.
- ⬜ Échap ouvre/ferme le menu pause sans casser la session adverse.
- ⬜ Paramètres conservés au redémarrage.
- ⬜ Bleu et corail différenciables aussi par des symboles.

## Performance
- ✅ 60 images/s sur l'arène (RTX 3050 Ti portable, 1280×720).
- ⬜ Mesure en 1080p et en vue lunette.
