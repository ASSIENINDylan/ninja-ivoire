class_name Ecran
extends Control
## Base des écrans : fond nocturne à motifs discrets, notification.

var params: Dictionary = {}
var _toast: Label


func _ready() -> void:
	construire()


## À redéfinir : construit l'interface de l'écran.
func construire() -> void:
	pass


func _draw() -> void:
	var s := size
	# Dégradé vertical sombre.
	var haut := Color("1a1216")
	var bas := Color("0a0709")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([haut, haut, bas, bas]))
	# Losanges discrets, comme un tissu en filigrane.
	var col := Color(Pal.OR, 0.035)
	var pas := 64.0
	var y := 0.0
	var ligne := 0
	while y < s.y + pas:
		var x := (pas * 0.5) if ligne % 2 == 1 else 0.0
		while x < s.x + pas:
			var c := Vector2(x, y)
			draw_polyline(PackedVector2Array([c + Vector2(0, -14), c + Vector2(14, 0), c + Vector2(0, 14), c + Vector2(-14, 0), c + Vector2(0, -14)]), col, 1.0, true)
			x += pas
		y += pas * 0.5
		ligne += 1
	# Vignette.
	var v := Color(0, 0, 0, 0.45)
	var t := Color(0, 0, 0, 0)
	var bord := 180.0
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(bord, 0), Vector2(bord, s.y), Vector2(0, s.y)]), PackedColorArray([v, t, t, v]))
	draw_polygon(PackedVector2Array([Vector2(s.x - bord, 0), Vector2(s.x, 0), s, Vector2(s.x - bord, s.y)]), PackedColorArray([t, v, v, t]))


func notifier(message: String, couleur: Color = Pal.OR_VIF, duree: float = 3.0) -> void:
	if size.x < 1:
		await get_tree().process_frame
	if _toast == null:
		_toast = UI.label("", 18, couleur)
		_toast.add_theme_stylebox_override("normal", Pal.boite(Color("150f12", 0.95), couleur, 8, 1, 12))

		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.z_index = 50
		add_child(_toast)
	_toast.text = message
	_toast.add_theme_color_override("font_color", couleur)
	_toast.reset_size()
	_toast.position = Vector2((size.x - _toast.size.x) * 0.5, size.y - _toast.size.y - 36)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(duree)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func erreur(message: String) -> void:
	notifier(message, Pal.SANG, 4.0)
