extends Control
## Racine du jeu : applique le thème et change d'écran à la demande.

const ECRANS := {
	"titre": preload("res://scripts/ecrans/titre.gd"),
	"creation": preload("res://scripts/ecrans/creation.gd"),
	"village": preload("res://scripts/ecrans/village.gd"),
	"dojo": preload("res://scripts/ecrans/dojo.gd"),
	"grimoire": preload("res://scripts/ecrans/grimoire.gd"),
	"combat": preload("res://scripts/ecrans/combat.gd"),
	"carte": preload("res://scripts/ecrans/carte.gd"),
}

var _ecran: Control = null


func _ready() -> void:
	theme = Pal.creer_theme()
	Jeu.ecran_demande.connect(_changer)
	_changer("titre", {})
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			add_child(load("res://scripts/outils/demo.gd").new())


func _changer(nom: String, params: Dictionary) -> void:
	if _ecran != null:
		_ecran.queue_free()
	var e: Control = ECRANS[nom].new()
	e.set("params", params)
	e.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(e)
	_ecran = e
	e.modulate.a = 0.0
	create_tween().tween_property(e, "modulate:a", 1.0, 0.25)
