class_name PartieLocale
extends RefCounted
## La partie du joueur, jouée entièrement dans le jeu (sans serveur).
## Copie fidèle de server/internal/game ; les réponses ont exactement le
## même format que l'API HTTP du serveur Go.

const ERR := {
	"nom": "le nom doit faire entre 2 et 20 caractères",
	"region": "région inconnue ou non jouable",
	"village": "type de village inconnu",
	"points": "pas assez de points à répartir",
	"element": "élément indisponible",
	"pas_de_choix": "aucun élément à choisir pour l'instant",
	"pas_de_ninja": "aucun ninja : créez-en un d'abord",
	"ninja_existe": "un ninja existe déjà",
	"combat_en_cours": "un combat est déjà en cours",
	"pas_de_combat": "aucun combat en cours",
	"rencontre": "rencontre inconnue",
	"niveau": "niveau trop bas pour cette zone",
}

var chemin := "user://ninja.save.json"
var ninja = null  # Dictionary ou null
var combat: CombatMoteur = null
var rencontre = null
var _vus := 0


func _init(fichier: String = "user://ninja.save.json") -> void:
	chemin = fichier
	if FileAccess.file_exists(chemin):
		var n = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if n is Dictionary and n.get("nom", "") != "":
			ninja = n
			# Les noms des jutsus peuvent évoluer d'une version à l'autre.
			for k in ninja.grimoire.values():
				var res := Grammaire.analyser(k.sequence)
				if res.jutsu != null:
					k.nom = res.jutsu.nom


func _sauver() -> void:
	if ninja == null:
		return
	var tmp := chemin + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(ninja, " "))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(chemin))


static func ok(data) -> Dictionary:
	return {"ok": true, "data": data}


static func ko(cle: String) -> Dictionary:
	return {"ok": false, "erreur": ERR.get(cle, cle)}


# --- Le ninja -------------------------------------------------------------------

static func xp_pour_niveau(n: int) -> int:
	return 40 * n + 8 * n * n


func pv_max() -> int:
	var pv: int = 60 + int(ninja.fangan) * 4 + int(ninja.niveau) * 6
	return pv * (100 + int(Regles.villages[ninja.type_village].bonus_pv)) / 100


func souffle_max() -> int:
	var s: int = 40 + int(ninja.gnanga) * 3 + int(ninja.niveau) * 2
	return s * (100 + int(Regles.villages[ninja.type_village].bonus_souffle)) / 100


func nombre_legendaires() -> int:
	var k := 0
	for j in ninja.grimoire.values():
		if j.legendaire:
			k += 1
	return k


func elements_max() -> int:
	return 1 + int(ninja.niveau) / int(Regles.c.palier_element) + nombre_legendaires()


func mudras_permis() -> Dictionary:
	var p := {}
	for m in Regles.d.mudras:
		if Regles.debloque(m, int(ninja.niveau), ninja.elements):
			p[m.id] = true
	return p


func mudras_par_tour() -> int:
	return 3 + int(ninja.gnanga) / 15


func _gagner_xp(xp: int) -> int:
	var bonus := int(Regles.villages[ninja.type_village].bonus_xp)
	ninja.xp = int(ninja.xp) + xp * (100 + bonus) / 100
	var gagnes := 0
	var nmax := int(Regles.c.niveau_max)
	while int(ninja.niveau) < nmax and int(ninja.xp) >= xp_pour_niveau(int(ninja.niveau)):
		ninja.xp = int(ninja.xp) - xp_pour_niveau(int(ninja.niveau))
		ninja.niveau = int(ninja.niveau) + 1
		gagnes += 1
		ninja.points = int(ninja.points) + int(Regles.c.points_par_niveau)
		var attr: String = Regles.regions[ninja.region].attribut
		ninja[attr] = int(ninja[attr]) + 1
		if int(ninja.niveau) % int(Regles.c.palier_element) == 0:
			ninja.elements_a_choisir = int(ninja.elements_a_choisir) + 1
	if int(ninja.niveau) == nmax:
		ninja.xp = 0
	return gagnes


## Inscrit un jutsu au grimoire ; renvoie true si c'est une nouveauté.
func _apprendre(j: Dictionary, maitrise: int) -> bool:
	if ninja.grimoire.has(j.cle):
		var ex: Dictionary = ninja.grimoire[j.cle]
		if maitrise > int(ex.maitrise):
			ex.maitrise = maitrise
		return false
	ninja.grimoire[j.cle] = {
		"cle": j.cle, "sequence": j.sequence.duplicate(), "nom": j.nom, "element": j.element,
		"legendaire": j.legendaire != "", "maitrise": maitrise, "usages": 0, "decouvert": Time.get_unix_time_from_system(),
	}
	if j.legendaire != "":
		ninja.elements_a_choisir = int(ninja.elements_a_choisir) + 1
	return true


func _pratiquer(cle: String, fois: int) -> void:
	var j = ninja.grimoire.get(cle)
	if j == null:
		return
	var mmax := int(Regles.c.maitrise_max)
	for i in fois:
		if int(j.maitrise) >= mmax:
			break
		j.maitrise = int(j.maitrise) + maxi(1, (mmax - int(j.maitrise)) / 20)
		j.usages = int(j.usages) + 1
	j.maitrise = mini(int(j.maitrise), mmax)


func _combattant(moment: Dictionary) -> Dictionary:
	var maitrise := {}
	for k in ninja.grimoire:
		maitrise[k] = int(ninja.grimoire[k].maitrise)
	return {
		"id": "joueur", "nom": ninja.nom, "camp": 0, "rang": 1, "joueur": true, "apparence": "ninja_" + ninja.type_village,
		"niveau": int(ninja.niveau), "fangan": int(ninja.fangan), "gnanga": int(ninja.gnanga), "manhis": int(ninja.manhis),
		"pv": pv_max(), "pv_max": pv_max(), "souffle": souffle_max(), "souffle_max": souffle_max(),
		"element": ninja.elements[0], "elements": ninja.elements.duplicate(), "arme": ninja.arme.duplicate(),
		"defense": int(ninja.fangan) / 2, "absorption": 0, "garde": false, "statuts": [], "incantation": null,
		"_maitrise": maitrise, "_permis": mudras_permis(),
		"_contexte": {"niveau": int(ninja.niveau), "elements": ninja.elements.duplicate()},
		"_precis": bool(Regles.villages[ninja.type_village].resonance),
	}


static func _instancier(r: Dictionary) -> Array:
	var out := []
	var i := 0
	for m in r.ennemis:
		var lv := int(r.niveau)
		var f := {
			"id": "pnj%d" % (i + 1), "nom": m.nom, "camp": 1, "rang": i + 1, "joueur": false, "apparence": m.apparence,
			"niveau": lv, "fangan": int(m.fangan) + lv, "gnanga": int(m.gnanga) + lv, "manhis": int(m.manhis) + lv / 2,
			"element": m.element, "elements": [m.element] if m.element != "" else [], "arme": m.arme.duplicate(),
			"absorption": 0, "garde": false, "statuts": [], "incantation": null, "_ia": m.ia, "_jutsus": [],
		}
		f.pv_max = int(m.pv) + lv * 8
		f.pv = f.pv_max
		f.souffle_max = 40 + int(f.gnanga) * 3
		f.souffle = f.souffle_max
		f.defense = int(f.fangan) / 2
		for seq in (m.jutsus if m.jutsus != null else []):
			var res := Grammaire.analyser(seq)
			if res.jutsu != null:
				f._jutsus.append(res.jutsu)
		out.append(f)
		i += 1
	return out


# --- Vues (même format que l'API du serveur) -----------------------------------------

func _vue_jutsu(j: Dictionary) -> Dictionary:
	var m := int(Regles.c.maitrise_decouverte)
	var usages := 0
	var k = ninja.grimoire.get(j.cle)
	if k != null:
		m = int(k.maitrise)
		usages = int(k.usages)
	var mpt := mudras_par_tour()
	return {
		"cle": j.cle, "nom": j.nom, "nature": j.get("nature", ""), "sequence": j.sequence, "element": j.element, "forme": j.forme,
		"soutien": j.soutien, "legendaire": j.legendaire != "", "texte": j.texte,
		"cout": CombatMoteur.cout_reel(j, m), "tours": (j.sequence.size() + mpt - 1) / mpt,
		"maitrise": m, "usages": usages,
	}


func vue_ninja():
	if ninja == null:
		return null
	var v: Dictionary = ninja.duplicate(true)
	v.region_nom = Regles.regions[ninja.region].nom
	v.pv_max = pv_max()
	v.souffle_max = souffle_max()
	v.xp_prochain = xp_pour_niveau(int(ninja.niveau))
	v.mudras_par_tour = mudras_par_tour()
	v.elements_max = elements_max()
	var permis := mudras_permis().keys()
	permis.sort()
	v.permis = permis
	var connus: Array = ninja.grimoire.values()
	connus.sort_custom(func(a, b): return float(a.decouvert) < float(b.decouvert))
	var jutsus := []
	for k in connus:
		var res := Grammaire.analyser(k.sequence)
		if res.jutsu != null:
			jutsus.append(_vue_jutsu(res.jutsu))
	v.jutsus = jutsus
	return v


static func ciel(m: Dictionary) -> Dictionary:
	return {
		"heure": m.texte, "nuit": Regles.est_nuit(m), "phase_lune": Regles.nom_phase(m),
		"illumination": Regles.illumination(m), "facteur_soleil": Regles.facteur_soleil(m), "facteur_lune": Regles.facteur_lune(m),
	}


func etat() -> Dictionary:
	return ok({"ninja": vue_ninja(), "combat": combat.vue(0) if combat != null else null, "ciel": ciel(Regles.maintenant())})


func catalogue() -> Dictionary:
	var mudras := []
	for m in Regles.d.mudras:
		var mp := {"id": m.id, "nom": m.nom, "categorie": m.categorie, "niveau": m.niveau}
		if m.categorie == "element":
			mp.element = m.ref
		mudras.append(mp)
	return ok({
		"version": Regles.d.version, "regions": Regles.d.regions, "villages": Regles.d.villages,
		"elements": Regles.d.elements, "mudras": mudras, "niveau_max": Regles.c.niveau_max,
		"legendaires": Regles.d.legendaires.nombre,
	})


# --- Actions ------------------------------------------------------------------------

func creer(nom: String, region: String, type_village: String) -> Dictionary:
	if ninja != null:
		return ko("ninja_existe")
	nom = nom.strip_edges()
	if nom.length() < 2 or nom.length() > 20:
		return ko("nom")
	var r = Regles.regions.get(region)
	if r == null or not r.jouable:
		return ko("region")
	var tv = Regles.villages.get(type_village)
	if tv == null:
		return ko("village")
	var depart := int(Regles.c.attribut_depart)
	ninja = {
		"nom": nom, "region": region, "type_village": type_village,
		"village": r.villages[Regles.village_index(type_village)],
		"niveau": 1, "xp": 0, "points": 0, "fangan": depart, "gnanga": depart, "manhis": depart,
		"elements": [r.element], "elements_a_choisir": 0, "grimoire": {}, "dje": 50,
		"arme": {"nom": "un sabre court", "puissance": 6 + int(tv.bonus_arme), "distance": false},
		"victoires": 0, "defaites": 0, "creation": Time.get_datetime_string_from_system(true),
	}
	ninja[r.attribut] = depart + int(Regles.c.bonus_region)
	_sauver()
	return ok(vue_ninja())


func abandonner() -> Dictionary:
	ninja = null
	combat = null
	rencontre = null
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	return ok({"ok": true})


func repartir(f: int, g: int, m: int) -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if f < 0 or g < 0 or m < 0 or f + g + m > int(ninja.points):
		return ko("points")
	ninja.fangan = int(ninja.fangan) + f
	ninja.gnanga = int(ninja.gnanga) + g
	ninja.manhis = int(ninja.manhis) + m
	ninja.points = int(ninja.points) - (f + g + m)
	_sauver()
	return ok(vue_ninja())


func choisir_element(id: String) -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if int(ninja.elements_a_choisir) <= 0:
		return ko("pas_de_choix")
	var e = Regles.elements.get(id)
	if e == null or e.tier != "base" or ninja.elements.has(id):
		return ko("element")
	ninja.elements.append(id)
	ninja.elements_a_choisir = int(ninja.elements_a_choisir) - 1
	_sauver()
	return ok(vue_ninja())


func dojo(seq: Array) -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if seq.size() > int(Regles.g.longueur_max):
		return ko(CombatMoteur.ERR_SEQUENCE)
	var permis := mudras_permis()
	for id in seq:
		if not permis.has(id):
			return ko(CombatMoteur.ERR_MUDRA)
	var r := {"valide": false, "nouveau": false, "message": ""}
	var res := Grammaire.analyser(seq)
	var j = res.jutsu
	var refus := ""
	if j != null:
		if j.legendaire != "":
			refus = Grammaire.verifier(j.conditions, int(ninja.niveau), ninja.elements, Regles.maintenant())
		elif j.fusion and int(ninja.niveau) < int(Regles.c.niveau_fusion):
			refus = "Deux éléments veulent se fondre… mais il faut un Souffle plus mûr pour les fusionner."
	if refus != "":
		r.refus = refus
		r.message = refus
	elif j != null:
		r.valide = true
		r.nouveau = _apprendre(j, int(Regles.c.maitrise_decouverte))
		r.jutsu = _vue_jutsu(j)
		if r.nouveau and j.legendaire != "":
			r.message = "JUTSU LÉGENDAIRE DÉCOUVERT : " + j.nom + " ! Un nouvel élément s'offre à vous."
		elif r.nouveau:
			r.message = "Nouveau jutsu découvert : " + j.nom + " !"
		else:
			r.message = "Vous connaissez déjà ce jutsu : " + j.nom + "."
	else:
		var reso := Grammaire.resonner(seq, res.echec, bool(Regles.villages[ninja.type_village].resonance))
		r.resonance = reso
		r.message = reso.message
	r.ninja = vue_ninja()
	_sauver()
	return ok(r)


func liste_rencontres() -> Dictionary:
	var out := []
	for rc in Regles.d.rencontres:
		var noms := []
		for e in rc.ennemis:
			noms.append(e.nom)
		out.append({
			"id": rc.id, "nom": rc.nom, "lieu": rc.lieu, "description": rc.description, "niveau": rc.niveau,
			"ennemis": noms, "xp": rc.xp, "dje": rc.dje, "accessible": ninja != null and int(ninja.niveau) >= int(rc.niveau),
		})
	return ok(out)


func demarrer_combat(id: String) -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if combat != null and not combat.fini:
		return ko("combat_en_cours")
	var r = Regles.rencontres.get(id)
	if r == null:
		return ko("rencontre")
	if int(ninja.niveau) < int(r.niveau):
		return ko("niveau")
	var liste := [_combattant(Regles.maintenant())]
	liste.append_array(_instancier(r))
	combat = CombatMoteur.new(id, liste, int(Time.get_unix_time_from_system() * 1000.0))
	rencontre = r
	_vus = 0
	return ok(combat.vue(0))


func agir(a: Dictionary) -> Dictionary:
	if combat == null or combat.fini:
		return ko("pas_de_combat")
	a = a.duplicate()
	a.acteur = "joueur"
	var res := combat.jouer_tour([a])
	if res.has("erreur"):
		return ko(res.erreur)
	# Les découvertes sont inscrites tout de suite : elles ne se perdent pas.
	while _vus < combat.decouvertes.size():
		_apprendre(combat.decouvertes[_vus].jutsu, int(Regles.c.maitrise_decouverte))
		_vus += 1
	var sortie := {"evenements": res.evenements, "combat": combat.vue(0), "fin": null}
	if combat.fini:
		sortie.fin = _terminer()
	sortie.ninja = vue_ninja()
	_sauver()
	return ok(sortie)


func fuir() -> Dictionary:
	if combat == null or combat.fini:
		return ko("pas_de_combat")
	combat.fini = true
	combat.vainqueur = 1
	var sortie := {
		"evenements": [{"type": "fin", "valeur": 1, "texte": ninja.nom + " prend la fuite.", "acteur": "", "cible": "", "element": "", "jutsu": ""}],
		"combat": combat.vue(0), "fin": _terminer(),
	}
	sortie.ninja = vue_ninja()
	_sauver()
	return ok(sortie)


func _terminer() -> Dictionary:
	var fin := {"victoire": false, "nul": false, "xp": 0, "dje": 0, "niveaux_gagnes": 0, "maitrise": {}, "message": ""}
	# La pratique paie, même dans la défaite.
	for cle in combat.usages:
		_pratiquer(cle, int(combat.usages[cle]))
		var k = ninja.grimoire.get(cle)
		if k != null:
			fin.maitrise[k.nom] = int(k.maitrise)
	match combat.vainqueur:
		0:
			fin.victoire = true
			fin.xp = int(rencontre.xp)
			fin.dje = int(rencontre.dje)
			ninja.dje = int(ninja.dje) + fin.dje
			ninja.victoires = int(ninja.victoires) + 1
			fin.niveaux_gagnes = _gagner_xp(fin.xp)
			fin.message = "Victoire ! Vous gagnez de l'expérience et des Djê."
		2:
			fin.nul = true
			fin.xp = int(rencontre.xp) / 4
			fin.niveaux_gagnes = _gagner_xp(fin.xp)
			fin.message = "Match nul. Les deux camps se retirent, épuisés."
		_:
			ninja.defaites = int(ninja.defaites) + 1
			fin.message = "Défaite. Vous renaissez dans votre village. (Quand l'inventaire existera, vos objets iront au vainqueur.)"
	return fin


## Point d'entrée unique, qui imite les routes de l'API du serveur.
func appel(methode: String, route: String, corps: Dictionary) -> Dictionary:
	match methode + " " + route:
		"GET /api/sante":
			return ok({"etat": "ok", "jeu": "ninja-ivoire", "version": Regles.d.version})
		"GET /api/catalogue":
			return catalogue()
		"GET /api/etat":
			return etat()
		"POST /api/ninja":
			return creer(str(corps.get("nom", "")), str(corps.get("region", "")), str(corps.get("village", "")))
		"DELETE /api/ninja":
			return abandonner()
		"POST /api/ninja/attributs":
			return repartir(int(corps.get("fangan", 0)), int(corps.get("gnanga", 0)), int(corps.get("manhis", 0)))
		"POST /api/ninja/element":
			return choisir_element(str(corps.get("element", "")))
		"POST /api/dojo":
			return dojo(corps.get("sequence", []))
		"GET /api/rencontres":
			return liste_rencontres()
		"POST /api/combat":
			return demarrer_combat(str(corps.get("rencontre", "")))
		"POST /api/combat/action":
			return agir(corps)
		"POST /api/combat/fuite":
			return fuir()
	return {"ok": false, "erreur": "route inconnue : " + route}
