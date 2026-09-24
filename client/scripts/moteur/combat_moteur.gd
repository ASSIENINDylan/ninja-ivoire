class_name CombatMoteur
extends RefCounted
## Combat au tour par tour simultané (copie fidèle de server/internal/combat).
## Les combattants sont des dictionnaires au format de l'API ; les clés qui
## commencent par « _ » sont privées et ne sont jamais montrées à l'écran.
## Les jutsus sont des listes d'effets élémentaires (voir grammaire.gd).

const ERR_FINI := "le combat est terminé"
const ERR_ACTEUR := "combattant inconnu ou hors de combat"
const ERR_MUDRA := "vous ne savez pas encore former ce mudra"
const ERR_SEQUENCE := "suite de mudras trop longue"
const ERR_ACTION := "action inconnue"
const NB_RANGS := 3
const RANGS_MAX := 4
const ENTRAVES_AU_HASARD := ["immobilise", "desarme", "scelle", "sans_garde"]
const TEXTES_POSES := {
	"regen": "ses blessures se referment peu à peu", "sangsue": "une sangsue de Souffle le vide",
	"baume": "un baume agira après le combat", "second_souffle": "un second souffle veille",
}

var id := ""
var tour := 0
var combattants: Array = []
var fini := false
var vainqueur := -1
var decouvertes: Array = []
var usages := {}
var resonances: Array = []

var rng := RandomNumberGenerator.new()
var moment: Callable = Regles.maintenant
var _evts: Array = []
var _differes: Array = []


func _init(ident: String, liste: Array, graine: int) -> void:
	id = ident
	combattants = liste
	rng.seed = graine
	for f in combattants:
		if not f.has("_maitrise"):
			f._maitrise = {}
		if not f.has("defense_mag"):
			f.defense_mag = 0
		if not f.has("clone"):
			f.clone = false
	_compacter(0)
	_compacter(1)


# --- Outils --------------------------------------------------------------------

func get_c(ident: String):
	for f in combattants:
		if f.id == ident:
			return f
	return null


static func vivant(f) -> bool:
	return f != null and f.pv > 0


func vivants(camp: int) -> Array:
	var out := []
	for f in combattants:
		if f.camp == camp and f.pv > 0:
			out.append(f)
	out.sort_custom(func(a, b): return a.rang < b.rang)
	return out


## Les combattants debout d'un camp, sans les clones.
func reels(camp: int) -> Array:
	return vivants(camp).filter(func(f): return not f.clone)


func _compacter(camp: int) -> void:
	var i := 1
	for f in vivants(camp):
		f.rang = i
		i += 1


func _emit(type: String, texte: String, acteur: String = "", cible: String = "", valeur: int = 0, element: String = "", jutsu: String = "") -> void:
	_evts.append({"type": type, "acteur": acteur, "cible": cible, "valeur": valeur, "element": element, "jutsu": jutsu, "texte": texte})


func _info(f: Dictionary, texte: String) -> void:
	_emit("info", texte, f.id)


static func statut(f: Dictionary, type: String):
	for s in f.statuts:
		if s.type == type and s.tours > 0:
			return s
	return null


static func a_statut(f: Dictionary, type: String) -> bool:
	return statut(f, type) != null


func _chance(p: float) -> bool:
	return rng.randf() < p


func _hasard(l: Array):
	return l[rng.randi_range(0, l.size() - 1)]


static func mudras_par_tour(f: Dictionary) -> int:
	return 3 + int(f.gnanga) / 15


static func cout_reel(j: Dictionary, maitrise: int) -> int:
	return int(round(float(j.cout) * (1.0 - 0.3 * float(maitrise) / 100.0)))


static func maitrise_de(f: Dictionary, j: Dictionary) -> int:
	if f._maitrise.has(j.cle):
		return int(f._maitrise[j.cle])
	return int(Regles.c.maitrise_decouverte) if f.joueur else int(Regles.c.maitrise_pnj)


## Puissance d'un jutsu : (8 + F·Fangan + G·Gnanga + M·Manhis) × N, modulée
## par la maîtrise, le Soleil et la Lune.
static func puissance_de(f: Dictionary, j: Dictionary, maitrise: int, cosmique: float) -> float:
	var k: Dictionary = j.coefs
	var base: float = (8.0 + float(k.f) * float(f.fangan) + float(k.g) * float(f.gnanga) + float(k.m) * float(f.manhis)) * float(k.n)
	return base * (0.8 + 0.4 * float(maitrise) / 100.0) * cosmique


## Soins qui s'appliqueront à la fin du combat.
static func baume(f: Dictionary) -> int:
	var total := 0.0
	for s in f.statuts:
		if s.type == "baume" and s.tours > 0:
			total += float(s.valeur)
	return int(total + 0.5)


## Vue d'un camp : sans données privées, sans les mudras des adversaires ;
## les clones adverses sont indiscernables de leur original.
func vue(camp: int) -> Dictionary:
	var liste := []
	for f in combattants:
		if f.clone and not vivant(f):
			continue
		var src: Dictionary = f
		if f.camp != camp and f.clone:
			var o = get_c(f._original)
			if vivant(o):
				src = o
		var cp := {}
		for k in src:
			if not str(k).begins_with("_"):
				cp[k] = src[k]
		cp.id = f.id
		cp.rang = f.rang
		cp.clone = f.clone and f.camp == camp
		cp.arme = src.arme.duplicate()
		cp.elements = src.elements.duplicate()
		var st := []
		for s in src.statuts:
			st.append({"type": s.type, "tours": s.tours, "valeur": s.valeur, "element": s.get("element", "")})
		cp.statuts = st
		if src.incantation != null:
			var inc: Dictionary = src.incantation
			cp.incantation = {"progres": inc.progres, "total": inc.total, "silence": inc.silence}
			if f.camp == camp:
				cp.incantation.sequence = inc.sequence.duplicate()
				cp.incantation.cible = inc.cible
		liste.append(cp)
	return {"id": id, "tour": tour, "combattants": liste, "fini": fini, "vainqueur": vainqueur}


# --- Tour de jeu ---------------------------------------------------------------

## Résout un tour. Renvoie {"evenements": […]} ou {"erreur": "…"}.
func jouer_tour(actions: Array) -> Dictionary:
	if fini:
		return {"erreur": ERR_FINI}
	var choix := {}
	for a in actions:
		var f = get_c(a.get("acteur", ""))
		if f == null or not vivant(f) or not f.joueur:
			return {"erreur": ERR_ACTEUR}
		var err := _valider(f, a)
		if err != "":
			return {"erreur": err}
		choix[f.id] = a
	_evts = []
	tour += 1
	for f in combattants:
		if not vivant(f):
			continue
		f.garde = false
		if choix.has(f.id):
			continue
		if f.joueur:
			choix[f.id] = {"acteur": f.id, "type": "incanter" if f.incantation != null else "garde"}
		else:
			choix[f.id] = _choisir_ia(f)
	for f in _initiative(choix):
		if fini or not vivant(f):
			continue
		_executer(f, choix[f.id])
		_verifier_fin()
	if not fini:
		_fin_de_tour()
		_verifier_fin()
	return {"evenements": _evts}


func _valider(f: Dictionary, a: Dictionary) -> String:
	match a.get("type", ""):
		"frapper", "garde", "deplacer", "concentrer":
			return ""
		"incanter":
			var seq: Array = a.get("sequence", [])
			if seq.size() > int(Regles.g.longueur_max):
				return ERR_SEQUENCE
			for m in seq:
				if not Regles.mudras.has(m) or (f.has("_permis") and not f._permis.has(m)):
					return ERR_MUDRA
			return ""
	return ERR_ACTION


func _initiative(choix: Dictionary) -> Array:
	var l := []
	for f in combattants:
		if not vivant(f):
			continue
		var s := float(f.manhis) + rng.randf() * 6.0
		match f.element:
			"vent":
				s += 4
			"foudre":
				s += 3
		if a_statut(f, "immobilise"):
			s *= 0.7
		if choix[f.id].type == "garde":
			s += 1000
		l.append([f, s])
	l.sort_custom(func(a, b): return a[1] > b[1])
	var out := []
	for e in l:
		out.append(e[0])
	return out


func _executer(f: Dictionary, a: Dictionary) -> void:
	var type: String = a.get("type", "")
	if type != "incanter" and f.incantation != null:
		f.incantation = null
		_emit("abandon", f.nom + " abandonne son incantation.", f.id)
	if a_statut(f, "endormi"):
		_info(f, f.nom + " dort profondément.")
		return
	var p = statut(f, "piege")
	if p != null:
		if _declencher_piege(f, p) or not vivant(f):
			return
	var cf = statut(f, "confus")
	if cf != null and type != "garde" and _chance(float(cf.valeur)):
		_frappe_confuse(f)
		return
	match type:
		"garde":
			if a_statut(f, "sans_garde"):
				_info(f, f.nom + " ne parvient pas à se mettre en garde.")
				return
			f.garde = true
			_emit("garde", f.nom + " se met en garde.", f.id)
		"concentrer":
			var gain: int = int(f.souffle_max) * 15 / 100 + int(f.gnanga)
			f.souffle = mini(f.souffle_max, f.souffle + gain)
			_emit("concentration", "%s se concentre et rassemble son Souffle (+%d)." % [f.nom, gain], f.id, "", gain)
		"deplacer":
			if a_statut(f, "immobilise"):
				_info(f, f.nom + " est immobilisé et ne peut pas changer de rang.")
				return
			_placer(f, int(a.get("rang", 0)))
			_emit("deplacement", "%s passe au rang %d." % [f.nom, f.rang], f.id, "", f.rang)
		"frapper":
			if a_statut(f, "desarme"):
				_info(f, f.nom + " est désarmé et ne peut pas frapper.")
				return
			_frapper(f, a.get("cible", ""))
		"incanter":
			if a_statut(f, "scelle"):
				f.incantation = null
				_info(f, "Les mains de " + f.nom + " sont scellées : impossible de former des mudras.")
				return
			_incanter(f, a)


func _frappe_confuse(f: Dictionary) -> void:
	var camp := reels(f.camp)
	if f.clone:
		camp.append(f)
	var t: Dictionary = _hasard(camp)
	var quoi: String = t.nom if t != f else "dans le vide et se blesse"
	_emit("frappe", f.nom + ", confus, frappe " + quoi + " !", f.id, t.id)
	_infliger(f, t, float(f.arme.puissance + f.fangan) * 0.8, "physique", "", false)


func _placer(f: Dictionary, rang: int) -> void:
	var v := vivants(f.camp)
	rang = clampi(rang, 1, v.size())
	for o in v:
		if o.rang == rang and o != f:
			o.rang = f.rang
	f.rang = rang


func ennemis(f: Dictionary) -> Array:
	return vivants(1 - int(f.camp))


static func ciblable(t: Dictionary) -> bool:
	return vivant(t) and not a_statut(t, "invisible") and not a_statut(t, "disparu")


func _cible_ennemie(f: Dictionary, ident: String, contact: bool):
	var possibles := []
	for t in ennemis(f):
		if ciblable(t) and (not contact or t.rang <= 2):
			possibles.append(t)
	if possibles.is_empty():
		return null
	if a_statut(f, "egare"):
		return _hasard(possibles)
	for t in possibles:
		if t.id == ident:
			return t
	return possibles[0]


static func esquive(t: Dictionary) -> float:
	var e := minf(0.35, float(t.manhis) * 0.008)
	var s = statut(t, "esquive")
	if s != null:
		e += float(s.valeur)
	if a_statut(t, "immobilise"):
		e /= 2.0
	return minf(0.9, e)


## Protections d'une cible visée seule. Renvoie la cible finale, ou null.
func _atteindre(a: Dictionary, t: Dictionary, jutsu: bool):
	if t.clone:
		_dissiper_clone(t, "L'attaque traverse " + t.nom + " : ce n'était qu'un clone !")
		return null
	var s = statut(t, "leurre")
	if s != null and s.valeur >= 1:
		s.valeur -= 1
		if s.valeur < 1:
			s.tours = 0
		_emit("esquive", "Un leurre de " + t.nom + " encaisse l'attaque et se dissipe !", a.id, t.id)
		return null
	s = statut(t, "deviation")
	if s != null:
		s.tours = 0
		var autres := reels(a.camp).filter(func(o): return o != a)
		if autres.is_empty():
			_emit("esquive", t.nom + " détourne l'attaque, qui se perd.", a.id, t.id)
			return null
		var o: Dictionary = _hasard(autres)
		_emit("esquive", t.nom + " détourne l'attaque sur " + o.nom + " !", a.id, o.id)
		return o
	s = statut(t, "reflet")
	if s != null and jutsu:
		s.tours = 0
		_emit("reflet", t.nom + " renvoie le jutsu à " + a.nom + " !", t.id, a.id)
		return a
	s = statut(t, "parade")
	if s != null:
		s.tours = 0
		_emit("esquive", t.nom + " pare entièrement le coup.", a.id, t.id)
		return null
	s = statut(a, "aveugle")
	if s != null and _chance(float(s.valeur)):
		_emit("rate", a.nom + ", aveuglé, frappe dans le vide.", a.id, t.id)
		return null
	var e := esquive(t)
	if jutsu:
		e /= 2.0
	if _chance(e):
		_emit("esquive", t.nom + " esquive.", a.id, t.id)
		return null
	return t


func _frapper(f: Dictionary, cible_id: String) -> void:
	var contact: bool = not f.arme.distance
	if contact and f.rang > 2:
		_info(f, f.nom + " est trop loin pour frapper au contact.")
		return
	var t = _cible_ennemie(f, cible_id, contact)
	if t == null:
		_info(f, f.nom + " ne trouve aucune cible à portée.")
		return
	t = _atteindre(f, t, false)
	if t == null:
		return
	var brut := float(f.arme.puissance + f.fangan) * (0.85 + rng.randf() * 0.3)
	var crit := _chance(float(f.manhis) * 0.007)
	if crit:
		brut *= 1.5
	var texte: String = f.nom + " frappe " + t.nom
	if crit:
		texte += " (coup critique)"
	_emit("frappe", texte + " avec " + f.arme.nom + ".", f.id, t.id)
	_infliger(f, t, brut, "physique", "", false)
	_riposter(t, f)


func _riposter(t: Dictionary, attaquant: Dictionary) -> void:
	if t.camp == attaquant.camp or not vivant(t):
		return
	for s in t.statuts.duplicate():
		if s.type != "riposte" or s.tours <= 0 or not vivant(attaquant):
			continue
		var src = get_c(s._source)
		if not vivant(src):
			src = t
		_emit("riposte", "Le Souffle de " + t.nom + " riposte contre " + attaquant.nom + " !", t.id, attaquant.id, 0, s.get("element", ""))
		_appliquer(_contexte_charge(src, s, attaquant), s._effets)


static func facteur_defense(t: Dictionary, nature: String) -> float:
	match nature:
		"physique":
			var f := 40.0 / (40.0 + float(t.defense) + float(t.fangan) * 0.6)
			var s = statut(t, "def_phys")
			if s != null:
				f *= 1.0 - minf(0.8, float(s.valeur))
			return f
		"magique":
			var f := 40.0 / (40.0 + float(t.get("defense_mag", 0)) + float(t.gnanga) * 0.6)
			var s = statut(t, "def_mag")
			if s != null:
				f *= 1.0 - minf(0.8, float(s.valeur))
			return f
	return 1.0


func _infliger(src, t: Dictionary, brut: float, nature: String, element: String, direct: bool) -> int:
	if not vivant(t):
		return 0
	if t.clone:
		_dissiper_clone(t, t.nom + " se dissipe : ce n'était qu'un clone !")
		return 0
	if a_statut(t, "disparu"):
		_emit("esquive", t.nom + " a disparu : rien ne l'atteint.", "", t.id)
		return 0
	if (nature == "physique" and a_statut(t, "intangible_phys")) or (nature == "magique" and a_statut(t, "intangible_mag")):
		_emit("esquive", "Les dégâts " + nature + "s traversent " + t.nom + " sans l'atteindre.", "", t.id)
		return 0
	var dmg := brut
	if nature != "pur" and element != "":
		dmg *= Regles.multiplicateur(element, t.element)
	var m = statut(t, "marque")
	if m != null:
		dmg *= 1.0 + float(m.valeur)
	if not direct:
		dmg *= facteur_defense(t, nature)
		if t.garde and nature != "pur":
			dmg *= 0.5
	var d := maxi(1, int(round(dmg)))
	if not direct and t.absorption > 0:
		var a := mini(int(t.absorption), d)
		t.absorption -= a
		d -= a
		_emit("absorption", "Le bouclier de %s absorbe %d." % [t.nom, a], "", t.id, a)
		if d == 0:
			return 0
	t.pv -= d
	var src_id: String = src.id if src != null else ""
	_emit("degats", "%s perd %d PV (%s)." % [t.nom, d, nature], src_id, t.id, d, element)
	var s = statut(t, "endormi")
	if s != null:
		s.tours = 0
		_emit("statut", t.nom + " se réveille !", "", t.id)
	s = statut(t, "renvoi")
	if s != null and not direct and src != null and src != t and vivant(src):
		_emit("riposte", t.nom + " renvoie une part des dégâts.", t.id, src.id)
		_infliger(t, src, float(d) * float(s.valeur), "pur", "", true)
	if t.pv <= 0:
		s = statut(t, "second_souffle")
		if s == null:
			_mourir(t)
			return d
		s.tours = 0
		t.pv = 1
		_emit("statut", t.nom + " refuse de tomber : second souffle !", "", t.id)
		_soigner(t, t, float(s.valeur))
	if t.incantation != null and not t.incantation.silence and d * 100 >= int(t.pv_max) * 12:
		_interrompre(t, "sous la violence du coup")
	s = statut(t, "declencheur")
	if s != null and float(t.pv) < float(s.valeur) * float(t.pv_max):
		s.tours = 0
		_emit("statut", "Le Souffle de " + t.nom + " réagit à ses blessures !", "", t.id)
		_appliquer(_contexte_charge(t, s, src), s._effets)
	return d


func _interrompre(t: Dictionary, raison: String) -> void:
	if t.incantation == null or t.incantation.silence:
		return
	t.incantation = null
	_emit("interruption", "L'incantation de " + t.nom + " est brisée " + raison + " !", "", t.id)


func _mourir(t: Dictionary) -> void:
	t.pv = 0
	t.incantation = null
	t.statuts = []
	t.rang = 0
	_emit("mort", t.nom + " tombe.", "", t.id)
	for o in combattants:
		if o.clone and o.get("_original", "") == t.id and vivant(o):
			_dissiper_clone(o, "")
	_compacter(t.camp)


func _soigner(f: Dictionary, t: Dictionary, montant: float) -> void:
	if not vivant(t):
		return
	var v := mini(maxi(1, int(round(montant))), int(t.pv_max) - int(t.pv))
	if v <= 0:
		return
	t.pv += v
	_emit("soin", "%s récupère %d PV." % [t.nom, v], f.id, t.id, v)


func _ajouter_statut(t: Dictionary, s: Dictionary) -> void:
	if not vivant(t):
		return
	for k in ["valeur", "element", "_nature", "_source", "_puissance", "_indissipable", "_effets", "_nouveau"]:
		if not s.has(k):
			s[k] = {"valeur": 0.0, "element": "", "_nature": "", "_source": "", "_puissance": 0.0, "_indissipable": false, "_effets": [], "_nouveau": false}[k]
	var cumulable: bool = s.type in ["piege", "invocation", "riposte", "declencheur", "sangsue"]
	var ex = statut(t, s.type)
	if ex != null and not cumulable:
		if s.type == "baume" or s.type == "leurre" or (s.type == "consume" and s.element == "venin"):
			ex.valeur += s.valeur
		else:
			ex.valeur = maxf(ex.valeur, s.valeur)
		ex.tours = maxi(ex.tours, s.tours)
		ex._puissance = maxf(ex._puissance, s._puissance)
		ex._indissipable = ex._indissipable or s._indissipable
		ex._nouveau = ex._nouveau or s._nouveau
		return
	t.statuts.append(s)


# --- Clones --------------------------------------------------------------------

func _creer_clone(f: Dictionary, tours: int, force: float) -> bool:
	if vivants(f.camp).size() >= RANGS_MAX:
		return false
	var base: String = f.id
	while base.length() > 0 and base[base.length() - 1] in "0123456789":
		base = base.substr(0, base.length() - 1)
	var n := 2
	for o in combattants:
		var reste: String = str(o.id).trim_prefix(base)
		if str(o.id).begins_with(base) and reste.is_valid_int() and int(reste) >= n:
			n = int(reste) + 1
	var cl := {
		"id": "%s%d" % [base, n], "nom": f.nom, "camp": f.camp, "rang": vivants(f.camp).size() + 1, "joueur": false,
		"apparence": f.apparence, "niveau": f.niveau, "fangan": int(float(f.fangan) * force), "gnanga": f.gnanga,
		"manhis": f.manhis, "pv": f.pv, "pv_max": f.pv_max, "souffle": f.souffle, "souffle_max": f.souffle_max,
		"element": f.element, "elements": f.elements.duplicate(), "defense": f.defense, "defense_mag": f.get("defense_mag", 0),
		"arme": {"nom": f.arme.nom, "puissance": int(float(f.arme.puissance) * force), "distance": f.arme.distance},
		"absorption": 0, "garde": false, "statuts": [], "incantation": null, "clone": true,
		"_original": f.id, "_tours_clone": tours, "_ia": "clone", "_maitrise": {}, "_jutsus": [],
	}
	combattants.append(cl)
	_placer(cl, 1 + rng.randi_range(0, vivants(f.camp).size() - 1))
	return true


func _dissiper_clone(t: Dictionary, texte: String) -> void:
	t.pv = 0
	t.statuts = []
	t.incantation = null
	if texte != "":
		_emit("clone_dissipe", texte, "", t.id)
	_compacter(t.camp)


func _verifier_fin() -> void:
	if fini:
		return
	var a := reels(0).size()
	var b := reels(1).size()
	if b == 0:
		fini = true
		vainqueur = 0
	elif a == 0:
		fini = true
		vainqueur = 1
	elif tour >= int(Regles.c.tour_max):
		fini = true
		vainqueur = 2
	if fini:
		for f in combattants:
			if f.clone and vivant(f):
				_dissiper_clone(f, "")
		var textes := {0: "Victoire !", 1: "Défaite…", 2: "Match nul : les deux camps sont épuisés."}
		_emit("fin", textes[vainqueur], "", "", vainqueur)


func _fin_de_tour() -> void:
	var reste := []
	var dus := []
	for d in _differes:
		d.tours -= 1
		if d.tours > 0:
			reste.append(d)
		else:
			dus.append(d)
	_differes = reste
	for d in dus:
		var l: Dictionary = d.cx.lanceur
		if not vivant(l) or fini:
			continue
		if d.jutsu != null:
			_emit("differe", "Le " + d.jutsu.nom + " de " + l.nom + " se libère !", l.id, "", 0, d.jutsu.element, d.jutsu.nom)
			_lancer(l, d.jutsu, d.cx.cible_id, d.facteur, true)
		else:
			_emit("differe", "Le Souffle différé de " + l.nom + " se libère.", l.id, "", 0, d.cx.element)
			_appliquer(d.cx, d.effets)
		_verifier_fin()

	for f in combattants.duplicate():
		if not vivant(f) or fini:
			continue
		for s in f.statuts.duplicate():
			if s.tours <= 0 or not vivant(f):
				continue
			match s.type:
				"consume":
					_emit("consume", f.nom + " se consume.", "", f.id, 0, s.element)
					_infliger(null, f, float(s.valeur), s._nature, s.element, true)
				"sangsue":
					var src = get_c(s._source)
					var d := _infliger(src, f, float(s.valeur), "magique", s.element, true)
					if src != null and d > 0:
						_soigner(src, src, float(d))
				"regen":
					_soigner(f, f, float(s.valeur))
				"invocation":
					_emit("invocation", "La créature de Souffle de " + f.nom + " agit.", f.id, "", 0, s.element)
					_appliquer(_contexte_charge(f, s, null), s._effets)
			if s._nouveau:
				s._nouveau = false
				continue
			s.tours -= 1
		f.statuts = f.statuts.filter(func(s): return s.tours > 0)
		if f.clone and vivant(f):
			f._tours_clone -= 1
			if f._tours_clone <= 0:
				_dissiper_clone(f, "Un clone de " + f.nom + " se dissipe.")
				continue
		if vivant(f):
			f.souffle = mini(f.souffle_max, f.souffle + 3 + int(f.gnanga) / 4)
		_verifier_fin()


func _declencher_piege(f: Dictionary, s: Dictionary) -> bool:
	s.tours = 0
	var src = get_c(s._source)
	if not vivant(src):
		return false
	_emit("piege", f.nom + " déclenche un piège !", src.id, f.id, 0, s.element)
	var cx := _contexte_charge(src, s, f)
	cx.annule = [false]
	_appliquer(cx, s._effets)
	if cx.annule[0]:
		_info(f, "L'action de " + f.nom + " est annulée.")
	return cx.annule[0]


# --- Jutsus --------------------------------------------------------------------

func _incanter(f: Dictionary, a: Dictionary) -> void:
	var seq: Array = a.get("sequence", [])
	if seq.is_empty():
		if f.incantation == null:
			f.garde = true
			_emit("garde", f.nom + " se met en garde.", f.id)
			return
		if a.get("cible", "") != "":
			f.incantation.cible = a.cible
	else:
		seq = seq.duplicate()
		var res := Grammaire.analyser(seq)
		var j = res.jutsu
		var refus := ""
		if j != null and j.legendaire != "" and f.has("_contexte"):
			refus = Grammaire.verifier(j.conditions, int(f._contexte.niveau), f._contexte.elements, moment.call())
		if j != null and j.fusion and j.legendaire == "" and int(f.niveau) < int(Regles.c.niveau_fusion):
			refus = "Deux éléments veulent se fondre… mais il faut le niveau %d pour les fusionner." % int(Regles.c.niveau_fusion)
		var cout := 3 * seq.size()
		if j != null and refus == "":
			cout = cout_reel(j, maitrise_de(f, j))
		if f.souffle < cout:
			_info(f, "%s manque de Souffle (%d requis)." % [f.nom, cout])
			f.garde = not a_statut(f, "sans_garde")
			return
		f.souffle -= cout
		f.incantation = {"sequence": seq, "jutsu": j if refus == "" else null, "echec": res.echec, "refus": refus,
			"cible": a.get("cible", ""), "progres": 0, "total": seq.size(), "silence": j != null and j.incassable}
	var inc: Dictionary = f.incantation
	inc.progres = mini(inc.total, inc.progres + mudras_par_tour(f))
	if inc.progres < inc.total:
		_emit("incantation", "%s forme des mudras (%d/%d)." % [f.nom, inc.progres, inc.total], f.id, "", inc.progres)
		return
	f.incantation = null
	_liberer(f, inc)


func _liberer(f: Dictionary, inc: Dictionary) -> void:
	if inc.refus != "":
		_emit("echec", inc.refus, f.id)
		return
	if inc.jutsu == null:
		var r := Grammaire.resonner(inc.sequence, inc.echec, f.get("_precis", false))
		if f.joueur:
			resonances.append(r)
		_emit("echec", f.nom + " : " + r.message, f.id, "", r.score)
		if r.retour_de_souffle:
			_emit("retour", "Retour de Souffle !", f.id, f.id)
			_infliger(null, f, float(4 + 2 * inc.sequence.size()), "pur", "", true)
		return
	var j: Dictionary = inc.jutsu
	if f.joueur:
		if not f._maitrise.has(j.cle):
			f._maitrise[j.cle] = int(Regles.c.maitrise_decouverte)
			decouvertes.append({"joueur": f.id, "jutsu": j})
			var texte: String = "Nouveau jutsu découvert : " + j.nom + " !"
			if j.legendaire != "":
				texte = "JUTSU LÉGENDAIRE DÉCOUVERT : " + j.nom + " !"
			_emit("decouverte", texte, f.id, "", 0, j.element, j.nom)
		usages[j.cle] = usages.get(j.cle, 0) + 1
	if j.delai:
		_emit("jutsu", f.nom + " accumule le Souffle de " + j.nom + " : il partira au prochain tour.", f.id, "", 0, j.element, j.nom)
		_differes.append({"jutsu": j, "effets": [], "cx": {"lanceur": f, "cible_id": inc.cible, "element": j.element}, "facteur": 1.0, "tours": 1})
		return
	_lancer(f, j, inc.cible, 1.0, false)


func puissance(f: Dictionary, j: Dictionary, facteur: float) -> float:
	var p := puissance_de(f, j, maitrise_de(f, j), Regles.facteur_cosmique(j.element, moment.call())) * facteur
	if j.element == "vegetal" or j.element == "bois_sacre":
		p *= 1.0 + 0.05 * minf(float(tour), 10.0)
	return p


func _lancer(f: Dictionary, j: Dictionary, cible_id: String, facteur: float, echo: bool) -> void:
	var p := puissance(f, j, facteur)
	if not echo:
		_emit("jutsu", "%s lance %s (puissance %d) !" % [f.nom, j.nom, int(round(p))], f.id, "", int(round(p)), j.element, j.nom)
		if float(j.echo) > 0:
			_differes.append({"jutsu": j, "effets": [], "cx": {"lanceur": f, "cible_id": cible_id, "element": j.element}, "facteur": float(j.echo), "tours": 1})
	if j.element in ["brume", "vapeur", "songe"]:
		_ajouter_statut(f, {"type": "esquive", "tours": 1, "valeur": 0.3, "element": j.element, "_puissance": p})
	var cx := {"lanceur": f, "p": p, "element": j.element, "maitrise": maitrise_de(f, j), "indissipable": j.indissipable,
		"cible_id": cible_id, "autre": null, "passif": true, "annule": null}
	_appliquer(cx, j.effets)


func _contexte_charge(src: Dictionary, s: Dictionary, autre) -> Dictionary:
	return {"lanceur": src, "p": float(s._puissance), "element": s.get("element", ""), "maitrise": 50,
		"indissipable": s._indissipable, "cible_id": "", "autre": autre, "passif": false, "annule": null}


static func _part(e: Dictionary, defaut: float) -> float:
	return float(e.part) if float(e.part) > 0 else defaut


## Cibles d'un effet : [{t, part, unique}].
func _resoudre(cx: Dictionary, e: Dictionary) -> Array:
	var l: Dictionary = cx.lanceur
	match e.cible:
		"soi":
			return [{"t": l, "part": 1.0, "unique": false}]
		"allies":
			var out := []
			for a in reels(l.camp):
				out.append({"t": a, "part": 1.0 if a == l else _part(e, 1.0), "unique": false})
			return out
		"ennemi", "ennemi_etendu", "contact", "contact_etendu":
			var contact: bool = e.cible == "contact" or e.cible == "contact_etendu"
			if contact and l.rang > 2:
				_info(l, "Trop loin : " + l.nom + " doit être au rang 1 ou 2 pour toucher au contact.")
				return []
			var t = _cible_ennemie(l, cx.cible_id, contact)
			if t == null:
				_info(l, "Aucune cible à portée.")
				return []
			var out := [{"t": t, "part": 1.0, "unique": true}]
			if e.cible == "ennemi_etendu" or e.cible == "contact_etendu":
				for o in ennemis(l):
					if o != t and ciblable(o) and (o.rang == t.rang + 1 or o.rang == t.rang - 1):
						out.append({"t": o, "part": _part(e, 0.7), "unique": true})
						break
			return out
		"ennemis":
			var out := []
			for t in ennemis(l):
				if not a_statut(t, "disparu"):
					out.append({"t": t, "part": 1.0, "unique": false})
			return out
		"front":
			for t in ennemis(l):
				if ciblable(t):
					return [{"t": t, "part": 1.0, "unique": true}]
		"aleatoire":
			var l2 := ennemis(l).filter(func(t): return ciblable(t))
			if l2.size() > 0:
				return [{"t": _hasard(l2), "part": 1.0, "unique": true}]
		"attaquant", "declencheur":
			if cx.autre != null and vivant(cx.autre):
				return [{"t": cx.autre, "part": 1.0, "unique": false}]
	return []


func _appliquer(cx: Dictionary, effets: Array) -> void:
	cx = cx.duplicate()
	for e in effets:
		if not vivant(cx.lanceur) or fini:
			return
		_effet(cx, e)


func _effet(cx: Dictionary, e: Dictionary) -> void:
	var l: Dictionary = cx.lanceur
	match e.op:
		"bond":
			if a_statut(l, "immobilise"):
				_info(l, l.nom + " est immobilisé et ne peut pas bondir.")
				return
			_placer(l, 1 if e.vers == "avant" else vivants(l.camp).size())
			_emit("deplacement", "%s bondit au rang %d." % [l.nom, l.rang], l.id, "", l.rang)
			return
		"clone":
			for i in maxi(1, int(e.nombre)):
				if not _creer_clone(l, int(e.duree), float(e.valeur)):
					_info(l, "Plus de place dans les rangs : le clone ne peut pas naître.")
					break
				_emit("clone", l.nom + " se dédouble !", l.id, "", 0, cx.element)
			return
		"soin":
			for i in maxi(1, int(e.frappes)):
				_soigner(l, l, cx.p * float(e.mult))
			return
		"purifier":
			_purifier(l)
			return
		"invocation":
			_ajouter_statut(l, {"type": "invocation", "tours": int(e.duree), "element": cx.element, "_source": l.id,
				"_puissance": cx.p, "_indissipable": cx.indissipable, "_effets": e.effets})
			_emit("invoque", l.nom + " invoque une créature de Souffle.", l.id, "", 0, cx.element)
			return
		"declencheur":
			_ajouter_statut(l, {"type": "declencheur", "tours": int(e.duree), "valeur": float(e.valeur), "element": cx.element,
				"_source": l.id, "_puissance": cx.p, "_indissipable": cx.indissipable, "_effets": e.effets})
			_emit("statut", "Le Souffle de " + l.nom + " veille sur ses blessures.", "", l.id)
			return
		"differe":
			var cp := cx.duplicate()
			cp.passif = false
			_differes.append({"jutsu": null, "effets": e.effets, "cx": cp, "facteur": 1.0, "tours": int(e.duree)})
			return
		"annuler":
			if cx.annule != null:
				cx.annule[0] = true
			return
	var cibles := _resoudre(cx, e)
	for ce in cibles:
		_effet_sur(cx, e, ce)
	if float(e.propage) > 0 and cibles.size() > 0 and cibles[0].t.camp != l.camp:
		var autres := []
		for o in ennemis(l):
			var deja := false
			for ce in cibles:
				deja = deja or ce.t == o
			if not deja and ciblable(o):
				autres.append(o)
		if autres.size() > 0:
			var o: Dictionary = _hasard(autres)
			_emit("info", "Le Souffle se propage à " + o.nom + ".", l.id, o.id)
			_effet_sur(cx, e, {"t": o, "part": float(e.propage), "unique": true})


func _reussite(cx: Dictionary, t: Dictionary, bonus: float, part: float) -> bool:
	var r := (8.0 + 0.8 * float(t.gnanga) + 0.4 * float(t.manhis)) * 1.1
	var p: float = 0.55 + 0.35 * (cx.p - r) / (cx.p + r) + bonus + 0.1 * float(cx.maitrise) / 100.0
	if cx.indissipable:
		p += 0.05
	p *= 0.5 + 0.5 * part
	return _chance(clampf(p, 0.15, 0.95))


func _effet_sur(cx: Dictionary, e: Dictionary, ce: Dictionary) -> void:
	var l: Dictionary = cx.lanceur
	var t = ce.t
	var k: float = ce.part
	var hostile: bool = t.camp != l.camp
	var frappe: bool = e.op == "degats" or e.op == "drain"
	if hostile and ce.unique and not frappe:
		t = _atteindre(l, t, true)
		if t == null:
			return
		hostile = t.camp != l.camp
	match e.op:
		"degats", "drain":
			for i in maxi(1, int(e.frappes)):
				if not vivant(l):
					break
				var tt = t
				if hostile and ce.unique:
					tt = _atteindre(l, t, true)
					if tt == null:
						continue
				if not vivant(tt):
					break
				var d := _infliger(l, tt, cx.p * float(e.mult) * k, e.nature, cx.element, false)
				if e.op == "drain" and d > 0:
					_soigner(l, l, float(d) * float(e.valeur))
				if cx.passif and vivant(tt) and tt.camp != l.camp:
					cx.passif = false
					_passif_element(cx, tt, cx.p * float(e.mult), d)
				if ce.unique and tt.camp != l.camp:
					_riposter(tt, l)
		"dot":
			_ajouter_statut(t, {"type": "consume", "tours": int(e.duree), "valeur": cx.p * float(e.mult) * k, "element": cx.element,
				"_nature": e.nature, "_source": l.id, "_puissance": cx.p, "_indissipable": cx.indissipable})
			_emit("statut", t.nom + " se consume.", "", t.id, 0, cx.element)
		"statut":
			_poser_statut(cx, e, t, k, hostile)
		"bouclier":
			var v := int(round(cx.p * float(e.mult) * k))
			t.absorption += v
			_emit("bouclier", "Un bouclier de Souffle couvre %s (%d)." % [t.nom, v], l.id, t.id, v, cx.element)
		"deplacer":
			if hostile and not _reussite(cx, t, float(e.valeur), k):
				_emit("resiste", t.nom + " tient bon et ne bouge pas.", "", t.id)
				return
			_placer(t, 1 if e.vers == "avant" else vivants(t.camp).size())
			_emit("deplacement", "%s est projeté au rang %d." % [t.nom, t.rang], t.id, "", t.rang)
		"dissiper":
			_dissiper(cx, t)
		"interrompre":
			_interrompre(t, "par le Souffle de " + l.nom)
		"piege":
			_ajouter_statut(t, {"type": "piege", "tours": int(e.duree), "element": cx.element, "_source": l.id,
				"_puissance": cx.p * k, "_indissipable": cx.indissipable, "_effets": e.effets})
			_emit("piege_pose", l.nom + " tend un piège sous les pieds de " + t.nom + ".", l.id, t.id, 0, cx.element)
		"riposte":
			_ajouter_statut(t, {"type": "riposte", "tours": int(e.duree), "element": cx.element, "_source": l.id,
				"_puissance": cx.p * k, "_indissipable": cx.indissipable, "_effets": e.effets, "_nouveau": true})
			_emit("statut", "Le Souffle de " + l.nom + " veille sur " + t.nom + " : qui l'attaque le paiera.", l.id, t.id, 0, cx.element)


func _poser_statut(cx: Dictionary, e: Dictionary, t: Dictionary, k: float, hostile: bool) -> void:
	var l: Dictionary = cx.lanceur
	var typ: String = e.statut
	if typ == "hasard":
		typ = _hasard(ENTRAVES_AU_HASARD)
	if hostile and Regles.g.statuts_controle.has(e.statut):
		var bonus: float = 0.0 if typ in ["confus", "aveugle"] else float(e.valeur)
		if not _reussite(cx, t, bonus, k):
			_emit("resiste", t.nom + " résiste au Souffle de " + l.nom + ".", "", t.id)
			return
	var val: float = float(e.valeur) * k
	match typ:
		"regen", "sangsue", "baume", "second_souffle":
			val = cx.p * float(e.valeur) * k
		"leurre":
			val = float(e.valeur)
	var tours: int = int(e.duree) if int(e.duree) > 0 else 99
	_ajouter_statut(t, {"type": typ, "tours": tours, "valeur": val, "element": cx.element, "_source": l.id,
		"_puissance": cx.p, "_indissipable": cx.indissipable, "_nouveau": true})
	var texte: String = TEXTES_POSES.get(typ, "")
	if texte == "":
		texte = str(Regles.g.textes_statut[typ]).replace("{v}", str(int(round(val * 100.0)))).replace("{n}", str(int(round(val))))
	_emit("statut", t.nom + " : " + texte + ".", l.id, t.id, 0, cx.element)
	if typ == "scelle" or typ == "endormi":
		_interrompre(t, "net")


func _dissiper(cx: Dictionary, t: Dictionary) -> void:
	var bienfaits: Dictionary = Regles.d.statuts.bienfaits
	var reste := []
	var retire := 0
	var tenu := 0
	for s in t.statuts:
		if bienfaits.has(s.type) and s.tours > 0:
			if s._indissipable or float(s._puissance) > cx.p * 1.25:
				tenu += 1
			else:
				retire += 1
				continue
		reste.append(s)
	t.statuts = reste
	if t.absorption > 0:
		t.absorption = 0
		retire += 1
	for o in combattants:
		if o.clone and o.get("_original", "") == t.id and vivant(o):
			_dissiper_clone(o, "Le clone de " + t.nom + " se dissipe.")
			retire += 1
	if retire > 0:
		_emit("purification", "Les protections de %s se dissipent (%d)." % [t.nom, retire], "", t.id)
	if tenu > 0:
		_emit("resiste", "Certaines protections de " + t.nom + " résistent.", "", t.id)


func _purifier(t: Dictionary) -> void:
	var maux: Dictionary = Regles.d.statuts.maux
	var avant: int = t.statuts.size()
	t.statuts = t.statuts.filter(func(s): return not (maux.has(s.type) and not s._indissipable))
	var retire: int = avant - t.statuts.size()
	if retire > 0:
		_emit("purification", "%s se purifie (%d maux effacés)." % [t.nom, retire], "", t.id)


func _passif_element(cx: Dictionary, t: Dictionary, base: float, d: int) -> void:
	var l: Dictionary = cx.lanceur
	match cx.element:
		"feu", "lave", "cendre":
			_ajouter_statut(t, {"type": "consume", "tours": 2, "valeur": base * 0.12, "element": cx.element, "_nature": "magique", "_source": l.id, "_puissance": cx.p})
		"eau", "maree":
			if d > 0:
				_soigner(l, l, float(d) * 0.1)
		"son", "onde":
			_interrompre(t, "par une onde sonore")
		"gravite", "seisme":
			if t.rang > 1:
				_placer(t, 1)
				_emit("deplacement", t.nom + " est attiré au premier rang !", t.id, "", 1)
		"sel", "cristal":
			_dissiper(cx, t)
		"sable", "harmattan":
			if _chance(0.25):
				_ajouter_statut(t, {"type": "aveugle", "tours": 1, "valeur": 0.4, "element": cx.element, "_source": l.id, "_puissance": cx.p, "_nouveau": true})
				_emit("statut", t.nom + " a du sable dans les yeux.", "", t.id, 0, cx.element)
		"foudre", "tempete", "magnetisme":
			if _chance(0.2):
				_ajouter_statut(t, {"type": "immobilise", "tours": 1, "element": cx.element, "_source": l.id, "_puissance": cx.p, "_nouveau": true})
				_emit("statut", t.nom + " est paralysé.", "", t.id, 0, cx.element)
		"essaim", "fleau":
			if vivant(t):
				_infliger(l, t, base * 0.15, "pur", cx.element, true)


# --- IA ------------------------------------------------------------------------

func _choisir_ia(f: Dictionary) -> Dictionary:
	if f.incantation != null and not a_statut(f, "scelle"):
		return {"acteur": f.id, "type": "incanter"}
	var opts := []
	var ajouter := func(a: Dictionary, s: float) -> void:
		a.acteur = f.id
		opts.append([a, s * (0.9 + rng.randf() * 0.2)])
	var ens := ennemis(f)
	var menace := _menace(ens)
	var ia: String = f.get("_ia", "")

	if not a_statut(f, "desarme") and (f.arme.distance or f.rang <= 2):
		for t in ens:
			if not ciblable(t) or (not f.arme.distance and t.rang > 2):
				continue
			var est := float(f.arme.puissance + f.fangan) * facteur_defense(t, "physique")
			ajouter.call({"type": "frapper", "cible": t.id}, _valeur_degats(t, est, 1.0))

	if ia == "ninja" and not a_statut(f, "scelle"):
		var mpt := mudras_par_tour(f)
		for j in f.get("_jutsus", []):
			if cout_reel(j, maitrise_de(f, j)) > f.souffle:
				continue
			var tours := float((j.sequence.size() + mpt - 1) / mpt)
			var p := puissance(f, j, 1.0)
			var cibles := [null]
			if not j.soutien:
				cibles = ens.filter(func(t): return ciblable(t))
			for t in cibles:
				var v := 0.0
				for e in j.effets:
					v += _valeur_effet(f, e, t, p, tours)
				if j.delai:
					v *= 0.8
				ajouter.call({"type": "incanter", "sequence": j.sequence, "cible": t.id if t != null else ""}, v / tours)

	var garde := 2.0
	if f.pv * 10 < f.pv_max * 3 and menace > 0:
		garde = 10.0 + menace
	if not a_statut(f, "sans_garde"):
		ajouter.call({"type": "garde"}, garde)
	if ia == "ninja" and f.souffle * 3 < f.souffle_max:
		ajouter.call({"type": "concentrer"}, 6.0)
	if not f.arme.distance and f.rang > 2 and not a_statut(f, "immobilise"):
		ajouter.call({"type": "deplacer", "rang": 1}, 8.0)
	if opts.is_empty():
		return {"acteur": f.id, "type": "garde"}
	var best = opts[0]
	for o in opts:
		if o[1] > best[1]:
			best = o
	return best[0]


func _valeur_degats(t: Dictionary, est: float, tours: float) -> float:
	var v := est
	if float(t.pv) <= est:
		v *= 2.0
	var inc = t.incantation
	if inc != null and not inc.silence and est * 100.0 >= float(t.pv_max * 12) and tours <= 1:
		v += 10.0 * float(inc.total)
	return v


func _menace(ens: Array) -> float:
	var m := 0.0
	for e in ens:
		if e.incantation != null:
			m += 4.0 * float(e.incantation.total)
	return m


func _valeur_effet(f: Dictionary, e: Dictionary, t, p: float, tours: float) -> float:
	var ens := ennemis(f)
	var nb := 1.0
	match e.cible:
		"ennemis":
			nb = float(ens.size())
		"ennemi_etendu", "contact_etendu":
			nb = 1.5
		"allies":
			nb = float(reels(f.camp).size())
	if t == null and ens.size() > 0:
		t = ens[0]
	if (e.cible == "contact" or e.cible == "contact_etendu") and (f.rang > 2 or (t != null and t.rang > 2)):
		return 0.0
	var danger := 2.0 if f.pv * 2 < f.pv_max else 1.0
	var manque := float(f.pv_max - f.pv)
	match e.op:
		"degats", "drain":
			if t == null:
				return 0.0
			var est := p * float(e.mult) * float(maxi(1, int(e.frappes))) * facteur_defense(t, e.nature)
			if e.nature != "pur":
				est *= Regles.multiplicateur(f.element, t.element)
			var v := _valeur_degats(t, est, tours) * nb
			if e.op == "drain":
				v += minf(est * float(e.valeur), manque) * danger * 0.6
			return v
		"dot":
			return p * float(e.mult) * float(e.duree) * 0.7 * nb
		"soin":
			if f.pv * 10 > f.pv_max * 7:
				return 0.0
			return minf(p * float(e.mult), manque) * danger
		"bouclier":
			if f.absorption > 0:
				return 0.0
			return p * float(e.mult) * 0.5 * nb * danger
		"statut":
			return _valeur_statut(f, e, t, p) * nb
		"deplacer":
			return 4.0
		"bond":
			return 1.0
		"clone":
			return 10.0 * float(maxi(1, int(e.nombre))) * danger
		"dissiper":
			if t == null:
				return 0.0
			var n := 0
			for s in t.statuts:
				if Regles.d.statuts.bienfaits.has(s.type):
					n += 1
			return 8.0 * n
		"purifier":
			var n := 0
			for s in f.statuts:
				if Regles.d.statuts.maux.has(s.type):
					n += 1
			return 8.0 * n
		"interrompre":
			if t != null and t.incantation != null and not t.incantation.silence:
				return 10.0 + 5.0 * float(t.incantation.total)
			return 0.0
		"riposte", "piege", "invocation", "declencheur", "differe":
			var v := 0.0
			for x in e.effets:
				v += _valeur_effet(f, x, t, p, tours)
			match e.op:
				"invocation":
					v *= float(e.duree) * 0.8
				"riposte":
					v *= 1.2
				"piege":
					v *= 0.8
				"declencheur":
					v *= 0.6
				_:
					v *= 0.9
			return v
	return 0.0


func _valeur_statut(f: Dictionary, e: Dictionary, t, p: float) -> float:
	var d := float(maxi(1, int(e.duree)))
	var danger := 2.0 if f.pv * 2 < f.pv_max else 1.0
	var sur = f if e.cible == "soi" or e.cible == "allies" else t
	if sur == null or a_statut(sur, e.statut):
		return 0.0
	var chance := 0.6 if Regles.g.statuts_controle.has(e.statut) else 1.0
	var v: float = float(e.valeur)
	match e.statut:
		"def_phys", "def_mag":
			return 6.0 * v * d * danger * 3.0
		"renvoi":
			return 8.0 * v * d
		"parade", "reflet", "deviation":
			return 9.0 * danger
		"esquive":
			return 12.0 * v * d * danger
		"intangible_phys", "intangible_mag", "invisible":
			return 7.0 * d * danger
		"disparu":
			return 5.0 * danger * danger
		"leurre":
			return 6.0 * v * danger
		"regen":
			return minf(p * v * d, float(f.pv_max - f.pv)) * 0.8
		"baume":
			return p * v * 0.15
		"second_souffle":
			return 6.0 * danger * danger
		"marque":
			return p * v * d * 0.8
		"sangsue":
			return p * v * d
		"scelle":
			var x := 6.0 * d
			if sur.incantation != null:
				x += 5.0 * float(sur.incantation.total)
			return x * chance
		"desarme":
			return 7.0 * d * chance
		"endormi":
			return 10.0 * d * chance
		"confus", "aveugle":
			return 14.0 * v * d * chance
		"egare":
			return 5.0 * d * chance
		"immobilise", "sans_garde", "hasard":
			return 4.0 * d * chance
		"retenu":
			return 1.0
	return 0.0
