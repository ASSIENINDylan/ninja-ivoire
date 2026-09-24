extends Node
## Démonstration automatique pour vérifier le rendu : joue un scénario
## (création, dojo, grimoire, combat) et enregistre des captures d'écran.
## Lancement : godot --path client -- --demo=/chemin/captures

var dossier := ""
var main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			dossier = a.substr(7)
	DirAccess.make_dir_recursive_absolute(dossier)
	main = get_parent()
	_scenario()


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dossier.path_join(nom + ".png"))
	print("capture ", nom)


func _ecran() -> Node:
	return main.get("_ecran")


func _scenario() -> void:
	for i in 60:
		await _attendre(0.25)
		if not Jeu.catalogue.is_empty():
			break
	await _attendre(1.5)
	await _capture("01_titre")

	if Jeu.ninja != null:
		await Api.supprimer("/api/ninja")
		Jeu.ninja = null
	Jeu.aller("creation")
	await _attendre(0.8)
	var e := _ecran()
	e._nom.text = "Kouadio"
	e._choisir_region("savanes_nord")
	e._choisir_village("traditionnel")
	await _attendre(0.5)
	await _capture("02_creation")
	e._creer()
	await _attendre(2.0)
	await _capture("03_village")

	Jeu.aller("carte", {"message": "Vous quittez votre village."})
	await _attendre(1.0)
	await _capture("11_carte")
	e = _ecran()
	# Quelques pas vers l'intérieur des terres, sans rencontre.
	if Api.partie != null:
		Api.partie.hasard = func() -> float: return 0.99
	for essai in 12:
		var pos: Array = Jeu.ninja.position
		var fait := false
		for v in [Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var x: int = int(pos[0]) + v.x
			var y: int = int(pos[1]) + v.y
			if Deplacements.possible(x, y) == "":
				e._aller(x, y)
				fait = true
				break
		await _attendre(0.35)
		if not is_instance_valid(e) or main.get("_ecran") != e or not fait:
			break
	await _attendre(1.0)
	if main.get("_ecran") == e:
		e._carte.survol = Vector2i(int(Jeu.ninja.position[0]) - 1, int(Jeu.ninja.position[1]))
		await _capture("12_carte_exploration")
	else:
		await _capture("12_carte_rencontre")
		await Api.envoyer("/api/combat/fuite")
		await Jeu.rafraichir()
	if Api.partie != null:
		Api.partie.hasard = randf

	Jeu.aller("dojo")
	await _attendre(0.8)
	e = _ecran()
	for id in ["panthere", "mante", "braise"]:
		e._barre.ajouter(id)
	e._essayer()
	await _attendre(1.2)
	await _capture("04_dojo_decouverte")
	e._barre.vider()
	for id in ["panthere", "panthere", "mante"]:
		e._barre.ajouter(id)
	e._essayer()
	await _attendre(1.2)
	await _capture("05_dojo_resonance")
	e._barre.vider()
	for id in ["panthere", "martin_pecheur", "liane", "braise"]:
		e._barre.ajouter(id)
	e._essayer()
	await _attendre(1.0)

	Jeu.aller("grimoire")
	await _attendre(0.8)
	await _capture("06_grimoire")

	var r := await Api.envoyer("/api/combat", {"rencontre": "chacals"})
	Jeu.aller("combat", {"combat": r.data})
	await _attendre(1.2)
	await _capture("07_combat")
	e = _ecran()
	e._envoyer({"type": "incanter", "sequence": ["panthere", "mante", "braise"], "cible": "pnj1"})
	await _attendre(1.1)
	await _capture("08_combat_action")
	for i in 30:
		await _attendre(0.5)
		if not e._occupe:
			break
	e._composer = true
	e._maj_interface()
	for id in ["panthere", "martin_pecheur", "liane", "braise"]:
		e._barre.ajouter(id)
	await _attendre(0.5)
	await _capture("09_combat_composer")
	for i in 12:
		if e.etat.get("fini", false):
			break
		e._envoyer({"type": "incanter", "sequence": ["panthere", "mante", "braise"], "cible": ""})
		for k in 40:
			await _attendre(0.25)
			if not e._occupe or e.etat.get("fini", false):
				break
	await _attendre(1.5)
	await _capture("10_combat_fin")
	print("demo terminee")
	Jeu.quitter()
