extends Node
## État partagé du client : serveur local, catalogue, ninja, navigation.

signal ecran_demande(nom: String, params: Dictionary)

var catalogue: Dictionary = {}
var ninja = null  # Dictionary ou null
var ciel: Dictionary = {}
var serveur_pid := -1

var _mudras := {}
var _elements := {}
var _regions := {}


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quitter()


func quitter() -> void:
	if serveur_pid > 0:
		OS.kill(serveur_pid)
		serveur_pid = -1
	get_tree().quit()


func aller(nom: String, params: Dictionary = {}) -> void:
	ecran_demande.emit(nom, params)


# --- Serveur local -----------------------------------------------------------

func _chemin_serveur() -> String:
	var exe := "ninja-server.exe" if OS.get_name() == "Windows" else "ninja-server"
	var candidats := [
		OS.get_executable_path().get_base_dir().path_join(exe),
		ProjectSettings.globalize_path("res://").path_join("../server").path_join(exe),
		ProjectSettings.globalize_path("res://").path_join("../dist").path_join(exe),
	]
	for c in candidats:
		if FileAccess.file_exists(c):
			return c
	return ""


func serveur_disponible() -> bool:
	var r := await Api.lire("/api/sante")
	return r.ok


## Démarre le serveur local s'il ne tourne pas déjà. Renvoie "" si tout va
## bien, sinon un message d'erreur lisible.
func demarrer_serveur() -> String:
	if await serveur_disponible():
		return ""
	var chemin := _chemin_serveur()
	if chemin == "":
		return "Serveur introuvable : placez ninja-server à côté du jeu."
	serveur_pid = OS.create_process(chemin, [])
	if serveur_pid <= 0:
		return "Impossible de lancer le serveur local."
	for i in 40:
		await get_tree().create_timer(0.15).timeout
		if await serveur_disponible():
			return ""
	return "Le serveur local ne répond pas."


func charger() -> String:
	var r := await Api.lire("/api/catalogue")
	if not r.ok:
		return r.erreur
	catalogue = r.data
	for m in catalogue.mudras:
		_mudras[m.id] = m
	for e in catalogue.elements:
		_elements[e.id] = e
	for g in catalogue.regions:
		_regions[g.id] = g
	return await rafraichir()


func rafraichir() -> String:
	var r := await Api.lire("/api/etat")
	if not r.ok:
		return r.erreur
	ninja = r.data.ninja
	ciel = r.data.ciel
	return ""


# --- Catalogue -----------------------------------------------------------------

func mudra(id: String) -> Dictionary:
	return _mudras.get(id, {})


func element(id: String) -> Dictionary:
	return _elements.get(id, {})


func region(id: String) -> Dictionary:
	return _regions.get(id, {})


func couleur_element(id: String) -> Color:
	var e := element(id)
	if e.is_empty():
		return Pal.IVOIRE_DOUX
	return Color(e.couleur)


func couleur_mudra(id: String) -> Color:
	var m := mudra(id)
	if m.is_empty():
		return Pal.GRIS
	if m.categorie == "element":
		return couleur_element(m.get("element", ""))
	return Pal.CATEGORIES.get(m.categorie, Pal.GRIS)


func mudra_permis(id: String) -> bool:
	return ninja != null and ninja.permis.has(id)
