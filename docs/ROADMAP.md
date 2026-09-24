# Feuille de route

| Étape | Contenu | Ce qu'on peut tester | État |
|---|---|---|---|
| **1. Prototype de combat** | Création du ninja, combat au tour par tour contre des PNJ, rangs, attributs Fangan, Gnanga et Manhis | Un combat complet sur PC | **Fait (0.1)** |
| **2. Mudras et découverte** | Grammaire des mudras, résonance, grimoire, maîtrise | Découvrir ses premiers jutsus | **Fait (0.1)** |
| **3. Carte de la Côte d'Ivoire** | 7 régions et leurs zones, déplacement façon shinobi.fr, zones réservées à certains niveaux | Parcourir la carte | **Fait (0.2)** |
| **3 bis. Jutsus typés** | 5 types de jutsus (dégâts physiques, magiques, purs ; défense ; entrave ; illusion ; soin), coefficients propres à chaque jutsu, 7 mudras au plus, seuls les favoris en combat, blessures durables | Composer ses 5 favoris et s'en servir | **Fait (0.3)** |
| **3 ter. Ressources et forge** | Cases libres, camps de bandits et gisements (fer, peau, pierre, or, diamant), niveaux d'exploitation, ninjas croisés à affronter, sac et coffre, forge et équipement ; interface claire, paysages | Exploiter, forger, s'équiper | **Fait (0.4)** |
| **4. Progression** | Missions, marché, suite de l'équipement | Une vraie partie en solo | À venir |
| **5. Passage en ligne** | Serveur, comptes, joueurs contre joueurs, recettes protégées | Se battre entre amis | À venir |
| **6. Économie** | Djê, académies, parchemins, taxes, marché | Vendre un jutsu découvert | À venir |
| **7. Guerre du vendredi** | Portails, gardes, sièges 3 contre 3, prise de zones, réinitialisation | Une première guerre | À venir |
| **8. Fin de jeu** | Éléments rares et mythiques, jutsus légendaires, lignées, organisations secrètes | Le contenu de haut niveau | À venir |

## Architecture

- **`server/`** : moteur de règles et serveur en **Go**. Toute la logique du jeu (grammaire des mudras, recettes, combat) vit ici. Le client ne connaît jamais les recettes.
- **`client/`** : jeu PC en **Godot 4**. Il affiche ce que le serveur décide.
- Pendant le prototype, le client lance automatiquement un serveur local.
