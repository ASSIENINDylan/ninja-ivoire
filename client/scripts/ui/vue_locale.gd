class_name VueLocale
extends Control
## La portion de carte autour du ninja, en grandes cases : terrain, contenu
## (camp de bandits, ressource), lieux, brouillard. On clique une case
## voisine pour s'y rendre.

signal case_cliquee(x: int, y: int)

const COLONNES := 7
const LIGNES := 5

var survol := Vector2i(-99, -99)
var taille_max := 96.0  # taille maximale d'une case, en pixels
var opacite := 0.62  # le paysage transparaît sous les cases
var _t := 0.0
var _cs := 100.0
var _orig := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_calculer)
	_calculer()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _calculer() -> void:
	_cs = floor(min(min(size.x / COLONNES, size.y / LIGNES), taille_max))
	# La planche est posée en bas, pour laisser voir le paysage au-dessus.
	_orig = Vector2(floor((size.x - COLONNES * _cs) * 0.5), size.y - LIGNES * _cs)


func _centre() -> Vector2i:
	var p = Jeu.ninja.position
	return Vector2i(int(p[0]), int(p[1]))


## Case de la carte sous un point de l'écran.
func vers_case(p: Vector2) -> Vector2i:
	var q := ((p - _orig) / _cs).floor()
	var c := _centre()
	return Vector2i(c.x + int(q.x) - COLONNES / 2, c.y + int(q.y) - LIGNES / 2)


func rect_case(x: int, y: int) -> Rect2:
	var c := _centre()
	var gx := x - c.x + COLONNES / 2
	var gy := y - c.y + LIGNES / 2
	return Rect2(_orig + Vector2(gx, gy) * _cs, Vector2(_cs, _cs))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		survol = vers_case(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var c := vers_case(ev.position)
		case_cliquee.emit(c.x, c.y)


func _explore(x: int, y: int) -> bool:
	var c: Dictionary = Jeu.catalogue.carte
	var e: String = Jeu.ninja.get("explore", "")
	var i := y * int(c.l) + x
	return i < e.length() and e[i] == "1"


static func info_case(x: int, y: int):
	var c: Dictionary = Jeu.catalogue.carte
	if x < 0 or y < 0 or x >= int(c.l) or y >= int(c.h):
		return null
	var i: int = y * int(c.l) + x
	if int(c.region[i]) < 0:
		return null
	var li := int(c.lieu[i])
	return {
		"terrain": c.terrains[int(c.terrain[i])], "zone": c.zones[int(c.zone[i])], "lieu": c.lieux[li] if li >= 0 else null,
		"contenu": c.contenus[int(c.contenu[i])], "region": c.regions[int(c.region[i])],
	}


func _draw() -> void:
	if Jeu.ninja == null or Jeu.catalogue.is_empty():
		return
	var f := Pal.police_texte
	var centre := _centre()
	var niveau := int(Jeu.ninja.niveau)
	# Ombre de la planche.
	draw_rect(Rect2(_orig + Vector2(6, 8), Vector2(COLONNES, LIGNES) * _cs), Color(0, 0, 0, 0.12))
	for gy in LIGNES:
		for gx in COLONNES:
			var x := centre.x + gx - COLONNES / 2
			var y := centre.y + gy - LIGNES / 2
			var r := Rect2(_orig + Vector2(gx, gy) * _cs, Vector2(_cs, _cs)).grow(-2)
			var info = info_case(x, y)
			if info == null:
				draw_rect(r, Color("d9d2c4", 0.45))  # hors du pays
				continue
			if not _explore(x, y):
				draw_rect(r, Color("efe6d4", 0.85))
				draw_string(f, r.get_center() + Vector2(-6, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("c9b99c"))
				continue
			var col: Color = CarteMonde.COULEURS.get(info.terrain, Pal.GRIS)
			draw_rect(r, Color(col, opacite))
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.3)), Color(1, 1, 1, 0.12))
			if int(info.zone.niveau) > niveau:
				draw_rect(r, Color(0.8, 0.15, 0.1, 0.28))
				for k in 4:
					draw_line(r.position + Vector2(k * r.size.x / 4, 0), r.position + Vector2(r.size.x, r.size.y - k * r.size.y / 4), Color(0.8, 0.1, 0.1, 0.25), 2.0)
			var ri := r
			if x == centre.x and y == centre.y:
				ri = Rect2(r.position - r.size * 0.22, r.size)  # sous le ninja : l'icône se décale
			_icone(ri, info, x, y)
			draw_rect(r, Color(1, 1, 1, 0.5), false, 1.0)
			if _cs >= 80:
				draw_string(f, r.position + Vector2(6, r.size.y - 6), "niv. %d" % int(info.zone.niveau), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.45))
	# Cases voisines accessibles.
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var x: int = centre.x + dx
			var y: int = centre.y + dy
			if info_case(x, y) == null:
				continue
			var r := rect_case(x, y).grow(-4)
			var raison := Deplacements.possible(x, y)
			if raison == "":
				draw_rect(r, Color(1, 1, 1, 0.9), false, 3.0)
				draw_string(f, r.position + Vector2(r.size.x - 22, 18), str(Deplacements.cout(x, y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))
			else:
				draw_rect(r, Color(0.85, 0.2, 0.15, 0.7), false, 2.0)
	# Survol.
	var rs := rect_case(survol.x, survol.y)
	if info_case(survol.x, survol.y) != null and Rect2(_orig, Vector2(COLONNES, LIGNES) * _cs).has_point(rs.get_center()):
		draw_rect(rs.grow(-1), Pal.OR_VIF, false, 3.0)
	# Le ninja.
	var rc := rect_case(centre.x, centre.y)
	var c := rc.get_center() + Vector2(0, _cs * 0.12)
	var el := Jeu.couleur_element(Jeu.ninja.elements[0])
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(c, _cs * (0.3 + 0.08 * pulse), Color(el, 0.25))
	draw_circle(c, _cs * 0.2, Color(1, 1, 1))
	draw_circle(c, _cs * 0.16, el)
	draw_arc(c, _cs * 0.2, 0, TAU, 24, Pal.IVOIRE, 2.0, true)
	var nom: String = Jeu.ninja.nom
	var nw := f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(f, c + Vector2(-nw * 0.5, _cs * 0.36), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.IVOIRE)
	# Un ninja croisé sur la case.
	var pr = Jeu.ninja.get("situation", {}).get("presence")
	if pr != null:
		var q := rc.get_center() + Vector2(_cs * 0.28, -_cs * 0.18)
		draw_circle(q, _cs * 0.12, Color(1, 1, 1))
		draw_circle(q, _cs * 0.09, Jeu.couleur_element(pr.element))
		draw_string(f, q + Vector2(-5, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.CLAIR)


## Pictogramme du contenu ou du lieu de la case.
func _icone(r: Rect2, info: Dictionary, x: int, y: int) -> void:
	var c := r.get_center() - Vector2(0, _cs * 0.08)
	var k := _cs / 100.0
	var l = info.lieu
	if l != null:
		match l.type:
			"village":
				var col: Color = CarteMonde.COULEURS_VILLAGES.get(l.get("type_village", ""), Pal.OCRE)
				for i in 3:
					var p := c + Vector2((i - 1) * 24, (i % 2) * 6) * k
					draw_rect(Rect2(p + Vector2(-10, -8) * k, Vector2(20, 16) * k), col)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-14, -8) * k, p + Vector2(0, -24) * k, p + Vector2(14, -8) * k]), Color("d9a93f"))
			"ville":
				for i in 3:
					draw_rect(Rect2(c + Vector2(-26 + i * 18, -20 - (i % 2) * 12) * k, Vector2(14, 34 + (i % 2) * 12) * k), [Color("e89a6a"), Color("7fb3d9"), Color("f2d28a")][i])
			"mythique":
				draw_circle(c, 20 * k, Color("9b6fe0", 0.35 + 0.15 * sin(_t * 2)))
				draw_circle(c, 10 * k, Color("c9a7ff"))
			"portail":
				draw_arc(c + Vector2(0, 8) * k, 20 * k, PI, TAU, 16, Pal.OR_VIF, 5 * k, true)
		var nw := Pal.police_texte.get_string_size(l.nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tr := Rect2(r.get_center() + Vector2(-nw * 0.5 - 4, r.size.y * 0.22), Vector2(nw + 8, 16))
		draw_rect(tr, Color(1, 1, 1, 0.85))
		draw_string(Pal.police_texte, tr.position + Vector2(4, 12), l.nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.IVOIRE)
		return
	var ct: String = info.contenu
	if ct == "":
		return
	var camps: Dictionary = Jeu.ninja.get("camps", {})
	match ct:
		"camp":
			var actif := not camps.has("%d,%d" % [x, y]) or int(camps["%d,%d" % [x, y]]) <= int(Time.get_unix_time_from_system())
			var col := Pal.SANG if actif else Color("a89c90")
			draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 18) * k, c + Vector2(0, -20) * k, c + Vector2(26, 18) * k]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 18) * k, c + Vector2(0, 2) * k, c + Vector2(6, 18) * k]), Color("3a2a22"))
			if actif:
				draw_circle(c + Vector2(22, 16) * k, 5 * k, Color("ffb02e"))
		_:
			var d = CarteMonde.CONTENUS.get(ct)
			if d == null:
				return
			var col: Color = d[0]
			draw_circle(c, 22 * k, Color(1, 1, 1, 0.9))
			draw_circle(c, 18 * k, col)
			if ct == "diamant":
				var q := 10 * k
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -q), c + Vector2(q * 0.7, 0), c + Vector2(0, q), c + Vector2(-q * 0.7, 0)]), Color(1, 1, 1, 0.9))
			else:
				var tw := Pal.police_texte.get_string_size(d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * k)).x
				draw_string(Pal.police_texte, c + Vector2(-tw * 0.5, 5 * k), d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * k), Pal.CLAIR)
