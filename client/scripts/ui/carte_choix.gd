class_name CarteChoix
extends PanelContainer
## Carte cliquable (région, village, rencontre…) avec état sélectionné.

signal clic

var couleur := Pal.OR
var selectionnee := false:
	set(v):
		selectionnee = v
		_style()
var inactive := false:
	set(v):
		inactive = v
		_style()
var contenu: VBoxContainer
var _survol := false


func _init(c: Color = Pal.OR) -> void:
	couleur = c
	contenu = UI.vbox(6)
	contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenu)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		_survol = true
		_style())
	mouse_exited.connect(func():
		_survol = false
		_style())
	_style()


func _gui_input(ev: InputEvent) -> void:
	if inactive:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clic.emit()
		accept_event()


func ajouter(c: Control) -> Control:
	_ignorer_souris(c)
	contenu.add_child(c)
	return c


func _ignorer_souris(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in c.get_children():
		if e is Control:
			_ignorer_souris(e)


func _style() -> void:
	var fond := Color(Pal.PANNEAU, 0.94)
	var bord := Pal.BORD
	var ep := 1
	if inactive:
		fond = Color("171114", 0.9)
	elif selectionnee:
		fond = Color(couleur.darkened(0.72), 0.95)
		bord = couleur
		ep = 2
	elif _survol:
		bord = Color(couleur, 0.8)
	add_theme_stylebox_override("panel", Pal.boite(fond, bord, 12, ep, 16))
	modulate = Color(1, 1, 1, 0.55) if inactive else Color.WHITE
