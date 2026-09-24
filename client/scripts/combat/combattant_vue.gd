class_name CombattantVue
extends Node2D
## Un combattant dessiné en silhouette, avec ses barres, ses statuts et
## son incantation en cours. Les pieds sont à l'origine.

const LETTRES := {
	# Maux et entraves.
	"consume": ["Br", Color("e2572b")], "sangsue": ["Sg", Color("7fc23a")], "immobilise": ["Im", Color("4f9d45")],
	"retenu": ["Rt", Color("8e6fd1")], "desarme": ["Dé", Color("e0604f")], "scelle": ["Sc", Color("d98bd4")],
	"sans_garde": ["SG", Color("a9b4bd")], "confus": ["Cf", Color("8ea4ff")], "endormi": ["Zz", Color("b9a7ff")],
	"aveugle": ["Av", Color("b7c3cf")], "egare": ["Ég", Color("9fd8c4")], "marque": ["M", Color("d98bd4")],
	"piege": ["P", Color("a0703c")],
	# Défenses, illusions et soins.
	"def_phys": ["DP", Color("c9955a")], "def_mag": ["DM", Color("5fa8e0")], "renvoi": ["Rv", Color("f2e8d5")],
	"parade": ["Pa", Color("e8c47a")], "esquive": ["Es", Color("9fd8c4")], "reflet": ["Rf", Color("e0f7ff")],
	"deviation": ["Dv", Color("7c8cff")], "intangible_phys": ["IP", Color("c6f1ff")], "intangible_mag": ["IM", Color("c6f1ff")],
	"invisible": ["In", Color("b7c3cf")], "disparu": ["Di", Color("a79ad0")], "leurre": ["L", Color("9fd8c4")],
	"regen": ["+", Color("6fbf73")], "baume": ["Ba", Color("8fd18f")], "second_souffle": ["2S", Color("fff8e7")],
	"riposte": ["Ri", Color("f2e8d5")], "invocation": ["I", Color("5ec8d8")], "declencheur": ["Dc", Color("e6c07b")],
}

## Nom lisible de chaque statut (infobulles et panneau de combat).
const NOMS := {
	"consume": "brûlure", "sangsue": "sangsue", "immobilise": "immobilisé", "retenu": "retenu (ne peut fuir)",
	"desarme": "désarmé", "scelle": "mains scellées", "sans_garde": "sans garde", "confus": "confus", "endormi": "endormi",
	"aveugle": "aveuglé", "egare": "égaré", "marque": "marqué", "piege": "piégé",
	"def_phys": "défense physique", "def_mag": "défense magique", "renvoi": "renvoi", "parade": "parade",
	"esquive": "esquive", "reflet": "reflet", "deviation": "déviation", "intangible_phys": "intangible (physique)",
	"intangible_mag": "intangible (magique)", "invisible": "invisible", "disparu": "disparu", "leurre": "leurres",
	"regen": "régénération", "baume": "baume", "second_souffle": "second souffle", "riposte": "riposte",
	"invocation": "créature", "declencheur": "réflexe de survie",
}

var d: Dictionary = {}
var pv_affiche := 0.0
var souffle_affiche := 0.0
var selection := false
var survol := false
var t := 0.0
var flash := 0.0
var mort := false


func maj(donnees: Dictionary, instantane: bool = false) -> void:
	d = donnees
	if instantane:
		pv_affiche = d.pv
		souffle_affiche = d.souffle
	if d.pv <= 0 and not mort:
		mort = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.28, 0.6)


func _process(delta: float) -> void:
	t += delta
	flash = max(0.0, flash - delta * 3.0)
	if not d.is_empty():
		pv_affiche = lerp(pv_affiche, float(d.pv), min(1.0, delta * 6.0))
		souffle_affiche = lerp(souffle_affiche, float(d.souffle), min(1.0, delta * 6.0))
	queue_redraw()


func couleur_element() -> Color:
	return Jeu.couleur_element(d.get("element", ""))


func _draw() -> void:
	if d.is_empty():
		return
	var el := couleur_element()
	# Ombre et anneau de sélection.
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 58, Color(0, 0, 0, 0.45))
	if selection or survol:
		var c := Pal.OR_VIF if selection else Color(Pal.IVOIRE, 0.5)
		draw_arc(Vector2.ZERO, 70 + 3 * sin(t * 4), 0, TAU, 48, c, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	var miroir := -1.0 if d.camp == 1 else 1.0
	var respir := sin(t * 2.2 + d.rang) * 1.6
	draw_set_transform(Vector2(0, respir), 0, Vector2(miroir, 1))
	var corps := Color("1c1519").lerp(Color.WHITE, flash * 0.8)
	match str(d.get("apparence", "")):
		"chacal":
			_chacal(corps)
		"esprit":
			_esprit(el)
		"drone":
			_drone(el)
		"gardien":
			_humain(corps.lerp(Color("4a4038"), 0.5), el, 1.35, "gardien")
		"sans_visage":
			_robe(corps, el)
		"cyborg":
			_humain(corps, el, 1.08, "cyborg")
		"brigand":
			_humain(corps, el, 1.0, "brigand")
		"ninja_renegat":
			_humain(corps, el, 1.0, "capuche")
		_:
			_humain(corps, el, 1.0, str(d.get("apparence", "")))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_interface()


# --- Silhouettes -------------------------------------------------------------

func _contour(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var p := pts.duplicate()
	p.append(pts[0])
	draw_polyline(p, Color(Pal.IVOIRE, 0.16), 1.2, true)


func _humain(col: Color, el: Color, k: float, variante: String) -> void:
	var m := func(v: Vector2) -> Vector2: return v * k
	var ondule := sin(t * 3.0) * 5
	# Jambes.
	_contour(PackedVector2Array([m.call(Vector2(-12, -70)), m.call(Vector2(-2, -70)), m.call(Vector2(-12, 0)), m.call(Vector2(-24, 0))]), col)
	_contour(PackedVector2Array([m.call(Vector2(2, -70)), m.call(Vector2(14, -70)), m.call(Vector2(22, 0)), m.call(Vector2(10, 0))]), col)
	# Buste.
	_contour(PackedVector2Array([m.call(Vector2(-17, -72)), m.call(Vector2(17, -72)), m.call(Vector2(21, -126)), m.call(Vector2(-19, -126))]), col)
	# Ceinture de la couleur de l'élément.
	draw_line(m.call(Vector2(-17, -78)), m.call(Vector2(17, -78)), el, 4.0 * k)
	# Bras arrière et avant.
	draw_line(m.call(Vector2(-12, -120)), m.call(Vector2(-28, -92)), col, 8.0 * k, true)
	draw_line(m.call(Vector2(12, -120)), m.call(Vector2(34, -96)), col, 8.0 * k, true)
	# Arme.
	var main: Vector2 = m.call(Vector2(34, -96))
	match variante:
		"gardien":
			draw_line(main, m.call(Vector2(60, -150)), Color("3a2e26"), 12.0 * k, true)
			draw_circle(m.call(Vector2(60, -150)), 16 * k, Color("4a3c30"))
		"brigand":
			draw_line(main, m.call(Vector2(74, -110)), Color("b8b0a0"), 4.0, true)
		_:
			draw_line(main, m.call(Vector2(76, -134)), Color("d8d2c4"), 3.0, true)
			draw_line(main, m.call(Vector2(28, -88)), Color("5a4030"), 5.0, true)
	# Tête.
	var tete: Vector2 = m.call(Vector2(2, -142))
	draw_circle(tete, 16 * k, col)
	draw_arc(tete, 16 * k, 0, TAU, 24, Color(Pal.IVOIRE, 0.16), 1.2, true)
	match variante:
		"ninja_futuriste", "cyborg":
			draw_line(tete + Vector2(-2, -3) * k, tete + Vector2(16, -3) * k, Color("5ec8d8"), 3.0, true)
			draw_circle(tete + Vector2(12, -3) * k, 3 * k, Color(0.4, 0.9, 1.0, 0.5 + 0.3 * sin(t * 5)))
			if variante == "cyborg":
				_contour(PackedVector2Array([m.call(Vector2(-22, -130)), m.call(Vector2(22, -130)), m.call(Vector2(26, -116)), m.call(Vector2(-24, -116))]), Color("3a4550"))
		"brigand":
			_contour(PackedVector2Array([tete + Vector2(-30, -8) * k, tete + Vector2(30, -8) * k, tete + Vector2(12, -26) * k, tete + Vector2(-12, -26) * k]), Color("2b2018"))
		"capuche":
			_contour(PackedVector2Array([tete + Vector2(-20, 10) * k, tete + Vector2(-4, -30) * k, tete + Vector2(20, 4) * k]), col.lightened(0.05))
			draw_circle(tete + Vector2(10, -2) * k, 2.5, el)
		"gardien":
			draw_circle(tete + Vector2(9, -3) * k, 3 * k, Color(1.0, 0.6, 0.2))
		_:
			# Bandeau de l'élément avec ses pans qui flottent.
			draw_line(tete + Vector2(-16, -6) * k, tete + Vector2(16, -6) * k, el, 5.0 * k, true)
			var pans := PackedVector2Array([tete + Vector2(-15, -6) * k, tete + Vector2(-34, 2 + ondule) * k, tete + Vector2(-52, -2 + ondule * 1.6) * k])
			draw_polyline(pans, el, 4.0 * k, true)
			if variante == "ninja_traditionnel":
				for i in 3:
					draw_circle(tete + Vector2(4 + i * 4, 4) * k, 1.6, Pal.IVOIRE)


func _chacal(col: Color) -> void:
	var bond: float = abs(sin(t * 3.0)) * 2
	_contour(PackedVector2Array([Vector2(-44, -40 - bond), Vector2(26, -44 - bond), Vector2(34, -30), Vector2(-40, -24)]), col)
	_contour(PackedVector2Array([Vector2(24, -46 - bond), Vector2(56, -44 - bond), Vector2(64, -34), Vector2(34, -30)]), col)
	_contour(PackedVector2Array([Vector2(34, -46 - bond), Vector2(38, -62 - bond), Vector2(44, -46 - bond)]), col)
	for x in [-34, -22, 14, 24]:
		draw_line(Vector2(x, -28), Vector2(x + 4, 0), col, 5.0, true)
	draw_polyline(PackedVector2Array([Vector2(-42, -36), Vector2(-62, -46 + sin(t * 4) * 4), Vector2(-74, -40)]), col, 5.0, true)
	draw_circle(Vector2(54, -40 - bond), 2.2, Color(1.0, 0.75, 0.3))


func _esprit(el: Color) -> void:
	var flotte := sin(t * 1.8) * 8 - 20
	var corps := Color(el.darkened(0.55), 0.85)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		var r := 44.0 + 10 * sin(a * 5 + t * 2)
		pts.append(Vector2(cos(a) * r * 0.75, -90 + flotte + sin(a) * r * 1.3))
	_contour(pts, corps)
	for i in 6:
		var a := t * 0.6 + i * TAU / 6
		draw_circle(Vector2(cos(a) * 58, -96 + flotte + sin(a) * 70), 6, Color(el, 0.6))
	draw_circle(Vector2(-10, -130 + flotte), 5, Color(0.8, 1.0, 0.6))
	draw_circle(Vector2(12, -130 + flotte), 5, Color(0.8, 1.0, 0.6))


func _drone(el: Color) -> void:
	var y := -96 + sin(t * 3.0) * 7
	draw_set_transform(Vector2(0, y + sin(t * 2.2) * 1.6), 0, Vector2(-1 if d.camp == 1 else 1, 0.35))
	draw_circle(Vector2.ZERO, 44, Color("2a3038"))
	draw_arc(Vector2.ZERO, 44, 0, TAU, 32, Color(el, 0.8), 2.0, true)
	draw_set_transform(Vector2(0, sin(t * 2.2) * 1.6), 0, Vector2(-1 if d.camp == 1 else 1, 1))
	_contour(PackedVector2Array([Vector2(-22, y - 4), Vector2(22, y - 4), Vector2(14, y + 14), Vector2(-14, y + 14)]), Color("3a4450"))
	draw_circle(Vector2(18, y + 4), 5, Color(1.0, 0.25, 0.2, 0.6 + 0.4 * sin(t * 6)))
	draw_line(Vector2(0, y + 16), Vector2(0, -6), Color(1.0, 0.3, 0.2, 0.08), 20.0)


func _robe(col: Color, el: Color) -> void:
	_contour(PackedVector2Array([Vector2(-16, -126), Vector2(16, -126), Vector2(34, 0), Vector2(-34, 0)]), col)
	draw_line(Vector2(-20, -60), Vector2(20, -60), Color(el, 0.8), 3.0)
	draw_line(Vector2(12, -118), Vector2(36, -86), col, 8.0, true)
	var tete := Vector2(2, -144)
	draw_circle(tete, 18, col)
	# Masque blanc sans visage.
	draw_set_transform(tete + Vector2(4, 0), 0, Vector2(0.7, 1.0))
	draw_circle(Vector2.ZERO, 15, Color("ece6da"))
	draw_set_transform(Vector2.ZERO, 0, Vector2(-1 if d.camp == 1 else 1, 1))


# --- Barres, statuts, incantation -----------------------------------------

func _interface() -> void:
	var f := Pal.police_texte
	var w := 128.0
	var y := 18.0
	# Nom.
	var nom: String = d.nom + (" (clone)" if d.get("clone", false) else "")
	var nw := f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(Pal.police_titre, Vector2(-nw * 0.5, y + 12), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.IVOIRE)
	y += 20
	# Points de vie.
	draw_rect(Rect2(-w * 0.5, y, w, 11), Color("140e11"))
	draw_rect(Rect2(-w * 0.5, y, w * clamp(pv_affiche / max(1.0, d.pv_max), 0, 1), 10), Pal.VIE)
	if d.absorption > 0:
		draw_rect(Rect2(-w * 0.5, y, w * clamp(d.absorption / max(1.0, float(d.pv_max)), 0, 1), 4), Color(Pal.IVOIRE, 0.8))
	draw_rect(Rect2(-w * 0.5, y, w, 10), Color(0, 0, 0, 0.6), false, 1.0)
	y += 13
	# Souffle.
	draw_rect(Rect2(-w * 0.5, y, w, 6), Color("140e11"))
	draw_rect(Rect2(-w * 0.5, y, w * clamp(souffle_affiche / max(1.0, d.souffle_max), 0, 1), 6), Pal.SOUFFLE)
	y += 8
	var txt := "PV %d / %d" % [d.pv, d.pv_max]
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f, Vector2(-tw * 0.5, y + 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.IVOIRE_DOUX)
	y += 18
	# Statuts.
	var sx := -w * 0.5
	for s in d.get("statuts", []) if d.get("statuts") != null else []:
		var info = LETTRES.get(s.type, ["?", Pal.GRIS])
		draw_circle(Vector2(sx + 9, y + 9), 9, Color(info[1], 0.25))
		draw_arc(Vector2(sx + 9, y + 9), 9, 0, TAU, 16, info[1], 1.2, true)
		draw_string(f, Vector2(sx + 4, y + 14), info[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, info[1])
		draw_string(f, Vector2(sx + 13, y + 22), str(s.tours), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.IVOIRE_DOUX)
		sx += 24
	# Incantation au-dessus de la tête.
	var inc = d.get("incantation")
	if inc != null and d.pv > 0:
		var c := Vector2(0, -205)
		var frac: float = float(inc.progres) / max(1.0, float(inc.total))
		var col := Pal.OR_VIF if inc.get("silence", false) == false else Color("b9a7ff")
		draw_circle(c, 22, Color(0, 0, 0, 0.55))
		draw_arc(c, 22, -PI / 2, -PI / 2 + TAU * frac, 32, col, 4.0, true)
		draw_arc(c, 22, 0, TAU, 32, Color(col, 0.25), 1.0, true)
		var it := "%d/%d" % [inc.progres, inc.total]
		var iw := f.get_string_size(it, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(f, c + Vector2(-iw * 0.5, 5), it, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.IVOIRE)
		var seq = inc.get("sequence")
		if seq != null:
			var gx: float = -(seq.size() * 22) * 0.5
			for i in seq.size():
				var gc := Vector2(gx + i * 22 + 11, -240)
				var mc := Jeu.couleur_mudra(seq[i])
				if i >= inc.progres:
					mc = Color(mc, 0.3)
				draw_circle(gc, 10, Color("140e11"))
				UI.dessiner_glyphe(self, gc, 9, seq[i], mc, 1.3)


func zone_clic() -> Rect2:
	return Rect2(position + Vector2(-60, -190) * scale, Vector2(120, 250) * scale)
