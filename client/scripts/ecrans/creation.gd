extends Ecran
## Création du ninja : nom, région, type de village.

const NOMS_ATTRIBUTS := {"fangan": "Fangan (force)", "gnanga": "Gnanga (technique)", "manhis": "Manhis (agilité)"}

var _nom: LineEdit
var _region := ""
var _village := ""
var _cartes_regions := {}
var _cartes_villages := {}
var _noms_villages := {}
var _resume: Label
var _naitre: Button


func construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + cote, 70)
	marge.add_theme_constant_override("margin_top", 36)
	marge.add_theme_constant_override("margin_bottom", 30)
	add_child(marge)
	var v := UI.vbox(14)
	marge.add_child(v)

	var tete := UI.hbox(20)
	v.add_child(tete)
	tete.add_child(UI.label("Naissance d'un ninja", 44, Pal.IVOIRE, true))
	tete.add_child(UI.extensible())
	tete.add_child(UI.bouton("Retour", func(): Jeu.aller("titre")))
	v.add_child(UI.frise())

	# 1. Nom
	var ligne_nom := UI.hbox(16)
	v.add_child(ligne_nom)
	ligne_nom.add_child(UI.label("1.  Ton nom de ninja", 22, Pal.OR, true))
	_nom = LineEdit.new()
	_nom.placeholder_text = "Kouadio, Aya, Yao, Adjoua…"
	_nom.max_length = 20
	_nom.custom_minimum_size = Vector2(360, 0)
	_nom.text_changed.connect(func(_t): _maj())
	ligne_nom.add_child(_nom)

	# 2. Région
	v.add_child(UI.label("2.  Ta région — elle te donne ton premier élément et favorise un attribut. On ne change jamais de région.", 18, Pal.OR))
	var grille := GridContainer.new()
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 14)
	grille.add_theme_constant_override("v_separation", 14)
	v.add_child(grille)
	for r in Jeu.catalogue.regions:
		if not r.jouable:
			continue
		var el := Jeu.element(r.element)
		var carte := CarteChoix.new(Color(el.couleur))
		carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := UI.hbox(10)
		h.add_child(UI.pastille(Color(el.couleur), 16))
		h.add_child(UI.label(r.nom, 24, Pal.IVOIRE, true))
		carte.ajouter(h)
		carte.ajouter(UI.label(r.geo, 14, Pal.IVOIRE_DOUX))
		carte.ajouter(UI.label("Élément : %s   ·   %s" % [el.nom, NOMS_ATTRIBUTS[r.attribut]], 15, Color(el.couleur).lightened(0.25)))
		carte.clic.connect(_choisir_region.bind(r.id))
		grille.add_child(carte)
		_cartes_regions[r.id] = carte

	# 3. Village
	v.add_child(UI.label("3.  Ton village — chaque région en compte trois.", 18, Pal.OR))
	var ligne_v := UI.hbox(14)
	v.add_child(ligne_v)
	var couleurs := {"traditionnel": Color("c98b4a"), "moderne": Color("9aa6b2"), "futuriste": Color("5ec8d8")}
	for t in Jeu.catalogue.villages:
		var carte := CarteChoix.new(couleurs.get(t.id, Pal.OR))
		carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carte.ajouter(UI.label(t.nom, 22, couleurs.get(t.id, Pal.OR), true))
		var nom_v := UI.label("—", 16, Pal.IVOIRE)
		carte.ajouter(nom_v)
		_noms_villages[t.id] = nom_v
		carte.ajouter(UI.texte("+ " + t.avantages, 14, Color("9ccf8f"), 300))
		carte.ajouter(UI.texte("− " + t.defauts, 14, Color("d98c7a"), 300))
		carte.clic.connect(_choisir_village.bind(t.id))
		ligne_v.add_child(carte)
		_cartes_villages[t.id] = carte

	v.add_child(UI.extensible())
	var bas := UI.hbox(20)
	v.add_child(bas)
	_resume = UI.label("", 18, Pal.IVOIRE_DOUX)
	bas.add_child(_resume)
	bas.add_child(UI.extensible())
	_naitre = UI.bouton_principal("Naître", _creer, 24)
	bas.add_child(_naitre)
	_maj()
	_nom.grab_focus()


func _choisir_region(id: String) -> void:
	_region = id
	for k in _cartes_regions:
		_cartes_regions[k].selectionnee = k == id
	var r := Jeu.region(id)
	var i := 0
	for t in Jeu.catalogue.villages:
		_noms_villages[t.id].text = r.villages[i]
		i += 1
	_maj()


func _choisir_village(id: String) -> void:
	_village = id
	for k in _cartes_villages:
		_cartes_villages[k].selectionnee = k == id
	_maj()


func _maj() -> void:
	var pret := _nom.text.strip_edges().length() >= 2 and _region != "" and _village != ""
	_naitre.disabled = not pret
	if not pret:
		_resume.text = "Choisis un nom, une région et un village."
		return
	var r := Jeu.region(_region)
	var i := ["traditionnel", "moderne", "futuriste"].find(_village)
	_resume.text = "%s naîtra à %s, région %s, avec l'élément %s." % [_nom.text.strip_edges(), r.villages[i], r.nom, Jeu.element(r.element).nom]


func _creer() -> void:
	_naitre.disabled = true
	var r := await Api.envoyer("/api/ninja", {"nom": _nom.text.strip_edges(), "region": _region, "village": _village})
	if not r.ok:
		erreur(r.erreur)
		_naitre.disabled = false
		return
	Jeu.ninja = r.data
	Jeu.aller("village", {"bienvenue": true})
