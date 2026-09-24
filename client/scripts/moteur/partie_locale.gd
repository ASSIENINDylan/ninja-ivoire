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
	"pas_adjacent": "on ne se déplace que d'une case à la fois",
	"hors_pays": "impossible de quitter le pays",
	"infranchi": "le lac barre la route",
	"pas_de_repos": "on ne se repose que dans un village de sa région ou du Cœur",
	"rien_a_defier": "il n'y a personne à défier ici",
	"jutsu_inconnu": "ce jutsu n'est pas dans votre grimoire",
	"favoris_pleins": "5 jutsus favoris au maximum : retirez-en un d'abord",
	"pas_favori": "ce jutsu n'est pas parmi vos 5 favoris : en combat, seuls vos favoris et les suites encore inconnues se lancent",
	"retenu": "vous êtes retenu : impossible de fuir",
}

var chemin := "user://ninja.save.json"
var ninja = null  # Dictionary ou null
var combat: CombatMoteur = null
var rencontre = null
var niveau_combat := 1
var _vus := 0
var _fuite := false
## Tire un nombre dans [0, 1) (remplaçable dans les tests).
var hasard: Callable = randf
## L'heure en secondes (remplaçable dans les tests).
var horloge: Callable = func() -> int: return int(Time.get_unix_time_from_system())


func _init(fichier: String = "user://ninja.save.json") -> void:
	chemin = fichier
	if FileAccess.file_exists(chemin):
		var n = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if n is Dictionary and n.get("nom", "") != "":
			ninja = n
			_initialiser_carte()
			_initialiser_favoris()
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
	# Les premières découvertes deviennent favorites, jusqu'à cinq.
	if ninja.favoris.size() < int(Regles.c.favoris_max):
		ninja.favoris.append(j.cle)
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
		"pv": maxi(1, mini(int(ninja.pv), pv_max())), "pv_max": pv_max(), "souffle": souffle_max(), "souffle_max": souffle_max(),
		"element": ninja.elements[0], "elements": ninja.elements.duplicate(), "arme": ninja.arme.duplicate(),
		"defense": int(ninja.fangan) / 2, "defense_mag": int(ninja.gnanga) / 2, "clone": false, "absorption": 0, "garde": false, "statuts": [], "incantation": null,
		"_maitrise": maitrise, "_permis": mudras_permis(),
		"_contexte": {"niveau": int(ninja.niveau), "elements": ninja.elements.duplicate()},
		"_precis": bool(Regles.villages[ninja.type_village].resonance),
	}


static func _instancier(r: Dictionary, niveau: int) -> Array:
	var out := []
	var i := 0
	# Un groupe se partage la force : chacun est un peu plus faible.
	var groupe := 0.8 if r.ennemis.size() > 1 else 1.0
	for m in r.ennemis:
		var lv := maxi(1, niveau)
		var f := {
			"id": "pnj%d" % (i + 1), "nom": m.nom, "camp": 1, "rang": i + 1, "joueur": false, "apparence": m.apparence,
			"niveau": lv, "fangan": int(float(int(m.fangan) + lv) * groupe), "gnanga": int(float(int(m.gnanga) + lv) * groupe),
			"manhis": int(m.manhis) + lv / 2, "clone": false,
			"element": m.element, "elements": [m.element] if m.element != "" else [], "arme": m.arme.duplicate(),
			"absorption": 0, "garde": false, "statuts": [], "incantation": null, "_ia": m.ia, "_jutsus": [],
		}
		f.pv_max = int(float(int(m.pv) + lv * 8) * groupe)
		f.pv = f.pv_max
		f.souffle_max = 40 + int(f.gnanga) * 3
		f.souffle = f.souffle_max
		f.defense = int(f.fangan) / 2
		f.defense_mag = int(f.gnanga) / 2
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
	var f := {"fangan": ninja.fangan, "gnanga": ninja.gnanga, "manhis": ninja.manhis}
	return {
		"cle": j.cle, "nom": j.nom, "nature": j.get("nature", ""), "sequence": j.sequence, "element": j.element, "forme": j.forme,
		"type": j.type, "degats_nature": j.degats_nature, "puissance": int(round(CombatMoteur.puissance_de(f, j, m, 1.0))),
		"soutien": j.soutien, "legendaire": j.legendaire != "", "texte": j.texte,
		"cout": CombatMoteur.cout_reel(j, m), "tours": (j.sequence.size() + mpt - 1) / mpt,
		"maitrise": m, "usages": usages, "favori": ninja.get("favoris", []).has(j.cle),
	}


func vue_ninja():
	if ninja == null:
		return null
	_maj_endurance()
	_maj_pv()
	var v: Dictionary = ninja.duplicate(true)
	v.situation = _situation()
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
		"legendaires": Regles.d.legendaires.nombre, "carte": Regles.d.carte,
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
		"elements": [r.element], "elements_a_choisir": 0, "grimoire": {}, "favoris": [], "dje": 50,
		"arme": {"nom": "un sabre court", "puissance": 6 + int(tv.bonus_arme), "distance": false},
		"victoires": 0, "defaites": 0, "creation": Time.get_datetime_string_from_system(true),
	}
	ninja[r.attribut] = depart + int(Regles.c.bonus_region)
	_initialiser_carte()
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
	return ok(_demarrer(r, int(r.niveau)))


func _demarrer(r: Dictionary, niveau: int) -> Dictionary:
	var liste := [_combattant(Regles.maintenant())]
	liste.append_array(_instancier(r, niveau))
	combat = CombatMoteur.new(r.id, liste, int(Time.get_unix_time_from_system() * 1000.0))
	rencontre = r
	niveau_combat = niveau
	_vus = 0
	_fuite = false
	return combat.vue(0)


static func recompenses(r: Dictionary, niveau: int) -> Array:
	niveau = maxi(1, niveau)
	return [int(r.xp) * niveau / int(r.niveau), int(r.dje) * niveau / int(r.niveau)]


func agir(a: Dictionary) -> Dictionary:
	if combat == null or combat.fini:
		return ko("pas_de_combat")
	a = a.duplicate()
	a.acteur = "joueur"
	if a.get("type", "") == "incanter" and a.get("sequence", []).size() > 0:
		# En combat, seuls les favoris et les suites encore inconnues.
		var j = Grammaire.analyser(a.sequence).jutsu
		if j != null and ninja.grimoire.has(j.cle) and not ninja.favoris.has(j.cle):
			return ko("pas_favori")
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
	var moi = combat.get_c("joueur")
	if moi != null and CombatMoteur.a_statut(moi, "retenu"):
		return ko("retenu")
	combat.fini = true
	combat.vainqueur = 1
	_fuite = true
	var sortie := {
		"evenements": [{"type": "fin", "valeur": 1, "texte": ninja.nom + " prend la fuite.", "acteur": "", "cible": "", "element": "", "jutsu": ""}],
		"combat": combat.vue(0), "fin": _terminer(),
	}
	sortie.ninja = vue_ninja()
	_sauver()
	return ok(sortie)


func _terminer() -> Dictionary:
	var fin := {"victoire": false, "nul": false, "defaite": false, "xp": 0, "dje": 0, "niveaux_gagnes": 0, "maitrise": {}, "message": ""}
	# La pratique paie, même dans la défaite.
	for cle in combat.usages:
		_pratiquer(cle, int(combat.usages[cle]))
		var k = ninja.grimoire.get(cle)
		if k != null:
			fin.maitrise[k.nom] = int(k.maitrise)
	# Les blessures restent ; les baumes agissent après le combat.
	fin.baume = 0
	var moi = combat.get_c("joueur")
	if moi != null:
		ninja.pv = maxi(0, int(moi.pv))
		ninja.pv_maj = horloge.call()
		if int(moi.pv) > 0:
			fin.baume = mini(CombatMoteur.baume(moi), pv_max() - int(ninja.pv))
			ninja.pv = int(ninja.pv) + fin.baume
	if combat.vainqueur == 0:
		fin.victoire = true
		var rec := recompenses(rencontre, niveau_combat)
		fin.xp = rec[0]
		fin.dje = rec[1]
		ninja.dje = int(ninja.dje) + fin.dje
		ninja.victoires = int(ninja.victoires) + 1
		fin.niveaux_gagnes = _gagner_xp(fin.xp)
		fin.message = "Victoire ! Vous gagnez de l'expérience et des Djê."
	elif combat.vainqueur == 2:
		fin.nul = true
		fin.xp = int(recompenses(rencontre, niveau_combat)[0]) / 4
		fin.niveaux_gagnes = _gagner_xp(fin.xp)
		fin.message = "Match nul. Les deux camps se retirent, épuisés."
	elif _fuite and int(ninja.pv) > 0:
		fin.defaite = true
		fin.message = "Vous prenez la fuite, blessé mais vivant."
	else:
		ninja.defaites = int(ninja.defaites) + 1
		_renaitre()
		fin.defaite = true
		fin.message = "Défaite. Vous renaissez dans votre village. (Quand l'inventaire existera, vos objets iront au vainqueur.)"
	if fin.baume > 0 and int(ninja.pv) > 0:
		fin.message += " Un baume de Souffle referme vos plaies (+%d PV)." % fin.baume
	fin.pv = int(ninja.pv)
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
		"POST /api/ninja/favori":
			return choisir_favori(str(corps.get("cle", "")), bool(corps.get("favori", false)))
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
		"POST /api/carte/deplacer":
			return deplacer(int(corps.get("x", -1)), int(corps.get("y", -1)))
		"POST /api/carte/reposer":
			return reposer()
		"POST /api/carte/defier":
			return defier()
	return {"ok": false, "erreur": "route inconnue : " + route}


# --- Carte : déplacements, endurance, brouillard -------------------------------------

func _initialiser_carte() -> void:
	var taille := int(Regles.carte().l) * int(Regles.carte().h)
	if str(ninja.get("explore", "")).length() == taille:
		return
	var v = village_natal()
	ninja.position = [int(v.x), int(v.y)]
	ninja.endurance = int(Regles.c.endurance_max)
	ninja.endurance_maj = horloge.call()
	ninja.explore = "0".repeat(taille)
	for l in Regles.carte().lieux:
		if l.type == "village" and (l.region == ninja.region or l.region == "coeur"):
			_reveler(int(l.x), int(l.y), 1)
	_reveler(int(v.x), int(v.y), int(Regles.c.rayon_vision) + 2)


func village_natal():
	return Regles.village_de(ninja.region, ninja.type_village)


func _reveler(x: int, y: int, rayon: int) -> void:
	var l := int(Regles.carte().l)
	var b: PackedByteArray = str(ninja.explore).to_ascii_buffer()
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			if Regles.dans(x + dx, y + dy):
				b[(y + dy) * l + x + dx] = 49  # « 1 »
	ninja.explore = b.get_string_from_ascii()


func _maj_endurance() -> void:
	var emax := int(Regles.c.endurance_max)
	var t: int = horloge.call()
	if int(ninja.endurance) >= emax:
		ninja.endurance = emax
		ninja.endurance_maj = t
		return
	var regen := int(Regles.c.regen_secondes)
	var gain: int = (t - int(ninja.endurance_maj)) / regen
	if gain > 0:
		ninja.endurance = mini(emax, int(ninja.endurance) + gain)
		ninja.endurance_maj = int(ninja.endurance_maj) + gain * regen


func _renaitre() -> void:
	var v = village_natal()
	ninja.position = [int(v.x), int(v.y)]
	ninja.endurance = int(Regles.c.endurance_max)
	ninja.endurance_maj = horloge.call()
	ninja.pv = pv_max()
	ninja.pv_maj = horloge.call()


## Les blessures guérissent avec le temps (une demi-heure pour tout guérir).
func _maj_pv() -> void:
	var pmax := pv_max()
	var t: int = horloge.call()
	if int(ninja.get("pv", 0)) <= 0 or int(ninja.get("pv_maj", 0)) == 0:
		ninja.pv = pmax
	if int(ninja.pv) >= pmax:
		ninja.pv = pmax
		ninja.pv_maj = t
		return
	var gain := int(float(pmax) * float(t - int(ninja.pv_maj)) / float(Regles.c.regen_pv_secondes))
	if gain > 0:
		ninja.pv = mini(pmax, int(ninja.pv) + gain)
		ninja.pv_maj = t


func _peut_se_reposer(l) -> bool:
	return l != null and l.type == "village" and (l.region == ninja.region or l.region == "coeur")


func _lieu_actuel():
	var cel = Regles.case_(int(ninja.position[0]), int(ninja.position[1]))
	if cel == null or cel.lieu < 0:
		return null
	return Regles.lieu(cel.lieu)


func _situation() -> Dictionary:
	var cel = Regles.case_(int(ninja.position[0]), int(ninja.position[1]))
	var s := {
		"terrain": cel.terrain, "terrain_nom": Regles.carte().noms_terrains[cel.terrain],
		"zone": Regles.zone(cel.zone), "lieu": null, "repos": false, "village": false,
		"endurance_max": int(Regles.c.endurance_max), "regen_dans": 0,
	}
	var l = _lieu_actuel()
	if l != null:
		s.lieu = l
		s.repos = _peut_se_reposer(l)
		s.village = l.type == "village" and l.region == ninja.region and l.get("type_village", "") == ninja.type_village
	if int(ninja.endurance) < int(Regles.c.endurance_max):
		s.regen_dans = int(ninja.endurance_maj) + int(Regles.c.regen_secondes) - int(horloge.call())
	return s


## Avance le ninja d'une case (huit directions).
func deplacer(x: int, y: int) -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if combat != null and not combat.fini:
		return ko("combat_en_cours")
	var dx: int = x - int(ninja.position[0])
	var dy: int = y - int(ninja.position[1])
	if dx < -1 or dx > 1 or dy < -1 or dy > 1 or (dx == 0 and dy == 0):
		return ko("pas_adjacent")
	var cel = Regles.case_(x, y)
	if cel == null:
		return ko("hors_pays")
	var cout := Regles.cout_terrain(cel.terrain)
	if cout == 0:
		return ko("infranchi")
	var z := Regles.zone(cel.zone)
	if int(ninja.niveau) < int(z.niveau):
		return ko("les environs de %s sont trop dangereux : niveau %d requis" % [z.nom, int(z.niveau)])
	_maj_endurance()
	if int(ninja.endurance) < cout:
		return ko("trop fatigué : il faut %d d'endurance (un point par minute, ou repos au village)" % cout)
	var ancienne: int = Regles.case_(int(ninja.position[0]), int(ninja.position[1])).zone
	if int(ninja.endurance) == int(Regles.c.endurance_max):
		ninja.endurance_maj = horloge.call()
	ninja.endurance = int(ninja.endurance) - cout
	ninja.position = [x, y]
	_reveler(x, y, int(Regles.c.rayon_vision))
	var res := {"message": "", "combat": null, "rencontre": ""}
	if cel.lieu >= 0:
		res.message = "Vous arrivez à " + Regles.lieu(cel.lieu).nom + "."
	elif cel.zone != ancienne:
		res.message = "Vous entrez dans les environs de %s (niveau %d)." % [z.nom, int(z.niveau)]
	# En pleine nature, on peut faire une mauvaise rencontre.
	var choix: Array = Regles.d.sauvages.get(cel.terrain, [])
	if cel.lieu < 0 and choix.size() > 0 and float(hasard.call()) < float(Regles.c.chance_rencontre):
		var r: Dictionary = Regles.rencontres[choix[int(float(hasard.call()) * choix.size()) % choix.size()]]
		res.combat = _demarrer(r, int(z.niveau))
		res.rencontre = r.nom
		res.message = r.nom + " vous barre la route !"
	res.ninja = vue_ninja()
	_sauver()
	return ok(res)


## Rend toute l'endurance, dans un village ami.
func reposer() -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if not _peut_se_reposer(_lieu_actuel()):
		return ko("pas_de_repos")
	ninja.endurance = int(Regles.c.endurance_max)
	ninja.endurance_maj = horloge.call()
	ninja.pv = pv_max()
	ninja.pv_maj = horloge.call()
	_sauver()
	return ok({"ninja": vue_ninja(), "message": "Vous vous reposez : vos blessures sont pansées et votre endurance est au maximum."})


## Lance la rencontre du lieu où se trouve le ninja.
func defier() -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if combat != null and not combat.fini:
		return ko("combat_en_cours")
	var l = _lieu_actuel()
	if l == null or l.get("rencontre", "") == "":
		return ko("rien_a_defier")
	if int(ninja.niveau) < int(l.niveau):
		return ko("%s : niveau %d requis" % [l.nom, int(l.niveau)])
	var r: Dictionary = Regles.rencontres[l.rencontre]
	var vue := _demarrer(r, int(l.niveau))
	return ok({"ninja": vue_ninja(), "combat": vue, "rencontre": r.nom, "message": l.nom + " : le combat commence."})


# --- Favoris : les jutsus sous la main en combat ------------------------------------

func _initialiser_favoris() -> void:
	if ninja.get("favoris") == null:
		var connus: Array = ninja.grimoire.values()
		connus.sort_custom(func(a, b): return float(a.decouvert) < float(b.decouvert))
		ninja.favoris = []
		for k in connus:
			if ninja.favoris.size() < int(Regles.c.favoris_max):
				ninja.favoris.append(k.cle)
	ninja.favoris = ninja.favoris.filter(func(c): return ninja.grimoire.has(c))


func choisir_favori(cle: String, favori: bool) -> Dictionary:
	if ninja == null:
		return ko("pas_de_ninja")
	if not ninja.grimoire.has(cle):
		return ko("jutsu_inconnu")
	if not favori:
		ninja.favoris = ninja.favoris.filter(func(c): return c != cle)
	elif not ninja.favoris.has(cle):
		if ninja.favoris.size() >= int(Regles.c.favoris_max):
			return ko("favoris_pleins")
		ninja.favoris.append(cle)
	_sauver()
	return ok(vue_ninja())
