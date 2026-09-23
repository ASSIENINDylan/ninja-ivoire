class_name Regles
extends RefCounted
## Règles du jeu, exportées depuis le serveur Go (donnees/regles.json) :
## éléments, mudras, régions, rencontres, tables de la grammaire.
## Le serveur Go reste la référence ; ce fichier en est une copie fidèle.

const CHEMIN := "res://donnees/regles.json"
const NOUVELLE_LUNE_REF := 947182440.0  # 6 janvier 2000, 18 h 14 UTC
const MOIS_SYNODIQUE := 29.530588853

static var d: Dictionary = {}
static var elements := {}
static var mudras := {}
static var regions := {}
static var villages := {}
static var rencontres := {}
static var fusions := {}
static var mudra_de_element := {}
static var g: Dictionary = {}
static var c: Dictionary = {}


static func charger() -> String:
	if not d.is_empty():
		return ""
	var f := FileAccess.open(CHEMIN, FileAccess.READ)
	if f == null:
		return "Règles du jeu introuvables (%s)." % CHEMIN
	var donnees = JSON.parse_string(f.get_as_text())
	if not donnees is Dictionary:
		return "Règles du jeu illisibles."
	d = donnees
	for e in d.elements:
		elements[e.id] = e
	for m in d.mudras:
		mudras[m.id] = m
		if m.categorie == "element":
			mudra_de_element[m.ref] = m.id
	for r in d.regions:
		regions[r.id] = r
	for v in d.villages:
		villages[v.id] = v
	for r in d.rencontres:
		rencontres[r.id] = r
	for t in d.fusions:
		fusions[t[0] + ">" + t[1]] = t[2]
	g = d.grammaire
	c = d.constantes
	return ""


## Élément rare issu de deux éléments de base enchaînés dans cet ordre.
static func fusion_de(a: String, b: String) -> String:
	return fusions.get(a + ">" + b, "")


## Multiplicateur de dégâts d'un élément attaquant contre l'élément de la cible.
static func multiplicateur(attaque: String, cible: String) -> float:
	var a = elements.get(attaque)
	if a == null or cible == "":
		return 1.0
	if a.tier == "mythique":
		return 1.25
	if (a.fort if a.fort != null else []).has(cible):
		return 1.5
	if (a.faible if a.faible != null else []).has(cible):
		return 0.67
	return 1.0


## Un ninja de ce niveau, connaissant ces éléments, sait-il former ce mudra ?
static func debloque(m: Dictionary, niveau: int, elements_connus: Array) -> bool:
	if m.categorie == "element":
		return elements_connus.has(m.ref)
	return int(m.niveau) >= 1 and niveau >= int(m.niveau)


static func village_index(type_id: String) -> int:
	for i in d.villages.size():
		if d.villages[i].id == type_id:
			return i
	return -1


# --- Soleil et Lune : l'heure réelle -----------------------------------------

## Le moment présent : temps universel et heure locale décimale.
static func maintenant() -> Dictionary:
	var t := Time.get_datetime_dict_from_system()
	return {"unix": Time.get_unix_time_from_system(), "heure": float(t.hour) + float(t.minute) / 60.0, "texte": "%02d:%02d" % [t.hour, t.minute]}


static func phase_lune(m: Dictionary) -> float:
	var jours: float = (m.unix - NOUVELLE_LUNE_REF) / 86400.0
	return fposmod(jours / MOIS_SYNODIQUE, 1.0)


static func illumination(m: Dictionary) -> float:
	return (1.0 - cos(TAU * phase_lune(m))) / 2.0


static func nom_phase(m: Dictionary) -> String:
	var p := phase_lune(m)
	if p < 0.03 or p >= 0.97:
		return "Nouvelle lune"
	if p < 0.22:
		return "Premier croissant"
	if p < 0.28:
		return "Premier quartier"
	if p < 0.47:
		return "Lune gibbeuse croissante"
	if p < 0.53:
		return "Pleine lune"
	if p < 0.72:
		return "Lune gibbeuse décroissante"
	if p < 0.78:
		return "Dernier quartier"
	return "Dernier croissant"


static func est_nuit(m: Dictionary) -> bool:
	return m.heure >= 19.0 or m.heure < 6.0


static func facteur_soleil(m: Dictionary) -> float:
	return 1.0 + 0.3 * cos((m.heure - 12.0) / 24.0 * TAU)


static func facteur_lune(m: Dictionary) -> float:
	var nuit := (1.0 - cos((m.heure - 12.0) / 24.0 * TAU)) / 2.0
	return 0.7 + 0.45 * nuit + 0.3 * illumination(m) * nuit


static func facteur_cosmique(element: String, m: Dictionary) -> float:
	match element:
		"soleil", "cristal", "bois_sacre":
			return facteur_soleil(m)
		"lune", "songe", "maree":
			return facteur_lune(m)
		"crepuscule":
			return max(facteur_soleil(m), facteur_lune(m))
	return 1.0
