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
	return {
		"cle": cle(seq), "nom": l.nom, "nature": "Jutsu légendaire", "sequence": seq.duplicate(), "element": l.element, "fusion": l.fusion,
		"forme": l.forme, "effet": l.effet, "effet2": l.effet2, "mods_forme": l.mods_forme.duplicate(),
		"mods_effet": l.mods_effet.duplicate(), "legendaire": l.id, "puissance": float(l.puissance),
		"intensite": float(l.intensite), "cout": int(l.cout), "soutien": effet_soutien(l.effet), "texte": l.texte,
		"conditions": l.conditions,
	}


static func effet_soutien(e: String) -> bool:
	return e == "soigner" or e == "renforcer" or e == "dissimuler"


static func _facteur_tier(element: String) -> float:
	match str(Regles.elements[element].tier):
		"rare":
			return 1.35
		"mythique":
			return 1.7
	return 1.0


static func _calculer(j: Dictionary) -> void:
	var n: int = j.sequence.size()
	j.puissance = float(Regles.g.puissance_forme[j.forme]) * (1.0 + 0.15 * float(n - 3)) * _facteur_tier(j.element)
	j.intensite = 1.0
	var cout := 5.0 + 4.0 * float(n)
	for m in j.mods_forme:
		if m == "amplifier":
			j.puissance *= 1.4
			cout *= 1.3
	for m in j.mods_effet:
		if m == "amplifier":
			j.intensite *= 1.5
			cout *= 1.2
	match str(Regles.elements[j.element].tier):
		"rare":
			cout *= 1.5
		"mythique":
			cout *= 2.0
	j.cout = int(cout + 0.5)
	j.soutien = effet_soutien(j.effet)
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


static func _decrire(j: Dictionary) -> String:
	var s: String = Regles.g.texte_forme[j.forme] + " Effet : " + Regles.g.texte_effet[j.effet]
	if j.effet2 != "":
		s += ", puis " + Regles.g.texte_effet[j.effet2] + " (atténué)"
	s += "."
	var mods := PackedStringArray()
	for m in j.mods_forme:
		mods.append(Regles.g.texte_modificateur[m][0])
	for m in j.mods_effet:
		mods.append(Regles.g.texte_modificateur[m][1])
	if mods.size() > 0:
		s += " Modificateurs : " + ", ".join(mods) + "."
	return s


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
