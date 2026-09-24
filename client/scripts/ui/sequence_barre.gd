class_name SequenceBarre
extends Control
## Les emplacements de la suite de mudras en cours de composition.

signal change

const MAX := 7  # longueur maximale d'un jutsu

var sequence: Array = []
var _t := 0.0
var eclat := 0.0  # lueur après une découverte
var couleur_eclat := Pal.OR_VIF
var rayon := 32.0


func _ready() -> void:
	custom_minimum_size = Vector2(MAX * (rayon * 2 + 28), rayon * 2 + 40)


func _process(delta: float) -> void:
	_t += delta
	eclat = max(0.0, eclat - delta * 0.6)
	queue_redraw()


func ajouter(id: String) -> void:
	if sequence.size() >= MAX:
		return
	sequence.append(id)
	change.emit()


func retirer() -> void:
	if sequence.size() > 0:
		sequence.pop_back()
		change.emit()


func vider() -> void:
	sequence.clear()
	change.emit()


func _draw() -> void:
	var pas := size.x / MAX
	for i in MAX:
		var c := Vector2(pas * (i + 0.5), rayon + 10)
		var r := rayon
		if i < sequence.size():
			var id: String = sequence[i]
			var col := Jeu.couleur_mudra(id)
			draw_circle(c, r + 6, Color(col, 0.12 + 0.3 * eclat))
			draw_circle(c, r, Color("ffffff"))
			draw_arc(c, r, 0, TAU, 48, col, 2.0, true)
			UI.dessiner_glyphe(self, c, r - 5, id, col, 2.2)
			var nom: String = Jeu.mudra(id).get("nom", "?")
			var w := Pal.police_texte.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(Pal.police_texte, Vector2(c.x - w * 0.5, c.y + r + 20), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.IVOIRE)
		else:
			var a := 0.18
			if i == sequence.size():
				a = 0.3 + 0.15 * sin(_t * 3.0)
			draw_arc(c, r, 0, TAU, 48, Color(Pal.OR, a), 1.5, true)
			var num := str(i + 1)
			draw_string(Pal.police_titre, c + Vector2(-5, 6), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.OR, a))
		if i < MAX - 1:
			draw_line(c + Vector2(r + 6, 0), c + Vector2(pas - r - 6, 0), Color(Pal.OR, 0.2), 1.0)
