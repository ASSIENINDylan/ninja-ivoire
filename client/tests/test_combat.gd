extends SceneTree
## Combats entre IA armées de jutsus tirés au hasard : aucun effet, même
## rare (clones, pièges, effets différés…), ne doit faire planter le moteur.
## godot --headless --path client --script res://tests/test_combat.gd


func _init() -> void:
	Regles.charger()
	var vecteurs = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vecteurs_grammaire.json"))
	var jutsus := []
	for v in vecteurs:
		if v.has("jutsu"):
			var j = Grammaire.analyser(v.sequence).jutsu
			if j != null:
				jutsus.append(j)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fins := [0, 0, 0]
	var types := {}
	for n in 300:
		var liste := []
		for camp in 2:
			for i in rng.randi_range(1, 3):
				var f := {
					"id": "c%d_%d" % [camp, i + 1], "nom": "N%d%d" % [camp, i], "camp": camp, "rang": i + 1, "joueur": false,
					"apparence": "ninja_moderne", "niveau": 10, "fangan": rng.randi_range(8, 30), "gnanga": rng.randi_range(8, 30),
					"manhis": rng.randi_range(8, 30), "pv": 150, "pv_max": 150, "souffle": 200, "souffle_max": 200,
					"element": "feu", "elements": ["feu"], "arme": {"nom": "un sabre", "puissance": 8, "distance": rng.randf() < 0.3},
					"defense": 5, "defense_mag": 5, "absorption": 0, "garde": false, "statuts": [], "incantation": null,
					"clone": false, "_ia": "ninja", "_jutsus": [],
				}
				for k in 4:
					var j: Dictionary = jutsus[rng.randi_range(0, jutsus.size() - 1)]
					f._jutsus.append(j)
					types[j.type] = types.get(j.type, 0) + 1
				liste.append(f)
		var c := CombatMoteur.new("fuzz", liste, n)
		var tours := 0
		while not c.fini and tours < 80:
			var r := c.jouer_tour([])
			if r.has("erreur"):
				print("ERREUR ", r.erreur)
				quit(1)
				return
			tours += 1
		fins[c.vainqueur] += 1
	print("Combats aléatoires : %d terminés (camp 0 : %d, camp 1 : %d, nuls : %d) · types : %s" % [300, fins[0], fins[1], fins[2], types])
	quit(0)
