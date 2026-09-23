extends Ecran
## Le combat : chaque tour, on choisit une action en secret ; le serveur
## résout le tour et renvoie ce qui s'est passé, que l'on anime.

const ECART := 205.0

var etat: Dictionary = {}
var _decor: DecorCombat
var _arene: Node2D
var _murs: Murs
var _vues := {}
var _cible := ""
var _occupe := false
var _composer := false
var _decouvertes: Array = []

var _tour: Label
var _banniere: Label
var _info: Label
var _info_cible: Label
var _actions: VBoxContainer
var _zone_jutsus: VBoxContainer
var _journal: RichTextLabel
var _barre: SequenceBarre
var _onglet_jutsus: Button
var _onglet_composer: Button


func construire() -> void:
	etat = params.combat
	_decor = DecorCombat.new()
	_decor.sol = 0.62
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_decor)
	_arene = Node2D.new()
	add_child(_arene)
	_murs = Murs.new()
	_arene.add_child(_murs)
	for f in etat.combattants:
		var v := CombattantVue.new()
		v.scale = Vector2(1.22, 1.22)
		_arene.add_child(v)
		v.maj(f, true)
		_vues[f.id] = v

	# En-tête.
	var tete := UI.hbox(18)
	tete.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tete.offset_left = 30
	tete.offset_right = -30
	tete.offset_top = 18
	add_child(tete)
	tete.add_child(UI.label(params.get("nom", _nom_rencontre()), 30, Pal.IVOIRE, true))
	_tour = UI.label("", 18, Pal.OR)
	_tour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(_tour)
	tete.add_child(UI.extensible())
	var c = Jeu.ciel
	if c != null and not c.is_empty():
		var ciel := UI.label("%s · %s · Soleil ×%.2f · Lune ×%.2f" % [c.heure, c.phase_lune, c.facteur_soleil, c.facteur_lune], 15, Pal.IVOIRE_DOUX)
		ciel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(ciel)
	tete.add_child(UI.bouton("Fuir", _fuir, 15))

	_banniere = UI.label("", 30, Pal.OR_VIF, true)
	_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banniere.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banniere.offset_top = 86
	_banniere.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banniere.add_theme_constant_override("outline_size", 8)
	_banniere.modulate.a = 0
	_banniere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banniere)

	_construire_panneau()
	resized.connect(func(): _placer(true))
	_placer.call_deferred(true)
	_choisir_cible_defaut()
	_maj_interface()
	_ecrire("[color=#c9a25b]Le combat commence. Choisis ton action : les adversaires choisissent la leur en même temps.[/color]")


func _nom_rencontre() -> String:
	var noms := []
	for f in etat.combattants:
		if f.camp == 1 and not noms.has(f.nom):
			noms.append(f.nom)
	return " · ".join(noms)


func _construire_panneau() -> void:
	var panneau := PanelContainer.new()
	panneau.add_theme_stylebox_override("panel", Pal.boite(Color("140e11", 0.96), Pal.BORD, 0, 1, 14))
	panneau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panneau.offset_top = -280
	add_child(panneau)
	var h := UI.hbox(18)
	panneau.add_child(h)

	var gauche := UI.vbox(8)
	gauche.custom_minimum_size.x = 300
	h.add_child(gauche)
	_info = UI.label("", 15, Pal.IVOIRE)
	gauche.add_child(_info)
	_info_cible = UI.label("", 15, Pal.OR_VIF)
	gauche.add_child(_info_cible)
	_actions = UI.vbox(6)
	gauche.add_child(_actions)

	var milieu := UI.vbox(8)
	milieu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(milieu)
	var onglets := UI.hbox(8)
	milieu.add_child(onglets)
	_onglet_jutsus = UI.bouton("Mes jutsus", func():
		_composer = false
		_maj_interface(), 15)
	_onglet_composer = UI.bouton("Composer une suite de mudras", func():
		_composer = true
		_maj_interface(), 15)
	onglets.add_child(_onglet_jutsus)
	onglets.add_child(_onglet_composer)
	_zone_jutsus = UI.vbox(6)
	_zone_jutsus.size_flags_vertical = Control.SIZE_EXPAND_FILL
	milieu.add_child(_zone_jutsus)

	var droite := UI.vbox(6)
	droite.custom_minimum_size.x = 380
	h.add_child(droite)
	droite.add_child(UI.label("Chronique du combat", 17, Pal.OR, true))
	_journal = RichTextLabel.new()
	_journal.bbcode_enabled = true
	_journal.scroll_following = true
	_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	droite.add_child(_journal)

	_barre = SequenceBarre.new()
	_barre.rayon = 20.0
	_barre.change.connect(_maj_interface)


# --- Placement et sélection -------------------------------------------------

func _placer(instantane: bool) -> void:
	var cx := size.x * 0.5
	var sol := size.y * 0.585
	for f in etat.combattants:
		var v: CombattantVue = _vues[f.id]
		if f.rang <= 0:
			continue
		var dx: float = 170.0 + (f.rang - 1) * ECART
		var p := Vector2(cx - dx if f.camp == 0 else cx + dx, sol)
		if instantane:
			v.position = p
		else:
			v.create_tween().tween_property(v, "position", p, 0.35).set_trans(Tween.TRANS_CUBIC)
	_murs.centre = Vector2(cx, sol)
	_murs.etat = etat.get("murs", [null, null])


func _combattant(id: String):
	for f in etat.combattants:
		if f.id == id:
			return f
	return null


func _choisir_cible_defaut() -> void:
	var c = _combattant(_cible)
	if c != null and c.pv > 0 and c.camp == 1:
		return
	_cible = ""
	var meilleur = null
	for f in etat.combattants:
		if f.camp == 1 and f.pv > 0 and (meilleur == null or f.rang < meilleur.rang):
			meilleur = f
	if meilleur != null:
		_cible = meilleur.id
	_maj_selection()


func _maj_selection() -> void:
	for id in _vues:
		_vues[id].selection = id == _cible


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		for id in _vues:
			_vues[id].survol = _vues[id].zone_clic().has_point(ev.position) and _vues[id].d.pv > 0
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for id in _vues:
			var v: CombattantVue = _vues[id]
			if v.zone_clic().has_point(ev.position) and v.d.pv > 0:
				_cible = id
				_maj_selection()
				_maj_interface()
				return


# --- Interface ------------------------------------------------------------------

func _joueur() -> Dictionary:
	var j = _combattant("joueur")
	return j if j != null else {}


func _maj_interface() -> void:
	if etat.is_empty():
		return
	var j := _joueur()
	_tour.text = "Tour %d" % (int(etat.tour) + 1)
	_info.text = "PV %d / %d   ·   Souffle %d / %d" % [j.pv, j.pv_max, j.souffle, j.souffle_max]
	var c = _combattant(_cible)
	_info_cible.text = ("Cible : %s (clique sur un adversaire)" % c.nom) if c != null else "Aucune cible"
	for n in _actions.get_children():
		n.queue_free()
	var inc = j.get("incantation")
	if inc != null:
		_actions.add_child(UI.bouton_principal("Continuer l'incantation (%d/%d)" % [inc.progres, inc.total], func(): _envoyer({"type": "incanter", "cible": _cible}), 16))
	_actions.add_child(UI.bouton("Frapper avec %s" % j.arme.nom, func(): _envoyer({"type": "frapper", "cible": _cible}), 16))
	var ligne := UI.hbox(6)
	ligne.add_child(UI.bouton("Garde", func(): _envoyer({"type": "garde"}), 16))
	ligne.add_child(UI.bouton("Concentrer", func(): _envoyer({"type": "concentrer"}), 16))
	_actions.add_child(ligne)
	if inc != null:
		_actions.add_child(UI.label("Toute autre action abandonne l'incantation.", 12, Pal.GRIS))
	for b in _actions.get_children():
		if b is Button:
			b.disabled = _occupe
	for n in ligne.get_children():
		n.disabled = _occupe

	_onglet_jutsus.disabled = not _composer
	_onglet_composer.disabled = _composer
	for n in _zone_jutsus.get_children():
		if n == _barre:
			continue
		n.queue_free()
	if _barre.get_parent() != null:
		_barre.get_parent().remove_child(_barre)
	if _composer:
		_construire_composer(j)
	else:
		_construire_liste(j)


func _construire_liste(j: Dictionary) -> void:
	var jutsus: Array = Jeu.ninja.jutsus if Jeu.ninja.jutsus != null else []
	if jutsus.is_empty():
		_zone_jutsus.add_child(UI.texte("Tu ne connais encore aucun jutsu. Compose une suite de mudras (un élément, une forme, un but…) et découvre-la en plein combat.", 15, Pal.IVOIRE_DOUX))
		return
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_zone_jutsus.add_child(defil)
	var flux := HFlowContainer.new()
	flux.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flux.add_theme_constant_override("h_separation", 8)
	flux.add_theme_constant_override("v_separation", 8)
	defil.add_child(flux)
	for ju in jutsus:
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 64)
		b.clip_text = true
		b.text = "%s\n%d Souffle · %d tour(s) · maîtrise %d" % [ju.nom, ju.cout, ju.tours, ju.maitrise]
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Jeu.couleur_element(ju.element).lightened(0.35))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = ju.texte
		b.disabled = _occupe or ju.cout > j.souffle
		var cible := "joueur" if ju.soutien else _cible
		b.pressed.connect(_envoyer.bind({"type": "incanter", "sequence": ju.sequence, "cible": cible}))
		flux.add_child(b)


func _construire_composer(_j: Dictionary) -> void:
	var h := UI.hbox(10)
	_zone_jutsus.add_child(h)
	_barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_barre)
	var bv := UI.vbox(6)
	h.add_child(bv)
	var incanter := UI.bouton_principal("Incanter", func():
		var seq := _barre.sequence.duplicate()
		_barre.sequence.clear()
		_envoyer({"type": "incanter", "sequence": seq, "cible": _cible}), 16)
	incanter.disabled = _occupe or _barre.sequence.is_empty()
	bv.add_child(incanter)
	bv.add_child(UI.bouton("Effacer", _barre.vider, 14))
	var mpt := int(Jeu.ninja.mudras_par_tour)
	if not _barre.sequence.is_empty():
		var tours := int(ceil(_barre.sequence.size() / float(mpt)))
		bv.add_child(UI.label("%d tour(s)" % tours, 13, Pal.OR))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_zone_jutsus.add_child(defil)
	var palette := PaletteMudras.new()
	palette.compacte = true
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.choisi.connect(_barre.ajouter)
	defil.add_child(palette)


# --- Tour de jeu -------------------------------------------------------------

func _envoyer(action: Dictionary) -> void:
	if _occupe:
		return
	_occupe = true
	_maj_interface()
	var r := await Api.envoyer("/api/combat/action", action)
	await _traiter(r)


func _fuir() -> void:
	if _occupe:
		return
	_occupe = true
	var r := await Api.envoyer("/api/combat/fuite")
	await _traiter(r)


func _traiter(r: Dictionary) -> void:
	if not r.ok:
		erreur(r.erreur)
		_occupe = false
		_maj_interface()
		return
	var data: Dictionary = r.data
	await _jouer(data.evenements)
	etat = data.combat
	Jeu.ninja = data.ninja
	for f in etat.combattants:
		_vues[f.id].maj(f)
	_placer(false)
	_choisir_cible_defaut()
	if data.get("fin") != null:
		_fin(data.fin)
		return
	_occupe = false
	_maj_interface()


func _jouer(evts: Array) -> void:
	_ecrire("[color=#6b6058]— Tour %d —[/color]" % (int(etat.tour) + 1))
	for e in evts:
		_journaliser(e)
		await _animer(e)


func _pos(id: String, haut: float = 100) -> Vector2:
	if _vues.has(id):
		return _vues[id].position + Vector2(0, -haut * 1.22)
	return size * 0.5


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _animer(e: Dictionary) -> void:
	var type: String = e.type
	var acteur: String = e.get("acteur", "")
	var cible: String = e.get("cible", "")
	var el := Jeu.couleur_element(e.get("element", ""))
	match type:
		"frappe":
			if _vues.has(acteur) and _vues.has(cible):
				var v: CombattantVue = _vues[acteur]
				var depart := v.position
				var dir: Vector2 = (_vues[cible].position - depart).normalized()
				var tw := v.create_tween()
				tw.tween_property(v, "position", depart + dir * 60, 0.1)
				tw.tween_property(v, "position", depart, 0.18)
				await _attendre(0.12)
		"degats":
			if e.get("element", "") != "" and acteur != "" and acteur != cible and _vues.has(acteur):
				await Effets.projectile(_arene, _pos(acteur, 110), _pos(cible, 100), el)
			if _vues.has(cible):
				var v: CombattantVue = _vues[cible]
				v.flash = 1.0
				v.d.pv = max(0, v.d.pv - int(e.valeur))
				Effets.texte(_arene, _pos(cible, 175), "-%d" % e.valeur, Color("ff6b5a"), 30)
				_secouer(4.0 if e.valeur < 20 else 9.0)
			await _attendre(0.28)
		"soin":
			if _vues.has(cible):
				var v: CombattantVue = _vues[cible]
				v.d.pv = min(v.d.pv_max, v.d.pv + int(e.valeur))
				Effets.texte(_arene, _pos(cible, 175), "+%d" % e.valeur, Pal.VERT, 28)
				Effets.onde(_arene, _pos(cible, 60), Pal.VERT, 60)
			await _attendre(0.25)
		"esquive":
			Effets.texte(_arene, _pos(cible, 175), "Esquive", Pal.IVOIRE, 22)
			await _attendre(0.25)
		"rate":
			Effets.texte(_arene, _pos(acteur, 175), "Raté", Pal.GRIS, 22)
			await _attendre(0.25)
		"jutsu", "differe":
			_annoncer(e.get("jutsu", e.texte), el.lightened(0.3))
			Effets.onde(_arene, _pos(acteur, 90), el, 110)
			await _attendre(0.45)
		"decouverte":
			_annoncer(e.texte, Pal.OR_VIF, 2.2)
			_decouvertes.append(e.get("jutsu", ""))
			Effets.onde(_arene, _pos(acteur, 90), Pal.OR_VIF, 180)
			await _attendre(1.1)
		"echec":
			_annoncer(e.texte, Color("b9a7ff"), 2.4)
			await _attendre(1.0)
		"interruption":
			Effets.texte(_arene, _pos(cible, 215), "Incantation brisée !", Pal.SANG, 22)
			if _vues.has(cible):
				_vues[cible].d.incantation = null
			await _attendre(0.45)
		"incantation":
			Effets.texte(_arene, _pos(acteur, 215), "mudras %d" % e.valeur, Pal.OR, 18)
			await _attendre(0.25)
		"garde":
			Effets.texte(_arene, _pos(acteur, 175), "Garde", Pal.IVOIRE_DOUX, 20)
			await _attendre(0.15)
		"concentration":
			Effets.texte(_arene, _pos(acteur, 175), "+%d Souffle" % e.valeur, Pal.SOUFFLE, 20)
			Effets.onde(_arene, _pos(acteur, 90), Pal.SOUFFLE, 70)
			await _attendre(0.25)
		"mur", "armure", "double", "invoque", "piege_pose":
			Effets.onde(_arene, _pos(acteur, 80), el, 140)
			await _attendre(0.35)
		"retour":
			Effets.onde(_arene, _pos(acteur, 90), Pal.SANG, 120)
			_secouer(8.0)
			await _attendre(0.3)
		"mort":
			await _attendre(0.35)
		"fin":
			pass
		_:
			if cible != "" and _vues.has(cible) and type in ["statut", "purification", "piege", "riposte", "leurre", "consume", "invocation"]:
				Effets.onde(_arene, _pos(cible, 90), el if e.get("element", "") != "" else Pal.IVOIRE_DOUX, 60)
			await _attendre(0.18)


func _annoncer(t: String, col: Color, duree: float = 1.3) -> void:
	_banniere.text = t
	_banniere.add_theme_color_override("font_color", col)
	var tw := create_tween()
	tw.tween_property(_banniere, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duree)
	tw.tween_property(_banniere, "modulate:a", 0.0, 0.4)


func _secouer(force: float) -> void:
	var tw := create_tween()
	for i in 5:
		tw.tween_property(_arene, "position", Vector2(randf_range(-force, force), randf_range(-force, force) * 0.5), 0.03)
	tw.tween_property(_arene, "position", Vector2.ZERO, 0.05)


func _journaliser(e: Dictionary) -> void:
	var couleurs := {
		"degats": "#e8806f", "soin": "#8fd18f", "decouverte": "#e8c47a", "echec": "#b9a7ff",
		"interruption": "#e0604f", "mort": "#f2e8d5", "fin": "#e8c47a", "jutsu": "#f2e8d5",
	}
	var col: String = couleurs.get(e.type, "#c9bda8")
	if e.type == "jutsu" and e.get("element", "") != "":
		col = "#" + Jeu.couleur_element(e.element).lightened(0.3).to_html(false)
	_ecrire("[color=%s]%s[/color]" % [col, e.texte])


func _ecrire(t: String) -> void:
	_journal.append_text(t + "\n")


# --- Fin du combat ---------------------------------------------------------------

func _fin(fin: Dictionary) -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.6, 0.5)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var carte := UI.carte(Color(Pal.PANNEAU, 0.97), Pal.OR, 30)
	carte.custom_minimum_size.x = 560
	centre.add_child(carte)
	var v := UI.vbox(12)
	carte.add_child(v)
	var titre := "Victoire" if fin.victoire else ("Match nul" if fin.nul else "Défaite")
	var tl := UI.label(titre, 56, Pal.OR_VIF if fin.victoire else Pal.IVOIRE, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	v.add_child(UI.frise())
	v.add_child(UI.texte(fin.message, 17, Pal.IVOIRE_DOUX, 500))
	if fin.xp > 0 or fin.dje > 0:
		v.add_child(UI.label("+%d expérience   ·   +%d Djê" % [fin.xp, fin.dje], 20, Pal.OR_VIF))
	if fin.niveaux_gagnes > 0:
		v.add_child(UI.label("Niveau %d atteint ! Tu as des points d'attribut à répartir." % Jeu.ninja.niveau, 19, Pal.OR_VIF, true))
	for d in _decouvertes:
		v.add_child(UI.label("Découvert : " + d, 16, Pal.OR))
	var m = fin.get("maitrise")
	if m != null:
		for nom in m:
			v.add_child(UI.label("%s — maîtrise %d" % [nom, m[nom]], 15, Pal.IVOIRE_DOUX))
	v.add_child(UI.espace(8))
	var b := UI.bouton_principal("Retour au village", func():
		await Jeu.rafraichir()
		Jeu.aller("village"), 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)


## Les murs de Souffle qui protègent un camp.
class Murs:
	extends Node2D
	var etat = [null, null]
	var centre := Vector2.ZERO
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if etat == null:
			return
		for camp in 2:
			var m = etat[camp]
			if m == null:
				continue
			var col := Jeu.couleur_element(m.get("element", ""))
			var x := centre.x + (-70.0 if camp == 0 else 70.0)
			for i in 6:
				var off := sin(t * 2 + i) * 3
				draw_rect(Rect2(x - 8 + off, centre.y - 190 + i * 32, 16, 30), Color(col, 0.35))
			draw_rect(Rect2(x - 14, centre.y - 196, 28, 200), Color(col, 0.12))
			draw_line(Vector2(x, centre.y - 200), Vector2(x, centre.y + 4), Color(col, 0.8), 2.0)
			draw_string(Pal.police_texte, Vector2(x - 14, centre.y - 206), str(m.absorption), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col.lightened(0.3))
