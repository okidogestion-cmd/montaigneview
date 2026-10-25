# Décisions de conception durables

> Une ligne par décision, avec la date et la raison. Les détails d'étape sont dans `PLAN.md`.

| Date | Décision | Raison |
|---|---|---|
| 25/10/2026 | `CLAUDE.md` (« Les Deux Îles ») devient la source de vérité ; l'ancien `docs/game-design.md` reste comme historique du prototype « Duel des Cimes ». | Demande de l'utilisateur. |
| 25/10/2026 | Arène reconstruite à la main : deux îles à ~90 m, construites **une seule fois** (`island_half`) puis posées deux fois, la seconde tournée de 180°. | Garantit l'équité exacte des deux îles (mêmes hauteurs, couverts, distances). |
| 25/10/2026 | L'île « avant » regarde l'île adverse ; les points d'apparition sont derrière la cabane, à l'abri des vues adverses. | Règle « spawn protégé » de `CLAUDE.md`. |
| 25/10/2026 | Les reliefs sont des cônes tronqués (pentes ≤ 40°) et des rampes : pas de marches à escalader. | `CharacterBody3D` ne monte pas les marches seul ; les pentes restent lisibles. |
| 25/10/2026 | Bloquent les tirs : sol, rochers, murs de ruine, cabane, tour, caisses, troncs de palmier. Ne bloquent pas : feuilles de palmier, buissons. | Règle de lisibilité de `CLAUDE.md` (les petites feuilles ne bloquent pas). |
| 25/10/2026 | Atelier de peinture gardé hors de la boucle principale. | Choix de l'utilisateur : à rebrancher après le 1v1. |
| 25/10/2026 | Entraînement = simple cible, l'ennemi ordinateur du prototype n'est pas repris. | Choix de l'utilisateur ; `CLAUDE.md` exclut les bots complexes. |
| 25/10/2026 | Réglages centralisés dans `config/game_config.tres` (ressource `GameConfig`). | Règle « pas de valeurs disséminées » de `CLAUDE.md`. |
