extends SceneTree
## Partie complète avec le moteur local : création, dojo, combats.
## godot --headless --path client --script res://tests/test_partie.gd

var echecs := 0


func verifier(cond: bool, msg: String) -> void:
	if not cond:
		echecs += 1
		print("ÉCHEC : ", msg)


func _init() -> void:
	verifier(Regles.charger() == "", "chargement des règles")
	var chemin := "user://test_partie.save.json"
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var p := PartieLocale.new(chemin)
	var r := p.appel("POST", "/api/ninja", {"nom": "Aya", "region": "lagunes", "village": "futuriste"})
	verifier(r.ok, "création : %s" % r.get("erreur", ""))
	verifier(p.ninja.elements[0] == "eau" and int(p.ninja.manhis) == 11, "les Lagunes donnent l'Eau et l'agilité")
	verifier(p.ninja.village == "Néo-Ébrié", "village futuriste des Lagunes")
	verifier(not p.appel("POST", "/api/ninja", {"nom": "Autre", "region": "lagunes", "village": "moderne"}).ok, "un seul ninja")

	r = p.appel("POST", "/api/dojo", {"sequence": ["lamantin", "martin_pecheur", "liane"]})
	verifier(r.ok and r.data.valide and r.data.nouveau, "découverte au dojo")
	r = p.appel("POST", "/api/dojo", {"sequence": ["lamantin", "martin_pecheur", "liane"]})
	verifier(r.ok and not r.data.nouveau, "pas de redécouverte")
	r = p.appel("POST", "/api/dojo", {"sequence": ["panthere", "martin_pecheur", "liane"]})
	verifier(not r.ok, "l'Eau ne forme pas le signe du Feu")
	r = p.appel("POST", "/api/dojo", {"sequence": ["lamantin", "lamantin", "case"]})
	verifier(not r.ok, "Case ronde verrouillée au niveau 1")
	r = p.appel("POST", "/api/dojo", {"sequence": ["lamantin", "lamantin", "mante"]})
	verifier(r.ok and r.data.resonance.ancienne, "vibration ancienne vers le Chant du Lamantin")

	var p2 := PartieLocale.new(chemin)
	verifier(p2.ninja != null and p2.ninja.grimoire.size() == 1, "la sauvegarde garde le grimoire")

	verifier(not p.appel("POST", "/api/combat", {"rencontre": "brigand"}).ok, "zone du brigand bloquée au niveau 1")
	var victoires := 0
	for essai in 6:
		p.ninja.pv = p.pv_max()  # les blessures durent : on repart soigné
		r = p.appel("POST", "/api/combat", {"rencontre": "chacals"})
		verifier(r.ok, "début du combat : %s" % r.get("erreur", ""))
		var fin = null
		for t in 70:
			var a := {"type": "incanter", "sequence": ["lamantin", "martin_pecheur", "braise"], "cible": "pnj1"} if t % 2 == 0 else {"type": "frapper", "cible": "pnj1"}
			r = p.appel("POST", "/api/combat/action", a)
			verifier(r.ok, "tour de combat : %s" % r.get("erreur", ""))
			if not r.ok:
				break
			for e in r.data.evenements:
				verifier(e.texte != "", "chaque événement a un texte")
			if r.data.fin != null:
				fin = r.data.fin
				break
		verifier(fin != null, "le combat se termine")
		if fin != null and fin.victoire:
			victoires += 1
	print("Victoires contre les chacals : %d / 6 · niveau %d · maîtrise %s" % [victoires, p.ninja.niveau, p.ninja.grimoire.values()[0].maitrise])
	verifier(victoires >= 4, "un ninja de niveau 1 bat en général les chacals")

	# Combat plus riche : l'esprit de Taï (soins, liens) contre un ninja de haut niveau.
	p.ninja.niveau = 12
	r = p.appel("POST", "/api/combat", {"rencontre": "sans_visage"})
	verifier(r.ok, "rituel des Sans-Visage")
	var tours := 0
	while r.ok and (r.data.get("fin") == null) and tours < 70:
		r = p.appel("POST", "/api/combat/action", {"type": "incanter", "sequence": ["lamantin", "martin_pecheur", "braise"], "cible": "pnj1"})
		tours += 1
	verifier(r.ok and r.data.fin != null, "le combat contre 3 adversaires se termine")
	print("Sans-Visage : %s en %d tours" % [r.data.fin.message if r.ok else r.erreur, tours])
	_test_carte()
	_test_favoris()
	print("Test partie : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func _test_carte() -> void:
	var chemin := "user://test_carte.save.json"
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var p := PartieLocale.new(chemin)
	p.appel("POST", "/api/ninja", {"nom": "Yao", "region": "lagunes", "village": "futuriste"})
	p.hasard = func() -> float: return 0.99
	var v = p.village_natal()
	verifier(int(p.ninja.position[0]) == int(v.x) and int(p.ninja.position[1]) == int(v.y), "naissance au village")
	verifier(not p.appel("POST", "/api/carte/deplacer", {"x": int(v.x) + 2, "y": int(v.y)}).ok, "pas de saut de deux cases")
	var r := p.appel("GET", "/api/etat", {})
	verifier(r.data.ninja.situation.village, "la situation dit qu'on est au village")
	# Un pas vers une case voisine de niveau 1.
	var fait := false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var cel = Regles.case_(int(v.x) + dx, int(v.y) + dy)
			if fait or (dx == 0 and dy == 0) or cel == null or Regles.cout_terrain(cel.terrain) == 0 or int(Regles.zone(cel.zone).niveau) > 1:
				continue
			var e0 := int(p.ninja.endurance)
			r = p.appel("POST", "/api/carte/deplacer", {"x": int(v.x) + dx, "y": int(v.y) + dy})
			verifier(r.ok and r.data.combat == null, "pas vers une case voisine : %s" % r.get("erreur", ""))
			verifier(int(p.ninja.endurance) == e0 - Regles.cout_terrain(cel.terrain), "le pas coûte de l'endurance")
			fait = true
	verifier(fait, "une case voisine praticable existe")
	# Endurance regagnée avec le temps.
	var t0: int = int(Time.get_unix_time_from_system())
	p.horloge = func() -> int: return t0 + 600
	r = p.appel("GET", "/api/etat", {})
	verifier(int(r.data.ninja.endurance) == int(Regles.c.endurance_max), "endurance pleine après 10 minutes")
	# Rencontre forcée en brousse, puis fuite et retour au village.
	p.hasard = func() -> float: return 0.0
	var combat_lance := false
	var pos: Array = p.ninja.position
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var x: int = int(pos[0]) + dx
			var y: int = int(pos[1]) + dy
			var cel = Regles.case_(x, y)
			if combat_lance or (dx == 0 and dy == 0) or cel == null or cel.lieu >= 0 or Regles.cout_terrain(cel.terrain) == 0 or int(Regles.zone(cel.zone).niveau) > 1:
				continue
			r = p.appel("POST", "/api/carte/deplacer", {"x": x, "y": y})
			combat_lance = r.ok and r.data.combat != null
	verifier(combat_lance, "une rencontre surgit en brousse")
	if combat_lance:
		verifier(not p.appel("POST", "/api/carte/deplacer", {"x": int(v.x), "y": int(v.y)}).ok, "pas de déplacement en combat")
		var ici: Array = p.ninja.position.duplicate()
		r = p.appel("POST", "/api/combat/fuite", {})
		verifier(r.ok and r.data.fin.defaite, "la fuite est une défaite")
		verifier(p.ninja.position == ici, "qui fuit reste sur place, sans renaître")
	# Repos et défi d'un lieu.
	p.ninja.position = [int(v.x), int(v.y)]
	p.ninja.endurance = 2
	verifier(p.appel("POST", "/api/carte/reposer", {}).ok and int(p.ninja.endurance) == int(Regles.c.endurance_max), "repos au village")
	var l = Regles.lieu_id("faubourgs_neo_ebrie")
	p.ninja.position = [int(l.x), int(l.y)]
	verifier(not p.appel("POST", "/api/carte/defier", {}).ok, "défi trop tôt")
	p.ninja.niveau = int(l.niveau)
	r = p.appel("POST", "/api/carte/defier", {})
	verifier(r.ok and r.data.rencontre == "Patrouille du Cercle d'Acier", "défi des faubourgs de Néo-Ébrié")


func _test_favoris() -> void:
	var chemin := "user://test_favoris.save.json"
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var p := PartieLocale.new(chemin)
	p.appel("POST", "/api/ninja", {"nom": "Ama", "region": "lagunes", "village": "moderne"})
	for s in [["lamantin", "martin_pecheur", "liane"], ["lamantin", "martin_pecheur", "kola"], ["lamantin", "martin_pecheur", "braise"],
			["lamantin", "mante", "liane"], ["lamantin", "mante", "braise"], ["lamantin", "tortue", "kola"]]:
		p.appel("POST", "/api/dojo", {"sequence": s})
	verifier(p.ninja.favoris.size() == 5 and not p.ninja.favoris.has("lamantin>tortue>kola"), "cinq premières découvertes favorites")
	verifier(not p.appel("POST", "/api/ninja/favori", {"cle": "lamantin>tortue>kola", "favori": true}).ok, "pas plus de cinq favoris")
	verifier(p.appel("POST", "/api/ninja/favori", {"cle": "lamantin>mante>liane", "favori": false}).ok, "retirer un favori")
	var r := p.appel("POST", "/api/ninja/favori", {"cle": "lamantin>tortue>kola", "favori": true})
	verifier(r.ok and p.ninja.favoris.has("lamantin>tortue>kola"), "ajouter un favori")
	var nb := 0
	for j in r.data.jutsus:
		if j.favori:
			nb += 1
	verifier(nb == 5, "la vue marque cinq favoris")
	var p2 := PartieLocale.new(chemin)
	verifier(p2.ninja.favoris.size() == 5, "les favoris sont sauvegardés")
	# En combat : seuls les favoris et les suites inconnues.
	r = p.appel("POST", "/api/combat", {"rencontre": "chacals"})
	verifier(r.ok, "combat des favoris")
	r = p.appel("POST", "/api/combat/action", {"type": "incanter", "sequence": ["lamantin", "mante", "liane"], "cible": "pnj1"})
	verifier(not r.ok, "un jutsu connu hors des favoris est refusé en combat")
	r = p.appel("POST", "/api/combat/action", {"type": "incanter", "sequence": ["lamantin", "martin_pecheur", "braise"], "cible": "pnj1"})
	verifier(r.ok, "un favori se lance : %s" % r.get("erreur", ""))
	if r.ok and r.data.fin == null:
		r = p.appel("POST", "/api/combat/action", {"type": "incanter", "sequence": ["lamantin", "tortue", "braise"], "cible": "pnj1"})
		verifier(r.ok, "une suite inconnue se lance : %s" % r.get("erreur", ""))
	_test_blessures()
	_test_ressources()


func _placer_sur(p: PartieLocale, contenu: String) -> void:
	var c: Dictionary = Regles.carte()
	for i in c.contenu.size():
		var reg := int(c.region[i])
		if c.contenus[int(c.contenu[i])] == contenu and reg >= 0 and c.regions[reg] != "coeur":
			p.ninja.position = [i % int(c.l), i / int(c.l)]
			p.ninja.niveau = 30
			return


func _test_ressources() -> void:
	var chemin := "user://test_ressources.save.json"
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var p := PartieLocale.new(chemin)
	p.appel("POST", "/api/ninja", {"nom": "Awa", "region": "lagunes", "village": "moderne"})
	p.hasard = func() -> float: return 0.9
	verifier(not p.appel("POST", "/api/carte/exploiter", {}).ok, "rien à exploiter au village")
	_placer_sur(p, "fer")
	var r := p.appel("GET", "/api/etat", {})
	verifier(r.data.ninja.situation.contenu == "fer" and int(r.data.ninja.situation.gisement.reste) == 5, "la situation montre le gisement")
	for i in 5:
		r = p.appel("POST", "/api/carte/exploiter", {})
		verifier(r.ok and int(r.data.gain.fer) > 0, "récolte de fer : %s" % r.get("erreur", ""))
	verifier(int(p.ninja.sac.fer) >= 5 and int(p.ninja.exploitation.fer.niveau) >= 2, "le métier progresse")
	verifier(not p.appel("POST", "/api/carte/exploiter", {}).ok, "gisement épuisé")
	verifier(PartieLocale.rendement("or", 20, 0.5, 0.0) > PartieLocale.rendement("or", 1, 0.5, 0.0), "le niveau augmente la récolte")
	# Bandits pendant la récolte.
	_placer_sur(p, "peau")
	p.hasard = func() -> float: return 0.1
	r = p.appel("POST", "/api/carte/exploiter", {})
	verifier(r.ok and r.data.combat != null, "des bandits surgissent")
	p.appel("POST", "/api/combat/fuite", {})
	# Un ninja sur le gisement : on peut l'affronter.
	var seq := [0.5, 0.5, 0.1, 0.9, 0.3, 0.2, 0.3, 0.4]
	var i := [0]
	p.hasard = func() -> float:
		var v: float = seq[i[0] % seq.size()]
		i[0] += 1
		return v
	r = p.appel("POST", "/api/carte/exploiter", {})
	verifier(r.ok and r.data.ninja.situation.presence != null, "un ninja arrive sur le gisement")
	r = p.appel("POST", "/api/carte/affronter", {})
	verifier(r.ok and r.data.combat != null, "on peut affronter tout ninja présent")
	p.appel("POST", "/api/combat/fuite", {})
	# Camp de bandits : victoire, butin, camp vaincu.
	_placer_sur(p, "camp")
	r = p.appel("POST", "/api/carte/camp", {})
	verifier(r.ok and r.data.combat != null, "attaque du camp")
	p.combat.fini = true
	p.combat.vainqueur = 0
	var fin := p._terminer()
	verifier(fin.get("butin", {}).size() > 0 and not p._camp_actif(int(p.ninja.position[0]), int(p.ninja.position[1])), "camp pillé")
	# Forge et équipement au village.
	var v = p.village_natal()
	p.ninja.position = [int(v.x), int(v.y)]
	p.ninja.sac = {"fer": 3, "peau": 1}
	p.ninja.coffre = {"fer": 5}
	r = p.appel("POST", "/api/forge/fabriquer", {"objet": "sabre_fer"})
	verifier(r.ok and int(p.ninja.coffre.get("fer", 0)) == 0 and int(p.ninja.sac.fer) == 2, "forge : le coffre d'abord")
	var avant := int(p._combattant(Regles.maintenant()).arme.puissance)
	r = p.appel("POST", "/api/equipement/equiper", {"objet": "sabre_fer"})
	var arme: Dictionary = p._combattant(Regles.maintenant()).arme
	verifier(r.ok and int(arme.puissance) > avant and arme.nom == "un sabre de fer", "l'arme forgée compte en combat")
	# Le coffre garde aussi les objets.
	p.ninja.objets = ["bandeau_cuir", "veste_cuir"]
	r = p.appel("POST", "/api/village/ranger", {"objet": "veste_cuir"})
	verifier(r.ok and p.ninja.coffre_objets == ["veste_cuir"], "ranger un objet au coffre")
	# Défaite : sac, objets et équipement porté perdus, coffre intact.
	p.ninja.coffre = {"pierre": 7}
	p.appel("POST", "/api/combat", {"rencontre": "chacals"})
	p.combat.fini = true
	p.combat.vainqueur = 1
	var fin2 := p._terminer()
	verifier(p.ninja.sac.is_empty() and p.ninja.objets.is_empty() and int(p.ninja.coffre.pierre) == 7 and p.ninja.equipement.is_empty(), "défaite : on perd le sac et l'équipement, pas le coffre")
	verifier(fin2.get("objets_perdus", []).size() == 2 and p._combattant(Regles.maintenant()).arme.nom == p.ninja.arme.nom, "on renaît avec l'arme de départ")
	verifier(p.ninja.coffre_objets == ["veste_cuir"], "le coffre garde ses objets après la défaite")
	r = p.appel("POST", "/api/village/sortir", {"objet": "veste_cuir"})
	verifier(r.ok and p.ninja.objets == ["veste_cuir"] and p.ninja.coffre_objets.is_empty(), "reprendre un objet du coffre")


func _test_blessures() -> void:
	var chemin := "user://test_blessures.save.json"
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var p := PartieLocale.new(chemin)
	p.appel("POST", "/api/ninja", {"nom": "Kofi", "region": "lagunes", "village": "moderne"})
	var t0: int = int(Time.get_unix_time_from_system())
	p.horloge = func() -> int: return t0
	var r := p.appel("GET", "/api/etat", {})
	verifier(int(r.data.ninja.pv) == p.pv_max(), "un nouveau ninja est en pleine forme")
	p.ninja.pv = 10
	p.ninja.pv_maj = t0
	r = p.appel("POST", "/api/combat", {"rencontre": "chacals"})
	var moi = null
	for f in r.data.combattants:
		if f.id == "joueur":
			moi = f
	verifier(moi != null and int(moi.pv) == 10, "le combat commence avec les blessures")
	p.appel("POST", "/api/combat/fuite", {})
	p.horloge = func() -> int: return t0 + int(Regles.c.regen_pv_secondes)
	r = p.appel("GET", "/api/etat", {})
	verifier(int(r.data.ninja.pv) == p.pv_max(), "une demi-heure guérit tout")
	# Un baume agit après le combat.
	var j: Dictionary = Grammaire.analyser(["lamantin", "tortue", "moustique"]).jutsu
	verifier(j.type == "soin" and j.effets[0].statut == "baume", "Moustique + Tortue : baume d'après-combat")
	var c := CombatMoteur.new("t", [p._combattant(Regles.maintenant()), PartieLocale._instancier(Regles.rencontres.chacals, 1)[0]], 1)
	c._lancer(c.get_c("joueur"), j, "", 1.0, false)
	verifier(CombatMoteur.baume(c.get_c("joueur")) > 0, "le baume attend la fin du combat")
	# Un clone reste indiscernable pour l'adversaire.
	var jc: Dictionary = Grammaire.analyser(["lamantin", "perroquet", "voile"]).jutsu
	c._lancer(c.get_c("joueur"), jc, "", 1.0, false)
	var vus: Array = c.vue(1).combattants.filter(func(f): return f.camp == 0)
	verifier(vus.size() == 2 and vus[0].nom == vus[1].nom and vus[0].pv == vus[1].pv and not vus[0].clone and not vus[1].clone, "clone indiscernable")
	verifier(c.vue(0).combattants.filter(func(f): return f.clone).size() == 1, "le joueur voit son clone")
