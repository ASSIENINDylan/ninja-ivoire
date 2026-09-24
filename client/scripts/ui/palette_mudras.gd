class_name PaletteMudras
extends VBoxContainer
## Tous les mudras, rangés par catégorie. Les mudras verrouillés restent
## visibles : ils donnent envie de progresser.

signal choisi(id: String)

var compacte := false


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	if compacte:
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", 2)
		add_child(flux)
		for m in Jeu.catalogue.mudras:
			if Jeu.mudra_permis(m.id):
				var b := MudraBouton.new(m.id)
				b.compact = true
				b.choisi.connect(func(id): choisi.emit(id))
				flux.add_child(b)
		return
	for cat in ["element", "forme", "effet", "modificateur"]:
		var tete := UI.hbox(8)
		tete.add_child(UI.pastille(Pal.CATEGORIES[cat], 10))
		tete.add_child(UI.label(Pal.NOMS_CATEGORIES[cat], 17, Pal.CATEGORIES[cat].darkened(0.1), true))
		add_child(tete)
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", 2)
		flux.add_theme_constant_override("v_separation", 2)
		add_child(flux)
		for m in Jeu.catalogue.mudras:
			if m.categorie != cat:
				continue
			var b := MudraBouton.new(m.id)
			b.choisi.connect(func(id): choisi.emit(id))
			flux.add_child(b)
