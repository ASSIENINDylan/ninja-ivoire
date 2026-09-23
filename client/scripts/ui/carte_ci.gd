class_name CarteCI
extends Control
## Carte stylisée de la Côte d'Ivoire et de ses sept régions de jeu.
## Contour simplifié (longitude, latitude) ; les régions sont découpées
## par proximité autour de leur centre, puis rognées au contour du pays.

const CONTOUR := [
	Vector2(-7.53, 4.37), Vector2(-7.45, 5.10), Vector2(-7.55, 5.90), Vector2(-8.10, 6.30),
	Vector2(-8.45, 6.60), Vector2(-8.55, 7.10), Vector2(-8.40, 7.60), Vector2(-8.10, 7.80),
	Vector2(-8.15, 8.25), Vector2(-8.20, 9.10), Vector2(-7.95, 9.60), Vector2(-8.05, 10.10),
	Vector2(-7.50, 10.30), Vector2(-6.95, 10.20), Vector2(-6.20, 10.50), Vector2(-5.90, 10.35),
	Vector2(-5.50, 10.45), Vector2(-5.20, 10.35), Vector2(-4.90, 10.00), Vector2(-4.60, 9.80),
	Vector2(-4.30, 9.65), Vector2(-3.90, 9.90), Vector2(-3.30, 9.90), Vector2(-2.70, 9.50),
	Vector2(-2.75, 9.00), Vector2(-2.55, 8.00), Vector2(-2.95, 7.30), Vector2(-3.10, 6.70),
	Vector2(-3.20, 6.20), Vector2(-2.95, 5.60), Vector2(-3.05, 5.10), Vector2(-3.28, 5.13),
	Vector2(-3.74, 5.20), Vector2(-4.02, 5.30), Vector2(-4.42, 5.20), Vector2(-5.00, 5.13),
	Vector2(-5.57, 5.08), Vector2(-6.08, 4.95), Vector2(-6.64, 4.75), Vector2(-7.36, 4.42),
]

const CENTRES := {
	"lagunes": Vector2(-3.9, 5.9),
	"cote_ouest": Vector2(-6.6, 5.5),
	"montagnes": Vector2(-7.7, 7.3),
	"hautes_savanes": Vector2(-7.1, 9.1),
	"savanes_nord": Vector2(-5.3, 9.5),
	"levant": Vector2(-3.3, 8.0),
	"coeur": Vector2(-5.2, 7.3),
}

const FLEUVES := [
	[Vector2(-4.6, 10.2), Vector2(-3.9, 9.0), Vector2(-3.65, 7.6), Vector2(-3.5, 6.4), Vector2(-3.75, 5.2)],
	[Vector2(-5.6, 9.9), Vector2(-5.5, 8.4), Vector2(-5.5, 7.3), Vector2(-5.2, 6.5), Vector2(-5.0, 5.15)],
	[Vector2(-7.4, 9.3), Vector2(-6.9, 7.7), Vector2(-6.6, 6.6), Vector2(-6.3, 5.8), Vector2(-6.1, 4.97)],
]

var region_joueur := ""
var _t := 0.0
var _polys := {}  # id → PackedVector2Array en coordonnées géographiques


func _ready() -> void:
	_calculer_regions()
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _calculer_regions() -> void:
	var pays := PackedVector2Array(CONTOUR)
	for id in CENTRES:
		var cellule := PackedVector2Array([Vector2(-12, 2), Vector2(0, 2), Vector2(0, 13), Vector2(-12, 13)])
		var c: Vector2 = CENTRES[id]
		for autre in CENTRES:
			if autre == id:
				continue
			var o: Vector2 = CENTRES[autre]
			var milieu := (c + o) * 0.5
			var n := (o - c).normalized()
			var t := Vector2(-n.y, n.x)
			# Demi-plan du côté de l'autre centre, à retirer.
			var demi := PackedVector2Array([milieu + t * 40, milieu + t * 40 + n * 40, milieu - t * 40 + n * 40, milieu - t * 40])
			var reste := Geometry2D.clip_polygons(cellule, demi)
			if reste.size() > 0:
				cellule = reste[0]
		var inter := Geometry2D.intersect_polygons(cellule, pays)
		if inter.size() > 0:
			_polys[id] = inter[0]


func _vers_ecran(p: Vector2) -> Vector2:
	var lon_min := -8.8
	var lon_max := -2.3
	var lat_min := 4.2
	var lat_max := 10.7
	var echelle: float = min(size.x / (lon_max - lon_min), size.y / (lat_max - lat_min))
	var decal := (size - Vector2(lon_max - lon_min, lat_max - lat_min) * echelle) * 0.5
	return decal + Vector2(p.x - lon_min, lat_max - p.y) * echelle


func _ecran(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(_vers_ecran(p))
	return out


func _draw() -> void:
	# Océan.
	var cote := _ecran(PackedVector2Array(CONTOUR))
	var ocean := Color("12202e")
	draw_string(Pal.police_titre, _vers_ecran(Vector2(-6.6, 4.35)), "Océan Atlantique", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Pal.SOUFFLE, 0.45))
	for i in 3:
		var ligne := PackedVector2Array()
		for p in CONTOUR.slice(31, CONTOUR.size()) + [CONTOUR[0]]:
			ligne.append(_vers_ecran(p) + Vector2(0, 10 + i * 9))
		draw_polyline(ligne, Color(ocean.lightened(0.2), 0.5 - i * 0.14), 1.0, true)
	# Régions.
	for id in _polys:
		var reg := Jeu.region(id)
		var col := Color(reg.get("couleur", "#888888"))
		var poly := _ecran(_polys[id])
		var fond := col.darkened(0.7)
		if id == region_joueur:
			fond = col.darkened(0.45 - 0.08 * sin(_t * 2.0))
		elif id == "coeur":
			fond = Color("3a3430")
		draw_colored_polygon(poly, fond)
		var bord := poly.duplicate()
		bord.append(poly[0])
		draw_polyline(bord, Color(Pal.IVOIRE, 0.25), 1.2, true)
	# Contour du pays.
	var contour := cote.duplicate()
	contour.append(cote[0])
	draw_polyline(contour, Color(Pal.OR, 0.8), 2.2, true)
	# Fleuves et lac de Kossou.
	for f in FLEUVES:
		draw_polyline(_ecran(PackedVector2Array(f)), Color(Pal.SOUFFLE, 0.55), 1.6, true)
	var lac := _vers_ecran(Vector2(-5.45, 7.25))
	draw_circle(lac, 6, Color(Pal.SOUFFLE, 0.6))
	# Noms et villages.
	for id in CENTRES:
		var reg := Jeu.region(id)
		var p := _vers_ecran(CENTRES[id])
		var nom: String = reg.get("nom", id)
		var fs := 17 if id == region_joueur else 14
		var col := Pal.OR_VIF if id == region_joueur else Pal.IVOIRE
		var w := Pal.police_titre.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(Pal.police_titre, p + Vector2(-w * 0.5, -10), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		for k in 3:
			var vp := p + Vector2((k - 1) * 12, 6)
			var vc: Color = [Color("c98b4a"), Color("9aa6b2"), Color("5ec8d8")][k]
			draw_circle(vp, 3.5, vc)
		if id == region_joueur:
			draw_arc(p + Vector2(0, 6), 22 + 3 * sin(_t * 3), 0, TAU, 32, Color(Pal.OR_VIF, 0.6), 1.5, true)
		if id == "coeur":
			draw_string(Pal.police_texte, p + Vector2(-26, 24), "zone sûre", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.IVOIRE_DOUX)
