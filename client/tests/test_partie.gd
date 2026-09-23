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
	print("Test partie : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
