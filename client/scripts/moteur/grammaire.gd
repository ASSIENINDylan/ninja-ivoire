class_name Grammaire
extends RefCounted
## Grammaire des mudras (copie fidèle de server/internal/grammar) :
##   Élément [Élément] → Forme → (Modificateurs) → Effet → (Effet 2) → (Modificateurs)
## Les recettes légendaires ne sont connues que par leur empreinte SHA-256.


static func cle(seq: Array) -> String:
	return ">".join(PackedStringArray(seq))


static func empreinte(cle_suite: String) -> String:
	return (Regles.d.legendaires.sel + cle_suite).sha256_text()


static func _echec(etape: String, position: int, valides: int) -> Dictionary:
	return {"jutsu": null, "echec": {"etape": etape, "position": position, "valides": valides}}


## Transforme une suite de mudras en jutsu : {"jutsu": …} ou {"echec": …}.
static func analyser(seq: Array) -> Dictionary:
	var longueur_max := int(Regles.g.longueur_max)
	if seq.is_empty():
		return _echec("element", 0, 0)
	if seq.size() > longueur_max:
		return _echec("surplus", longueur_max, longueur_max)
	for i in seq.size():
		if not Regles.mudras.has(seq[i]):
			return _echec("inconnu", i, i)
	var l = Regles.d.legendaires.recettes.get(empreinte(cle(seq)))
	if l != null:
		return {"jutsu": _jutsu_legendaire(l, seq), "echec": null}

	var j := {"cle": cle(seq), "sequence": seq.duplicate(), "fusion": false, "effet2": "", "mods_forme": [], "mods_effet": [], "legendaire": ""}
	var cat := func(k: int) -> String:
		return "" if k >= seq.size() else str(Regles.mudras[seq[k]].categorie)
	var ref := func(k: int) -> String:
		return str(Regles.mudras[seq[k]].ref)
	var i := 0
	if cat.call(i) != "element":
		return _echec("element", i, i)
	j.element = ref.call(i)
	i += 1
	if cat.call(i) == "element":
		var rare := Regles.fusion_de(j.element, ref.call(i))
		if rare == "" or Regles.elements[j.element].tier != "base":
			return _echec("fusion", i, i)
		j.element = rare
		j.fusion = true
		i += 1
	if cat.call(i) != "forme":
		return _echec("forme", i, i)
	j.forme = ref.call(i)
	i += 1
	var vus := {}
	var max_mods := int(Regles.g.max_modificateurs)
	while cat.call(i) == "modificateur":
		if vus.size() >= max_mods or vus.has(ref.call(i)):
			return _echec("modificateurs", i, i)
		vus[ref.call(i)] = true
		j.mods_forme.append(ref.call(i))
		i += 1
	if cat.call(i) != "effet":
		return _echec("effet", i, i)
	j.effet = ref.call(i)
	i += 1
	if cat.call(i) == "effet":
		if ref.call(i) == j.effet:
			return _echec("effet", i, i)
		j.effet2 = ref.call(i)
		i += 1
	while cat.call(i) == "modificateur":
		if vus.size() >= max_mods or vus.has(ref.call(i)):
			return _echec("modificateurs", i, i)
		vus[ref.call(i)] = true
		j.mods_effet.append(ref.call(i))
		i += 1
	if i != seq.size():
		return _echec("surplus", i, i)
	_calculer(j)
	return {"jutsu": j, "echec": null}


static func _jutsu_legendaire(l: Dictionary, seq: Array) -> Dictionary:
	var j: Dictionary = l.jutsu.duplicate(true)
	j.sequence = seq.duplicate()
	j.cle = cle(seq)
	j.effets = normaliser(j.get("effets", []))
	for k in ["effet2", "legendaire", "degats_nature"]:
		j[k] = str(j.get(k, ""))
	for k in ["mods_forme", "mods_effet"]:
		if j.get(k) == null:
			j[k] = []
	for k in ["delai", "incassable", "indissipable", "fusion"]:
		j[k] = bool(j.get(k, false))
	j.echo = float(j.get("echo", 0.0))
	j.conditions = l.conditions
	return j


# --- Profil de combat (copie de grammar/profil.go) ------------------------------

const _CLES_EFFET := {"op": "", "cible": "", "nature": "", "mult": 0.0, "frappes": 0, "statut": "", "duree": 0,
	"valeur": 0.0, "vers": "", "nombre": 0, "part": 0.0, "propage": 0.0}


## Complète les effets venus du JSON (champs omis = valeur nulle).
static func normaliser(l) -> Array:
	var out := []
	if l == null:
		return out
	for e in l:
		var n := {}
		for k in _CLES_EFFET:
			var v = e.get(k, _CLES_EFFET[k])
			match typeof(_CLES_EFFET[k]):
				TYPE_INT:
					n[k] = int(v)
				TYPE_FLOAT:
					n[k] = float(v)
				_:
					n[k] = str(v)
		n.effets = normaliser(e.get("effets"))
		out.append(n)
	return out


static func _arrondi2(x: float) -> float:
	return round(x * 100.0) / 100.0


static func _arrondi3(x: float) -> float:
	return round(x * 1000.0) / 1000.0


static func _force(i: int) -> float:
	return 1.0 if i == 0 else 0.6


static func _cloner(l: Array) -> Array:
	return l.duplicate(true)


static func _fixer_nature(l: Array, nature: String) -> void:
	if nature == "":
		nature = "magique"
	for e in l:
		if e.op in ["degats", "dot", "drain"] and e.nature == "":
			e.nature = nature
		_fixer_nature(e.effets, nature)


static func _affaiblir(l: Array) -> Array:
	var out := []
	for e in l:
		if e.op == "bond":
			continue
		e.mult *= 0.5
		if e.op == "declencheur" or (e.op == "statut" and Regles.g.statuts_drapeau.has(e.statut)):
			pass
		elif e.op == "statut" and e.statut == "leurre":
			e.valeur = max(1.0, e.valeur - 1.0)
		else:
			e.valeur *= 0.7
		if e.duree > 1:
			e.duree -= 1
		if e.nombre > 1:
			e.nombre -= 1
		for x in e.effets:
			x.mult *= 0.5
			if x.duree > 1:
				x.duree -= 1
		out.append(e)
	return out


static func _elargir(l: Array, s: float) -> bool:
	var ok := false
	for e in l:
		var avant: String = e.cible
		match e.cible:
			"ennemi":
				e.cible = "ennemi_etendu"
			"contact":
				e.cible = "contact_etendu"
			"soi":
				if e.op in ["statut", "bouclier", "riposte"]:
					e.cible = "allies"
		if e.cible != avant:
			e.part = _arrondi2(0.7 * s)
			ok = true
	return ok


static func _propager(l: Array, part: float) -> bool:
	var ok := false
	for e in l:
		if e.op in ["bond", "clone", "differe"]:
			continue
		if e.cible in ["ennemi", "contact", "ennemi_etendu", "contact_etendu", "front", "aleatoire", "attaquant", "declencheur"]:
			e.propage = part
			ok = true
		if _propager(e.effets, part):
			ok = true
	return ok


static func _sans_bond(l: Array) -> Array:
	return l.filter(func(e): return e.op != "bond")


static func _multiplier(l: Array) -> void:
	for e in l:
		match e.op:
			"degats", "drain":
				e.frappes *= 2
				e.mult *= 0.6
			"clone":
				e.nombre += 1
			"invocation", "piege", "riposte", "declencheur":
				e.duree += 1
				for x in e.effets:
					if x.op == "degats" or x.op == "drain":
						x.frappes = 2
						x.mult *= 0.6
			"statut", "bouclier", "soin", "dot":
				e.mult *= 1.2
				e.valeur *= 1.2


static func _amplifier(e: Dictionary, f: float) -> void:
	e.mult *= f
	var controle: bool = Regles.g.statuts_controle.has(e.statut)
	if e.op == "statut" and e.statut == "leurre":
		e.valeur += 1.0
	elif e.op == "statut" and Regles.g.statuts_drapeau.has(e.statut):
		pass
	elif ((e.op == "statut" and controle) or e.op == "deplacer") and e.valeur == 0.0:
		e.valeur = _arrondi2((f - 1.0) / 2.0)
	else:
		e.valeur *= f
	for x in e.effets:
		_amplifier(x, f)


static func _retarder(l: Array, f: float) -> Array:
	var now := []
	var plus := []
	for e in l:
		if e.op in ["bond", "clone", "deplacer", "interrompre"]:
			now.append(e)
		else:
			_amplifier(e, f)
			plus.append(e)
	if plus.size() > 0:
		var d := _effet_vide()
		d.op = "differe"
		d.cible = "soi"
		d.duree = 1
		d.effets = plus
		now.append(d)
	return now


static func _effet_vide() -> Dictionary:
	var e := _CLES_EFFET.duplicate()
	e.effets = []
	return e


static func _allonger(l: Array, persistance: bool, s: float) -> bool:
	var ok := false
	for e in l:
		if e.duree > 0 and e.op != "differe":
			e.duree = 2 * e.duree + int(s)
			ok = true
	return ok


static func _arrondir(l: Array) -> void:
	for e in l:
		e.mult = _arrondi2(e.mult)
		e.valeur = _arrondi2(e.valeur)
		_arrondir(e.effets)


static func _profiler(j: Dictionary) -> void:
	var g: Dictionary = Regles.g
	j.type = str(g.type_effet[j.effet])
	j.degats_nature = str(g.nature_effet.get(j.effet, ""))
	var eff := _cloner(normaliser(g.cellules[j.effet][j.forme]))
	_fixer_nature(eff, j.degats_nature)
	if j.effet2 != "":
		var e2 := _cloner(normaliser(g.cellules[j.effet2][j.forme]))
		_fixer_nature(e2, str(g.nature_effet.get(j.effet2, "")))
		eff.append_array(_affaiblir(e2))
	var cle_base: String = j.type if j.type != "degats" else "degats_" + j.degats_nature
	var b: Dictionary = g.bases_type[cle_base]
	var n: float = float(b.n) * (1.0 + 0.12 * float(j.sequence.size() - 3))
	match str(Regles.elements[j.element].tier):
		"rare":
			n *= 1.3
		"mythique":
			n *= 1.6
	j.delai = false
	j.echo = 0.0
	j.incassable = false
	j.indissipable = false
	var k := 0
	for m in j.mods_forme:
		var s := _force(k)
		k += 1
		match m:
			"amplifier":
				n *= 1.0 + 0.35 * s
			"etendre":
				n *= 1.0 - 0.15 * s
				_elargir(eff, s)
			"multiplier":
				n *= 1.0 - 0.1 * s
				_multiplier(eff)
			"retarder":
				n *= 1.0 + 0.5 * s
				j.delai = true
			"silence":
				n *= 1.0 - 0.05 * s
				j.incassable = true
			"persistance":
				j.echo = _arrondi2(0.5 * s)
	for m in j.mods_effet:
		var s := _force(k)
		k += 1
		match m:
			"amplifier":
				for e in eff:
					if e.op == "degats" or e.op == "drain":
						e.mult *= 1.0 + 0.2 * s
					else:
						_amplifier(e, 1.0 + 0.4 * s)
			"etendre":
				if not _elargir(eff, s):
					for e in eff:
						_amplifier(e, 1.0 + 0.1 * s)
			"multiplier":
				if not _propager(eff, _arrondi2(0.5 * s)):
					var rappel := _sans_bond(_cloner(eff))
					for e in rappel:
						_amplifier(e, 0.5 + 0.5 * s)
					var d := _effet_vide()
					d.op = "differe"
					d.cible = "soi"
					d.duree = 2
					d.effets = rappel
					eff.append(d)
			"retarder":
				eff = _retarder(eff, 1.0 + 0.6 * s)
			"persistance":
				if not _allonger(eff, true, s):
					var rappel := _sans_bond(_cloner(eff))
					for e in rappel:
						e.mult *= 0.4 * s
						e.valeur *= 0.4 * s
					var d := _effet_vide()
					d.op = "differe"
					d.cible = "soi"
					d.duree = 1
					d.effets = rappel
					eff.append(d)
			"silence":
				j.indissipable = true
	_arrondir(eff)
	j.effets = eff

	var ie: Array = g.inclinaisons.elements[j.element]
	var tf: Array = g.inclinaisons.formes[j.forme]
	var sig: PackedByteArray = (str(g.sel_signature) + str(j.cle)).sha256_buffer()
	var jit := func(i: int) -> float: return 0.9 + 0.2 * float(sig[i]) / 255.0
	j.coefs = {
		"f": _arrondi3(max(0.05, (float(b.f) + float(ie[0]) + float(tf[0])) * jit.call(0))),
		"g": _arrondi3(max(0.05, (float(b.g) + float(ie[1]) + float(tf[1])) * jit.call(1))),
		"m": _arrondi3(max(0.05, (float(b.m) + float(ie[2]) + float(tf[2])) * jit.call(2))),
		"n": _arrondi3(n),
	}


static func est_soutien(j: Dictionary) -> bool:
	for e in j.effets:
		if e.cible != "soi" and e.cible != "allies":
			return false
	return true


static func _calculer(j: Dictionary) -> void:
	_profiler(j)
	var n: int = j.sequence.size()
	var cout := 5.0 + 4.0 * float(n)
	for m in j.mods_forme:
		if m == "amplifier":
			cout *= 1.3
	for m in j.mods_effet:
		if m == "amplifier":
			cout *= 1.2
	match str(Regles.elements[j.element].tier):
		"rare":
			cout *= 1.5
		"mythique":
			cout *= 2.0
	j.cout = int(cout + 0.5)
	j.soutien = est_soutien(j)
	j.nom = _nommer(j)
	j.nature = _nature(j)
	j.texte = _decrire(j)


## Nom poétique : « Braise : Croc de la hyène ».
static func _nommer(j: Dictionary) -> String:
	var n: Dictionary = Regles.g.noms
	var img: Dictionary = n.images[j.forme][j.effet]
	var genre := 1 if img.feminin else 0
	var tete := PackedStringArray()
	for m in j.mods_forme:
		tete.append(Regles.g.prefixe_mod_forme[m][genre])
	tete.append(img.texte)
	var nom: String = n.voies[j.element] + " : " + " ".join(tete)
	if j.effet2 != "":
		nom += ", " + n.suites_effet[j.effet2]
	if j.mods_effet.size() > 0:
		var ep := PackedStringArray()
		for m in j.mods_effet:
			ep.append(n.epithetes_mod_effet[m])
		nom += " — " + ", ".join(ep)
	return nom


## Nom descriptif : « Lame de Feu dévorante ».
static func _nature(j: Dictionary) -> String:
	var nf: Dictionary = Regles.g.noms_formes[j.forme]
	var genre := 1 if nf.feminin else 0
	var parts := PackedStringArray()
	for m in j.mods_forme:
		parts.append(Regles.g.prefixe_mod_forme[m][genre])
	parts.append(nf.nom)
	parts.append(Regles.elements[j.element].de)
	parts.append(Regles.g.adj_effet[j.effet][genre])
	if j.effet2 != "":
		parts.append("et")
		parts.append(Regles.g.adj_effet[j.effet2][genre])
	for m in j.mods_effet:
		parts.append(Regles.g.suffixe_mod_effet[m][genre])
	return " ".join(parts)


# --- Description (copie de grammar/description.go) ------------------------------

static func _pct(x: float) -> int:
	return int(round(x * 100.0))


static func _tours(d: int) -> String:
	return "%d tours" % d if d > 1 else "1 tour"


static func _maj(s: String) -> String:
	return s if s == "" else s.substr(0, 1).to_upper() + s.substr(1)


## Jusqu'à trois décimales, au moins deux, à la française : 1,153 ; 0,45.
static func decimale3(x: float) -> String:
	var m := int(round(x * 1000.0))
	var t := "%d.%03d" % [m / 1000, m % 1000]
	if t.ends_with("0"):
		t = t.substr(0, t.length() - 1)
	return t.replace(".", ",")


static func _texte_statut(e: Dictionary) -> String:
	var t: String = Regles.g.textes_statut[e.statut]
	if Regles.g.statuts_controle.has(e.statut) and e.valeur > 0 and not t.contains("{v}"):
		t += " (réussite +{v} %)"
	return t.replace("{v}", str(_pct(e.valeur))).replace("{n}", str(int(round(e.valeur))))


## Une phrase par effet.
static func decrire_effet(e: Dictionary) -> String:
	var c: String = Regles.g.textes_cible.get(e.cible, "")
	var s := ""
	match e.op:
		"degats":
			s = "Dégâts %ss à %s : %d %% de la puissance" % [e.nature, c, _pct(e.mult)]
			if e.frappes > 1:
				s += ", en %d frappes" % e.frappes
			s += "."
		"dot":
			s = "%s se consume : %d %% de la puissance par tour, %s." % [_maj(c), _pct(e.mult), _tours(e.duree)]
		"statut":
			if e.duree > 0:
				s = "%s : %s, %s." % [_maj(c), _texte_statut(e), _tours(e.duree)]
			else:
				s = "%s : %s." % [_maj(c), _texte_statut(e)]
		"bouclier":
			s = "Bouclier de Souffle sur %s : %d %% de la puissance en PV temporaires." % [c, _pct(e.mult)]
		"soin":
			s = "Soigne le lanceur : %d %% de la puissance." % _pct(e.mult)
		"drain":
			s = "Draine %s (dégâts %ss, %d %% de la puissance" % [c, e.nature, _pct(e.mult)]
			if e.frappes > 1:
				s += ", en %d frappes" % e.frappes
			s += ") : le lanceur récupère %d %% des dégâts." % _pct(e.valeur)
		"deplacer":
			if e.vers == "avant":
				s = "Attire %s au premier rang" % c
			else:
				s = "Repousse %s au dernier rang" % c
			if e.valeur > 0:
				s += " (réussite +%d %%)" % _pct(e.valeur)
			s += "."
		"bond":
			s = "Le lanceur bondit au premier rang." if e.vers == "avant" else "Le lanceur bondit au dernier rang."
		"clone":
			if e.nombre > 1:
				s = "Crée %d clones du lanceur, indiscernables pour l'adversaire, %s ; ils frappent à %d %% de sa force." % [e.nombre, _tours(e.duree), _pct(e.valeur)]
			else:
				s = "Crée un clone du lanceur, indiscernable pour l'adversaire, %s ; il frappe à %d %% de sa force." % [_tours(e.duree), _pct(e.valeur)]
		"dissiper":
			s = "Dissipe les protections et illusions de %s." % c
		"purifier":
			s = "Purifie le lanceur de ses entraves et de ses maux."
		"interrompre":
			s = "Brise l'incantation de %s." % c
		"annuler":
			s = "Son action est annulée."
		"riposte":
			s = "Pendant %s, qui attaque %s subit : %s" % [_tours(e.duree), c, _charge(e.effets)]
		"piege":
			s = "Piège sous %s, %s ; dès qu'elle agit : %s" % [c, _tours(e.duree), _charge(e.effets)]
		"invocation":
			s = "Une créature de Souffle agit pendant %s ; à chaque tour : %s" % [_tours(e.duree), _charge(e.effets)]
		"declencheur":
			s = "Si le lanceur passe sous %d %% de ses PV dans les %s : %s" % [_pct(e.valeur), _tours(e.duree), _charge(e.effets)]
		"differe":
			if e.duree > 1:
				s = "Au bout de %s : %s" % [_tours(e.duree), _charge(e.effets)]
			else:
				s = "Au tour suivant : " + _charge(e.effets)
	if e.part > 0:
		s += " (Cibles secondaires : %d %%.)" % _pct(e.part)
	if e.propage > 0:
		s += " L'effet se propage à un second adversaire (%d %%)." % _pct(e.propage)
	return s


static func _charge(l: Array) -> String:
	var parts := PackedStringArray()
	for e in l:
		var d := decrire_effet(e)
		parts.append(d.substr(0, 1).to_lower() + d.substr(1))
	return " ".join(parts)


## « Dégâts magiques », « Entrave »…
static func libelle_type(j: Dictionary) -> String:
	if j.type == "degats":
		return str(Regles.g.noms_types.degats) + " " + j.degats_nature + "s"
	return str(Regles.g.noms_types[j.type])


static func formule(k: Dictionary) -> String:
	return "Puissance = (8 + %s × Fangan + %s × Gnanga + %s × Manhis) × %s" % [
		decimale3(float(k.f)), decimale3(float(k.g)), decimale3(float(k.m)), decimale3(float(k.n))]


static func _decrire(j: Dictionary) -> String:
	var lignes := PackedStringArray([libelle_type(j) + ". " + formule(j.coefs) + "."])
	for e in j.effets:
		lignes.append(decrire_effet(e))
	if j.delai:
		lignes.append("Le Souffle s'accumule : le jutsu part au tour suivant.")
	if j.echo > 0:
		lignes.append("Un écho rejoue le jutsu au tour suivant, à %d %%." % _pct(j.echo))
	if j.incassable:
		lignes.append("Incantation impossible à interrompre.")
	if j.indissipable:
		lignes.append("Ses effets ne peuvent être ni dissipés ni purifiés.")
	return "\n".join(lignes)


# --- Légendaires : conditions cachées ------------------------------------------

## Raison (volontairement vague) du refus, ou "" si les conditions sont réunies.
static func verifier(cond: Dictionary, niveau: int, elements_connus: Array, moment: Dictionary) -> String:
	if niveau < int(cond.niveau_min):
		return "Un pouvoir immense frémit… mais votre Souffle n'est pas encore assez mûr."
	for e in cond.elements:
		if not elements_connus.has(e):
			return "Un pouvoir immense frémit… mais il réclame un élément que vous ne maîtrisez pas."
	if cond.nuit and not Regles.est_nuit(moment):
		return "Un pouvoir immense frémit… puis s'endort. Il semble attendre l'obscurité."
	if cond.jour and Regles.est_nuit(moment):
		return "Un pouvoir immense frémit… mais la nuit l'étouffe. Il attend le jour."
	if cond.pleine_lune and Regles.nom_phase(moment) != "Pleine lune":
		return "Un pouvoir immense frémit… Il attend que la lune soit entière."
	return ""


# --- Résonance ------------------------------------------------------------------

## Réaction du Souffle à un essai raté. `precise` : villages traditionnels.
static func resonner(seq: Array, e: Dictionary, precise: bool) -> Dictionary:
	var r := {"score": 0, "message": str(Regles.g.messages_echec[e.etape]), "indice": "", "ancienne": false, "retour_de_souffle": false}
	var structure: float = min(float(e.valides) / 3.0, 1.0)
	var score := 60.0 * structure
	var meilleur := 0.0
	var prefixes: Dictionary = Regles.d.legendaires.prefixes
	for k in range(2, min(seq.size(), int(Regles.g.longueur_max)) + 1):
		var h := empreinte(cle(seq.slice(0, k)))
		if prefixes.has(h):
			meilleur = max(meilleur, float(prefixes[h]))
	if meilleur > 0:
		r.ancienne = true
		score = max(score, 45.0 + 55.0 * meilleur)
		r.message = "Une vibration ancienne parcourt vos mains. " + r.message
	r.score = int(score + 0.5)
	if r.score < 25 and seq.size() >= 4:
		r.retour_de_souffle = true
		r.message += " Le Souffle se retourne contre vous !"
	if precise and r.ancienne:
		r.indice = "Les anciens murmurent que cette voie est rare : peu de ninjas l'ont suivie jusqu'au bout."
	elif precise and int(e.position) < seq.size():
		var m = Regles.mudras.get(seq[int(e.position)])
		if m != null:
			r.indice = "Les anciens sentent que le signe n°%d (%s) trouble le Souffle." % [int(e.position) + 1, m.nom]
	elif precise and e.etape != "surplus":
		r.indice = "Les anciens sentent qu'il manque un signe à la fin."
	return r
