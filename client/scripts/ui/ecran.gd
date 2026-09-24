class_name Ecran
extends Control
## Base des écrans : fond clair aux motifs de pagne colorés, notification.

var params: Dictionary = {}
var _toast: Label


func _ready() -> void:
	construire()


## À redéfinir : construit l'interface de l'écran.
func construire() -> void:
	pass


func _draw() -> void:
	var s := size
	# Dégradé vertical clair.
	var haut := Color("fdf8ef")
	var bas := Color("f1e4cc")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([haut, haut, bas, bas]))
	# Losanges colorés, comme un pagne en filigrane.
	var couleurs := [Pal.OR_VIF, Pal.VERT, Pal.SOUFFLE, Pal.ROSE, Pal.TURQUOISE]
	var pas := 64.0
	var y := 0.0
	var ligne := 0
	while y < s.y + pas:
		var x := (pas * 0.5) if ligne % 2 == 1 else 0.0
		var k := ligne
		while x < s.x + pas:
			var c := Vector2(x, y)
			var col: Color = Color(couleurs[k % couleurs.size()], 0.09)
			draw_polyline(PackedVector2Array([c + Vector2(0, -14), c + Vector2(14, 0), c + Vector2(0, 14), c + Vector2(-14, 0), c + Vector2(0, -14)]), col, 1.5, true)
			x += pas
			k += 1
		y += pas * 0.5
		ligne += 1
	# Bandes de couleur en haut et en bas, comme la lisière d'un pagne.
	var bande := 6.0
	var n := 0
	var bx := 0.0
	while bx < s.x:
		var col2: Color = couleurs[n % couleurs.size()]
		draw_rect(Rect2(bx, 0, 40, bande), col2)
		draw_rect(Rect2(bx, s.y - bande, 40, bande), col2)
		bx += 40
		n += 1


func notifier(message: String, couleur: Color = Pal.OR_VIF, duree: float = 3.0) -> void:
	if size.x < 1:
		await get_tree().process_frame
	if _toast == null:
		_toast = UI.label("", 18, couleur)
		_toast.add_theme_stylebox_override("normal", Pal.boite(Color(Pal.PANNEAU, 0.97), couleur, 8, 2, 12))

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
