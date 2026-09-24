extends SceneTree
## Parité de la grammaire GDScript avec le serveur Go.
## godot --headless --path client --script res://tests/test_grammaire.gd


func _init() -> void:
	var err := Regles.charger()
	if err != "":
		push_error(err)
		quit(1)
		return
	var vecteurs = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vecteurs_grammaire.json"))
	var erreurs := 0
	for v in vecteurs:
		var res := Grammaire.analyser(v.sequence)
		var diff := ""
		if v.has("jutsu"):
			var a: Dictionary = v.jutsu
			var b = res.jutsu
			if b == null:
				diff = "jutsu attendu, échec obtenu %s" % res.echec
			else:
				for k in ["nom", "nature", "element", "forme", "effet", "texte", "cout", "soutien", "fusion"]:
					if not _egal(a.get(k), b.get(k)):
						diff += " %s: %s ≠ %s" % [k, a.get(k), b.get(k)]
				for k in ["effet2", "legendaire"]:
					if str(a.get(k, "")) != str(b.get(k, "")):
						diff += " %s: %s ≠ %s" % [k, a.get(k, ""), b.get(k, "")]
				for k in ["mods_forme", "mods_effet"]:
					if str(a.get(k, [])) != str(b.get(k, [])):
						diff += " %s: %s ≠ %s" % [k, a.get(k, []), b.get(k, [])]
				for k in ["puissance", "intensite"]:
					if abs(float(a[k]) - float(b[k])) > 1e-9:
						diff += " %s: %s ≠ %s" % [k, a[k], b[k]]
		else:
			var e = res.echec
			if e == null:
				diff = "échec attendu, jutsu obtenu %s" % res.jutsu.nom
			else:
				for k in ["etape", "position", "valides"]:
					if not _egal(v.echec[k], e[k]):
						diff += " echec.%s: %s ≠ %s" % [k, v.echec[k], e[k]]
				for p in [false, true]:
					var a: Dictionary = v.resonance_precise if p else v.resonance
					var b := Grammaire.resonner(v.sequence, e, p)
					for k in ["score", "message", "ancienne", "retour_de_souffle"]:
						if not _egal(a[k], b[k]):
							diff += " res(%s).%s: %s ≠ %s" % [p, k, a[k], b[k]]
					if str(a.get("indice", "")) != str(b.indice):
						diff += " res(%s).indice: %s ≠ %s" % [p, a.get("indice", ""), b.indice]
		if diff != "":
			erreurs += 1
			if erreurs <= 10:
				print("ÉCART ", v.sequence, " :", diff)
	print("Parité grammaire : %d suites, %d écarts" % [vecteurs.size(), erreurs])
	quit(1 if erreurs > 0 else 0)


func _egal(a, b) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return abs(float(a) - float(b)) < 1e-9
	return str(a) == str(b)
