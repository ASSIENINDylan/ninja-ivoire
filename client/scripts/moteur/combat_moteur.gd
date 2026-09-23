class_name CombatMoteur
extends RefCounted
## Combat au tour par tour simultané (copie fidèle de server/internal/combat).
## Les combattants sont des dictionnaires au format de l'API ; les clés qui
## commencent par « _ » sont privées et ne sont jamais montrées à l'écran.

const ERR_FINI := "le combat est terminé"
const ERR_ACTEUR := "combattant inconnu ou hors de combat"
const ERR_MUDRA := "vous ne savez pas encore former ce mudra"
const ERR_SEQUENCE := "suite de mudras trop longue"
const ERR_ACTION := "action inconnue"
const NB_RANGS := 3

var id := ""
var tour := 0
var combattants: Array = []
var murs: Array = [null, null]
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


func _compacter(camp: int) -> void:
	var i := 1
	for f in vivants(camp):
		f.rang = i
		i += 1


func _emit(type: String, texte: String, acteur: String = "", cible: String = "", valeur: int = 0, element: String = "", jutsu: String = "") -> void:
	_evts.append({"type": type, "acteur": acteur, "cible": cible, "valeur": valeur, "element": element, "jutsu": jutsu, "texte": texte})


static func statut(f: Dictionary, type: String):
	for s in f.statuts:
		if s.type == type and s.tours > 0:
			return s
	return null


func _chance(pct: float) -> bool:
	return rng.randf() * 100.0 < pct


static func mudras_par_tour(f: Dictionary) -> int:
	return 3 + int(f.gnanga) / 15


static func cout_reel(j: Dictionary, maitrise: int) -> int:
	return int(round(float(j.cout) * (1.0 - 0.3 * float(maitrise) / 100.0)))


static func maitrise_de(f: Dictionary, j: Dictionary) -> int:
	if f._maitrise.has(j.cle):
		return int(f._maitrise[j.cle])
	return int(Regles.c.maitrise_decouverte) if f.joueur else int(Regles.c.maitrise_pnj)


## Vue d'un camp : sans données privées, sans les mudras des adversaires.
func vue(camp: int) -> Dictionary:
	var liste := []
	for f in combattants:
		var cp := {}
		for k in f:
			if not str(k).begins_with("_"):
				cp[k] = f[k]
		cp.arme = f.arme.duplicate()
		cp.elements = f.elements.duplicate()
		var st := []
		for s in f.statuts:
			st.append({"type": s.type, "tours": s.tours, "valeur": s.valeur, "element": s.get("element", "")})
		cp.statuts = st
		if f.incantation != null:
			var inc: Dictionary = f.incantation
			cp.incantation = {"progres": inc.progres, "total": inc.total, "silence": inc.silence}
			if f.camp == camp:
				cp.incantation.sequence = inc.sequence.duplicate()
				cp.incantation.cible = inc.cible
		liste.append(cp)
	var m := []
	for x in murs:
		m.append(null if x == null else {"absorption": x.absorption, "tours": x.tours, "element": x.element})
	return {"id": id, "tour": tour, "combattants": liste, "murs": m, "fini": fini, "vainqueur": vainqueur}


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
		if statut(f, "entrave") != null:
			s *= 0.5
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
	var p = statut(f, "piege")
	if p != null and type in ["frapper", "incanter", "deplacer"]:
		_declencher_piege(f, p)
		if not vivant(f):
			return
	match type:
		"garde":
			f.garde = true
			_emit("garde", f.nom + " se met en garde.", f.id)
		"concentrer":
			var gain: int = int(f.souffle_max) * 15 / 100 + int(f.gnanga)
			f.souffle = mini(f.souffle_max, f.souffle + gain)
			_emit("concentration", "%s se concentre et rassemble son Souffle (+%d)." % [f.nom, gain], f.id, "", gain)
		"deplacer":
			if statut(f, "entrave") != null:
				_emit("info", f.nom + " est entravé et ne peut pas bouger.", f.id)
				return
			_placer(f, int(a.get("rang", 0)))
			_emit("deplacement", "%s passe au rang %d." % [f.nom, f.rang], f.id, "", f.rang)
		"frapper":
			_frapper(f, a.get("cible", ""))
		"incanter":
			_incanter(f, a)


func _placer(f: Dictionary, rang: int) -> void:
	var v := vivants(f.camp)
	rang = clampi(rang, 1, v.size())
	for o in v:
		if o.rang == rang and o != f:
			o.rang = f.rang
	f.rang = rang


func ennemis(f: Dictionary) -> Array:
	return vivants(1 - int(f.camp))


func _cible_ennemie(f: Dictionary, ident: String, contact: bool):
	var t = get_c(ident)
	if t != null and vivant(t) and t.camp != f.camp and (not contact or t.rang <= 2):
		return t
	for e in ennemis(f):
		if not contact or e.rang <= 2:
			return e
	return null


static func esquive(t: Dictionary) -> float:
	var e := minf(35.0, float(t.manhis) * 0.8)
	if statut(t, "voile") != null:
		e += 50
	if statut(t, "entrave") != null:
		e /= 2
	return e


func _frapper(f: Dictionary, cible_id: String) -> void:
	var contact: bool = not f.arme.distance
	if contact and statut(f, "entrave") != null:
		_emit("info", f.nom + " est entravé et ne peut pas frapper au contact.", f.id)
		return
	if contact and f.rang > 2:
		_emit("info", f.nom + " est trop loin pour frapper au contact.", f.id)
		return
	var t = _cible_ennemie(f, cible_id, contact)
	if t == null:
		_emit("info", f.nom + " ne trouve aucune cible à portée.", f.id)
		return
	var av = statut(f, "aveugle")
	if av != null and _chance(av.valeur * 100.0):
		_emit("rate", f.nom + ", aveuglé, frappe dans le vide.", f.id, t.id)
		return
	if _intercepter(f, t):
		return
	if _chance(esquive(t)):
		_emit("esquive", t.nom + " esquive le coup de " + f.nom + ".", f.id, t.id)
		return
	var brut := float(f.arme.puissance + f.fangan) * (0.85 + rng.randf() * 0.3)
	var crit := _chance(float(f.manhis) * 0.7)
	if crit:
		brut *= 1.5
	var rf = statut(f, "renfort")
	if rf != null:
		brut *= 1.0 + rf.valeur
	var texte: String = f.nom + " frappe " + t.nom
	if crit:
		texte += " (coup critique)"
	_emit("frappe", texte + " avec " + f.arme.nom + ".", f.id, t.id)
	_infliger(f, t, brut, "", false)
	if contact:
		_riposter(t, f)


func _intercepter(f: Dictionary, t: Dictionary) -> bool:
	var s = statut(t, "leurre")
	if s == null:
		return false
	s.tours = 0
	_emit("leurre", "Le double de " + t.nom + " encaisse l'attaque et se dissipe !", f.id, t.id)
	if s.get("_effet", "") != "" and vivant(f):
		_appliquer_effet(t, f, s._effet, s.valeur, s._base, 0, _opts({"element": s.element}))
	return true


func _riposter(t: Dictionary, attaquant: Dictionary) -> void:
	if not vivant(attaquant):
		return
	var s = statut(t, "riposte")
	if s != null:
		_emit("riposte", "L'armure de " + t.nom + " riposte !", t.id, attaquant.id, 0, s.element)
		_infliger(t, attaquant, s._base * 0.4, s.element, true)
		if vivant(attaquant):
			_appliquer_effet(t, attaquant, s._effet, s.valeur, s._base, 0, _opts({"element": s.element}))
	var m = murs[t.camp]
	if m != null and m._riposte != "" and vivant(attaquant):
		var lanceur = get_c(m._lanceur)
		if lanceur == null:
			lanceur = t
		_emit("riposte", "Le mur riposte contre " + attaquant.nom + " !", lanceur.id, attaquant.id, 0, m.element)
		_appliquer_effet(lanceur, attaquant, m._riposte, m._intensite, m._base, 0, _opts({"element": m.element}))


## Dégâts après défense, garde et absorptions. `direct` : ignore tout cela.
func _infliger(src, t: Dictionary, brut: float, element: String, direct: bool) -> int:
	if not vivant(t):
		return 0
	var dmg := brut
	if not direct:
		if element != "":
			dmg *= Regles.multiplicateur(element, t.element)
		var mq = statut(t, "marque")
		if mq != null:
			dmg *= 1.0 + mq.valeur
		var def := float(t.defense) + float(t.fangan) * 0.5
		if statut(t, "affaibli") != null:
			def *= 0.5
		if element != "":
			def *= 0.5
			if element == "metal" or element == "foudre":
				def *= 0.5
		dmg *= 40.0 / (40.0 + def)
		if t.garde:
			dmg *= 0.5
	var d := int(round(dmg))
	if d < 1:
		d = 1
	if not direct and t.absorption > 0:
		var a := mini(t.absorption, d)
		t.absorption -= a
		d -= a
		_emit("absorption", "L'armure de Souffle de %s absorbe %d." % [t.nom, a], "", t.id, a)
	var m = murs[t.camp]
	if not direct and m != null and d > 0:
		var a := mini(m.absorption, d)
		m.absorption -= a
		d -= a
		_emit("absorption", "Le mur absorbe %d." % a, "", t.id, a)
		if m.absorption <= 0:
			murs[t.camp] = null
			_emit("mur_brise", "Le mur s'effondre !", "", t.id)
	if d <= 0:
		return 0
	t.pv -= d
	_emit("degats", "%s perd %d PV." % [t.nom, d], src.id if src != null else "", t.id, d, element)
	if t.pv <= 0:
		_mourir(t)
		return d
	if t.incantation != null and not t.incantation.silence and d * 100 >= int(t.pv_max) * 12:
		_interrompre(t, "sous la violence du coup")
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
	_compacter(t.camp)


func _soigner(f: Dictionary, t: Dictionary, montant: float) -> void:
	if not vivant(t):
		return
	var v := int(round(montant))
	if v < 1:
		v = 1
	v = mini(v, int(t.pv_max) - int(t.pv))
	t.pv += v
	_emit("soin", "%s récupère %d PV." % [t.nom, v], f.id, t.id, v)


func _ajouter_statut(t: Dictionary, s: Dictionary) -> void:
	if not vivant(t):
		return
	for k in ["valeur", "element", "_effet", "_source", "_base"]:
		if not s.has(k):
			s[k] = 0.0 if k in ["valeur", "_base"] else ""
	if not s.has("_silence"):
		s._silence = false
	var ex = statut(t, s.type)
	if ex != null and s.type != "piege" and s.type != "invocation":
		if s.type == "consume" and s.element == "venin":
			ex.valeur += s.valeur
		else:
			ex.valeur = maxf(ex.valeur, s.valeur)
		ex.tours = maxi(ex.tours, s.tours)
		ex._silence = ex._silence or s._silence
		return
	t.statuts.append(s)


func _verifier_fin() -> void:
	if fini:
		return
	var a := vivants(0).size()
	var b := vivants(1).size()
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
		var textes := {0: "Victoire !", 1: "Défaite…", 2: "Match nul : les deux camps sont épuisés."}
		_emit("fin", textes[vainqueur], "", "", vainqueur)


func _fin_de_tour() -> void:
	var reste := []
	for d in _differes:
		d.tours -= 1
		if d.tours > 0:
			reste.append(d)
			continue
		if vivant(d.lanceur):
			_emit("differe", "Le " + d.jutsu.nom + " de " + d.lanceur.nom + " frappe à nouveau !", d.lanceur.id, "", 0, d.jutsu.element, d.jutsu.nom)
			_lancer(d.lanceur, d.jutsu, d.cible, d.facteur, true)
	_differes = reste

	for f in combattants:
		if not vivant(f):
			continue
		for s in f.statuts:
			if s.tours <= 0 or not vivant(f):
				continue
			match s.type:
				"consume":
					_emit("consume", f.nom + " se consume.", "", f.id, 0, s.element)
					_infliger(null, f, s.valeur, s.element, true)
				"regen":
					_soigner(f, f, s.valeur)
				"invocation":
					_invocation_frappe(f, s)
			s.tours -= 1
		f.statuts = f.statuts.filter(func(s): return s.tours > 0)
		if vivant(f):
			f.souffle = mini(f.souffle_max, f.souffle + 3 + int(f.gnanga) / 4)
	for camp in 2:
		var m = murs[camp]
		if m != null:
			m.tours -= 1
			if m.tours <= 0:
				murs[camp] = null
				_emit("mur_fin", "Le mur se dissipe.")


func _invocation_frappe(f: Dictionary, s: Dictionary) -> void:
	var e := ennemis(f)
	if e.is_empty():
		return
	var t: Dictionary = e[rng.randi_range(0, e.size() - 1)]
	_emit("invocation", "La créature de Souffle de " + f.nom + " attaque " + t.nom + ".", f.id, t.id, 0, s.element)
	var d := _infliger(f, t, s._base, s.element, false)
	if vivant(t) and s._effet != "":
		_appliquer_effet(f, t, s._effet, s.valeur * 0.5, s._base, d, _opts({"element": s.element}))


func _declencher_piege(f: Dictionary, s: Dictionary) -> void:
	s.tours = 0
	var lanceur = get_c(s._source)
	if lanceur == null:
		lanceur = f
	_emit("piege", f.nom + " déclenche un piège !", lanceur.id, f.id, 0, s.element)
	var d := _infliger(lanceur, f, s._base, s.element, false)
	if vivant(f) and s._effet != "":
		_appliquer_effet(lanceur, f, s._effet, s.valeur, s._base, d, _opts({"element": s.element}))


# --- Jutsus ----------------------------------------------------------------------

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
			refus = Grammaire.verifier(j.conditions, f._contexte.niveau, f._contexte.elements, moment.call())
		if j != null and j.fusion and j.legendaire == "" and f.niveau < int(Regles.c.niveau_fusion):
			refus = "Deux éléments veulent se fondre… mais il faut le niveau %d pour les fusionner." % int(Regles.c.niveau_fusion)
		var cout := 3 * seq.size()
		if j != null and refus == "":
			cout = cout_reel(j, maitrise_de(f, j))
		if f.souffle < cout:
			_emit("info", "%s manque de Souffle (%d requis)." % [f.nom, cout], f.id)
			f.garde = true
			return
		f.souffle -= cout
		var inc := {"sequence": seq, "_jutsu": null, "_echec": res.echec, "_refus": refus, "cible": a.get("cible", ""), "progres": 0, "total": seq.size(), "silence": false}
		if refus == "":
			inc._jutsu = j
		if j != null and j.mods_forme.has("silence"):
			inc.silence = true
		f.incantation = inc
	var inc: Dictionary = f.incantation
	inc.progres = mini(inc.total, inc.progres + mudras_par_tour(f))
	if inc.progres < inc.total:
		_emit("incantation", "%s forme des mudras (%d/%d)." % [f.nom, inc.progres, inc.total], f.id, "", inc.progres)
		return
	f.incantation = null
	_liberer(f, inc)


func _liberer(f: Dictionary, inc: Dictionary) -> void:
	if inc._refus != "":
		_emit("echec", inc._refus, f.id)
		return
	if inc._jutsu == null:
		var r := Grammaire.resonner(inc.sequence, inc._echec, f.get("_precis", false))
		if f.joueur:
			resonances.append(r)
		_emit("echec", f.nom + " : " + r.message, f.id, "", r.score)
		if r.retour_de_souffle:
			_emit("retour", "Retour de Souffle !", f.id, f.id)
			_infliger(null, f, float(4 + 2 * inc.sequence.size()), "", true)
		return
	var j: Dictionary = inc._jutsu
	if f.joueur:
		if not f._maitrise.has(j.cle):
			f._maitrise[j.cle] = int(Regles.c.maitrise_decouverte)
			decouvertes.append({"joueur": f.id, "jutsu": j})
			var texte: String = ("JUTSU LÉGENDAIRE DÉCOUVERT : " if j.legendaire != "" else "Nouveau jutsu découvert : ") + j.nom + " !"
			_emit("decouverte", texte, f.id, "", 0, j.element, j.nom)
		usages[j.cle] = usages.get(j.cle, 0) + 1
	if j.mods_forme.has("retarder"):
		_emit("jutsu", f.nom + " prépare " + j.nom + " : il frappera au prochain tour.", f.id, "", 0, j.element, j.nom)
		_differes.append({"lanceur": f, "jutsu": j, "cible": inc.cible, "facteur": 1.6, "tours": 1})
		return
	_lancer(f, j, inc.cible, 1.0, false)


func puissance(f: Dictionary, j: Dictionary, facteur: float) -> float:
	var m := float(maitrise_de(f, j))
	var base := (12.0 + float(f.gnanga) * 1.6 + float(f.niveau) * 1.2) * float(j.puissance) * (0.8 + 0.4 * m / 100.0)
	base *= Regles.facteur_cosmique(j.element, moment.call()) * facteur
	if j.element == "vegetal" or j.element == "bois_sacre":
		base *= 1.0 + 0.05 * minf(float(tour), 10.0)
	var rf = statut(f, "renfort")
	if rf != null:
		base *= 1.0 + rf.valeur
	return base


func _lancer(f: Dictionary, j: Dictionary, cible_id: String, facteur: float, echo: bool) -> void:
	var base := puissance(f, j, facteur)
	if not echo:
		_emit("jutsu", f.nom + " lance " + j.nom + " !", f.id, "", 0, j.element, j.nom)
	if not echo and j.mods_forme.has("persistance"):
		_differes.append({"lanceur": f, "jutsu": j, "cible": cible_id, "facteur": 0.5, "tours": 1})
	if j.element in ["brume", "vapeur", "songe"]:
		_ajouter_statut(f, {"type": "voile", "tours": 1, "valeur": 0.5, "element": j.element})
	if j.soutien:
		_lancer_soutien(f, j, cible_id, base)
		return
	var o := _opts_de(j)
	match j.forme:
		"cercle":
			for t in ennemis(f):
				_toucher(f, t, j, base, o, false)
		"mur":
			var ab := base * 1.5
			if j.element in ["terre", "seisme", "lave"]:
				ab *= 1.3
			murs[f.camp] = {"absorption": int(ab), "tours": 2 + o.bonus, "element": j.element, "_riposte": j.effet, "_intensite": j.intensite, "_base": base, "_lanceur": f.id}
			_emit("mur", "Un mur se dresse devant le camp de %s (%d)." % [f.nom, int(ab)], f.id, "", int(ab), j.element)
		"armure":
			var ab := int(base * 1.2)
			f.absorption += ab
			_ajouter_statut(f, {"type": "riposte", "tours": 3 + o.bonus, "valeur": j.intensite, "_base": base, "_effet": j.effet, "element": j.element})
			_emit("armure", "%s se couvre d'une armure de Souffle (%d)." % [f.nom, ab], f.id, "", ab, j.element)
		"double":
			_ajouter_statut(f, {"type": "leurre", "tours": 2 + o.bonus, "valeur": j.intensite, "_base": base, "_effet": j.effet, "element": j.element})
			_emit("double", f.nom + " crée un double.", f.id, "", 0, j.element)
		"pas":
			_placer(f, 1 if f.rang > 1 else NB_RANGS)
			_ajouter_statut(f, {"type": "voile", "tours": 1, "valeur": 0.5, "element": j.element})
			_emit("deplacement", "%s bondit au rang %d." % [f.nom, f.rang], f.id, "", f.rang)
			var t = _cible_ennemie(f, "", true)
			if t != null:
				_toucher(f, t, j, base, o, true)
		"invocation":
			_ajouter_statut(f, {"type": "invocation", "tours": 3 + o.bonus, "valeur": j.intensite, "_base": base, "_effet": j.effet, "element": j.element})
			_emit("invoque", f.nom + " invoque une créature de Souffle.", f.id, "", 0, j.element)
		"piege":
			var t = _cible_ennemie(f, cible_id, false)
			if t == null:
				return
			_ajouter_statut(t, {"type": "piege", "tours": 3, "valeur": j.intensite, "_base": base * 1.2, "_effet": j.effet, "element": j.element, "_source": f.id})
			_emit("piege_pose", f.nom + " tend un piège sous les pieds de " + t.nom + ".", f.id, t.id, 0, j.element)
		_:
			var contact: bool = j.forme == "lame"
			if contact and f.rang > 2:
				_emit("info", "Trop loin : la lame de Souffle se dissipe.", f.id)
				return
			var t = _cible_ennemie(f, cible_id, contact)
			if t == null:
				_emit("info", "Aucune cible à portée.", f.id)
				return
			var cibles := [t]
			if j.mods_forme.has("etendre"):
				for e in ennemis(f):
					if e != t and (e.rang == t.rang + 1 or e.rang == t.rang - 1):
						cibles.append(e)
						break
			for i in cibles.size():
				_toucher(f, cibles[i], j, base * (0.7 if i > 0 else 1.0), o, contact)


func _opts(extra: Dictionary = {}) -> Dictionary:
	var o := {"bonus": 0, "mult": 1, "silence": false, "propage": false, "lien": false, "intens_mu": 1.0, "element": ""}
	o.merge(extra, true)
	return o


func _opts_de(j: Dictionary) -> Dictionary:
	var o := _opts({"element": j.element})
	for m in j.mods_effet:
		match m:
			"etendre":
				o.bonus += 2
			"persistance", "retarder":
				o.mult = 2
			"silence":
				o.silence = true
			"multiplier":
				o.propage = true
	if j.forme == "lien":
		o.lien = true
		o.bonus += 1
		o.intens_mu = 1.5
	return o


static func _duree(o: Dictionary, n: int) -> int:
	var m: int = o.mult if o.mult != 0 else 1
	return (n + int(o.bonus)) * m


func _toucher(f: Dictionary, t: Dictionary, j: Dictionary, base: float, o: Dictionary, contact: bool) -> void:
	if not vivant(t):
		return
	var frappes := 1
	var mult := 1.0
	if j.mods_forme.has("multiplier"):
		frappes = 2
		mult = 0.6
	var n := 0
	while n < frappes and vivant(t):
		n += 1
		if j.forme != "cercle":
			if _intercepter(f, t):
				continue
			if j.forme == "trait" and _chance(esquive(t) / 2.0):
				_emit("esquive", t.nom + " esquive le jutsu.", f.id, t.id)
				continue
		var d := _infliger(f, t, base * mult, j.element, false)
		if not vivant(t):
			break
		_passif_element(f, t, j, base * mult, d)
		_appliquer_effet(f, t, j.effet, j.intensite * o.intens_mu, base, d, o)
		if j.effet2 != "" and vivant(t):
			_appliquer_effet(f, t, j.effet2, j.intensite * o.intens_mu * 0.6, base, d, o)
		if contact:
			_riposter(t, f)
	if o.propage and vivant(f):
		for e in ennemis(f):
			if e != t:
				_emit("info", "L'effet se propage à " + e.nom + ".", f.id, e.id)
				_appliquer_effet(f, e, j.effet, j.intensite * 0.7, base, 0, _opts())
				break


func _passif_element(f: Dictionary, t: Dictionary, j: Dictionary, base: float, d: int) -> void:
	match j.element:
		"feu", "lave", "cendre":
			if j.effet != "consumer":
				_ajouter_statut(t, {"type": "consume", "tours": 2, "valeur": base * 0.12, "element": j.element})
		"eau", "maree":
			_soigner(f, f, float(d) * 0.1)
		"son", "onde":
			_interrompre(t, "par une onde sonore")
		"gravite", "seisme":
			if t.rang > 1:
				_placer(t, 1)
				_emit("deplacement", t.nom + " est attiré au premier rang !", t.id, "", 1)
		"sel", "cristal":
			_purifier(t)
		"sable", "harmattan":
			if _chance(25):
				_ajouter_statut(t, {"type": "aveugle", "tours": 1, "valeur": 0.4, "element": j.element})
		"foudre", "tempete", "magnetisme":
			if _chance(20):
				_ajouter_statut(t, {"type": "entrave", "tours": 1, "element": j.element})
				_emit("statut", t.nom + " est paralysé.", "", t.id, 0, j.element)
		"essaim", "fleau":
			if vivant(t):
				_infliger(f, t, base * 0.15, j.element, true)


func _purifier(t: Dictionary) -> void:
	var reste := []
	var retire := false
	for s in t.statuts:
		if s.type in ["voile", "renfort", "regen", "riposte"] and not s._silence:
			retire = true
			continue
		reste.append(s)
	t.statuts = reste
	if t.absorption > 0:
		t.absorption = 0
		retire = true
	if retire:
		_emit("purification", "Le Sel purifie " + t.nom + " : ses protections s'effacent.", "", t.id)


func _appliquer_effet(f: Dictionary, t: Dictionary, effet: String, intens: float, base: float, degats: int, o: Dictionary) -> void:
	if effet == "":
		return
	match effet:
		"consumer":
			_ajouter_statut(t, {"type": "consume", "tours": _duree(o, 3), "valeur": base * 0.25 * intens, "element": o.element, "_silence": o.silence})
			_emit("statut", t.nom + " est rongé par le Souffle.", "", t.id)
		"lier":
			_ajouter_statut(t, {"type": "entrave", "tours": _duree(o, 2), "_silence": o.silence})
			_emit("statut", t.nom + " est entravé.", "", t.id)
		"aveugler":
			_ajouter_statut(t, {"type": "aveugle", "tours": _duree(o, 2), "valeur": minf(0.7, 0.4 * intens), "_silence": o.silence})
			_emit("statut", t.nom + " est aveuglé.", "", t.id)
		"repousser":
			if t.rang < vivants(t.camp).size():
				_placer(t, t.rang + 1)
				_emit("deplacement", "%s est repoussé au rang %d." % [t.nom, t.rang], t.id, "", t.rang)
			_interrompre(t, "par le choc")
		"drainer":
			_soigner(f, f, float(degats) * 0.5 * intens)
			var gain := int(float(degats) * 0.2 * intens)
			f.souffle = mini(f.souffle_max, f.souffle + gain)
		"briser":
			_ajouter_statut(t, {"type": "affaibli", "tours": _duree(o, 3), "valeur": 0.5, "_silence": o.silence})
			t.absorption = 0
			_emit("statut", "Les défenses de " + t.nom + " sont brisées.", "", t.id)
			_interrompre(t, "net")
		"marquer":
			_ajouter_statut(t, {"type": "marque", "tours": _duree(o, 3), "valeur": 0.25 * intens, "_silence": o.silence})
			_emit("statut", t.nom + " est marqué.", "", t.id)
		"soigner":
			_soigner(f, f, maxf(float(degats) * 0.4, base * 0.2) * intens)
		"renforcer":
			_ajouter_statut(f, {"type": "renfort", "tours": _duree(o, 2), "valeur": 0.2 * intens})
		"dissimuler":
			_ajouter_statut(f, {"type": "voile", "tours": _duree(o, 1), "valeur": 0.5})


func _lancer_soutien(f: Dictionary, j: Dictionary, cible_id: String, base: float) -> void:
	var o := _opts_de(j)
	var allies := vivants(f.camp)
	var cibles := []
	match j.forme:
		"cercle", "mur", "invocation":
			cibles = allies
		"armure", "pas", "double":
			cibles = [f]
		_:
			var t = get_c(cible_id)
			if t == null or not vivant(t) or t.camp != f.camp:
				t = plus_blesse(allies)
			cibles = [t]
	match j.forme:
		"mur":
			var ab := int(base * 1.2)
			murs[f.camp] = {"absorption": ab, "tours": 2 + o.bonus, "element": j.element, "_riposte": "", "_intensite": 0.0, "_base": 0.0, "_lanceur": f.id}
			_emit("mur", "Un mur protecteur se dresse (%d)." % ab, f.id, "", ab, j.element)
		"armure":
			f.absorption += int(base)
		"pas":
			_placer(f, f.rang - 1 if f.rang > 1 else NB_RANGS)
		"double":
			_ajouter_statut(f, {"type": "leurre", "tours": 2})
	for t in cibles:
		_soutenir(f, t, j.effet, j.intensite * o.intens_mu, base, o, j.forme == "invocation")
		if j.effet2 != "" and Grammaire.effet_soutien(j.effet2):
			_soutenir(f, t, j.effet2, j.intensite * 0.6, base, o, false)


func _soutenir(f: Dictionary, t: Dictionary, effet: String, intens: float, base: float, o: Dictionary, durable: bool) -> void:
	match effet:
		"soigner":
			if durable or o.bonus > 0 or o.mult > 1:
				_ajouter_statut(t, {"type": "regen", "tours": _duree(o, 3), "valeur": base * 0.3 * intens})
			if not durable:
				_soigner(f, t, base * 0.9 * intens)
		"renforcer":
			_ajouter_statut(t, {"type": "renfort", "tours": _duree(o, 3), "valeur": 0.25 * intens, "_silence": o.silence})
			_emit("statut", t.nom + " est renforcé.", "", t.id)
		"dissimuler":
			_ajouter_statut(t, {"type": "voile", "tours": _duree(o, 2), "valeur": 0.5, "_silence": o.silence})
			_emit("statut", t.nom + " se fond dans le Souffle.", "", t.id)


static func plus_blesse(l: Array):
	var best = null
	for f in l:
		if best == null or float(f.pv) / float(f.pv_max) < float(best.pv) / float(best.pv_max):
			best = f
	return best


# --- IA des PNJ ----------------------------------------------------------------------
## L'IA évalue chaque action possible : elle soigne les blessés, profite des
## faiblesses élémentaires et cherche à briser les longues incantations.

func _choisir_ia(f: Dictionary) -> Dictionary:
	if f.incantation != null:
		return {"acteur": f.id, "type": "incanter"}
	var opts := []
	var ajouter := func(a: Dictionary, s: float) -> void:
		a.acteur = f.id
		opts.append([a, s * (0.9 + rng.randf() * 0.2)])
	var ens := ennemis(f)
	var menace := _menace(ens)
	var distance: bool = f.arme.distance
	if not (not distance and (f.rang > 2 or statut(f, "entrave") != null)):
		for t in ens:
			if not distance and t.rang > 2:
				continue
			var est := float(f.arme.puissance + f.fangan) * 40.0 / (40.0 + _defense_de(t))
			ajouter.call({"type": "frapper", "cible": t.id}, _valeur_degats(t, est, 1.0))
	if f._ia != "bete":
		var mpt := mudras_par_tour(f)
		for j in f._jutsus:
			if cout_reel(j, maitrise_de(f, j)) > f.souffle:
				continue
			var tours := float((j.sequence.size() + mpt - 1) / mpt)
			var base := puissance(f, j, 1.0)
			var seq: Array = j.sequence
			if j.soutien:
				var s := _valeur_soutien(f, j, base)
				if s > 0:
					var c = plus_blesse(vivants(f.camp))
					ajouter.call({"type": "incanter", "sequence": seq, "cible": c.id}, s / tours)
				continue
			if j.forme in ["mur", "armure", "double"]:
				var v := base * 0.3
				if menace > 0 or f.pv * 2 < f.pv_max:
					v = base * 0.8 + menace
				if (j.forme == "mur" and murs[f.camp] != null) or (j.forme == "armure" and f.absorption > 0):
					v *= 0.2
				ajouter.call({"type": "incanter", "sequence": seq}, v / tours)
				continue
			if j.forme in ["cercle", "invocation"]:
				var total := 0.0
				for t in ens:
					total += _valeur_degats(t, base * Regles.multiplicateur(j.element, t.element), tours)
				if j.forme == "invocation":
					total *= 2.2
				ajouter.call({"type": "incanter", "sequence": seq}, total / tours + _bonus_effet(j, base))
				continue
			for t in ens:
				if j.forme == "lame" and (f.rang > 2 or t.rang > 2):
					continue
				var v := _valeur_degats(t, base * Regles.multiplicateur(j.element, t.element), tours)
				if t.incantation != null and _interrompt(j) and tours <= float(t.incantation.total - t.incantation.progres + 1):
					v += 12.0 * float(t.incantation.total)
				ajouter.call({"type": "incanter", "sequence": seq, "cible": t.id}, v / tours + _bonus_effet(j, base))
	var garde := 2.0
	if f.pv * 10 < f.pv_max * 3 and menace > 0:
		garde = 10.0 + menace
	ajouter.call({"type": "garde"}, garde)
	if f._ia != "bete" and f.souffle * 3 < f.souffle_max:
		ajouter.call({"type": "concentrer"}, 6.0)
	if not distance and f.rang > 2:
		ajouter.call({"type": "deplacer", "rang": 1}, 8.0)
	var best = opts[0]
	for o in opts.slice(1):
		if o[1] > best[1]:
			best = o
	return best[0]


static func _defense_de(t: Dictionary) -> float:
	var d := float(t.defense) + float(t.fangan) * 0.5
	if statut(t, "affaibli") != null:
		d *= 0.5
	return d


func _valeur_degats(t: Dictionary, est: float, tours: float) -> float:
	var v := est
	if float(t.pv) <= est:
		v *= 2
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


static func _interrompt(j: Dictionary) -> bool:
	return j.element in ["son", "onde"] or j.effet in ["repousser", "briser"] or j.effet2 in ["repousser", "briser"]


static func _bonus_effet(j: Dictionary, base: float) -> float:
	var b := 0.0
	for e in [j.effet, j.effet2]:
		match e:
			"consumer":
				b += base * 0.5
			"lier", "aveugler", "marquer":
				b += base * 0.3
			"drainer", "briser":
				b += base * 0.2
	return b


func _valeur_soutien(f: Dictionary, j: Dictionary, base: float) -> float:
	match j.effet:
		"soigner":
			var manque := 0.0
			for a in vivants(f.camp):
				if a.pv * 10 < a.pv_max * 6:
					manque += float(a.pv_max - a.pv)
			return minf(manque, base * 1.5) * 1.2
		"renforcer":
			if statut(f, "renfort") == null:
				return base * 0.4
		"dissimuler":
			if statut(f, "voile") == null:
				return base * 0.3
	return 0.0
