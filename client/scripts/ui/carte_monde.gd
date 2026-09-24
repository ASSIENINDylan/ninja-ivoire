class_name CarteMonde
extends Control
## La carte du monde, case par case : terrains, brouillard, frontières des
## régions, lieux et position du ninja. Sert en grand (exploration) et en
## petit (aperçu au village).

signal case_cliquee(x: int, y: int)

const COULEURS := {
	"savane": Color("8c7a45"), "savane_boisee": Color("6e7a40"), "foret": Color("3d6a3a"),
	"foret_dense": Color("284a2c"), "montagne": Color("7b6d60"), "fleuve": Color("3b6e98"),
	"lac": Color("2d5e8c"), "lagune": Color("3b8290"), "littoral": Color("b19c66"),
}
const COULEURS_VILLAGES := {"traditionnel": Color("d9974f"), "moderne": Color("b8c3cf"), "futuriste": Color("5ed6e6")}

var interactif := true
var survol := Vector2i(-1, -1)
var _t := 0.0
var _c: Dictionary
var _cs := 10.0
var _orig := Vector2.ZERO


func _ready() -> void:
	_c = Jeu.catalogue.carte
	mouse_filter = Control.MOUSE_FILTER_STOP if interactif else Control.MOUSE_FILTER_IGNORE
	resized.connect(_calculer)
	_calculer()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _calculer() -> void:
	var l := int(_c.l)
	var h := int(_c.h)
	_cs = floor(min(size.x / l, size.y / h))
	_orig = ((size - Vector2(l, h) * _cs) * 0.5).floor()


func vers_case(p: Vector2) -> Vector2i:
	var q := ((p - _orig) / _cs).floor()
	return Vector2i(int(q.x), int(q.y))


func centre_case(x: int, y: int) -> Vector2:
	return _orig + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cs


func _i(x: int, y: int) -> int:
	return y * int(_c.l) + x


func _explore(x: int, y: int) -> bool:
	var e: String = Jeu.ninja.get("explore", "")
	var i := _i(x, y)
	return i < e.length() and e[i] == "1"


func _region_de(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= int(_c.l) or y >= int(_c.h):
		return -1
	return int(_c.region[_i(x, y)])


func _gui_input(ev: InputEvent) -> void:
	if not interactif:
		return
	if ev is InputEventMouseMotion:
		survol = vers_case(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var c := vers_case(ev.position)
		if _region_de(c.x, c.y) >= 0:
			case_cliquee.emit(c.x, c.y)


func _draw() -> void:
	if _c.is_empty() or Jeu.ninja == null:
		return
	var l := int(_c.l)
	var h := int(_c.h)
	var n = Jeu.ninja
	var niveau := int(n.niveau)
	var brouillard := Color("1d1619")
	var teintes := []
	for rid in _c.regions:
		teintes.append(brouillard.lerp(Color(Jeu.region(rid).get("couleur", "#888888")), 0.13))
	# Cases.
	for y in h:
		for x in l:
			var i := _i(x, y)
			if int(_c.region[i]) < 0:
				continue
			var r := Rect2(_orig + Vector2(x, y) * _cs, Vector2(_cs, _cs))
			if not _explore(x, y):
				draw_rect(r, teintes[int(_c.region[i])])
				continue
			var terrain: String = _c.terrains[int(_c.terrain[i])]
			var col: Color = COULEURS.get(terrain, Pal.GRIS)
			# Léger damier pour donner du grain.
			if (x + y) % 2 == 0:
				col = col.darkened(0.05)
			draw_rect(r, col)
			var z: Dictionary = _c.zones[int(_c.zone[i])]
			if int(z.niveau) > niveau:
				draw_rect(r, Color(0.35, 0.05, 0.05, 0.35))
				if _cs >= 8 and (x + y) % 3 == 0:
					draw_line(r.position, r.end, Color(0.8, 0.2, 0.15, 0.35), 1.0)
	# Frontières des régions (toujours connues) et des zones (si explorées).
	var frontiere := Color(Pal.IVOIRE, 0.55)
	var limite_zone := Color(0, 0, 0, 0.22)
	for y in h:
		for x in l:
			var i := _i(x, y)
			var r := int(_c.region[i])
			if r < 0:
				continue
			var p := _orig + Vector2(x, y) * _cs
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var x2: int = x + d.x
				var y2: int = y + d.y
				var r2 := _region_de(x2, y2)
				var a := p + Vector2(_cs, 0) if d.x == 1 else p + Vector2(0, _cs)
				var b := p + Vector2(_cs, _cs)
				if r2 >= 0 and r2 != r:
					draw_line(a, b, frontiere, 1.6)
				elif r2 == r and int(_c.zone[_i(x2, y2)]) != int(_c.zone[i]) and _explore(x, y):
					draw_line(a, b, limite_zone, 1.0)
	# Contour du pays.
	var cont := PackedVector2Array()
	for pt in _c.contour:
		cont.append(_geo(pt[0], pt[1]))
	cont.append(cont[0])
	draw_polyline(cont, Color(Pal.OR, 0.7), 2.0, true)
	# Lieux.
	for lieu in _c.lieux:
		var x := int(lieu.x)
		var y := int(lieu.y)
		if not _explore(x, y):
			continue
		var c := centre_case(x, y)
		var s := _cs * 0.42
		match lieu.type:
			"village":
				var col: Color = COULEURS_VILLAGES.get(lieu.get("type_village", ""), Pal.IVOIRE)
				var pts := PackedVector2Array([c + Vector2(0, -s * 1.3), c + Vector2(s * 1.3, 0), c + Vector2(0, s * 1.3), c + Vector2(-s * 1.3, 0)])
				draw_colored_polygon(pts, col)
				pts.append(pts[0])
				draw_polyline(pts, Color(0, 0, 0, 0.7), 1.2, true)
			"ville":
				draw_circle(c, max(1.8, s * 0.55), Pal.IVOIRE)
				draw_arc(c, max(1.8, s * 0.55), 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0, true)
			"mythique":
				_etoile(c, s * 1.3, Color("c9a7ff"))
			"portail":
				draw_arc(c + Vector2(0, s * 0.4), s * 1.1, PI, TAU, 12, Pal.OR_VIF, 2.2, true)
				draw_line(c + Vector2(-s * 1.1, s * 0.4), c + Vector2(-s * 1.1, s * 1.2), Pal.OR_VIF, 2.2)
				draw_line(c + Vector2(s * 1.1, s * 0.4), c + Vector2(s * 1.1, s * 1.2), Pal.OR_VIF, 2.2)
	# Ninja.
	var pos = n.get("position")
	if pos != null:
		var c := centre_case(int(pos[0]), int(pos[1]))
		var col := Jeu.couleur_element(n.elements[0])
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(c, _cs * (0.9 + 0.5 * pulse), Color(col, 0.18))
		draw_circle(c, _cs * 0.55, Color(0, 0, 0, 0.8))
		draw_circle(c, _cs * 0.42, col)
		draw_arc(c, _cs * 0.55, 0, TAU, 20, Pal.IVOIRE, 1.5, true)
		# Cases voisines accessibles.
		if interactif:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var x: int = int(pos[0]) + dx
					var y: int = int(pos[1]) + dy
					if _region_de(x, y) < 0:
						continue
					var r := Rect2(_orig + Vector2(x, y) * _cs, Vector2(_cs, _cs)).grow(-1)
					var ok := Deplacements.possible(x, y) == ""
					draw_rect(r, Color(Pal.IVOIRE, 0.5) if ok else Color(0.9, 0.3, 0.2, 0.5), false, 1.2)
	# Survol.
	if interactif and _region_de(survol.x, survol.y) >= 0:
		var r := Rect2(_orig + Vector2(survol) * _cs, Vector2(_cs, _cs))
		draw_rect(r.grow(1), Pal.OR_VIF, false, 2.0)


func _geo(lon: float, lat: float) -> Vector2:
	return _orig + Vector2((lon - float(_c.lon_min)) / float(_c.pas), (float(_c.lat_max) - lat) / float(_c.pas)) * _cs


func _etoile(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## Description d'une case pour l'infobulle et le panneau.
func description(x: int, y: int) -> String:
	if _region_de(x, y) < 0:
		return ""
	if not _explore(x, y):
		return "Terre inconnue"
	var i := _i(x, y)
	var z: Dictionary = _c.zones[int(_c.zone[i])]
	var terrain: String = _c.terrains[int(_c.terrain[i])]
	var t := "%s — environs de %s (niv. %d)" % [_c.noms_terrains[terrain], z.nom, int(z.niveau)]
	var li := int(_c.lieu[i])
	if li >= 0:
		t = _c.lieux[li].nom + "\n" + t
	return t
