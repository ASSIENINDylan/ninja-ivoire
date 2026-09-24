class_name MudraBouton
extends Button
## Bouton d'un mudra : son glyphe, son nom, et un verrou s'il n'est pas
## encore débloqué.

signal choisi(id: String)

var mudra_id := ""
var verrou := ""  # texte affiché si le mudra est verrouillé
var compact := false
var _survol := false


func _init(id: String = "") -> void:
	mudra_id = id


func _ready() -> void:
	custom_minimum_size = Vector2(84, 74) if compact else Vector2(86, 98)
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var m := Jeu.mudra(mudra_id)
	var permis := Jeu.mudra_permis(mudra_id)
	disabled = not permis
	if not permis:
		var niv := int(m.get("niveau", 0))
		if m.get("categorie", "") == "element":
			verrou = "élément" if niv >= 0 else "quête"
		else:
			verrou = "niv. %d" % niv
	tooltip_text = "%s — %s" % [m.get("nom", "?"), Pal.NOMS_CATEGORIES.get(m.get("categorie", ""), "")]
	pressed.connect(func(): choisi.emit(mudra_id))
	mouse_entered.connect(func():
		_survol = true
		queue_redraw())
	mouse_exited.connect(func():
		_survol = false
		queue_redraw())


func _draw() -> void:
	var m := Jeu.mudra(mudra_id)
	var col := Jeu.couleur_mudra(mudra_id)
	var r := 22.0 if compact else 30.0
	var c := Vector2(size.x * 0.5, r + 6)
	if disabled:
		col = Color("c9bfb2")
	draw_circle(c, r + 3, Color(col, 0.18 if _survol and not disabled else 0.08))
	draw_circle(c, r, Color("ffffff"))
	draw_arc(c, r, 0, TAU, 48, Color(col, 0.9 if _survol and not disabled else 0.6), 2.0, true)
	UI.dessiner_glyphe(self, c, r - 5, mudra_id, col, 2.2)
	var font := Pal.police_texte
	var nom: String = m.get("nom", "?")
	var fs := (12 if nom.length() < 11 else 11) if compact else (14 if nom.length() < 12 else 12)
	var w := font.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) * 0.5, c.y + r + (15 if compact else 18)), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GRIS if disabled else Pal.IVOIRE)
	if disabled and verrou != "":
		draw_circle(c, r - 1, Color(0.95, 0.92, 0.88, 0.85))
		var w2 := font.get_string_size(verrou, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2((size.x - w2) * 0.5, c.y + 5), verrou, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.IVOIRE_DOUX)
