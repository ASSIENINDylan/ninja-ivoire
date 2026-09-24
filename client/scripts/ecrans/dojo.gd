extends Ecran
## Le dojo : on compose des suites de mudras et on libère le Souffle,
## sans danger. Chaque découverte entre pour toujours au grimoire.

var _barre: SequenceBarre
var _resultat: VBoxContainer
var _journal: VBoxContainer
var _liberer: Button


func construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 26)
	add_child(marge)
	var h := UI.hbox(22)
	marge.add_child(h)

	var gauche := UI.vbox(12)
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gauche)
	var tete := UI.hbox(16)
	gauche.add_child(tete)
	tete.add_child(UI.label("Le dojo", 42, Pal.IVOIRE, true))
	var aide := UI.label("Un jutsu naît d'un élément, d'une forme et d'un but. L'ordre des signes compte.", 16, Pal.OR)
	aide.size_flags_vertical = Control.SIZE_SHRINK_END
	tete.add_child(aide)
	tete.add_child(UI.extensible())
	tete.add_child(UI.bouton("Retour au village", func(): Jeu.aller("village")))

	var zone := UI.carte(Color("150f12", 0.9), Pal.BORD, 14)
	gauche.add_child(zone)
	var zv := UI.vbox(10)
	zone.add_child(zv)
	_barre = SequenceBarre.new()
	_barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_barre.change.connect(_maj)
	zv.add_child(_barre)
	var actions := UI.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	zv.add_child(actions)
	_liberer = UI.bouton_principal("Libérer le Souffle", _essayer, 20)
	actions.add_child(_liberer)
	actions.add_child(UI.bouton("Retirer le dernier signe", _barre.retirer))
	actions.add_child(UI.bouton("Effacer", _barre.vider))

	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gauche.add_child(defil)
	var palette := PaletteMudras.new()
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.choisi.connect(_barre.ajouter)
	defil.add_child(palette)

	var droite := UI.carte()
	droite.custom_minimum_size.x = 440
	h.add_child(droite)
	var dv := UI.vbox(12)
	droite.add_child(dv)
	dv.add_child(UI.label("Ce que dit le Souffle", 24, Pal.IVOIRE, true))
	_resultat = UI.vbox(10)
	dv.add_child(_resultat)
	_resultat.add_child(UI.texte("Compose une suite de signes, puis libère ton Souffle. Un essai raté n'est jamais perdu : écoute la résonance.", 16, Pal.IVOIRE_DOUX, 400))
	dv.add_child(UI.frise())
	dv.add_child(UI.label("Essais récents", 18, Pal.OR, true))
	var dj := ScrollContainer.new()
	dj.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dj)
	_journal = UI.vbox(6)
	_journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dj.add_child(_journal)
	_maj()


func _maj() -> void:
	_liberer.disabled = _barre.sequence.is_empty()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_BACKSPACE:
				_barre.retirer()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not _liberer.disabled:
					_essayer()
			KEY_ESCAPE:
				_barre.vider()


func _essayer() -> void:
	var seq := _barre.sequence.duplicate()
	_liberer.disabled = true
	var r := await Api.envoyer("/api/dojo", {"sequence": seq})
	_liberer.disabled = false
	if not r.ok:
		erreur(r.erreur)
		return
	var d: Dictionary = r.data
	Jeu.ninja = d.ninja
	for c in _resultat.get_children():
		c.queue_free()
	var score := 0
	if d.valide:
		var j: Dictionary = d.jutsu
		var col := Jeu.couleur_element(j.element)
		_barre.couleur_eclat = col
		_barre.eclat = 1.0
		if d.nouveau:
			_resultat.add_child(UI.label("JUTSU LÉGENDAIRE !" if j.legendaire else "Nouveau jutsu !", 20, Pal.OR_VIF, true))
		_resultat.add_child(UI.texte(j.nom, 28 if j.nom.length() < 30 else 22, col.lightened(0.25), 400))
		_resultat.get_child(_resultat.get_child_count() - 1).add_theme_font_override("font", Pal.police_titre)
		_resultat.add_child(UI.label("%s  ·  %s  ·  puissance %d" % [Jeu.libelle_type(j), j.get("nature", ""), int(j.get("puissance", 0))], 15, Pal.IVOIRE_DOUX))
		_resultat.add_child(UI.glyphes(j.sequence, 30))
		_resultat.add_child(UI.texte(j.texte, 15, Pal.IVOIRE_DOUX, 400))
		_resultat.add_child(UI.label("Souffle : %d   ·   %d tour(s) d'incantation   ·   maîtrise %d" % [j.cout, j.tours, j.maitrise], 14, Pal.OR))
		_resultat.add_child(_bouton_favori(j))
		if not d.nouveau:
			_resultat.add_child(UI.label("Tu connais déjà ce jutsu.", 14, Pal.GRIS))
		else:
			notifier(d.message, Pal.OR_VIF, 3.5)
		score = 100
	else:
		var res = d.get("resonance")
		if res != null:
			score = int(res.score)
			var col := Pal.SANG.lerp(Pal.OR_VIF, score / 100.0)
			if res.ancienne:
				col = Color("b9a7ff")
			_resultat.add_child(UI.label("Résonance : %d / 100" % score, 20, col, true))
			_resultat.add_child(UI.barre(score, 100, col, 12))
			if res.ancienne:
				_resultat.add_child(UI.label("Une vibration ancienne…", 16, col))
		_resultat.add_child(UI.texte(d.message, 16, Pal.IVOIRE, 400))
		if res != null and res.get("indice", "") != "":
			_resultat.add_child(UI.texte(res.indice, 14, Pal.OR, 400))
	_ajouter_journal(seq, d, score)


func _ajouter_journal(seq: Array, d: Dictionary, score: int) -> void:
	var ligne := UI.hbox(8)
	ligne.add_child(UI.glyphes(seq, 20))
	ligne.add_child(UI.extensible())
	var t := ""
	var col := Pal.GRIS
	if d.valide:
		t = d.jutsu.nom
		col = Jeu.couleur_element(d.jutsu.element).lightened(0.2)
	elif d.get("refus", "") != "":
		t = "pouvoir endormi"
		col = Color("b9a7ff")
	else:
		t = "résonance %d" % score
	var l := UI.label(t, 13, col)
	l.clip_text = true
	l.custom_minimum_size.x = 150
	ligne.add_child(l)
	_journal.add_child(ligne)
	_journal.move_child(ligne, 0)
	while _journal.get_child_count() > 14:
		_journal.get_child(_journal.get_child_count() - 1).free()


func _bouton_favori(j: Dictionary) -> Control:
	var zone := UI.hbox(0)
	_remplir_favori(zone, j)
	return zone


func _remplir_favori(zone: HBoxContainer, j: Dictionary) -> void:
	for c in zone.get_children():
		c.queue_free()
	var fav: bool = j.get("favori", false)
	var b := UI.bouton("★ Dans tes favoris (retirer)" if fav else "☆ Ajouter aux favoris de combat", func():
		var r := await Api.envoyer("/api/ninja/favori", {"cle": j.cle, "favori": not fav})
		if not r.ok:
			erreur(r.erreur)
			return
		Jeu.ninja = r.data
		j.favori = not fav
		notifier("Favoris : %d / 5" % r.data.favoris.size(), Pal.OR_VIF, 1.5)
		_remplir_favori(zone, j), 15)
	b.add_theme_color_override("font_color", Pal.OR_VIF if fav else Pal.IVOIRE)
	zone.add_child(b)
