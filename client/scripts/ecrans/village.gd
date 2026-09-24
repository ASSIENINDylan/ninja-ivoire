extends Ecran
## Le village : fiche du ninja, carte du pays, dojo, grimoire, combats.

const ATTRIBUTS := [["fangan", "Fangan", "force : dégâts des armes, points de vie"], ["gnanga", "Gnanga", "technique : puissance des jutsus, Souffle, mudras par tour"], ["manhis", "Manhis", "agilité : initiative, esquive, coups critiques"]]

var _fiche: VBoxContainer
var _droite: VBoxContainer
var _carte: CarteMonde
var _ciel: Label


func construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 26)
	add_child(marge)
	var h := UI.hbox(22)
	marge.add_child(h)

	var gauche := UI.carte()
	gauche.custom_minimum_size.x = 400
	h.add_child(gauche)
	_fiche = UI.vbox(10)
	gauche.add_child(_fiche)

	var centre := UI.vbox(10)
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(centre)
	_carte = CarteMonde.new()
	_carte.interactif = false
	_carte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_child(_carte)
	_ciel = UI.label("", 16, Pal.IVOIRE_DOUX)
	_ciel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_ciel)

	var droite_carte := UI.carte()
	droite_carte.custom_minimum_size.x = 430
	h.add_child(droite_carte)
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	droite_carte.add_child(defil)
	_droite = UI.vbox(12)
	_droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defil.add_child(_droite)

	_remplir()
	if params.get("bienvenue", false):
		notifier("Bienvenue, %s. Ton Souffle s'éveille. Va au dojo essayer tes premiers signes." % Jeu.ninja.nom, Pal.OR_VIF, 5.0)
	if params.has("message"):
		notifier(params.message, Pal.OR_VIF, 5.0)


func _remplir() -> void:
	for c in _fiche.get_children():
		c.queue_free()
	for c in _droite.get_children():
		c.queue_free()
	var n = Jeu.ninja
	var reg := Jeu.region(n.region)

	# --- Fiche ---
	_fiche.add_child(UI.label(n.nom, 40, Pal.IVOIRE, true))
	_fiche.add_child(UI.label("%s — %s" % [n.village, reg.nom], 16, Pal.OR))
	_fiche.add_child(UI.label("Village %s" % n.type_village, 14, Pal.IVOIRE_DOUX))
	_fiche.add_child(UI.frise())
	var lv := UI.hbox(10)
	lv.add_child(UI.label("Niveau %d" % n.niveau, 24, Pal.IVOIRE, true))
	lv.add_child(UI.extensible())
	lv.add_child(UI.label("%d Djê" % n.dje, 18, Pal.OR_VIF))
	_fiche.add_child(lv)
	_fiche.add_child(UI.label("Expérience %d / %d" % [n.xp, n.xp_prochain], 13, Pal.IVOIRE_DOUX))
	_fiche.add_child(UI.barre(n.xp, n.xp_prochain, Pal.OR, 10))
	var pv := int(n.get("pv", n.pv_max))
	_fiche.add_child(UI.label("Points de vie  %d / %d%s" % [pv, n.pv_max, "" if pv >= int(n.pv_max) else "  (blessé : repos, ou le temps guérit)"], 15, Pal.IVOIRE_DOUX))
	_fiche.add_child(UI.barre(pv, n.pv_max, Pal.VIE, 10))
	_fiche.add_child(UI.label("Souffle  %d   ·   %d mudras par tour" % [n.souffle_max, n.mudras_par_tour], 15, Pal.IVOIRE_DOUX))
	_fiche.add_child(UI.barre(n.souffle_max, n.souffle_max, Pal.SOUFFLE, 10))
	_fiche.add_child(UI.espace(4))

	var titre_attr := UI.hbox(8)
	titre_attr.add_child(UI.label("Attributs", 20, Pal.OR, true))
	titre_attr.add_child(UI.extensible())
	if n.points > 0:
		titre_attr.add_child(UI.label("%d points à répartir" % n.points, 15, Pal.OR_VIF))
	_fiche.add_child(titre_attr)
	for a in ATTRIBUTS:
		var ligne := UI.hbox(8)
		var nom_l := UI.label(a[1], 18, Pal.IVOIRE)
		nom_l.custom_minimum_size.x = 90
		nom_l.tooltip_text = a[2]
		nom_l.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(nom_l)
		ligne.add_child(UI.label(str(int(n[a[0]])), 20, Pal.OR_VIF, true))
		ligne.add_child(UI.label(a[2].split(":")[0], 13, Pal.GRIS))
		ligne.add_child(UI.extensible())
		if n.points > 0:
			var b := UI.bouton("+", _ajouter_point.bind(a[0]), 16)
			ligne.add_child(b)
		_fiche.add_child(ligne)

	_fiche.add_child(UI.espace(4))
	_fiche.add_child(UI.label("Éléments  (%d / %d)" % [n.elements.size(), n.elements_max], 20, Pal.OR, true))
	var els := HFlowContainer.new()
	els.add_theme_constant_override("h_separation", 12)
	for e in n.elements:
		var el := Jeu.element(e)
		var b := UI.hbox(6)
		b.add_child(UI.pastille(Color(el.couleur), 14))
		b.add_child(UI.label(el.nom, 17, Jeu.couleur_texte(el.couleur)))
		b.tooltip_text = el.role
		els.add_child(b)
	_fiche.add_child(els)
	_fiche.add_child(UI.espace(4))
	var jutsus: Array = n.jutsus if n.jutsus != null else []
	_fiche.add_child(UI.label("%d jutsus connus   ·   %d victoires, %d défaites" % [jutsus.size(), n.victoires, n.defaites], 15, Pal.IVOIRE_DOUX))
	_fiche.add_child(UI.extensible())
	_fiche.add_child(UI.bouton("Abandonner ce ninja", _abandonner, 14))

	# --- Actions ---
	if n.elements_a_choisir > 0:
		_droite.add_child(_panneau_element())
	_droite.add_child(UI.label("Le village", 26, Pal.IVOIRE, true))
	var dojo := UI.bouton_principal("Dojo — expérimenter les mudras", func(): Jeu.aller("dojo"), 19)
	_droite.add_child(dojo)
	_droite.add_child(UI.bouton("Grimoire — mes jutsus (%d)" % jutsus.size(), func(): Jeu.aller("grimoire"), 18))
	_droite.add_child(UI.bouton("Forge, coffre et équipement", func(): Jeu.aller("forge"), 18))
	var sac: Dictionary = n.get("sac", {})
	if not sac.is_empty():
		var total := 0
		for r in sac:
			total += int(sac[r])
		_droite.add_child(UI.texte("Ton sac contient %d ressources : dépose-les au coffre de la forge pour ne pas les perdre." % total, 13, Pal.OCRE, 380))
	_droite.add_child(UI.frise())
	_droite.add_child(UI.label("Au-delà des murs", 26, Pal.IVOIRE, true))
	_droite.add_child(UI.texte("Explore la Côte d'Ivoire case par case. Exploite le fer, les peaux, la pierre, l'or et le diamant ; attaque les camps de bandits ; méfie-toi des autres ninjas. La défaite te ramène ici, sans ton sac ni ton équipement.", 14, Pal.IVOIRE_DOUX, 380))
	_droite.add_child(UI.bouton_principal("Sortir explorer la carte", func(): Jeu.aller("carte", {"message": "Vous quittez %s." % Jeu.ninja.village}), 19))
	var s = n.get("situation")
	if s != null:
		_droite.add_child(UI.label("Endurance %d / %d" % [int(n.endurance), int(s.endurance_max)], 15, Pal.IVOIRE_DOUX))

	var c = Jeu.ciel
	if c != null and not c.is_empty():
		_ciel.text = "%s  ·  %s  ·  %s  ·  Soleil ×%.2f  ·  Lune ×%.2f" % [c.heure, "nuit" if c.nuit else "jour", c.phase_lune, c.facteur_soleil, c.facteur_lune]



func _panneau_element() -> Control:
	var carte := UI.carte(Color("fff4de"), Pal.OR_VIF)
	var v := UI.vbox(8)
	carte.add_child(v)
	v.add_child(UI.label("Un nouvel élément s'offre à toi", 20, Pal.OR_VIF, true))
	v.add_child(UI.texte("Choisis-le bien : il ouvre de nouveaux mudras et de nouvelles fusions.", 14))
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	v.add_child(grille)
	for e in Jeu.catalogue.elements:
		if e.tier != "base" or Jeu.ninja.elements.has(e.id):
			continue
		var b := UI.bouton(e.nom, _choisir_element.bind(e.id), 14)
		b.add_theme_color_override("font_color", Jeu.couleur_texte(e.couleur))
		b.tooltip_text = "%s\nFort contre : %s\nFaible contre : %s" % [e.role, ", ".join(e.fort), ", ".join(e.faible)]
		grille.add_child(b)
	return carte


func _ajouter_point(attr: String) -> void:
	var corps := {"fangan": 0, "gnanga": 0, "manhis": 0}
	corps[attr] = 1
	var r := await Api.envoyer("/api/ninja/attributs", corps)
	if not r.ok:
		erreur(r.erreur)
		return
	Jeu.ninja = r.data
	_remplir()


func _choisir_element(id: String) -> void:
	var r := await Api.envoyer("/api/ninja/element", {"element": id})
	if not r.ok:
		erreur(r.erreur)
		return
	Jeu.ninja = r.data
	notifier("Tu maîtrises désormais l'élément %s." % Jeu.element(id).nom)
	_remplir()



func _abandonner() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Abandonner ce ninja"
	d.dialog_text = "Ton ninja et son grimoire seront effacés pour toujours. Continuer ?"
	d.ok_button_text = "Effacer"
	d.cancel_button_text = "Garder"
	add_child(d)
	d.confirmed.connect(func():
		await Api.supprimer("/api/ninja")
		Jeu.ninja = null
		Jeu.aller("creation"))
	d.popup_centered()
