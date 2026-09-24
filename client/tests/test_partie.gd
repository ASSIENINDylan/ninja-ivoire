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
		r = p.appel("POST", "/api/combat", {"rencontre": "chacals"})
		verifier(r.ok, "début du combat : %s" % r.get("erreur", ""))
		var fin = null
		for t in 70:
			var a := {"type": "incanter", "sequence": ["lamantin", "martin_pecheur", "liane"], "cible": "pnj1"} if t % 2 == 0 else {"type": "frapper", "cible": "pnj1"}
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
		r = p.appel("POST", "/api/combat/action", {"type": "incanter", "sequence": ["lamantin", "martin_pecheur", "liane"], "cible": "pnj1"})
		tours += 1
	verifier(r.ok and r.data.fin != null, "le combat contre 3 adversaires se termine")
	print("Sans-Visage : %s en %d tours" % [r.data.fin.message if r.ok else r.erreur, tours])
	_test_carte()
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
		r = p.appel("POST", "/api/combat/fuite", {})
		verifier(r.ok and r.data.fin.defaite, "la fuite est une défaite")
		verifier(int(p.ninja.position[0]) == int(v.x) and int(p.ninja.position[1]) == int(v.y), "on renaît au village")
	# Repos et défi d'un lieu.
	p.ninja.endurance = 2
	verifier(p.appel("POST", "/api/carte/reposer", {}).ok and int(p.ninja.endurance) == int(Regles.c.endurance_max), "repos au village")
	var l = Regles.lieu_id("faubourgs_neo_ebrie")
	p.ninja.position = [int(l.x), int(l.y)]
	verifier(not p.appel("POST", "/api/carte/defier", {}).ok, "défi trop tôt")
	p.ninja.niveau = int(l.niveau)
	r = p.appel("POST", "/api/carte/defier", {})
	verifier(r.ok and r.data.rencontre == "Patrouille du Cercle d'Acier", "défi des faubourgs de Néo-Ébrié")
