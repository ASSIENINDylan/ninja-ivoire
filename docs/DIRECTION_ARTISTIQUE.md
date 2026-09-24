# Ninja Ivoire — Direction artistique

**Décidé :**
- **Images** : générées par IA.
- **Ambiance** : la technique de *Darkest Dungeon*, dans des couleurs ivoiriennes.
- **Combats** : en 2D, vus de côté et animés.
- **Carte** : une carte peinte, et au centre la scène illustrée du lieu.
- **Interface** : parchemin, bois sculpté, bronze akan, motifs des toiles de Korhogo. Les maquettes validées sont sur le canevas Claude Design « Ninja Ivoire — Maquettes d'interface ».
- **Ninjas** : 3 allures, une par type de village (traditionnel, moderne, futuriste).
- **Équipement visible** : l'arme, le casque, l'armure et les jambières que porte un ninja se voient sur son personnage, en combat comme au village. Quand il perd son équipement après une défaite, on le voit aussi.

Ce document sert de référence pour toutes les images du jeu. Tant qu'on le respecte, les images restent cohérentes entre elles.

---

## 1. Le style en une phrase

> Des illustrations **peintes à l'encre**, aux **contours noirs épais** et aux **ombres profondes**, dans les **couleurs chaudes de la Côte d'Ivoire** (latérite, ocre, or de savane, vert de forêt, indigo), nourries des **arts ivoiriens** (toiles de Korhogo, masques dan, gouro et baoulé, poids à peser l'or akan, cauris, mosquées de banco).

### Ce qu'on reprend de Darkest Dungeon
- Traits d'encre noire épais et irréguliers, comme tracés au pinceau.
- Clair-obscur : de grands aplats d'ombre noire et une lumière qui sculpte les volumes.
- Peinture texturée, un peu rugueuse, jamais lisse ni « plastique ».
- Des personnages expressifs aux silhouettes lisibles, même en petit.
- Des décors de combat vus de côté, avec un sol plat en bas pour les combattants.

### Ce qui change par rapport à Darkest Dungeon
- **Palette chaude et colorée**, pas désaturée : les couleurs vivent dans la lumière, le noir reste dans les ombres.
- **Jour et nuit** selon l'heure réelle : midi est éclatant, la nuit est bleu indigo, éclairée à la lune et aux torches.
- **Monde ivoirien** : terrains, architectures, vêtements et créatures du pays, du traditionnel au futuriste.

### Palette de référence
| Rôle | Couleurs |
|---|---|
| Terre, sols | latérite `#A8452B`, ocre `#C98A3A`, sable `#E3C27A` |
| Végétation | savane `#C9A94A`, forêt `#3E6B35`, forêt profonde `#1F3B26` |
| Eaux | lagune `#2E7F86`, fleuve `#35607F` |
| Tissus, accents | indigo `#243B6B`, rouge garance `#9E2A22`, or akan `#D9A534`, kaolin `#EFE7D6` |
| Ombres | brun-noir `#1A1210` (jamais un noir pur et plat) |

---

## 2. L'outil et les réglages

- **Outil recommandé : Midjourney** (version 7), car c'est lui qui donne le meilleur rendu peint. **Leonardo.ai** est une bonne alternative : il a une offre gratuite et peut produire des fonds transparents.
- **Pour garder un seul style** : on commence par une **image de style** (étape 1.1). Toutes les images suivantes s'en servent comme **référence de style** : `--sref` suivi du lien de l'image dans Midjourney, ou la fonction « Style Reference » dans Leonardo.
- **Pour garder le même personnage d'une image à l'autre** : on utilise la **référence de personnage**. C'est `--oref` en version 7 (`--cref` en version 6), ou « Character Reference » dans Leonardo.
- **Les poses d'un même personnage** : on les génère **sur une seule planche**, les poses côte à côte. C'est la façon la plus sûre qu'elles se ressemblent. Je découpe ensuite la planche moi-même.
- **Le fond des personnages** : **uni et clair** (gris très pâle). Je détoure moi-même, tu n'as pas à le faire.
- **Les descriptions sont en anglais**, parce que les outils d'IA les comprennent mieux.

### Tailles
| Type | Format | Taille minimale |
|---|---|---|
| Décor de combat, scène de lieu | paysage `--ar 16:9` | 2688 × 1512 (agrandie avec la fonction « Upscale ») |
| Planche de personnage | paysage `--ar 16:9` (4 poses côte à côte) | 2688 × 1512 |
| Portrait | carré `--ar 1:1` | 1024 × 1024 |
| Icône (objet, ressource, mudra) | carré `--ar 1:1` | 1024 × 1024 |
| Grande carte | presque carré `--ar 1:1` | 2048 × 2048 |

### Comment me transmettre les images
1. Sur GitHub, ouvre le dépôt **ninja-ivoire**, sur la branche `claude/prototype-combat-mudras`.
2. Va dans le dossier `client/assets/brut/`. Il suffit de taper ce chemin dans « Add file → Create new file » : GitHub crée le dossier.
3. Fais **Add file → Upload files**, glisse les images, puis clique sur **Commit changes**.
4. Nomme chaque image comme indiqué dans la liste, par exemple `decor_savane_jour.png`.

Si c'est plus simple pour toi, tu peux aussi m'envoyer les images directement dans la conversation, pour que je les voie et les commente.

---

## 3. Comment l'équipement se voit sur le personnage

C'est la méthode de Darkest Dungeon : **l'animation par pièces**.

- Chaque ninja est découpé en pièces : tête, buste, bras, avant-bras, mains, cuisses, jambes, pieds. Les pièces sont posées sur un **squelette** que j'anime : respiration, élan, mudras, recul, chute.
- Les **3 allures** partagent le **même squelette** et les mêmes proportions. Seules leurs pièces de base changent : la peau, les vêtements, la coiffure.
- Chaque objet de forge devient une ou plusieurs **pièces d'équipement**, posées par-dessus les pièces de base : le casque sur la tête, la cuirasse sur le buste, les jambières sur les jambes, l'arme dans la main. Comme le squelette est commun, **un objet dessiné une fois va sur les 3 allures**.
- Si on n'a rien d'équipé à un emplacement, on voit simplement la pièce de base à cet endroit.

**Ce que ça demande côté images :**
- Le ninja de base est généré **sans arme ni armure**. Il a les **poings fermés** comme s'il tenait un manche, et les **bras un peu écartés du corps**, pour que je puisse découper les pièces proprement.
- Les **armes** sont générées **seules**, vues de côté, à plat sur un fond clair. Je les place ensuite dans la main.
- Les **casques, armures et jambières** sont générés **portés par le ninja de base**, dans la même pose. Utilise la référence de personnage, et la planche du ninja comme image de départ. J'en découpe ensuite seulement l'objet.
- Le **portrait** montre le ninja de base. L'équipement se voit sur le personnage en pied.

J'assemble et je retouche moi-même. Si une pièce ne s'ajuste pas bien, je te demanderai de la regénérer.

### Les pièces d'équipement à produire (après l'étape 1)
| Emplacement | Objets | Nombre |
|---|---|---|
| Arme | massue de pierre, sabre de fer, arc du chasseur, sabre d'or, lame de diamant | 5 |
| Arme secondaire | kunaïs de fer, shurikens d'or (portés à la ceinture, et lancés en combat) | 2 |
| Tête | bandeau de cuir, casque de fer, diadème d'or | 3 |
| Corps | veste de cuir, cuirasse de fer, armure de pierre et d'or, armure de diamant | 4 |
| Pieds | sandales de cuir, jambières de fer, bottes de pierre | 3 |

---

## 4. Étape 1 : une scène complète (tranche verticale)

**Objectif :** un combat en savane, ton ninja équipé d'un sabre de fer et d'un bandeau de cuir contre deux chacals, entièrement dans le nouveau style. On valide cette scène avant de produire le reste.

### 1.1 Image de style → `style_reference.png`
Cette image sert uniquement de référence de style.
```
Hand-painted 2D game illustration, gothic ink style: thick irregular black brush outlines, deep chiaroscuro shadows, gritty textured painterly brushwork, dramatic rim light. A lone West African ninja warrior standing in a northern Ivory Coast savanna at golden hour, laterite red earth, dry golden grass, shea trees and a granite inselberg in the distance, termite mound. Warm Ivorian palette: laterite red, ochre, savanna gold, deep forest green, indigo cloth, gold accents. Senufo Korhogo-cloth painted patterns on the clothing. Moody but colorful, no text --ar 16:9 --v 7 --stylize 300
```
Génère plusieurs essais, garde **celui qui te plaît le plus**, et envoie-le-moi pour qu'on le valide ensemble avant de continuer.

### 1.2 Décor de combat, savane de jour → `decor_savane_jour.png`
```
Side-view 2D game battle background, empty stage, no characters. Northern Ivory Coast savanna at midday: flat laterite red ground across the lower third for fighters to stand on, dry golden grass, scattered shea trees and a rônier palm, a big termite mound on the left, a granite inselberg dome far away, heat haze, bright sky with a few clouds. Hand-painted gothic ink style, thick black outlines, strong shadows, textured brushwork, warm Ivorian palette --ar 16:9 --v 7 --sref [lien de style_reference] --stylize 250
```

### 1.3 Même décor, la nuit → `decor_savane_nuit.png`
Donne l'image 1.2 comme **image de départ** (image prompt), puis ajoute :
```
Same savanna battle background at night: deep indigo sky, full moon, cold blue moonlight, warm orange glow of a campfire off-screen on the right, long dark shadows, fireflies. Same composition, empty stage, no characters --ar 16:9 --v 7 --sref [lien de style_reference]
```

### 1.4 Ton ninja de base : village traditionnel des Savanes du Nord, élément Feu → `ninja_traditionnel_planche.png`
Sans arme ni armure : l'équipement viendra par-dessus (voir la partie 3).
```
Character sheet, 2D game sprite for cutout animation, full body, side view facing right, four poses side by side on a plain very light grey background: 1) idle fighting stance, 2) slashing motion with an empty clenched fist, as if gripping a sword handle, 3) casting: hands forming a ninja hand seal with small embers and fire glowing between the fingers, 4) staggering back hurt. Arms held slightly away from the body, limbs clearly separated, no weapon, no armor, no helmet. Young West African ninja from a traditional northern Ivorian village: indigo-dyed cotton tunic and trousers with hand-painted Senufo Korhogo-cloth patterns, leather straps and cowrie shells, lower face wrapped in dark cloth, short hair, dark brown skin, bare feet, lean athletic build. Same character in all four poses, same scale, feet on the same ground line. Hand-painted gothic ink style, thick black outlines, strong shadows, warm palette --ar 16:9 --v 7 --sref [lien de style_reference]
```
Quand un ninja te plaît, garde son image : elle servira de **référence de personnage** pour ses autres images, comme son portrait.

### 1.5 Le chacal → `chacal_planche.png`
```
Character sheet, 2D game creature sprite, full body, side view facing left, three poses side by side on a plain very light grey background: 1) idle, growling, 2) lunging bite attack, 3) hurt, recoiling. Gaunt, mangy African golden jackal of the Ivorian savanna, ribs showing, scarred ears, glowing amber eyes, bristling fur. Same creature, same scale, feet on the same ground line. Hand-painted gothic ink style, thick black outlines, strong shadows --ar 16:9 --v 7 --sref [lien de style_reference]
```

### 1.6 Portrait du ninja → `ninja_traditionnel_portrait.png`
```
Portrait bust of the same young West African ninja (use as character reference), three-quarter view, indigo tunic with Korhogo patterns, cloth over the lower face, intense eyes lit by embers, dark vignette background. Hand-painted gothic ink style, thick black outlines --ar 1:1 --v 7 --sref [lien de style_reference] --oref [lien du ninja]
```

### 1.7 Première arme : le sabre de fer → `arme_sabre_fer.png`
```
2D game item sprite: a short curved iron sabre forged by a West African blacksmith, dark hammered iron blade, wooden grip wrapped in leather, small brass pommel. Shown alone, side view, blade pointing right, perfectly horizontal, flat lay, centered on a plain very light grey background. Hand-painted gothic ink style, thick black outlines, strong shadows, no text --ar 16:9 --v 7 --sref [lien de style_reference]
```

### 1.8 Première pièce portée : le bandeau de cuir → `tete_bandeau_cuir.png`
Donne la pose 1 de la planche 1.4 comme **image de départ**, et le ninja comme **référence de personnage**.
```
The same young West African ninja in the same idle fighting stance, side view facing right, now wearing a tanned leather headband tied at the back of the head with long trailing ends, decorated with cowrie shells. Nothing else changes. Plain very light grey background. Hand-painted gothic ink style, thick black outlines, strong shadows --ar 16:9 --v 7 --sref [lien de style_reference] --oref [lien du ninja]
```

**Ce que je fais ensuite avec ces images :**
- détourer les personnages ;
- découper le ninja en pièces, le poser sur son squelette, y ajouter le sabre et le bandeau ;
- l'animer : respiration, élan d'attaque, mains qui forment les mudras, recul quand il est touché, chute ;
- montrer le ninja sans son équipement quand il l'a perdu ;
- découper le décor en couches qui bougent légèrement ;
- ajouter la lumière (jour ou nuit selon l'heure réelle), la poussière, les particules de feu des jutsus, le grain et le vignettage ;
- habiller l'interface du combat.

---

## 5. La suite (après validation de l'étape 1)

| Lot | Contenu | Nombre d'images |
|---|---|---|
| **Décors de combat** | savane boisée, forêt, forêt dense, montagne, fleuve, lac, lagune, littoral ; chacun de jour et de nuit | 16 |
| **Scènes de lieux** (centre de la carte) | un village de chaque type par région (traditionnel, moderne, futuriste), ville, camp de bandits, gisements (fer, peau, pierre, or, diamant), lieux mythiques, portail | ~35 |
| **Grande carte** | la Côte d'Ivoire peinte comme une carte ancienne enluminée : régions, fleuves, lacs, reliefs | 1 à 2 |
| **Ninjas** | 3 allures de village (traditionnel, moderne, futuriste), sans équipement ; planche de poses et portrait pour chacune | 6 |
| **Équipement porté** | les 17 objets de forge, en pièces posées sur le personnage (partie 3) | 17 |
| **Ennemis** | brigand, apprenti renégat, esprit de la forêt de Taï, drone et ninja cybernétique du Cercle d'Acier, adeptes Sans-Visage, panthère, bandits et chef, gardien du portail | 11 |
| **Mudras** | 50 signes de la main peints, avec l'animal ou le symbole en filigrane | 50 |
| **Objets et ressources** | 17 objets de forge, 5 ressources | 22 |
| **Interface** | cadres de bois sculpté et de bronze, parchemin, boutons, motifs de toiles de Korhogo | ~10 |
| **Écran titre** | une grande illustration | 1 |

Les descriptions détaillées de chaque lot viendront au fur et à mesure, sur le modèle de l'étape 1.

---

## 6. Règles de cohérence
- Toujours la **même image de style** (`--sref`).
- Les combattants du joueur **regardent vers la droite**, les adversaires **vers la gauche**.
- Les pieds sont sur la **même ligne de sol** dans une planche, et l'**échelle** est la même pour tous les humains.
- Les ninjas et leurs pièces d'équipement sont toujours **vus de côté, tournés vers la droite**, dans la **même pose de repos** : sinon les pièces ne s'emboîtent pas.
- Aucun texte, logo ni signature dans les images.
- Pas de clichés : l'Afrique de Ninja Ivoire est variée, moderne autant que traditionnelle, et respectueuse des cultures qu'elle cite (voir le GDD, principes de respect culturel).
