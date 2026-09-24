extends Ecran
## Exploration de la Côte d'Ivoire, case par case, à la manière de
## shinobi.fr. Au centre, les cases autour du ninja ; derrière, le paysage
## du terrain où il se trouve ; en bas à gauche, la grande carte. Chaque
## case peut être libre, abriter un camp de bandits ou une ressource.

const RESSOURCES := ["fer", "peau", "pierre", "or", "diamant"]

var _paysage: Paysage
var _vue: VueLocale
var _mini: CarteMonde
var _titre: Label
var _sous_titre: Label
var _pv: Label
var _barre_pv: ProgressBar
var _endurance: Label
var _barre_endurance: ProgressBar
var _sac: HFlowContainer
var _metiers: VBoxContainer
var _case: VBoxContainer
var _actions: VBoxContainer
var _journal: VBoxContainer
var _bulle: Label
var _occupe := false
var _horloge := 0.0


func construire() -> void:
	_paysage = Paysage.new()
	_paysage.sol = 0.5
	_paysage.pos_contenu = Vector2(0.5, 0.47)
	_paysage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_paysage)

	# En-tête : où l'on est.
	var tete := UI.carte(Color(Pal.PANNEAU, 0.88), Pal.BORD, 14)
	tete.position = Vector2(20, 18)
	add_child(tete)
	var tv := UI.vbox(2)
	tete.add_child(tv)
	_titre = UI.label("", 28, Pal.IVOIRE, true)
	tv.add_child(_titre)
	_sous_titre = UI.label("", 15, Pal.OCRE)
	tv.add_child(_sous_titre)

	# Colonne de gauche : le ninja, son sac, ses métiers.
	var etat := UI.carte(Color(Pal.PANNEAU, 0.92), Pal.BORD, 14)
	etat.name = "Etat"
	add_child(etat)
	var ev := UI.vbox(6)
	etat.add_child(ev)
	_pv = UI.label("", 14, Pal.IVOIRE)
	ev.add_child(_pv)
	_barre_pv = UI.barre(0, 100, Pal.VIE, 9)
	ev.add_child(_barre_pv)
	_endurance = UI.label("", 14, Pal.IVOIRE)
	ev.add_child(_endurance)
	_barre_endurance = UI.barre(0, 60, Pal.OR_VIF, 9)
	ev.add_child(_barre_endurance)
	ev.add_child(UI.label("Sac", 15, Pal.OCRE, true))
	_sac = HFlowContainer.new()
	_sac.add_theme_constant_override("h_separation", 10)
	ev.add_child(_sac)
	ev.add_child(UI.label("Exploitation", 15, Pal.OCRE, true))
	_metiers = UI.vbox(2)
	ev.add_child(_metiers)
	ev.add_child(UI.bouton("Grimoire", func(): Jeu.aller("grimoire", {"retour": "carte"}), 14))

	# En bas à gauche : la grande carte.
	var mini_carte := UI.carte(Color(Pal.PANNEAU, 0.92), Pal.BORD, 8)
	mini_carte.name = "Mini"
	add_child(mini_carte)
	_mini = CarteMonde.new()
	_mini.interactif = false
	_mini.custom_minimum_size = Vector2(318, 318)
	mini_carte.add_child(_mini)

	# Au centre : les cases autour du ninja.
	_vue = VueLocale.new()
	_vue.case_cliquee.connect(_clic_case)
	add_child(_vue)

	# À droite : la case, ses actions, le carnet de route.
	var droite := UI.carte(Color(Pal.PANNEAU, 0.94), Pal.BORD, 16)
	droite.name = "Droite"
	add_child(droite)
	var dv := UI.vbox(10)
	droite.add_child(dv)
	_case = UI.vbox(6)
	dv.add_child(_case)
	_actions = UI.vbox(8)
	dv.add_child(_actions)
	dv.add_child(UI.frise())
	dv.add_child(UI.label("Carnet de route", 16, Pal.OCRE, true))
	_journal = UI.vbox(4)
	dv.add_child(_journal)

	_bulle = UI.label("", 14, Pal.IVOIRE)
	_bulle.add_theme_stylebox_override("normal", Pal.boite(Color(Pal.PANNEAU, 0.97), Pal.OR_VIF, 6, 1, 8))
	_bulle.visible = false
	_bulle.z_index = 30
	_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bulle)

	resized.connect(_disposer)
	_disposer.call_deferred()
	_maj()
	if params.has("message"):
		_noter(params.message)
	else:
		_noter("Vous êtes à %s." % _nom_lieu_ou_zone())


## Place les panneaux selon la taille de la fenêtre.
func _disposer() -> void:
	var s := size
	var mini: Control = get_node("Mini")
	mini.position = Vector2(20, s.y - 356)
	mini.size = Vector2(336, 336)
	var etat: Control = get_node("Etat")
	etat.position = Vector2(20, 112)
	etat.size = Vector2(336, s.y - 356 - 124)
	var droite: Control = get_node("Droite")
	droite.position = Vector2(s.x - 420, 18)
	droite.size = Vector2(400, s.y - 36)
	_vue.position = Vector2(376, 112)
	_vue.size = Vector2(s.x - 420 - 376 - 20, s.y - 132)


func _nom_lieu_ou_zone() -> String:
	var s: Dictionary = Jeu.ninja.situation
	if s.get("lieu") != null:
		return s.lieu.nom
	return "l'orée des environs de " + s.zone.nom


func _process(delta: float) -> void:
	# Infobulle de la case survolée.
	var c := _vue.survol
	var t := _description(c.x, c.y)
	if t != "" and _vue.get_global_rect().has_point(get_global_mouse_position()):
		_bulle.text = t
		_bulle.visible = true
		_bulle.reset_size()
		_bulle.position = get_local_mouse_position() + Vector2(18, 14)
		if _bulle.position.x + _bulle.size.x > size.x:
			_bulle.position.x -= _bulle.size.x + 30
	else:
		_bulle.visible = false
	# Comptes à rebours (endurance, gisement, camp).
	_horloge += delta
	if _horloge >= 1.0:
		_horloge = 0.0
		var s: Dictionary = Jeu.ninja.situation
		var fin := false
		for k in ["regen_dans", "regen_gisement", "camp_retour"]:
			if int(s.get(k, 0)) > 0:
				s[k] = int(s[k]) - 1
				fin = fin or int(s[k]) <= 0
		if fin:
			_rafraichir()
		elif not _occupe:
			_maj_etat()
			_maj_case()


func _description(x: int, y: int) -> String:
	var info = VueLocale.info_case(x, y)
	if info == null:
		return ""
	var e: String = Jeu.ninja.get("explore", "")
	var i := y * int(Jeu.catalogue.carte.l) + x
	if i >= e.length() or e[i] != "1":
		return "Terre inconnue"
	var t := "%s — environs de %s (niv. %d)" % [Jeu.catalogue.carte.noms_terrains[info.terrain], info.zone.nom, int(info.zone.niveau)]
	if info.lieu != null:
		t = info.lieu.nom + "\n" + t
	elif info.contenu != "":
		t = Jeu.catalogue.carte.noms_contenus[info.contenu] + "\n" + t
	if abs(x - int(Jeu.ninja.position[0])) <= 1 and abs(y - int(Jeu.ninja.position[1])) <= 1:
		var raison := Deplacements.possible(x, y)
		t += "\n" + (raison if raison != "" else "Endurance : %d" % Deplacements.cout(x, y))
	return t


func _rafraichir() -> void:
	var r := await Api.lire("/api/etat")
	if r.ok and r.data.ninja != null:
		Jeu.ninja = r.data.ninja
		_maj()


func _maj() -> void:
	var s: Dictionary = Jeu.ninja.situation
	var z: Dictionary = s.zone
	var reg := Jeu.region(z.region)
	_paysage.terrain = s.terrain
	_paysage.contenu = s.get("contenu", "") if s.get("lieu") == null else ""
	_paysage.lieu = s.lieu.type if s.get("lieu") != null else ""
	_titre.text = s.lieu.nom if s.get("lieu") != null else "Environs de " + z.nom
	_sous_titre.text = "%s · %s · zone de niveau %d%s" % [reg.get("nom", ""), s.terrain_nom, int(z.niveau), " · zone sûre" if z.region == "coeur" else ""]
	_maj_etat()
	_maj_case()


func _maj_etat() -> void:
	var n = Jeu.ninja
	var s: Dictionary = n.situation
	var pv := int(n.get("pv", n.pv_max))
	_pv.text = "Points de vie %d / %d" % [pv, int(n.pv_max)] + ("" if pv >= int(n.pv_max) else "  ·  blessé")
	_barre_pv.max_value = int(n.pv_max)
	_barre_pv.value = pv
	var emax := int(s.endurance_max)
	var t := "Endurance %d / %d" % [int(n.endurance), emax]
	if int(n.endurance) < emax:
		var sec := maxi(0, int(s.regen_dans))
		t += "  ·  +1 dans %d:%02d" % [sec / 60, sec % 60]
	_endurance.text = t
	_barre_endurance.max_value = emax
	_barre_endurance.value = int(n.endurance)
	for c in _sac.get_children():
		c.queue_free()
	var sac: Dictionary = n.get("sac", {})
	if sac.is_empty():
		_sac.add_child(UI.label("vide", 13, Pal.GRIS))
	for r in RESSOURCES:
		if int(sac.get(r, 0)) > 0:
			_sac.add_child(pastille_ressource(r, int(sac[r])))
	for c in _metiers.get_children():
		c.queue_free()
	var ex: Dictionary = n.get("exploitation", {})
	for r in RESSOURCES:
		var m = ex.get(r)
		if m == null:
			continue
		var ligne := UI.hbox(6)
		ligne.add_child(UI.pastille(couleur_ressource(r), 9))
		ligne.add_child(UI.label(str(Jeu.catalogue.noms_ressources.get(r, r)), 13, Pal.IVOIRE))
		ligne.add_child(UI.extensible())
		ligne.add_child(UI.label("niv. %d" % int(m.niveau), 13, Pal.IVOIRE))
		_metiers.add_child(ligne)


static func couleur_ressource(r: String) -> Color:
	var d = CarteMonde.CONTENUS.get(r)
	return d[0] if d != null else Pal.GRIS


static func pastille_ressource(r: String, q: int) -> Control:
	var h := UI.hbox(4)
	h.add_child(UI.pastille(couleur_ressource(r), 10))
	h.add_child(UI.label("%s %d" % [Jeu.catalogue.noms_ressources.get(r, r), q], 13, Pal.IVOIRE))
	return h


func _maj_case() -> void:
	var n = Jeu.ninja
	var s: Dictionary = n.situation
	for c in _case.get_children():
		c.queue_free()
	for c in _actions.get_children():
		c.queue_free()
	var ct: String = s.get("contenu", "")
	if s.get("lieu") != null:
		_case.add_child(UI.label(s.lieu.nom, 22, Pal.IVOIRE, true))
		if s.lieu.get("description", "") != "":
			_case.add_child(UI.texte(s.lieu.description, 14, Pal.IVOIRE_DOUX, 360))
	elif ct == "":
		_case.add_child(UI.label("Case libre", 22, Pal.IVOIRE, true))
		_case.add_child(UI.texte("Rien à exploiter ici. Les cases voisines cachent peut-être un gisement ou un camp.", 14, Pal.IVOIRE_DOUX, 360))
	elif ct == "camp":
		_case.add_child(UI.label("Camp de bandits", 22, Pal.SANG, true))
		if s.get("camp_actif", false):
			_case.add_child(UI.texte("Des bandits et leur chef campent ici. Vaincus, ils laissent leur butin (fer, peaux, parfois de l'or).", 14, Pal.IVOIRE_DOUX, 360))
			var b := UI.bouton_principal("Attaquer le camp", _attaquer_camp, 17)
			b.disabled = _occupe
			_actions.add_child(b)
		else:
			var sec := maxi(0, int(s.get("camp_retour", 0)))
			_case.add_child(UI.texte("Camp vaincu. Les bandits reviennent dans %d:%02d." % [sec / 60, sec % 60], 14, Pal.IVOIRE_DOUX, 360))
	else:
		_case_ressource(n, s, ct)
	# Un ninja croisé : il n'est pas de votre équipe, on peut l'affronter.
	var pr = s.get("presence")
	if pr != null:
		var carte := UI.carte(Color("fff1e6"), Pal.OCRE, 12)
		var pv := UI.vbox(6)
		carte.add_child(pv)
		pv.add_child(UI.label("%s, niveau %d" % [pr.nom, int(pr.niveau)], 17, Pal.IVOIRE, true))
		var d := "ninja de %s (%s)" % [pr.village, pr.region_nom]
		if pr.meme_village:
			d += " — de votre village, mais pas de votre équipe"
		pv.add_child(UI.texte(d, 13, Pal.IVOIRE_DOUX, 330))
		var ph := UI.hbox(8)
		pv.add_child(ph)
		ph.add_child(UI.bouton_principal("Affronter", _affronter, 15))
		ph.add_child(UI.bouton("Ignorer", _ignorer, 15))
		_actions.add_child(carte)
	# Actions des lieux.
	if s.village:
		_actions.add_child(UI.bouton_principal("Entrer dans %s" % s.lieu.nom, func(): Jeu.aller("village"), 17))
	if s.repos:
		var b := UI.bouton("Se reposer (PV et endurance au maximum)", _reposer, 15)
		b.disabled = int(n.endurance) >= int(s.endurance_max) and int(n.get("pv", n.pv_max)) >= int(n.pv_max)
		_actions.add_child(b)
	if s.get("lieu") != null and s.lieu.get("rencontre", "") != "":
		var niv := int(s.lieu.niveau)
		var b := UI.bouton("Affronter ce qui se cache ici (niv. %d)" % niv, _defier, 15)
		b.disabled = int(n.niveau) < niv
		b.add_theme_color_override("font_color", Pal.SANG)
		_actions.add_child(b)


func _case_ressource(n: Dictionary, s: Dictionary, ct: String) -> void:
	var col := couleur_ressource(ct)
	_case.add_child(UI.label(s.get("contenu_nom", ct), 22, col.darkened(0.25), true))
	var g = s.get("gisement")
	var reste := int(g.reste) if g != null else int(s.gisement_max)
	var ligne := UI.hbox(8)
	ligne.add_child(UI.label("Gisement %d / %d" % [reste, int(s.gisement_max)], 14, Pal.IVOIRE))
	if reste < int(s.gisement_max):
		var sec := maxi(0, int(s.get("regen_gisement", 0)))
		ligne.add_child(UI.label("· +1 dans %d:%02d" % [sec / 60, sec % 60], 13, Pal.GRIS))
	_case.add_child(ligne)
	_case.add_child(UI.barre(reste, int(s.gisement_max), col, 8))
	var m = n.get("exploitation", {}).get(ct)
	if m != null:
		var niv := int(m.niveau)
		_case.add_child(UI.label("Exploitation (%s) : niveau %d" % [str(Jeu.catalogue.noms_ressources.get(ct, ct)).to_lower(), niv], 14, Pal.IVOIRE))
		_case.add_child(UI.barre(int(m.xp), 8 * niv, Pal.VERT, 6))
		var rend: Dictionary = Jeu.catalogue.get("rendement", {})
		if rend.has(ct):
			var q := float(rend[ct]) * (1.0 + 0.25 * float(niv - 1))
			_case.add_child(UI.label("Récolte : environ %d par exploitation" % maxi(1, int(round(q))), 13, Pal.IVOIRE_DOUX))
	var b := UI.bouton_principal("Exploiter (2 endurance)", _exploiter, 17)
	b.disabled = _occupe or reste <= 0 or int(n.endurance) < 2
	_actions.add_child(b)
	if reste <= 0:
		_actions.add_child(UI.label("Épuisé : il se reconstitue avec le temps.", 13, Pal.GRIS))
	_actions.add_child(UI.texte("En exploitant, on peut être attaqué par des bandits ou croiser un autre ninja.", 12, Pal.GRIS, 360))


func _noter(t: String) -> void:
	if t == "":
		return
	var l := UI.texte(t, 13, Pal.IVOIRE_DOUX, 360)
	_journal.add_child(l)
	_journal.move_child(l, 0)
	while _journal.get_child_count() > 6:
		_journal.get_child(_journal.get_child_count() - 1).free()
	for i in _journal.get_child_count():
		_journal.get_child(i).modulate.a = 1.0 - i * 0.13


func _clic_case(x: int, y: int) -> void:
	var pos: Array = Jeu.ninja.position
	if abs(x - int(pos[0])) <= 1 and abs(y - int(pos[1])) <= 1 and not (x == int(pos[0]) and y == int(pos[1])):
		_aller(x, y)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var dirs := {
		KEY_UP: Vector2i(0, -1), KEY_Z: Vector2i(0, -1), KEY_KP_8: Vector2i(0, -1),
		KEY_DOWN: Vector2i(0, 1), KEY_S: Vector2i(0, 1), KEY_KP_2: Vector2i(0, 1),
		KEY_LEFT: Vector2i(-1, 0), KEY_Q: Vector2i(-1, 0), KEY_KP_4: Vector2i(-1, 0),
		KEY_RIGHT: Vector2i(1, 0), KEY_D: Vector2i(1, 0), KEY_KP_6: Vector2i(1, 0),
		KEY_A: Vector2i(-1, -1), KEY_KP_7: Vector2i(-1, -1), KEY_E: Vector2i(1, -1), KEY_KP_9: Vector2i(1, -1),
		KEY_W: Vector2i(-1, 1), KEY_KP_1: Vector2i(-1, 1), KEY_C: Vector2i(1, 1), KEY_KP_3: Vector2i(1, 1),
	}
	if dirs.has(ev.keycode):
		var v: Vector2i = dirs[ev.keycode]
		var pos: Array = Jeu.ninja.position
		_aller(int(pos[0]) + v.x, int(pos[1]) + v.y)
		accept_event()
	elif ev.keycode == KEY_X:
		if RESSOURCES.has(Jeu.ninja.situation.get("contenu", "")):
			_exploiter()
		accept_event()


func _aller(x: int, y: int) -> void:
	if _occupe:
		return
	var raison := Deplacements.possible(x, y)
	if raison != "":
		erreur(raison)
		return
	await _action("/api/carte/deplacer", {"x": x, "y": y})


func _exploiter() -> void:
	await _action("/api/carte/exploiter")


func _attaquer_camp() -> void:
	await _action("/api/carte/camp")


func _affronter() -> void:
	await _action("/api/carte/affronter")


func _ignorer() -> void:
	await _action("/api/carte/ignorer")


func _reposer() -> void:
	await _action("/api/carte/reposer")


func _defier() -> void:
	await _action("/api/carte/defier")


func _action(route: String, corps: Dictionary = {}) -> void:
	if _occupe:
		return
	_occupe = true
	var r := await Api.envoyer(route, corps)
	_occupe = false
	await _traiter(r)


func _traiter(r: Dictionary) -> void:
	if not r.ok:
		erreur(r.erreur)
		_maj()
		return
	Jeu.ninja = r.data.ninja
	_noter(r.data.get("message", ""))
	var gain = r.data.get("gain")
	if gain != null:
		for res in gain:
			if int(gain[res]) > 0:
				notifier("+%d %s" % [int(gain[res]), Jeu.catalogue.noms_ressources.get(res, res)], couleur_ressource(res).darkened(0.2), 1.2)
	if r.data.get("combat") != null:
		_maj()
		notifier(r.data.message, Pal.SANG, 1.2)
		await get_tree().create_timer(0.9).timeout
		Jeu.aller("combat", {"combat": r.data.combat, "nom": r.data.get("rencontre", ""), "retour": "carte"})
		return
	_maj()
