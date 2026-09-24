class_name Paysage
extends Control
## Un paysage dessiné, de jour et en couleurs, qui rappelle où l'on se
## trouve : savane, savane boisée, forêt, forêt dense, montagne, fleuve,
## lac, lagune ou littoral. Il peut montrer ce qu'abrite la case (camp de
## bandits, gisement, village…). Sert de fond à la carte et aux combats.

var terrain := "savane":
	set(v):
		terrain = v
		queue_redraw()
var contenu := "":
	set(v):
		contenu = v
		queue_redraw()
var lieu := "":  # village, ville, mythique, portail
	set(v):
		lieu = v
		queue_redraw()
var sol := 0.62  # hauteur de l'horizon du sol (fraction de la hauteur)
var pos_contenu := Vector2(-1, -1)  # où dessiner le contenu (fraction) ; par défaut au premier plan
var t := 0.0
var _rng := RandomNumberGenerator.new()

const SOLS := {
	"savane": [Color("f0cf6a"), Color("dcae45")], "savane_boisee": [Color("c8cf62"), Color("9fb04a")],
	"foret": [Color("7cc45e"), Color("4f9a43")], "foret_dense": [Color("4f9c52"), Color("2f6e3a")],
	"montagne": [Color("b9a58a"), Color("8f7a62")], "fleuve": [Color("9fd06a"), Color("6fae4c")],
	"lac": [Color("a6d66c"), Color("78b451")], "lagune": [Color("9ed7a0"), Color("6db483")],
	"littoral": [Color("f6e3a8"), Color("e8c982")],
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var gy := s.y * sol
	_rng.seed = hash(terrain)
	# Ciel de jour.
	var haut := Color("6fc3ee")
	var bas := Color("fdf0d2")
	if terrain == "foret_dense":
		haut = Color("8fd0c0")
		bas = Color("e8f5d8")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, gy), Vector2(0, gy)]),
		PackedColorArray([haut, haut, bas, bas]))
	# Soleil.
	var soleil := Vector2(s.x * 0.82, s.y * 0.16)
	for i in 10:
		draw_circle(soleil, 46 + i * 9, Color(1, 0.93, 0.6, 0.05))
	draw_circle(soleil, 44, Color("ffd54a"))
	draw_circle(soleil, 36, Color("ffe27a"))
	# Nuages qui dérivent.
	for i in 5:
		var x := fmod(_rng.randf() * s.x + t * (6.0 + i * 2.0), s.x + 300.0) - 150.0
		_nuage(Vector2(x, s.y * (0.08 + 0.07 * i)), 0.7 + _rng.randf() * 0.6)
	var cols: Array = SOLS.get(terrain, SOLS.savane)
	match terrain:
		"montagne":
			_montagnes(s, gy)
		"littoral":
			_mer(s, gy)
		_:
			_collines(s, gy, Color(cols[1], 1).lerp(Color("9cc6e0"), 0.45))
	# Sol.
	var sol_haut: Color = cols[0]
	var sol_bas: Color = cols[1]
	draw_polygon(PackedVector2Array([Vector2(0, gy), Vector2(s.x, gy), s, Vector2(0, s.y)]),
		PackedColorArray([sol_haut, sol_haut, sol_bas, sol_bas]))
	match terrain:
		"savane":
			_herbes(s, gy, Color("c9962e"), 90)
			_acacia(Vector2(s.x * 0.14, gy + 10), 1.3)
			_acacia(Vector2(s.x * 0.86, gy + 4), 1.0)
			_acacia(Vector2(s.x * 0.62, gy - 4), 0.6)
		"savane_boisee":
			_herbes(s, gy, Color("8a9a3a"), 70)
			_acacia(Vector2(s.x * 0.1, gy + 8), 1.2)
			_arbre_rond(Vector2(s.x * 0.84, gy + 12), 1.2, Color("5d9e3c"))
			_arbre_rond(Vector2(s.x * 0.7, gy), 0.8, Color("6fae44"))
			_acacia(Vector2(s.x * 0.34, gy - 2), 0.6)
		"foret":
			for i in 9:
				var x := s.x * (i / 8.0)
				_arbre_rond(Vector2(x, gy + 4 + (i % 3) * 6), 0.9 + _rng.randf() * 0.5, Color("3f8f3c").lerp(Color("7cc14f"), _rng.randf()))
			_herbes(s, gy, Color("3f8a36"), 60)
		"foret_dense":
			for i in 14:
				var x := s.x * (i / 13.0)
				_arbre_haut(Vector2(x, gy + 10), 1.1 + _rng.randf() * 0.7, Color("2f7a3a").lerp(Color("4fa052"), _rng.randf()))
			for i in 8:
				var x := s.x * (0.05 + i * 0.13)
				draw_line(Vector2(x, 0), Vector2(x + 20, gy * 0.8), Color("2d6b35", 0.5), 3.0)
			_herbes(s, gy, Color("2a6a30"), 80)
		"montagne":
			_herbes(s, gy, Color("7b6a52"), 40)
			_rocher(Vector2(s.x * 0.15, gy + 40), 1.4)
			_rocher(Vector2(s.x * 0.8, gy + 30), 1.0)
		"fleuve":
			_riviere(s, gy, 0.52, 70.0)
			_arbre_rond(Vector2(s.x * 0.12, gy + 6), 1.2, Color("4f9f3f"))
			_palmier(Vector2(s.x * 0.86, gy + 10), 1.0)
		"lac":
			_riviere(s, gy, 0.5, 220.0)
			_arbre_rond(Vector2(s.x * 0.1, gy + 6), 1.0, Color("4f9f3f"))
		"lagune":
			_riviere(s, gy, 0.55, 160.0, Color("3fbcc0"))
			_mangrove(Vector2(s.x * 0.12, gy + 30), 1.2)
			_mangrove(Vector2(s.x * 0.88, gy + 20), 1.0)
			_pirogue(Vector2(s.x * 0.5 + sin(t * 0.4) * 30.0, gy + s.y * 0.2))
		"littoral":
			_palmier(Vector2(s.x * 0.12, gy + 30), 1.4)
			_palmier(Vector2(s.x * 0.9, gy + 20), 1.1)
			_herbes(s, gy, Color("d9b86a"), 30)
	# Ce qu'abrite la case.
	var c := Vector2(s.x * 0.5, gy + (s.y - gy) * 0.35)
	if pos_contenu.x >= 0:
		c = Vector2(s.x * pos_contenu.x, s.y * pos_contenu.y)
	match lieu:
		"village":
			_case_ronde(c + Vector2(-120, 0), 1.2, Color("c8743a"))
			_case_ronde(c + Vector2(20, 10), 1.5, Color("b8612f"))
			_case_ronde(c + Vector2(150, -5), 1.0, Color("d98b4a"))
		"ville":
			for i in 5:
				var h := 90.0 + (i % 3) * 50.0
				draw_rect(Rect2(c.x - 200 + i * 80, c.y - h, 64, h), [Color("e8a06a"), Color("7fb3d9"), Color("f2d28a"), Color("b9d38a"), Color("e89aa0")][i])
				for k in int(h / 26):
					draw_rect(Rect2(c.x - 190 + i * 80, c.y - h + 10 + k * 26, 14, 12), Color(1, 1, 1, 0.7))
					draw_rect(Rect2(c.x - 166 + i * 80, c.y - h + 10 + k * 26, 14, 12), Color(1, 1, 1, 0.7))
		"mythique":
			for i in 3:
				draw_circle(c + Vector2(0, -60), 60 + i * 24 + sin(t * 2) * 6, Color("9b6fe0", 0.12))
			draw_rect(Rect2(c.x - 14, c.y - 120, 28, 120), Color("7a5a3a"))
			draw_circle(c + Vector2(0, -130), 22, Color("c9a7ff"))
		"portail":
			draw_arc(c + Vector2(0, -40), 90, PI, TAU, 32, Pal.OR_VIF, 14.0, true)
			draw_rect(Rect2(c.x - 97, c.y - 40, 14, 40), Pal.OR_VIF)
			draw_rect(Rect2(c.x + 83, c.y - 40, 14, 40), Pal.OR_VIF)
			draw_circle(c + Vector2(0, -40), 70, Color("5ec8d8", 0.25 + 0.1 * sin(t * 3)))
	match contenu:
		"camp":
			_tente(c + Vector2(-90, 0), 1.2, Color("b8452e"))
			_tente(c + Vector2(80, 8), 1.0, Color("8a6a3a"))
			_feu(c + Vector2(0, 18))
		"fer":
			_rocher(c + Vector2(-40, 10), 1.3)
			_rocher(c + Vector2(50, 18), 0.9)
			for i in 6:
				draw_circle(c + Vector2(-60 + i * 22, -6 + (i % 2) * 10), 5, Color("6f7c8a"))
		"pierre":
			_rocher(c + Vector2(-60, 12), 1.1)
			_rocher(c + Vector2(10, 0), 1.6)
			_rocher(c + Vector2(80, 16), 0.9)
		"peau":
			_antilope(c + Vector2(-60, 10), 1.1)
			_antilope(c + Vector2(70, 18), 0.9)
		"or":
			_rocher(c + Vector2(0, 14), 1.2)
			for i in 7:
				var p := c + Vector2(-50 + i * 17, -10 + (i % 3) * 8)
				draw_circle(p, 6, Color("f2c230"))
				draw_circle(p + Vector2(-2, -2), 2, Color("fff4b0"))
		"diamant":
			_rocher(c + Vector2(0, 16), 1.3)
			for i in 4:
				var p := c + Vector2(-45 + i * 30, -14 + (i % 2) * 10)
				var r := 10.0 + sin(t * 3 + i) * 2.0
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)]), Color("7fe0f5"))
				draw_line(p + Vector2(-r, -r), p + Vector2(r, r), Color(1, 1, 1, 0.5 + 0.5 * sin(t * 4 + i)), 1.5)


# --- Éléments du décor ---------------------------------------------------------------

func _nuage(c: Vector2, k: float) -> void:
	var col := Color(1, 1, 1, 0.85)
	draw_circle(c, 26 * k, col)
	draw_circle(c + Vector2(28, 6) * k, 22 * k, col)
	draw_circle(c + Vector2(-28, 8) * k, 20 * k, col)
	draw_circle(c + Vector2(8, -14) * k, 22 * k, col)


func _collines(s: Vector2, gy: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, gy)])
	for i in 13:
		var x := s.x * i / 12.0
		pts.append(Vector2(x, gy - 50 - 35 * sin(i * 1.7) - 20 * sin(i * 0.6)))
	pts.append(Vector2(s.x, gy))
	draw_colored_polygon(pts, col)


func _montagnes(s: Vector2, gy: float) -> void:
	var cols := [Color("9aaec4"), Color("8a9a88"), Color("a08b72")]
	for k in 3:
		var pts := PackedVector2Array([Vector2(0, gy)])
		for i in 7:
			var x := s.x * (i + 0.5 * (k % 2)) / 6.0
			pts.append(Vector2(x - s.x * 0.08, gy - (120 + 90 * k) * (0.6 + 0.4 * abs(sin(i * 2.3 + k)))))
			pts.append(Vector2(x, gy - 30))
		pts.append(Vector2(s.x, gy))
		draw_colored_polygon(pts, cols[k])


func _mer(s: Vector2, gy: float) -> void:
	var mer := gy - 60
	draw_rect(Rect2(0, mer, s.x, 60), Color("3fa6d6"))
	for i in 12:
		var x := fmod(i * 140.0 + t * 20.0, s.x)
		draw_line(Vector2(x, mer + 20 + (i % 3) * 12), Vector2(x + 40, mer + 20 + (i % 3) * 12), Color(1, 1, 1, 0.6), 2.0)


func _herbes(s: Vector2, gy: float, col: Color, n: int) -> void:
	for i in n:
		var x := _rng.randf() * s.x
		var y := gy + _rng.randf() * (s.y - gy)
		var h := 6.0 + _rng.randf() * 10.0
		var vent := sin(t * 1.5 + x * 0.01) * 2.0
		draw_line(Vector2(x, y), Vector2(x - 3 + vent, y - h), col, 1.5)
		draw_line(Vector2(x, y), Vector2(x + 3 + vent, y - h * 0.8), col, 1.5)


func _acacia(p: Vector2, k: float) -> void:
	draw_line(p, p + Vector2(4, -90) * k, Color("6b4a2e"), 7 * k)
	draw_line(p + Vector2(3, -70) * k, p + Vector2(-30, -95) * k, Color("6b4a2e"), 4 * k)
	draw_line(p + Vector2(3, -70) * k, p + Vector2(34, -98) * k, Color("6b4a2e"), 4 * k)
	var canopee := PackedVector2Array([p + Vector2(-75, -95) * k, p + Vector2(-40, -118) * k, p + Vector2(40, -120) * k,
		p + Vector2(80, -98) * k, p + Vector2(40, -90) * k, p + Vector2(-40, -90) * k])
	draw_colored_polygon(canopee, Color("6f9e3a"))


func _arbre_rond(p: Vector2, k: float, col: Color) -> void:
	draw_line(p, p + Vector2(0, -60) * k, Color("6b4a2e"), 9 * k)
	draw_circle(p + Vector2(0, -80) * k, 40 * k, col)
	draw_circle(p + Vector2(-26, -64) * k, 28 * k, col.darkened(0.08))
	draw_circle(p + Vector2(26, -66) * k, 30 * k, col.lightened(0.06))


func _arbre_haut(p: Vector2, k: float, col: Color) -> void:
	draw_line(p, p + Vector2(0, -150) * k, Color("5a3e26"), 8 * k)
	draw_circle(p + Vector2(0, -160) * k, 46 * k, col)
	draw_circle(p + Vector2(-30, -140) * k, 32 * k, col.darkened(0.1))
	draw_circle(p + Vector2(30, -138) * k, 34 * k, col.lightened(0.05))


func _palmier(p: Vector2, k: float) -> void:
	var sommet := p + Vector2(20, -130) * k
	draw_line(p, sommet, Color("8a6a3a"), 8 * k)
	for a in [-2.6, -2.0, -1.2, -0.5, 0.2]:
		var fin := sommet + Vector2(cos(a), sin(a) + 0.6) * 70 * k
		draw_line(sommet, fin, Color("3f9a3c"), 6 * k)
	draw_circle(sommet + Vector2(0, 6) * k, 6 * k, Color("7a4a1e"))


func _rocher(p: Vector2, k: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-40, 0) * k, p + Vector2(-30, -30) * k, p + Vector2(0, -44) * k,
		p + Vector2(34, -26) * k, p + Vector2(44, 0) * k])
	draw_colored_polygon(pts, Color("9a8e80"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-30, -30) * k, p + Vector2(0, -44) * k, p + Vector2(-4, -20) * k]), Color("b8ad9e"))


func _riviere(s: Vector2, gy: float, y: float, largeur: float, col: Color = Color("4aa3e0")) -> void:
	var cy := gy + (s.y - gy) * y
	var pts := PackedVector2Array()
	for i in 21:
		var x := s.x * i / 20.0
		pts.append(Vector2(x, cy - largeur * 0.5 + sin(i * 0.8) * 12))
	for i in range(20, -1, -1):
		var x := s.x * i / 20.0
		pts.append(Vector2(x, cy + largeur * 0.5 + sin(i * 0.8 + 1) * 12))
	draw_colored_polygon(pts, col)
	for i in 10:
		var x := fmod(i * 170.0 + t * 30.0, s.x)
		draw_line(Vector2(x, cy - 6 + (i % 3) * 8), Vector2(x + 50, cy - 6 + (i % 3) * 8), Color(1, 1, 1, 0.55), 2.0)


func _mangrove(p: Vector2, k: float) -> void:
	for i in 5:
		draw_line(p + Vector2(-30 + i * 15, 0) * k, p + Vector2(0, -50) * k, Color("5a3e26"), 3 * k)
	draw_circle(p + Vector2(0, -70) * k, 40 * k, Color("3f8f4a"))
	draw_circle(p + Vector2(-26, -58) * k, 26 * k, Color("4fa058"))


func _pirogue(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-60, 0), p + Vector2(60, 0), p + Vector2(45, 14), p + Vector2(-45, 14)]), Color("8a4a24"))
	draw_line(p + Vector2(10, 0), p + Vector2(30, -40), Color("5a3e26"), 3.0)
	draw_circle(p + Vector2(-10, -14), 8, Color("3a2a22"))


func _case_ronde(p: Vector2, k: float, col: Color) -> void:
	draw_rect(Rect2(p + Vector2(-40, -50) * k, Vector2(80, 50) * k), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-56, -46) * k, p + Vector2(0, -100) * k, p + Vector2(56, -46) * k]), Color("d9b25f"))
	draw_rect(Rect2(p + Vector2(-10, -30) * k, Vector2(20, 30) * k), Color("5a3a22"))


func _tente(p: Vector2, k: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-60, 0) * k, p + Vector2(0, -80) * k, p + Vector2(60, 0) * k]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0) * k, p + Vector2(0, -40) * k, p + Vector2(12, 0) * k]), Color("3a2a22"))
	draw_line(p + Vector2(0, -80) * k, p + Vector2(0, -110) * k, Color("5a3e26"), 3 * k)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -110) * k, p + Vector2(26, -102) * k, p + Vector2(0, -94) * k]), Pal.SANG)


func _feu(p: Vector2) -> void:
	for i in 3:
		var h := 30.0 + sin(t * 8 + i) * 8.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-14 + i * 6, 0), p + Vector2(-4 + i * 4, -h), p + Vector2(6 + i * 4, 0)]),
			[Color("f25a1f"), Color("ffb02e"), Color("ffe066")][i])
	draw_line(p + Vector2(-22, 4), p + Vector2(22, -2), Color("5a3e26"), 5.0)


func _antilope(p: Vector2, k: float) -> void:
	var col := Color("b0703a")
	draw_rect(Rect2(p + Vector2(-30, -40) * k, Vector2(60, 24) * k), col)
	for dx in [-24, -12, 14, 24]:
		draw_line(p + Vector2(dx, -18) * k, p + Vector2(dx, 0) * k, col.darkened(0.2), 4 * k)
	draw_line(p + Vector2(28, -36) * k, p + Vector2(40, -56) * k, col, 7 * k)
	draw_circle(p + Vector2(42, -58) * k, 8 * k, col)
	draw_line(p + Vector2(42, -64) * k, p + Vector2(36, -86) * k, Color("3a2a22"), 2 * k)
	draw_line(p + Vector2(46, -64) * k, p + Vector2(50, -86) * k, Color("3a2a22"), 2 * k)
	draw_rect(Rect2(p + Vector2(-20, -30) * k, Vector2(40, 6) * k), Color("f2e2c2"))
