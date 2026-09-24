extends Ecran
## Exploration de la Côte d'Ivoire, case par case, à la manière de
## shinobi.fr : chaque pas coûte de l'endurance, le brouillard se lève,
## des rencontres surgissent en brousse.

const LEGENDE := [["savane", "Savane"], ["savane_boisee", "Savane boisée"], ["foret", "Forêt"], ["foret_dense", "Forêt dense"],
	["montagne", "Montagne"], ["fleuve", "Fleuve"], ["lagune", "Lagune"], ["littoral", "Littoral"], ["lac", "Lac"]]

var _carte: CarteMonde
var _titre: Label
var _sous_titre: Label
var _desc: Label
var _endurance: Label
var _barre_endurance: ProgressBar
var _pv: Label
var _barre_pv: ProgressBar
var _pad: GridContainer
var _actions: VBoxContainer
var _journal: VBoxContainer
var _bulle: Label
var _occupe := false
var _horloge := 0.0


func construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 20)
	add_child(marge)
	var h := UI.hbox(20)
	marge.add_child(h)

	var gauche := UI.vbox(8)
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gauche)
	var tete := UI.hbox(14)
	gauche.add_child(tete)
	tete.add_child(UI.label("Côte d'Ivoire", 30, Pal.IVOIRE, true))
	var aide := UI.label("Clique une case voisine ou utilise les flèches · A, E, W, C pour les diagonales", 14, Pal.GRIS)
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(aide)
	_carte = CarteMonde.new()
	_carte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_carte.case_cliquee.connect(_clic_case)
	gauche.add_child(_carte)
	var legende := HFlowContainer.new()
	legende.add_theme_constant_override("h_separation", 14)
	for e in LEGENDE:
		var item := UI.hbox(5)
		var p := UI.pastille(CarteMonde.COULEURS[e[0]], 11)
		item.add_child(p)
		item.add_child(UI.label(e[1], 13, Pal.IVOIRE_DOUX))
		legende.add_child(item)
	var danger := UI.hbox(5)
	danger.add_child(UI.pastille(Color(0.6, 0.15, 0.12), 11))
	danger.add_child(UI.label("Zone trop dangereuse", 13, Pal.IVOIRE_DOUX))
	legende.add_child(danger)
	gauche.add_child(legende)

	var droite := UI.carte()
	droite.custom_minimum_size.x = 410
	h.add_child(droite)
	var dv := UI.vbox(10)
	droite.add_child(dv)
	_titre = UI.label("", 28, Pal.IVOIRE, true)
	_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_titre)
	_sous_titre = UI.label("", 15, Pal.OR)
	dv.add_child(_sous_titre)
	_desc = UI.texte("", 14, Pal.IVOIRE_DOUX, 370)
	dv.add_child(_desc)
	dv.add_child(UI.frise())
	_pv = UI.label("", 15, Pal.IVOIRE)
	dv.add_child(_pv)
	_barre_pv = UI.barre(0, 100, Pal.VIE, 8)
	dv.add_child(_barre_pv)
	_endurance = UI.label("", 15, Pal.IVOIRE)
	dv.add_child(_endurance)
	_barre_endurance = UI.barre(0, 60, Color("d9b25f"), 10)
	dv.add_child(_barre_endurance)
	dv.add_child(UI.espace(4))
	var centre_pad := CenterContainer.new()
	dv.add_child(centre_pad)
	_pad = GridContainer.new()
	_pad.columns = 3
	_pad.add_theme_constant_override("h_separation", 6)
	_pad.add_theme_constant_override("v_separation", 6)
	centre_pad.add_child(_pad)
	_actions = UI.vbox(8)
	dv.add_child(_actions)
	dv.add_child(UI.frise())
	dv.add_child(UI.label("Carnet de route", 17, Pal.OR, true))
	_journal = UI.vbox(4)
	dv.add_child(_journal)

	_bulle = UI.label("", 14, Pal.IVOIRE)
	_bulle.add_theme_stylebox_override("normal", Pal.boite(Color("150f12", 0.95), Pal.OR, 6, 1, 8))
	_bulle.visible = false
	_bulle.z_index = 30
	_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bulle)

	_maj()
	if params.has("message"):
		_noter(params.message)
	else:
		_noter("Vous êtes à %s." % _nom_lieu_ou_zone())


func _nom_lieu_ou_zone() -> String:
	var s: Dictionary = Jeu.ninja.situation
	if s.get("lieu") != null:
		return s.lieu.nom
	return "l'orée des environs de " + s.zone.nom


func _process(delta: float) -> void:
	# Infobulle de la case survolée.
	var c := _carte.survol
	var t := _carte.description(c.x, c.y)
	if t != "" and _carte.get_global_rect().has_point(get_global_mouse_position()):
		_bulle.text = t
		_bulle.visible = true
		_bulle.reset_size()
		_bulle.position = get_local_mouse_position() + Vector2(18, 14)
		if _bulle.position.x + _bulle.size.x > size.x:
			_bulle.position.x -= _bulle.size.x + 30
	else:
		_bulle.visible = false
	# Compte à rebours de l'endurance.
	var n = Jeu.ninja
	if int(n.endurance) < int(n.situation.endurance_max):
		_horloge += delta
		if _horloge >= 1.0:
			_horloge = 0.0
			n.situation.regen_dans = int(n.situation.regen_dans) - 1
			if int(n.situation.regen_dans) <= 0:
				_rafraichir()
			else:
				_maj_endurance()


func _rafraichir() -> void:
	var r := await Api.lire("/api/etat")
	if r.ok and r.data.ninja != null:
		Jeu.ninja = r.data.ninja
		_maj()


func _maj() -> void:
	var n = Jeu.ninja
	var s: Dictionary = n.situation
	var z: Dictionary = s.zone
	var reg := Jeu.region(z.region)
	if s.get("lieu") != null:
		_titre.text = s.lieu.nom
		_sous_titre.text = "%s — environs de %s (niv. %d)" % [reg.get("nom", ""), z.nom, int(z.niveau)]
		_desc.text = s.lieu.get("description", "") if s.lieu.get("description", "") != "" else s.terrain_nom
	else:
		_titre.text = "Environs de " + z.nom
		_sous_titre.text = "%s — zone de niveau %d" % [reg.get("nom", ""), int(z.niveau)]
		_desc.text = s.terrain_nom + (" · zone sûre" if z.region == "coeur" else "")
	_maj_endurance()
	# Pavé de directions.
	for b in _pad.get_children():
		b.queue_free()
	var pos: Array = n.position
	for d in Deplacements.DIRECTIONS:
		var v: Vector2i = d[0]
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 56)
		b.focus_mode = Control.FOCUS_NONE
		if v == Vector2i.ZERO:
			b.text = "Ici"
			b.disabled = true
		else:
			var x: int = int(pos[0]) + v.x
			var y: int = int(pos[1]) + v.y
			var raison := Deplacements.possible(x, y)
			var cout := Deplacements.cout(x, y)
			b.text = d[1] + ("\n%d" % cout if cout > 0 else "")
			b.add_theme_font_size_override("font_size", 18)
			b.disabled = raison != "" or _occupe
			b.tooltip_text = _carte.description(x, y) + ("\n" + raison if raison != "" else "\nEndurance : %d" % cout)
			b.pressed.connect(_aller.bind(x, y))
		_pad.add_child(b)
	# Actions du lieu.
	for a in _actions.get_children():
		a.queue_free()
	if s.village:
		_actions.add_child(UI.bouton_principal("Entrer dans %s" % s.lieu.nom, func(): Jeu.aller("village"), 17))
	if s.repos:
		var b := UI.bouton("Se reposer (PV et endurance au maximum)", _reposer, 16)
		b.disabled = int(n.endurance) >= int(s.endurance_max) and int(n.get("pv", n.pv_max)) >= int(n.pv_max)
		_actions.add_child(b)
	if s.get("lieu") != null and s.lieu.get("rencontre", "") != "":
		var niv := int(s.lieu.niveau)
		var b := UI.bouton("Affronter ce qui se cache ici (niv. %d)" % niv, _defier, 16)
		b.disabled = int(n.niveau) < niv
		b.add_theme_color_override("font_color", Color("e8806f"))
		_actions.add_child(b)
	_actions.add_child(UI.bouton("Grimoire", func(): Jeu.aller("grimoire", {"retour": "carte"}), 15))


func _maj_endurance() -> void:
	var n = Jeu.ninja
	var emax := int(n.situation.endurance_max)
	var t := "Endurance %d / %d" % [int(n.endurance), emax]
	if int(n.endurance) < emax:
		var sec := maxi(0, int(n.situation.regen_dans))
		t += "   ·   +1 dans %d:%02d" % [sec / 60, sec % 60]
	_endurance.text = t
	_barre_endurance.max_value = emax
	_barre_endurance.value = int(n.endurance)
	var pv := int(n.get("pv", n.pv_max))
	_pv.text = "Points de vie %d / %d" % [pv, int(n.pv_max)] + ("" if pv >= int(n.pv_max) else "   ·   blessé")
	_barre_pv.max_value = int(n.pv_max)
	_barre_pv.value = pv


func _noter(t: String) -> void:
	if t == "":
		return
	var l := UI.texte(t, 13, Pal.IVOIRE_DOUX, 370)
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


func _aller(x: int, y: int) -> void:
	if _occupe:
		return
	var raison := Deplacements.possible(x, y)
	if raison != "":
		erreur(raison)
		return
	_occupe = true
	var r := await Api.envoyer("/api/carte/deplacer", {"x": x, "y": y})
	_occupe = false
	await _traiter(r)


func _reposer() -> void:
	await _traiter(await Api.envoyer("/api/carte/reposer"))


func _defier() -> void:
	await _traiter(await Api.envoyer("/api/carte/defier"))


func _traiter(r: Dictionary) -> void:
	if not r.ok:
		erreur(r.erreur)
		_maj()
		return
	Jeu.ninja = r.data.ninja
	_noter(r.data.get("message", ""))
	if r.data.get("combat") != null:
		_maj()
		notifier(r.data.message, Color("e8806f"), 1.2)
		await get_tree().create_timer(0.9).timeout
		Jeu.aller("combat", {"combat": r.data.combat, "nom": r.data.get("rencontre", ""), "retour": "carte"})
		return
	_maj()
