class_name UI
extends RefCounted
## Petits constructeurs d'interface, pour écrire les écrans en code.


static func label(texte: String, taille: int = 18, couleur: Color = Pal.IVOIRE, titre: bool = false) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if titre:
		l.add_theme_font_override("font", Pal.police_titre)
	return l


static func texte(t: String, taille: int = 16, couleur: Color = Pal.IVOIRE_DOUX, largeur: float = 0) -> Label:
	var l := label(t, taille, couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if largeur > 0:
		l.custom_minimum_size.x = largeur
	return l


static func bouton(t: String, cb: Callable, taille: int = 18) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", taille)
	b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func bouton_principal(t: String, cb: Callable, taille: int = 20) -> Button:
	var b := bouton(t, cb, taille)
	var n := Pal.boite(Color("5a3b22"), Pal.OR, 8, 1, 12)
	n.content_margin_left = 26
	n.content_margin_right = 26
	var h := Pal.boite(Color("6e4828"), Pal.OR_VIF, 8, 2, 12)
	h.content_margin_left = 26
	h.content_margin_right = 26
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", Pal.IVOIRE)
	return b


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func carte(fond: Color = Color(Pal.PANNEAU, 0.94), bord: Color = Pal.BORD, marge: int = 18, rayon: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Pal.boite(fond, bord, rayon, 1, marge))
	return p


static func barre(valeur: float, maximum: float, couleur: Color, hauteur: float = 14, avec_texte: bool = false) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max(1.0, maximum)
	b.value = valeur
	b.show_percentage = false
	b.custom_minimum_size.y = hauteur
	b.add_theme_stylebox_override("fill", Pal.boite(couleur, couleur, 5, 0, 0))
	if avec_texte:
		var l := label("%d / %d" % [valeur, maximum], 12, Pal.IVOIRE)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
	return b


static func espace(h: float = 0, w: float = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c


static func extensible() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func frise(largeur: float = 0) -> Control:
	var f := Frise.new()
	f.custom_minimum_size = Vector2(largeur, 12)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func pastille(couleur: Color, taille: float = 12) -> Control:
	var p := Pastille.new()
	p.couleur = couleur
	p.custom_minimum_size = Vector2(taille, taille)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func glyphes(sequence: Array, taille: float = 26) -> HBoxContainer:
	var h := hbox(4)
	for id in sequence:
		var g := Glyphe.new()
		g.mudra_id = id
		g.custom_minimum_size = Vector2(taille, taille)
		g.tooltip_text = Jeu.mudra(id).get("nom", "?")
		h.add_child(g)
	return h


## Dessine le glyphe d'un mudra : un signe géométrique unique, symétrique,
## inspiré des symboles tracés sur les tissus et les masques.
static func dessiner_glyphe(ci: CanvasItem, c: Vector2, r: float, id: String, col: Color, ep: float = 2.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var n_axes: int = [2, 3, 4, 4, 6][rng.randi() % 5]
	var motif := rng.randi() % 6
	var rr := r * 0.72
	ci.draw_arc(c, r, 0, TAU, 40, Color(col, 0.55), ep * 0.7, true)
	for k in n_axes:
		var a := TAU * k / n_axes - PI / 2
		var d := Vector2(cos(a), sin(a))
		var p := Vector2(-d.y, d.x)
		match motif:
			0:
				ci.draw_line(c + d * rr * 0.25, c + d * rr, col, ep, true)
				ci.draw_circle(c + d * rr, ep * 1.3, col)
			1:
				ci.draw_line(c + d * rr * 0.35, c + d * rr + p * rr * 0.3, col, ep, true)
				ci.draw_line(c + d * rr * 0.35, c + d * rr - p * rr * 0.3, col, ep, true)
			2:
				ci.draw_arc(c + d * rr * 0.55, rr * 0.3, a - PI / 2, a + PI / 2, 12, col, ep, true)
			3:
				var pts := PackedVector2Array([c + d * rr * 0.3, c + d * rr * 0.65 + p * rr * 0.22, c + d * rr, c + d * rr * 0.65 - p * rr * 0.22, c + d * rr * 0.3])
				ci.draw_polyline(pts, col, ep, true)
			4:
				for s in 3:
					ci.draw_circle(c + d * rr * (0.35 + 0.3 * s), ep * (0.9 + 0.3 * s), col)
			5:
				ci.draw_line(c + d * rr * 0.2, c + d * rr * 0.9, col, ep, true)
				ci.draw_line(c + d * rr * 0.7 + p * rr * 0.2, c + d * rr * 0.7 - p * rr * 0.2, col, ep, true)
	match rng.randi() % 4:
		0:
			ci.draw_circle(c, r * 0.14, col)
		1:
			ci.draw_arc(c, r * 0.2, 0, TAU, 16, col, ep, true)
		2:
			var q := r * 0.16
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -q), c + Vector2(q, 0), c + Vector2(0, q), c + Vector2(-q, 0)]), col)
		_:
			pass


## Frise décorative en zigzag et losanges (inspiration bogolan).
class Frise:
	extends Control
	var couleur := Color(Pal.OR, 0.45)

	func _draw() -> void:
		var h := size.y
		var pas := 14.0
		var x := 0.0
		var pts := PackedVector2Array()
		while x <= size.x:
			pts.append(Vector2(x, h * 0.5 + (h * 0.35 if int(x / pas) % 2 == 0 else -h * 0.35)))
			x += pas
		if pts.size() > 1:
			draw_polyline(pts, couleur, 1.5, true)
		x = pas * 2
		while x < size.x:
			var c := Vector2(x, h * 0.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), couleur)
			x += pas * 4


class Pastille:
	extends Control
	var couleur := Pal.IVOIRE

	func _draw() -> void:
		var r: float = min(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, couleur)
		draw_arc(size * 0.5, r, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.0, true)


class Glyphe:
	extends Control
	var mudra_id := ""

	func _draw() -> void:
		var r: float = min(size.x, size.y) * 0.5 - 1
		draw_circle(size * 0.5, r, Color("150f12"))
		UI.dessiner_glyphe(self, size * 0.5, r - 1, mudra_id, Jeu.couleur_mudra(mudra_id), max(1.2, r / 10.0))
