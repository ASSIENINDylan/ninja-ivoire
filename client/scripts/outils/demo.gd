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


## La case la plus proche (du ninja) qui porte l'un de ces contenus, dans
## une zone à sa portée.
func _plus_proche(contenus: Array) -> Vector2i:
	var c: Dictionary = Regles.carte()
	var pos: Array = Api.partie.ninja.position
	var meilleur := Vector2i(-1, -1)
	var dmin := 1e9
	for i in c.contenu.size():
		if not contenus.has(c.contenus[int(c.contenu[i])]):
			continue
		if int(Regles.zone(int(c.zone[i])).niveau) > maxi(3, int(Api.partie.ninja.niveau)):
			continue
		var x: int = i % int(c.l)
		var y: int = i / int(c.l)
		var d := Vector2(x - int(pos[0]), y - int(pos[1])).length()
		if d < dmin:
			dmin = d
			meilleur = Vector2i(x, y)
	return meilleur


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
		e._vue.survol = Vector2i(int(Jeu.ninja.position[0]) - 1, int(Jeu.ninja.position[1]))
		await _capture("12_carte_exploration")
	else:
		await _capture("12_carte_rencontre")
		await Api.envoyer("/api/combat/fuite")
		await Jeu.rafraichir()
	# Un gisement tout proche, une récolte, puis un camp de bandits.
	if Api.partie != null:
		var c := _plus_proche(["pierre", "peau", "fer"])
		if c != Vector2i(-1, -1):
			Api.partie.ninja.position = [c.x, c.y]
			Api.partie._reveler(c.x, c.y, 2)
			await Jeu.rafraichir()
			Jeu.aller("carte", {"message": "Un gisement !"})
			await _attendre(1.0)
			await _capture("13_carte_gisement")
			e = _ecran()
			e._exploiter()
			await _attendre(0.8)
			e._exploiter()
			await _attendre(1.2)
			await _capture("14_exploitation")
		var k := _plus_proche(["camp"])
		if k != Vector2i(-1, -1):
			Api.partie.ninja.position = [k.x, k.y]
			Api.partie._reveler(k.x, k.y, 2)
			Api.partie.ninja.niveau = maxi(int(Api.partie.ninja.niveau), 3)
			await Jeu.rafraichir()
			Jeu.aller("carte", {"message": "Un camp de bandits."})
			await _attendre(1.0)
			await _capture("15_carte_camp")
		Api.partie.hasard = randf
		# Retour au village pour la forge, avec de quoi forger.
		var v = Api.partie.village_natal()
		Api.partie.ninja.position = [int(v.x), int(v.y)]
		Api.partie.ninja.sac = {"fer": 9, "peau": 7, "pierre": 4}
		Api.partie.ninja.coffre = {"or": 2}
		await Jeu.rafraichir()
		Jeu.aller("forge")
		await _attendre(0.8)
		e = _ecran()
		e._fabriquer("sabre_fer")
		await _attendre(0.6)
		e._equiper("sabre_fer")
		await _attendre(1.0)
		await _capture("16_forge")

	# Pour la démonstration, le ninja a déjà du métier (niveau 25).
	if Api.partie != null:
		Api.partie.ninja.niveau = 25
		await Jeu.rafraichir()
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
	for id in ["panthere", "perroquet", "voile"]:
		e._barre.ajouter(id)
	e._essayer()
	await _attendre(1.2)
	await _capture("05b_dojo_illusion")

	# D'autres jutsus : un soin, une entrave, une défense, et un sixième hors des favoris.
	for sq in [["panthere", "martin_pecheur", "kola"], ["panthere", "araignee", "liane"], ["panthere", "tortue", "moustique"], ["panthere", "case", "belier"], ["panthere", "pangolin", "hache"]]:
		await Api.envoyer("/api/dojo", {"sequence": sq})
	await Jeu.rafraichir()
	Jeu.aller("grimoire")
	await _attendre(0.8)
	await _capture("06_grimoire")

	var r := await Api.envoyer("/api/combat", {"rencontre": "chacals"})
	Jeu.aller("combat", {"combat": r.data})
	await _attendre(1.2)
	await _capture("07_combat")
	e = _ecran()
	e._envoyer({"type": "incanter", "sequence": ["panthere", "perroquet", "voile"], "cible": ""})
	for i in 30:
		await _attendre(0.25)
		if not e._occupe:
			break
	await _attendre(0.6)
	await _capture("08_combat_clone")
	e._envoyer({"type": "incanter", "sequence": ["panthere", "araignee", "liane"], "cible": "pnj1"})
	for i in 30:
		await _attendre(0.25)
		if not e._occupe:
			break
	e._composer = true
	e._maj_interface()
	for id in ["panthere", "tortue", "hache"]:
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
