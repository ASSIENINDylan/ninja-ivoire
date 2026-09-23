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
	return _extraire_serveur_embarque(exe)


## Une copie du serveur voyage dans le jeu lui-même (res://bin). Si le
## fichier manque à côté de l'exécutable, on l'extrait dans les données
## de l'utilisateur et on lance cette copie.
func _extraire_serveur_embarque(exe: String) -> String:
	var source := "res://bin/" + exe
	if not FileAccess.file_exists(source):
		return ""
	var octets := FileAccess.get_file_as_bytes(source)
	if octets.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://bin"))
	var dest := ProjectSettings.globalize_path("user://bin/" + exe)
	if not FileAccess.file_exists(dest) or FileAccess.get_file_as_bytes(dest).size() != octets.size():
		var f := FileAccess.open(dest, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_buffer(octets)
		f.close()
		if OS.get_name() != "Windows":
			OS.execute("chmod", ["+x", dest])
	return dest


const PORTS := [7777, 7778, 7779, 7780]


func journal_serveur() -> String:
	return ProjectSettings.globalize_path("user://serveur.log")


func dossier_jeu() -> String:
	return OS.get_executable_path().get_base_dir()


## Un serveur de Ninja Ivoire répond-il sur ce port ?
func serveur_disponible() -> bool:
	var r := await Api.lire("/api/sante")
	return r.ok and r.data is Dictionary and r.data.get("jeu", "") == "ninja-ivoire"


func _derniere_ligne_journal() -> String:
	var f := FileAccess.open(journal_serveur(), FileAccess.READ)
	if f == null:
		return ""
	var lignes := f.get_as_text().strip_edges().split("\n")
	return lignes[lignes.size() - 1] if lignes.size() > 0 else ""


## Démarre le serveur local s'il ne tourne pas déjà. Renvoie "" si tout va
## bien, sinon un message d'erreur qui dit précisément ce qui bloque.
func demarrer_serveur() -> String:
	for p in PORTS:
		Api.utiliser_port(p)
		if await serveur_disponible():
			return ""
	var chemin := _chemin_serveur()
	if chemin == "":
		var exe := "ninja-server.exe" if OS.get_name() == "Windows" else "ninja-server"
		return ("Le fichier %s est introuvable dans le dossier du jeu :\n%s\n\n" % [exe, dossier_jeu()]
			+ "Vérifie qu'il a bien été extrait du zip à côté de NinjaIvoire.exe. "
			+ "S'il a disparu, l'antivirus (Windows Defender) l'a sans doute mis en quarantaine : "
			+ "restaure-le dans Sécurité Windows > Protection contre les virus > Historique de protection.")
	var raison := ""
	for p in PORTS:
		Api.utiliser_port(p)
		serveur_pid = OS.create_process(chemin, ["-addr", "127.0.0.1:%d" % p, "-log", journal_serveur()])
		if serveur_pid <= 0:
			return ("Windows a empêché le lancement de ninja-server.exe.\n\n"
				+ "C'est presque toujours l'antivirus (faux positif : le jeu n'est pas signé). "
				+ "Autorise le fichier dans Sécurité Windows > Protection contre les virus > Historique de protection, "
				+ "ou ajoute le dossier du jeu aux exclusions.")
		for i in 50:
			await get_tree().create_timer(0.15).timeout
			if await serveur_disponible():
				return ""
			if not OS.is_process_running(serveur_pid):
				break
		raison = _derniere_ligne_journal()
		if OS.is_process_running(serveur_pid):
			OS.kill(serveur_pid)
		serveur_pid = -1
		# Port occupé : on essaie le suivant. Sinon inutile d'insister.
		if not raison.contains("écouter"):
			break
	if raison == "":
		raison = "aucun message (le programme a été arrêté dès son lancement, souvent par l'antivirus)"
	return "Le serveur local s'est arrêté.\nRaison : %s\n\nJournal : %s" % [raison, journal_serveur()]


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
