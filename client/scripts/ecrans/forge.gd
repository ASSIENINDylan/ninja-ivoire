extends Ecran
## La forge du village : les ressources exploitées deviennent armes et
## armures. Le coffre garde les ressources à l'abri : ce qu'il contient
## n'est jamais perdu, contrairement au sac.

const RESSOURCES := ["fer", "peau", "pierre", "or", "diamant"]

var _gauche: VBoxContainer
var _milieu: VBoxContainer
var _droite: VBoxContainer


func construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 26)
	add_child(marge)
	var v := UI.vbox(12)
	marge.add_child(v)
	var tete := UI.hbox(16)
	v.add_child(tete)
	tete.add_child(UI.label("La forge de %s" % Jeu.ninja.village, 40, Pal.IVOIRE, true))
	tete.add_child(UI.extensible())
	tete.add_child(UI.bouton("Retour au village", func(): Jeu.aller("village")))
	v.add_child(UI.frise())
	var h := UI.hbox(18)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	for i in 3:
		var carte := UI.carte()
		carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carte.size_flags_stretch_ratio = [1.0, 1.4, 0.9][i]
		h.add_child(carte)
		var defil := ScrollContainer.new()
		defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		carte.add_child(defil)
		var col := UI.vbox(10)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		defil.add_child(col)
		match i:
			0:
				_gauche = col
			1:
				_milieu = col
			2:
				_droite = col
	_remplir()


static func _objet(id: String):
	for o in Jeu.catalogue.forge.objets:
		if o.id == id:
			return o
	return null


static func _effets(o: Dictionary) -> String:
	var t := PackedStringArray()
	if int(o.get("puissance", 0)) > 0:
		t.append("arme +%d" % int(o.puissance))
	if o.get("distance", false):
		t.append("à distance")
	if int(o.get("defense", 0)) > 0:
		t.append("défense +%d" % int(o.defense))
	if int(o.get("defense_mag", 0)) > 0:
		t.append("défense magique +%d" % int(o.defense_mag))
	if int(o.get("pv", 0)) > 0:
		t.append("PV +%d" % int(o.pv))
	if int(o.get("manhis", 0)) > 0:
		t.append("Manhis +%d" % int(o.manhis))
	return " · ".join(t)


func _cout(o: Dictionary) -> Control:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 10)
	var n = Jeu.ninja
	for r in RESSOURCES:
		var q := int(o.cout.get(r, 0))
		if q == 0:
			continue
		var dispo := int(n.sac.get(r, 0)) + int(n.coffre.get(r, 0))
		var l := UI.hbox(4)
		l.add_child(UI.pastille(CarteMonde.CONTENUS[r][0], 9))
		l.add_child(UI.label("%s ×%d (vous : %d)" % [Jeu.catalogue.noms_ressources[r], q, dispo], 13, Pal.IVOIRE if dispo >= q else Pal.SANG))
		h.add_child(l)
	return h


func _peut(o: Dictionary) -> bool:
	var n = Jeu.ninja
	for r in o.cout:
		if int(n.sac.get(r, 0)) + int(n.coffre.get(r, 0)) < int(o.cout[r]):
			return false
	return true


func _remplir() -> void:
	for col in [_gauche, _milieu, _droite]:
		for c in col.get_children():
			c.queue_free()
	var n = Jeu.ninja
	var noms: Dictionary = Jeu.catalogue.forge.noms_emplacements

	# Équipement porté et objets du sac.
	_gauche.add_child(UI.label("Équipement", 24, Pal.IVOIRE, true))
	for e in Jeu.catalogue.forge.emplacements:
		var carte := UI.carte(Color(Pal.PANNEAU_2, 0.9), Pal.BORD, 10)
		var cv := UI.vbox(4)
		carte.add_child(cv)
		var ligne := UI.hbox(8)
		cv.add_child(ligne)
		ligne.add_child(UI.label(noms[e], 14, Pal.OCRE))
		ligne.add_child(UI.extensible())
		var id: String = n.equipement.get(e, "")
		var o = _objet(id)
		if o != null:
			ligne.add_child(UI.bouton("Retirer", _retirer.bind(e), 13))
			cv.add_child(UI.label(o.nom, 17, Pal.IVOIRE, true))
			cv.add_child(UI.label(_effets(o), 13, Pal.VERT))
		else:
			cv.add_child(UI.label("— rien" if e != "arme" else "— " + str(n.arme.nom) + " (arme de départ)", 14, Pal.GRIS))
		_gauche.add_child(carte)
	_gauche.add_child(UI.label("Objets dans le sac", 20, Pal.IVOIRE, true))
	if n.objets.is_empty():
		_gauche.add_child(UI.texte("Aucun. Attention : à la défaite, le vainqueur emporte les objets non portés.", 13, Pal.GRIS))
	for id in n.objets:
		var o = _objet(id)
		if o == null:
			continue
		var ligne := UI.hbox(8)
		var lv := UI.vbox(2)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_child(UI.label("%s (%s)" % [o.nom, noms[o.emplacement]], 15, Pal.IVOIRE))
		lv.add_child(UI.label(_effets(o), 12, Pal.VERT))
		ligne.add_child(lv)
		ligne.add_child(UI.bouton("Équiper", _equiper.bind(id), 13))
		_gauche.add_child(ligne)

	# La forge.
	_milieu.add_child(UI.label("Forger", 24, Pal.IVOIRE, true))
	_milieu.add_child(UI.texte("La forge prend d'abord dans le coffre, puis dans le sac.", 13, Pal.IVOIRE_DOUX))
	var emplacement := ""
	for o in Jeu.catalogue.forge.objets:
		if o.emplacement != emplacement:
			emplacement = o.emplacement
			_milieu.add_child(UI.label(noms[emplacement], 16, Pal.OCRE, true))
		var carte := UI.carte(Color(Pal.PANNEAU, 0.95), Pal.OR_VIF if _peut(o) else Pal.BORD, 10)
		var ligne := UI.hbox(10)
		carte.add_child(ligne)
		var lv := UI.vbox(3)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(lv)
		lv.add_child(UI.label(o.nom, 17, Pal.IVOIRE, true))
		lv.add_child(UI.label(_effets(o), 13, Pal.VERT))
		lv.add_child(_cout(o))
		var b := UI.bouton_principal("Forger", _fabriquer.bind(o.id), 15)
		b.disabled = not _peut(o)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(b)
		_milieu.add_child(carte)

	# Sac et coffre.
	_droite.add_child(UI.label("Sac", 24, Pal.IVOIRE, true))
	_droite.add_child(UI.texte("Perdu à la défaite : le vainqueur l'emporte.", 13, Pal.SANG))
	_droite.add_child(_liste(n.sac))
	_droite.add_child(UI.bouton_principal("Tout déposer au coffre", _transferer.bind(true), 15))
	_droite.add_child(UI.frise())
	_droite.add_child(UI.label("Coffre du village", 24, Pal.IVOIRE, true))
	_droite.add_child(UI.texte("Jamais perdu.", 13, Pal.VERT))
	_droite.add_child(_liste(n.coffre))
	_droite.add_child(UI.bouton("Tout reprendre dans le sac", _transferer.bind(false), 15))


func _liste(m: Dictionary) -> Control:
	var v := UI.vbox(4)
	var vide := true
	for r in RESSOURCES:
		if int(m.get(r, 0)) > 0:
			vide = false
			var l := UI.hbox(6)
			l.add_child(UI.pastille(CarteMonde.CONTENUS[r][0], 11))
			l.add_child(UI.label(Jeu.catalogue.noms_ressources[r], 15, Pal.IVOIRE))
			l.add_child(UI.extensible())
			l.add_child(UI.label(str(int(m[r])), 15, Pal.IVOIRE, true))
			v.add_child(l)
	if vide:
		v.add_child(UI.label("vide", 14, Pal.GRIS))
	return v


func _appel(route: String, corps: Dictionary, message: String) -> void:
	var r := await Api.envoyer(route, corps)
	if not r.ok:
		erreur(r.erreur)
		return
	Jeu.ninja = r.data
	if message != "":
		notifier(message, Pal.VERT, 2.0)
	_remplir()


func _fabriquer(id: String) -> void:
	await _appel("/api/forge/fabriquer", {"objet": id}, "Forgé : %s. Il t'attend dans le sac." % _objet(id).nom)


func _equiper(id: String) -> void:
	await _appel("/api/equipement/equiper", {"objet": id}, "Tu portes : %s." % _objet(id).nom)


func _retirer(e: String) -> void:
	await _appel("/api/equipement/retirer", {"emplacement": e}, "")


func _transferer(deposer: bool) -> void:
	await _appel("/api/village/deposer" if deposer else "/api/village/reprendre", {}, "Coffre mis à jour.")
