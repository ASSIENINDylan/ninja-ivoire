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
				for k in ["nom", "nature", "element", "forme", "effet", "texte", "cout", "soutien", "fusion", "type"]:
					if not _egal(a.get(k), b.get(k)):
						diff += " %s: %s ≠ %s" % [k, a.get(k), b.get(k)]
				for k in ["effet2", "legendaire", "degats_nature"]:
					if str(a.get(k, "")) != str(b.get(k, "")):
						diff += " %s: %s ≠ %s" % [k, a.get(k, ""), b.get(k, "")]
				for k in ["mods_forme", "mods_effet"]:
					if str(a.get(k, [])) != str(b.get(k, [])):
						diff += " %s: %s ≠ %s" % [k, a.get(k, []), b.get(k, [])]
				for k in ["f", "g", "m", "n"]:
					if abs(float(a.coefs[k]) - float(b.coefs[k])) > 1e-9:
						diff += " coefs.%s: %s ≠ %s" % [k, a.coefs[k], b.coefs[k]]
				for k in ["delai", "incassable", "indissipable"]:
					if bool(a.get(k, false)) != bool(b.get(k, false)):
						diff += " %s: %s ≠ %s" % [k, a.get(k, false), b.get(k, false)]
				if abs(float(a.get("echo", 0)) - float(b.echo)) > 1e-9:
					diff += " echo: %s ≠ %s" % [a.get("echo", 0), b.echo]
				var ca := _canon(Grammaire.normaliser(a.effets))
				var cb := _canon(b.effets)
				if ca != cb:
					diff += " effets: %s ≠ %s" % [ca, cb]
				var ref := {"fangan": 10, "gnanga": 12, "manhis": 8}
				var p := CombatMoteur.puissance_de(ref, b, 40, 1.0)
				if abs(p - float(v.puissance_ref)) > 1e-6:
					diff += " puissance: %s ≠ %s" % [v.puissance_ref, p]
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


## Forme canonique d'une liste d'effets, pour comparer Go et GDScript.
func _canon(l: Array) -> String:
	var parts := PackedStringArray()
	for e in l:
		parts.append("%s|%s|%s|%.4f|%d|%s|%d|%.4f|%s|%d|%.4f|%.4f[%s]" % [e.op, e.cible, e.nature, e.mult, e.frappes,
			e.statut, e.duree, e.valeur, e.vers, e.nombre, e.part, e.propage, _canon(e.effets)])
	return ";".join(parts)
