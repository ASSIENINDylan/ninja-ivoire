class_name DecorCombat
extends Control
## Décor du combat : ciel nocturne, silhouettes de savane, sol, torches
## vacillantes et brume, dans l'esprit de Darkest Dungeon.

var t := 0.0
var sol := 0.64  # hauteur du sol (fraction de l'écran)
var teinte := Color("1d2340")  # couleur du ciel, selon le lieu
var _brume: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	for i in 9:
		_brume.append({"x": _rng.randf(), "y": _rng.randf_range(0.55, 0.8), "r": _rng.randf_range(160, 320), "v": _rng.randf_range(4, 12)})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var gy := s.y * sol
	# Ciel.
	var haut := teinte.darkened(0.55)
	var horizon := teinte.lightened(0.08)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, gy), Vector2(0, gy)]),
		PackedColorArray([haut, haut, horizon, horizon]))
	# Lune.
	var lune := Vector2(s.x * 0.8, s.y * 0.16)
	for i in 16:
		draw_circle(lune, 32 + i * 6, Color(0.9, 0.9, 1.0, 0.009))
	draw_circle(lune, 30, Color("e9e4d4"))
	draw_circle(lune + Vector2(9, -4), 26, Color(teinte.darkened(0.4), 0.35))
	# Étoiles.
	_rng.seed = 11
	for i in 70:
		var p := Vector2(_rng.randf() * s.x, _rng.randf() * gy * 0.7)
		var a := 0.3 + 0.3 * sin(t * _rng.randf_range(0.5, 2.0) + i)
		draw_circle(p, _rng.randf_range(0.6, 1.6), Color(1, 1, 1, a))
	# Silhouettes lointaines : collines, baobabs, cases.
	var loin := Color(teinte.darkened(0.35), 1)
	var pts := PackedVector2Array([Vector2(0, gy)])
	for i in 13:
		var x := s.x * i / 12.0
		pts.append(Vector2(x, gy - 60 - 40 * sin(i * 1.7) - 25 * sin(i * 0.6)))
	pts.append(Vector2(s.x, gy))
	draw_colored_polygon(pts, loin)
	var proche := Color("0d0a0c")
	_baobab(Vector2(s.x * 0.12, gy), 1.2, proche)
	_baobab(Vector2(s.x * 0.9, gy), 0.9, proche)
	_case(Vector2(s.x * 0.24, gy), 0.9, proche)
	_case(Vector2(s.x * 0.73, gy), 0.75, proche)
	# Sol.
	var sol_haut := Color("2a1c16")
	var sol_bas := Color("0c0808")
	draw_polygon(PackedVector2Array([Vector2(0, gy), Vector2(s.x, gy), s, Vector2(0, s.y)]),
		PackedColorArray([sol_haut, sol_haut, sol_bas, sol_bas]))
	for i in 18:
		var y := gy + 8 + i * i * 1.6
		if y > s.y:
			break
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.12), 1.0)
	# Torches.
	_torche(Vector2(s.x * 0.5 - 360, gy - 6))
	_torche(Vector2(s.x * 0.5 + 360, gy - 6))
	# Brume.
	for b in _brume:
		var x: float = fposmod(b.x * s.x + t * b.v, s.x + 600) - 300
		var c := Vector2(x, s.y * b.y)
		for k in 4:
			draw_circle(c + Vector2(k * 60 - 90, sin(k + t * 0.3) * 8), b.r * (0.5 + 0.12 * k), Color(0.75, 0.72, 0.8, 0.012))
	# Vignette.
	var v := Color(0, 0, 0, 0.7)
	var z := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(260, 0), Vector2(260, s.y), Vector2(0, s.y)]), PackedColorArray([v, z, z, v]))
	draw_polygon(PackedVector2Array([Vector2(s.x - 260, 0), Vector2(s.x, 0), s, Vector2(s.x - 260, s.y)]), PackedColorArray([z, v, v, z]))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, 120), Vector2(0, 120)]), PackedColorArray([v, v, z, z]))


func _torche(p: Vector2) -> void:
	var f := 0.85 + 0.1 * sin(t * 9.0) + 0.05 * sin(t * 23.0)
	for i in 24:
		draw_circle(p + Vector2(0, -70), (30 + i * 12) * f, Color(1.0, 0.55, 0.2, 0.011))
	draw_line(p, p + Vector2(0, -64), Color("2b1b12"), 6.0)
	draw_circle(p + Vector2(0, -72), 9 * f, Color(1.0, 0.6, 0.2, 0.9))
	draw_circle(p + Vector2(0, -75), 5 * f, Color(1.0, 0.9, 0.6))
	# Halo au sol.
	draw_set_transform(p, 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 180 * f, Color(1.0, 0.5, 0.2, 0.06))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _baobab(p: Vector2, k: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-26, 0) * k, p + Vector2(-18, -120) * k, p + Vector2(18, -120) * k, p + Vector2(28, 0) * k]), col)
	for a in [-1.2, -0.7, -0.2, 0.3, 0.8, 1.2]:
		var d := Vector2(sin(a), -cos(a))
		var base := p + Vector2(0, -118) * k
		draw_line(base, base + d * 70 * k, col, 7 * k)
		draw_circle(base + d * 70 * k, 14 * k, col)


func _case(p: Vector2, k: float, col: Color) -> void:
	draw_rect(Rect2(p + Vector2(-40, -50) * k, Vector2(80, 50) * k), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-54, -48) * k, p + Vector2(0, -100) * k, p + Vector2(54, -48) * k]), col)
