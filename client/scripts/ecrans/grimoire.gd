extends Ecran
## Le grimoire : tous les jutsus découverts, pour toujours.


func construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + cote, 80)
	marge.add_theme_constant_override("margin_top", 30)
	marge.add_theme_constant_override("margin_bottom", 30)
	add_child(marge)
	var v := UI.vbox(12)
	marge.add_child(v)
	var tete := UI.hbox(16)
	v.add_child(tete)
	tete.add_child(UI.label("Grimoire de %s" % Jeu.ninja.nom, 42, Pal.IVOIRE, true))
	tete.add_child(UI.extensible())
	tete.add_child(UI.bouton("Dojo", func(): Jeu.aller("dojo")))
	tete.add_child(UI.bouton("Retour au village", func(): Jeu.aller("village")))
	v.add_child(UI.frise())

	var jutsus: Array = Jeu.ninja.jutsus if Jeu.ninja.jutsus != null else []
	if jutsus.is_empty():
		v.add_child(UI.texte("Ton grimoire est vide. Va au dojo : compose un élément, une forme et un but, puis libère ton Souffle.", 20, Pal.IVOIRE_DOUX))
		return
	v.add_child(UI.label("%d jutsus sur des milliers possibles" % jutsus.size(), 16, Pal.OR))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(defil)
	var grille := GridContainer.new()
	grille.columns = 2
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override("h_separation", 16)
	grille.add_theme_constant_override("v_separation", 16)
	defil.add_child(grille)
	for j in jutsus:
		var col := Jeu.couleur_element(j.element)
		var carte := UI.carte(Color(Pal.PANNEAU, 0.94), Pal.OR_VIF if j.legendaire else col.darkened(0.3))
		carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(8)
		carte.add_child(cv)
		var t := UI.hbox(10)
		t.add_child(UI.pastille(col, 14))
		var nom := UI.label(j.nom, 21, col.lightened(0.3), true)
		nom.clip_text = true
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(nom)
		if j.legendaire:
			t.add_child(UI.label("légendaire", 14, Pal.OR_VIF))
		cv.add_child(t)
		cv.add_child(UI.label(j.get("nature", ""), 14, Pal.IVOIRE_DOUX))
		cv.add_child(UI.glyphes(j.sequence, 30))
		cv.add_child(UI.texte(j.texte, 14, Pal.IVOIRE_DOUX, 600))
		var bas := UI.hbox(12)
		bas.add_child(UI.label("Souffle %d  ·  %d tour(s)  ·  %d usages" % [j.cout, j.tours, j.usages], 14, Pal.OR))
		bas.add_child(UI.extensible())
		bas.add_child(UI.label("Maîtrise %d" % j.maitrise, 14, Pal.IVOIRE))
		cv.add_child(bas)
		cv.add_child(UI.barre(j.maitrise, 100, col, 8))
		grille.add_child(carte)
