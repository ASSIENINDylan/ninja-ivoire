#!/usr/bin/env python3
"""Génère le document de conception complet de Ninja Ivoire en PDF.

Il rassemble le GDD, le contenu du jeu (lu dans client/donnees/regles.json),
la direction artistique, la feuille de route et l'état du prototype.

    pip install markdown playwright pypdf
    python3 docs/outils/generer_pdf.py [sortie.pdf]

Chromium : celui de Playwright, ou le chemin donné par la variable CHROMIUM.
"""

import html
import json
import os
import re
import sys
import tempfile
from datetime import date
from pathlib import Path

import markdown
from playwright.sync_api import sync_playwright

# pypdf n'a pas besoin de chiffrement ici ; certaines installations de
# « cryptography » plantent à l'import, on l'écarte donc.
sys.modules.setdefault("cryptography", None)
from pypdf import PdfReader, PdfWriter  # noqa: E402

RACINE = Path(__file__).resolve().parents[2]
DOCS = RACINE / "docs"
SORTIE = Path(sys.argv[1]) if len(sys.argv) > 1 else DOCS / "Ninja_Ivoire_Document_de_conception.pdf"
REGLES = json.loads((RACINE / "client/donnees/regles.json").read_text(encoding="utf-8"))
POLICES = RACINE / "client/assets/fonts"
VERSION = "0.4"
MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]


def date_fr(d: date) -> str:
    return f"{d.day} {MOIS[d.month - 1]} {d.year}"


def e(t) -> str:
    return html.escape(str(t))


# --- Markdown -----------------------------------------------------------------

def preparer(md: str) -> str:
    """Rend le Markdown des documents lisible par python-markdown : ligne vide
    avant les listes et les tableaux, listes imbriquées sur 4 espaces."""
    sortie = []
    for ligne in md.split("\n"):
        m = re.match(r"^( +)([-*]|\d+\.) ", ligne)
        if m:
            ligne = "    " + ligne[len(m.group(1)):]
        debut_liste = re.match(r"^([-*]|\d+\.) ", ligne)
        debut_table = ligne.startswith("|")
        if sortie and sortie[-1].strip() != "":
            prec = sortie[-1]
            prec_liste = re.match(r"^\s*([-*]|\d+\.) ", prec) or prec.startswith("    ")
            if debut_liste and not prec_liste:
                sortie.append("")
            elif debut_table and not prec.startswith("|"):
                sortie.append("")
        sortie.append(ligne)
    return "\n".join(sortie)


def md_vers_html(md: str) -> str:
    return markdown.markdown(preparer(md), extensions=["tables", "fenced_code", "sane_lists"])


def document(nom: str, sans_titre: bool = True) -> str:
    md = (DOCS / nom).read_text(encoding="utf-8")
    if sans_titre:
        md = re.sub(r"^# .*\n", "", md, count=1)
    # Les renvois entre documents deviennent des renvois entre parties du PDF.
    md = md.replace("[DIRECTION_ARTISTIQUE.md](DIRECTION_ARTISTIQUE.md)", "la partie 3 de ce document")
    return md_vers_html(md)


# --- Tableaux tirés des règles du jeu ------------------------------------------

def table(entetes, lignes, classe="") -> str:
    h = "".join(f"<th>{e(x)}</th>" for x in entetes)
    corps = "".join("<tr>" + "".join(f"<td>{x}</td>" for x in l) + "</tr>" for l in lignes)
    return f'<table class="{classe}"><thead><tr>{h}</tr></thead><tbody>{corps}</tbody></table>'


ELEMENTS = {x["id"]: x for x in REGLES["elements"]}
FORMES = {"trait": "Projectile", "lame": "Lame", "mur": "Mur", "cercle": "Zone", "lien": "Lien", "armure": "Armure",
          "double": "Clone", "piege": "Piège", "pas": "Déplacement", "invocation": "Invocation"}
EFFETS = {"consumer": "Dégâts magiques", "briser": "Dégâts physiques", "marquer": "Dégâts purs", "renforcer": "Défense",
          "repousser": "Entrave (mouvement, fuite)", "lier": "Entrave (frapper, garde, mudras)",
          "aveugler": "Illusion (tromper)", "dissimuler": "Illusion (insaisissable)",
          "soigner": "Soin", "drainer": "Soin (drain, après le combat)"}
MODIFS = {"amplifier": "Amplifier", "etendre": "Étendre", "multiplier": "Multiplier", "retarder": "Retarder",
          "silence": "Silence", "persistance": "Persistance"}
ATTRIBUTS = {"fangan": "Fangan (force)", "gnanga": "Gnanga (technique)", "manhis": "Manhis (agilité)"}
RESSOURCES = REGLES["ressources"]["noms"]


def niveau_mudra(m) -> str:
    if m["niveau"] < 0:
        return "par quête"
    if m["categorie"] == "element":
        return "avec l'élément"
    return str(max(1, m["niveau"]))


def partie_contenu() -> str:
    c = REGLES["constantes"]
    out = []
    out.append("<p>Ces tableaux sont tirés directement des règles du prototype : ils décrivent le jeu tel qu'il tourne aujourd'hui.</p>")

    # Mudras
    out.append('<h2 id="c-mudras">Les 50 mudras</h2>')
    cats = [("element", "Mudras d'élément (16 de base, 8 mythiques)"), ("forme", "Mudras de forme (10)"),
            ("effet", "Mudras d'effet (10)"), ("modificateur", "Modificateurs (6)")]
    for cat, titre in cats:
        out.append(f"<h3>{e(titre)}</h3>")
        lignes = []
        for m in REGLES["mudras"]:
            if m["categorie"] != cat:
                continue
            if cat == "element":
                el = ELEMENTS.get(m["ref"], {})
                sens = f'{e(el.get("nom", m["ref"]))} <span class="dim">({e(el.get("tier", ""))})</span>'
            elif cat == "forme":
                sens = e(FORMES.get(m["ref"], m["ref"]))
            elif cat == "effet":
                sens = e(EFFETS.get(m["ref"], m["ref"]))
            else:
                sens = e(MODIFS.get(m["ref"], m["ref"]))
            lignes.append([f"<b>{e(m['nom'])}</b>", sens, e(niveau_mudra(m))])
        out.append(table(["Mudra", "Sens", "Débloqué au niveau"], lignes, "compacte"))

    # Régions et villages
    out.append('<h2 id="c-regions">Régions et villages</h2>')
    lignes = []
    for r in REGLES["regions"]:
        el = ELEMENTS.get(r["element"], {}).get("nom", "—") if r["element"] else "—"
        lignes.append([f"<b>{e(r['nom'])}</b>", e(el), e(ATTRIBUTS.get(r["attribut"], "—")),
                       "<br>".join(e(v) for v in r["villages"])])
    out.append(table(["Région", "Élément de départ", "Attribut favorisé", "Villages (traditionnel, moderne, futuriste)"], lignes))
    out.append("<p>Le Cœur n'est pas jouable : ses trois villages sont peuplés de PNJ neutres.</p>")
    out.append("<h3>Types de village</h3>")
    lignes = []
    for v in REGLES["villages"]:
        bonus = []
        if v["bonus_pv"]:
            bonus.append(f"PV {v['bonus_pv']:+d}")
        if v["bonus_souffle"]:
            bonus.append(f"Souffle {v['bonus_souffle']:+d}")
        if v["bonus_xp"]:
            bonus.append(f"expérience +{v['bonus_xp']} %")
        if v["bonus_arme"]:
            bonus.append(f"arme de départ +{v['bonus_arme']}")
        if v["resonance"]:
            bonus.append("résonance précise")
        lignes.append([f"<b>{e(v['nom'])}</b>", e(v["avantages"]), e(v["defauts"]), e(", ".join(bonus))])
    out.append(table(["Type", "Avantages", "Défauts", "Effets en jeu"], lignes))

    # Progression
    out.append('<h2 id="c-progression">Progression du ninja</h2>')
    lignes = [
        ["Niveau maximum", str(c["niveau_max"])],
        ["Attributs au départ", f"{c['attribut_depart']} partout, +{c['bonus_region']} dans l'attribut de la région"],
        ["À chaque niveau", f"{c['points_par_niveau']} points à répartir, +1 automatique dans l'attribut de la région"],
        ["Expérience pour passer du niveau n au suivant", "40 × n + 8 × n²"],
        ["Éléments", f"1 de départ, 1 au choix tous les {c['palier_element']} niveaux, 1 de plus par légendaire connu"],
        ["Fusions (éléments rares)", f"à partir du niveau {c['niveau_fusion']}, en maîtrisant les deux éléments"],
        ["Points de vie", "60 + 4 × Fangan + 6 × niveau, plus les bonus de village et d'équipement"],
        ["Souffle", "40 + 3 × Gnanga + 2 × niveau, plus le bonus de village"],
        ["Mudras formés par tour", "3 + Gnanga ÷ 15"],
        ["Jutsus favoris", f"{c['favoris_max']} au plus"],
        ["Maîtrise", f"{c['maitrise_decouverte']} à la découverte, {c['maitrise_parchemin']} par parchemin, jusqu'à {c['maitrise_max']}"],
        ["Endurance", f"{c['endurance_max']} points, +1 par minute réelle"],
        ["Guérison", f"toute la vie en {c['regen_pv_secondes'] // 60} minutes réelles, ou d'un coup au repos"],
        ["Rencontres en pleine nature", f"{int(c['chance_rencontre'] * 100)} % par pas"],
    ]
    out.append(table(["Règle", "Valeur"], [[e(a), e(b)] for a, b in lignes], "regles"))

    # Rencontres
    out.append('<h2 id="c-rencontres">Rencontres et adversaires</h2>')
    lignes = []
    for r in REGLES["rencontres"]:
        noms = {}
        for x in r["ennemis"]:
            noms[x["nom"]] = noms.get(x["nom"], 0) + 1
        ennemis = ", ".join(f"{n} × {k}" if n > 1 else k for k, n in noms.items())
        lignes.append([f"<b>{e(r['nom'])}</b>", str(r["niveau"]), e(r["lieu"]), e(ennemis), f"{r['xp']} xp · {r['dje']} Djê"])
    out.append(table(["Rencontre", "Niveau", "Lieu", "Adversaires", "Récompense"], lignes))

    # Ressources et forge
    out.append('<h2 id="c-forge">Ressources et forge</h2>')
    res = REGLES["ressources"]
    lignes = [[f"<b>{e(RESSOURCES[k])}</b>", str(res["rendement"][k]), str(res["xp"][k])] for k in res["liste"]]
    out.append(table(["Ressource", "Récolte de base", "Expérience d'exploitation"], lignes))
    out.append(f"<p>Exploiter coûte {res['cout_exploitation']} d'endurance. Un gisement compte {res['gisement_max']} charges "
               f"et en regagne une toutes les {res['gisement_regen'] // 60} minutes. Récolte : base × (1 + 25 % par niveau "
               f"d'exploitation au-delà du premier), avec une part de hasard. Une récolte sur cinq déclenche un événement "
               f"(bandits ou ninja de passage) ; un camp de bandits se reforme en {res['camp_repos'] // 60} minutes.</p>")
    noms_empl = REGLES["forge"]["noms_emplacements"]
    lignes = []
    for o in REGLES["forge"]["objets"]:
        cout = ", ".join(f"{n} {RESSOURCES[k].lower()}" for k, n in sorted(o["cout"].items(), key=lambda kv: -kv[1]))
        eff = []
        if o.get("puissance"):
            eff.append(f"puissance {o['puissance']}" + (" (à distance)" if o.get("distance") else ""))
        if o.get("defense"):
            eff.append(f"défense +{o['defense']}")
        if o.get("defense_mag"):
            eff.append(f"défense magique +{o['defense_mag']}")
        if o.get("pv"):
            eff.append(f"PV +{o['pv']}")
        if o.get("manhis"):
            eff.append(f"Manhis +{o['manhis']}")
        lignes.append([f"<b>{e(o['nom'])}</b>", e(noms_empl[o["emplacement"]]), e(cout), e(", ".join(eff))])
    out.append(table(["Objet", "Emplacement", "Coût", "Effets"], lignes))

    # Légendaires (recettes volontairement absentes : elles restent secrètes)
    out.append('<h2 id="c-legendaires">Les 8 jutsus légendaires</h2>')
    out.append("<p>Les suites de mudras des légendaires restent secrètes : elles ne figurent que dans le code du serveur. "
               "La puissance est calculée pour un ninja à 60 dans chaque attribut, avec une maîtrise de 100. "
               "Pour comparaison, les meilleurs jutsus ordinaires accessibles aujourd'hui (sans élément mythique) "
               "atteignent 580 en soin et 466 en dégâts, pour 64 de Souffle ; avec un élément mythique, jusqu'à 696 "
               "(voir les questions ouvertes, §10 de la partie 1).</p>")
    legendaires = [
        ("Souffle d'Ivoire", "Soin", "877", "120", "niveau 100, pleine lune, élément Ivoire (mythique)",
         "Le Souffle originel, blanc et pur : celui qui le porte ne tombe pas."),
        ("Rempart des Mosquées d'argile", "Soin", "483", "40", "niveau 8",
         "Un rempart d'argile hérissé de pieux protège tout le camp et régénère celui qui l'a bâti."),
        ("Colère de la Panthère", "Dégâts", "441", "40", "niveau 8",
         "Le Souffle de Feu prend la forme d'une panthère qui déchire la cible et la consume longuement."),
        ("Harmattan des Anciens", "Illusion", "384", "70", "niveau 60, de jour, fusion Harmattan",
         "Le vent sec du Nord se lève, aveugle et disperse toute l'armée adverse."),
        ("Chant du Lamantin", "Soin", "359", "38", "niveau 10, de nuit",
         "Un chant venu des lagunes referme les plaies du chanteur, longtemps après la bataille."),
        ("Tonnerre de la Dent de Man", "Dégâts", "309", "42", "niveau 12",
         "La foudre tombe du sommet de la Dent de Man et pulvérise les défenses de la cible."),
        ("Racines du Fromager", "Entrave", "292", "36", "niveau 10",
         "Les racines du grand fromager enserrent la cible, l'immobilisent et l'épuisent."),
        ("Danse du Calao", "Entrave", "220", "38", "niveau 12",
         "Une nuée de rafales en forme de calaos frappe deux fois et balaie les rangs adverses."),
    ]
    lignes = [[f"<b>{e(n)}</b><br><span class='dim'>{e(t)}</span>", e(ty), p, s, e(cond)] for n, ty, p, s, cond, t in legendaires]
    out.append(table(["Légendaire", "Type", "Puissance", "Souffle", "Conditions cachées"], lignes))
    return "\n".join(out)


def partie_prototype() -> str:
    out = []
    out.append('<h2 id="p-feuille">Feuille de route</h2>')
    feuille = (DOCS / "ROADMAP.md").read_text(encoding="utf-8")
    feuille = feuille.split("## Architecture")[0]
    out.append(md_vers_html(re.sub(r"^# .*\n", "", feuille, count=1)))

    out.append('<h2 id="p-etat">Ce que contient le prototype 0.4</h2>')
    readme = (RACINE / "README.md").read_text(encoding="utf-8")
    bloc = re.search(r"\| Écran \| Contenu \|.*?\n\n", readme, re.S)
    if bloc:
        out.append(md_vers_html(bloc.group(0)))
    out.append(md_vers_html("""En chiffres :

- **4 120 000 jutsus** ordinaires, tous différents en combat (vérifié par un test), et **8 légendaires** ;
- **50 mudras**, **40 éléments** (16 de base, 16 rares par fusion, 8 mythiques) ;
- une carte de **1 352 cases**, avec **402 cases occupées** : 56 camps de bandits et 346 gisements (134 de peau, 77 de pierre, 52 de fer, 23 d'or, 10 de diamant) ;
- **10 rencontres** et **17 objets** à forger ;
- des tests automatiques à chaque version : règles Go, parité du moteur du jeu sur près de 3 000 suites de mudras, partie complète, 300 combats simulés.
"""))
    out.append('<h3>Jouer et tester</h3>')
    out.append(md_vers_html("""- Chaque version est construite automatiquement pour Windows : `NinjaIvoire.exe` et `NinjaIvoire.pck`, sans installation.
- Le jeu tourne entièrement hors ligne ; les autres ninjas croisés sur la carte sont simulés.
- **Mode test** : au village, sous la fiche du ninja, on choisit un niveau (40 par défaut) et on clique sur « Y passer ». Le ninja gagne d'un coup les niveaux, avec leurs points d'attribut et leurs éléments à choisir, que l'on répartit soi-même.
- **Portails** : ils sont sur la carte et leur gardien se combat, mais la guerre du vendredi (sièges, prise de zones) viendra avec le jeu en ligne.
"""))

    out.append('<h2 id="p-captures">Captures du prototype</h2>')
    out.append("<p>L'interface actuelle est provisoire : elle sera remplacée par la direction artistique de la partie 3.</p>")
    captures = [("03_village", "Le village"), ("13_carte_gisement", "La carte : un gisement"),
                ("15_carte_camp", "La carte : un camp de bandits"), ("16_forge", "La forge et le coffre"),
                ("05_dojo_resonance", "Le dojo : la résonance"), ("06_grimoire", "Le grimoire"),
                ("08_combat_clone", "Un combat : clone indiscernable"), ("18_village_niveau_40", "Le mode test : niveau 40")]
    cellules = []
    for f, legende in captures:
        chemin = DOCS / "captures" / f"{f}.png"
        if chemin.exists():
            cellules.append(f'<figure><img src="{chemin.as_uri()}"><figcaption>{e(legende)}</figcaption></figure>')
    out.append('<div class="captures">' + "".join(cellules) + "</div>")

    out.append('<h2 id="p-architecture">Architecture technique</h2>')
    archi = readme.split("## Architecture", 1)[1].split("## Développer")[0]
    out.append(md_vers_html(archi))
    return "\n".join(out)


# --- Assemblage ----------------------------------------------------------------

PARTIES = [
    ("partie1", "Partie 1", "La conception du jeu", "Vision, combat, mudras, éléments, ninja, monde, guerre, organisations, direction artistique, technique."),
    ("partie2", "Partie 2", "Le contenu du jeu", "Mudras, régions, progression, rencontres, forge et légendaires, tels qu'ils tournent dans le prototype."),
    ("partie3", "Partie 3", "La direction artistique", "La bible graphique : style, palette, méthode de production par IA, équipement visible."),
    ("partie4", "Partie 4", "Feuille de route et prototype", "Les étapes du projet, ce que contient la version 0.4, captures et architecture."),
]

CSS = """
@font-face { font-family: 'Marcellus'; src: url('POLICE_TITRE'); }
@font-face { font-family: 'Outfit'; src: url('POLICE_TEXTE'); font-weight: 100 900; }
@page { size: A4; margin: 20mm 17mm 20mm 17mm; }
@page couverture { margin: 0; }
:root { --encre: #2A1A12; --bois: #5A3A22; --bronze: #B8862F; --or: #D9A534; --laterite: #A8452B;
        --indigo: #243B6B; --foret: #3E6B35; --parchemin: #EFE3C8; --clair: #F7EEDA; --gris: #7A6A58; }
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { margin: 0; font-family: 'Outfit', sans-serif; font-weight: 300; font-size: 10pt; line-height: 1.5; color: var(--encre); background: #fff; }
b, strong { font-weight: 600; }
h1, h2, h3, h4 { font-family: 'Marcellus', serif; font-weight: 400; color: var(--bois); break-after: avoid; }
h2 { font-size: 17pt; margin: 22pt 0 6pt; padding-bottom: 3pt; border-bottom: 1.5pt solid var(--bronze); }
h3 { font-size: 13pt; margin: 14pt 0 4pt; color: var(--laterite); }
h4 { font-size: 11pt; margin: 10pt 0 3pt; }
p { margin: 4pt 0 6pt; orphans: 3; widows: 3; }
ul, ol { margin: 4pt 0 8pt; padding-left: 16pt; }
li { margin: 1.5pt 0; }
blockquote { margin: 6pt 0; padding: 6pt 10pt; background: var(--clair); border-left: 3pt solid var(--bronze); }
blockquote p { margin: 0; }
code { font-family: 'DejaVu Sans Mono', monospace; font-size: 8.5pt; background: var(--clair); padding: 0 2pt; border-radius: 2pt; }
pre { background: var(--clair); border: 0.75pt solid #D9C9A6; border-radius: 3pt; padding: 7pt 9pt; white-space: pre-wrap; word-break: break-word; break-inside: avoid; }
pre code { background: none; padding: 0; font-size: 8pt; line-height: 1.4; }
table { width: 100%; border-collapse: collapse; margin: 6pt 0 10pt; font-size: 8.8pt; line-height: 1.35; }
thead { display: table-header-group; }
tr { break-inside: avoid; }
th { background: var(--bois); color: var(--parchemin); font-weight: 500; text-align: left; padding: 4pt 6pt; }
td { padding: 3.5pt 6pt; border-bottom: 0.5pt solid #E3D6BA; vertical-align: top; }
tbody tr:nth-child(even) td { background: #FBF6EA; }
table.compacte td, table.compacte th { padding: 2.5pt 6pt; }
table.regles td:first-child { width: 42%; font-weight: 500; }
.dim { color: var(--gris); font-size: 8.3pt; }
a { color: var(--laterite); text-decoration: none; }

.couverture { page: couverture; height: 297mm; position: relative; background: #2B1B12; color: var(--parchemin); overflow: hidden; }
.couverture .bande { height: 12mm; background: repeating-linear-gradient(90deg, #B8862F 0 9mm, #2B1B12 9mm 11mm, #A8452B 11mm 20mm, #2B1B12 20mm 22mm, #243B6B 22mm 31mm, #2B1B12 31mm 33mm); border-top: 1pt solid var(--or); border-bottom: 1pt solid var(--or); }
.couverture .haut { position: absolute; top: 0; left: 0; right: 0; }
.couverture .bas { position: absolute; bottom: 0; left: 0; right: 0; }
.couverture .contenu { position: absolute; top: 44mm; left: 22mm; right: 22mm; }
.couverture .sur { font-size: 11pt; letter-spacing: 3pt; text-transform: uppercase; color: var(--or); }
.couverture h1 { font-size: 58pt; color: var(--parchemin); margin: 6mm 0 2mm; line-height: 1; }
.couverture .sous { font-family: 'Marcellus', serif; font-size: 20pt; color: #E9D9B4; margin: 0 0 10mm; }
.couverture .phrase { font-size: 11.5pt; line-height: 1.6; color: #D8C39A; max-width: 150mm; }
.couverture .image { margin-top: 12mm; border: 1.5mm solid var(--bois); outline: 0.6mm solid var(--bronze); border-radius: 1.5mm; }
.couverture .image img { display: block; width: 100%; }
.couverture .pied { position: absolute; bottom: 22mm; left: 22mm; right: 22mm; display: flex; justify-content: space-between; font-size: 10pt; color: #D8C39A; }
.couverture .pied b { color: var(--parchemin); }

.sommaire { }
.sommaire h2 { margin-top: 0; }
.toc { list-style: none; padding: 0; margin: 10pt 0 0; }
.toc li { display: flex; align-items: baseline; margin: 3pt 0; }
.toc li .t { flex: 0 1 auto; }
.toc li .pts { flex: 1; border-bottom: 0.75pt dotted #BFA886; margin: 0 5pt; transform: translateY(-3pt); }
.toc li .n { flex: 0 0 auto; min-width: 14pt; text-align: right; }
.toc li.partie { margin-top: 10pt; font-family: 'Marcellus', serif; font-size: 12.5pt; color: var(--laterite); }
.toc li.section { padding-left: 12pt; font-size: 9.8pt; }
.legende { margin-top: 14pt; padding: 8pt 10pt; background: var(--clair); border-left: 3pt solid var(--bronze); font-size: 9.3pt; }

.intercalaire { break-before: page; padding-top: 55mm; }
.intercalaire .num { font-size: 11pt; letter-spacing: 3pt; text-transform: uppercase; color: var(--bronze); }
.intercalaire h1 { font-size: 34pt; margin: 4mm 0 5mm; color: var(--bois); }
.intercalaire .bande { height: 5mm; width: 60mm; margin: 0 0 8mm; background: repeating-linear-gradient(90deg, #B8862F 0 6mm, #fff 6mm 7mm, #A8452B 7mm 13mm, #fff 13mm 14mm, #243B6B 14mm 20mm, #fff 20mm 21mm); }
.intercalaire p { font-size: 12pt; color: var(--gris); max-width: 130mm; }
.corps-partie { break-before: page; }
.corps-partie > h2:first-child, .corps-partie > p:first-child + h2 { margin-top: 0; }

.captures { display: grid; grid-template-columns: 1fr 1fr; gap: 8pt; }
.captures figure { margin: 0; break-inside: avoid; }
.captures img { width: 100%; display: block; border: 0.75pt solid #D9C9A6; border-radius: 2pt; }
.captures figcaption { font-size: 8.5pt; color: var(--gris); margin-top: 2pt; }
"""


def couverture(auj: date) -> str:
    img = DOCS / "captures" / "14_exploitation.png"
    image = f'<div class="image"><img src="{img.as_uri()}"></div>' if img.exists() else ""
    return f"""
<section class="couverture">
  <div class="haut"><div class="bande"></div></div>
  <div class="contenu">
    <div class="sur">Document de conception</div>
    <h1>Ninja Ivoire</h1>
    <p class="sous">Tous les aspects du jeu</p>
    <p class="phrase">Un jeu de ninjas sur PC, dans une Côte d'Ivoire à la fois mythique et futuriste : combats stratégiques au tour par tour,
    jutsus composés de mudras à découvrir, régions en guerre, ressources, forge et économie tenue par les joueurs.</p>
    {image}
  </div>
  <div class="pied"><span>Prototype <b>{VERSION}</b> · {date_fr(auj)}</span><span>Conception : <b>Terence</b> · Développement : <b>Claude</b></span></div>
  <div class="bas"><div class="bande"></div></div>
</section>"""


def extraire_sections(corps: str, prefixe: str):
    """Donne un identifiant à chaque titre de niveau 2 et renvoie leur liste."""
    sections = []

    def remplacer(m):
        attrs, titre = m.group(1), m.group(2)
        if "id=" in attrs:
            ident = re.search(r'id="([^"]+)"', attrs).group(1)
        else:
            ident = f"{prefixe}-{len(sections)}"
            attrs = f' id="{ident}"'
        sections.append((ident, re.sub(r"<[^>]+>", "", titre)))
        return f"<h2{attrs}>{titre}</h2>"

    corps = re.sub(r"<h2([^>]*)>(.*?)</h2>", remplacer, corps)
    return corps, sections


def page_html(corps: str) -> str:
    css = CSS.replace("POLICE_TITRE", (POLICES / "Marcellus-Regular.ttf").as_uri()).replace("POLICE_TEXTE", (POLICES / "Outfit.ttf").as_uri())
    return f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Ninja Ivoire — Document de conception</title>
<style>{css}</style></head><body>{corps}</body></html>"""


def assembler(pages: dict) -> str:
    """Le corps du document : tout sauf la couverture, imprimée à part sans pied de page."""
    corps_parties = {
        "partie1": document("GDD.md"),
        "partie2": partie_contenu(),
        "partie3": document("DIRECTION_ARTISTIQUE.md"),
        "partie4": partie_prototype(),
    }
    toc = []
    blocs = []
    for pid, num, titre, resume in PARTIES:
        corps, sections = extraire_sections(corps_parties[pid], pid)
        toc.append(f'<li class="partie"><span class="t">{num} — {e(titre)}</span><span class="pts"></span><span class="n">{pages.get(pid, "")}</span></li>')
        for ident, t in sections:
            toc.append(f'<li class="section"><span class="t">{e(t)}</span><span class="pts"></span><span class="n">{pages.get(ident, "")}</span></li>')
        blocs.append(f"""
<section class="intercalaire" id="{pid}"><div class="num">{num}</div><h1>{e(titre)}</h1><div class="bande"></div><p>{e(resume)}</p></section>
<section class="corps-partie">{corps}</section>""")
    sommaire = f"""
<section class="sommaire">
  <h2>Sommaire</h2>
  <ul class="toc">{''.join(toc)}</ul>
  <div class="legende"><b>Comment lire ce document.</b> <b>Décidé</b> : validé par Terence. <b>Proposé</b> : piste de Claude, à valider.
  <b>En place</b> : déjà dans le prototype. Les chiffres de la partie 2 sont ceux du prototype {VERSION}.</div>
</section>"""
    return page_html(sommaire + "".join(blocs))


PIED = """<div style="width:100%; font-family: sans-serif; font-size:7.5pt; color:#7A6A58; padding: 0 17mm; display:flex; justify-content:space-between;">
<span>Ninja Ivoire — Document de conception · prototype VERSION</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>"""


def imprimer(page, source_html: str, chemin: Path, pied: bool = True) -> None:
    fichier = Path(tempfile.gettempdir()) / "ninja_ivoire_doc.html"
    fichier.write_text(source_html, encoding="utf-8")
    page.goto(fichier.as_uri(), wait_until="load")
    page.evaluate("document.fonts.ready")
    page.pdf(path=str(chemin), format="A4", print_background=True, prefer_css_page_size=True,
             display_header_footer=pied, header_template="<div></div>", footer_template=PIED.replace("VERSION", VERSION))


def numeros_de_page(chemin: Path, titres: dict) -> dict:
    """Retrouve la page de chaque titre dans le PDF (première occurrence après le sommaire)."""
    lecteur = PdfReader(str(chemin))
    textes = [re.sub(r"\s+", " ", p.extract_text() or "") for p in lecteur.pages]
    trouve = {}
    debut = 1  # après le début du sommaire
    for ident, titre in titres.items():
        cle = re.sub(r"\s+", " ", titre).strip()[:40]
        for i in range(debut, len(textes)):
            if cle in textes[i]:
                trouve[ident] = i + 1
                debut = i
                break
    return trouve


def main() -> None:
    auj = date.today()
    executable = os.environ.get("CHROMIUM")
    with sync_playwright() as p:
        navigateur = p.chromium.launch(executable_path=executable) if executable else p.chromium.launch()
        page = navigateur.new_page()
        # Premier passage : mise en page ; second : numéros de page du sommaire.
        brouillon = SORTIE.with_suffix(".brouillon.pdf")
        titres = {}
        for pid, num, titre, resume in PARTIES:
            titres[pid] = resume  # le résumé de l'intercalaire n'apparaît qu'une fois
            _, sections = extraire_sections({"partie1": document("GDD.md"), "partie2": partie_contenu(),
                                             "partie3": document("DIRECTION_ARTISTIQUE.md"), "partie4": partie_prototype()}[pid], pid)
            for ident, t in sections:
                titres[ident] = t
        factices = {k: "00" for k in titres}
        imprimer(page, assembler(factices), brouillon)
        pages = numeros_de_page(brouillon, titres)
        corps = SORTIE.with_suffix(".corps.pdf")
        imprimer(page, assembler(pages), corps)
        premiere = SORTIE.with_suffix(".couverture.pdf")
        imprimer(page, page_html(couverture(auj)), premiere, pied=False)
        navigateur.close()
    # La couverture, sans numéro, puis le corps numéroté à partir du sommaire.
    ecrivain = PdfWriter()
    for f in (premiere, corps):
        ecrivain.append(str(f))
    ecrivain.add_metadata({"/Title": "Ninja Ivoire — Document de conception", "/Author": "Terence (conception), Claude (développement)"})
    with open(SORTIE, "wb") as sortie:
        ecrivain.write(sortie)
    for f in (brouillon, corps, premiere):
        f.unlink()
    manquants = [t for k, t in titres.items() if k not in pages]
    print(f"{SORTIE} : {len(PdfReader(str(SORTIE)).pages)} pages")
    if manquants:
        print("Titres non retrouvés pour le sommaire :", manquants)


if __name__ == "__main__":
    main()
