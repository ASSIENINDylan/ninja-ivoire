class_name Effets
extends RefCounted
## Effets visuels du combat : projectiles, ondes, textes flottants.


static func texte(parent: Node, pos: Vector2, t: String, col: Color, taille: int = 26) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Pal.police_titre)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	parent.add_child(l)
	l.reset_size()
	l.position = pos - Vector2(l.size.x * 0.5, 0)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 70, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


static func projectile(parent: Node, de: Vector2, a: Vector2, col: Color, duree: float = 0.35) -> void:
	var p := Projectile.new()
	p.couleur = col
	p.position = de
	p.z_index = 15
	parent.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "position", a, duree).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	p.queue_free()
	onde(parent, a, col)


static func onde(parent: Node, pos: Vector2, col: Color, rayon: float = 70) -> void:
	var o := Onde.new()
	o.couleur = col
	o.rayon_max = rayon
	o.position = pos
	o.z_index = 16
	parent.add_child(o)


class Projectile:
	extends Node2D
	var couleur := Color.WHITE
	var trace: Array = []

	func _process(_delta: float) -> void:
		trace.push_front(global_position)
		if trace.size() > 10:
			trace.pop_back()
		queue_redraw()

	func _draw() -> void:
		for i in trace.size():
			var p: Vector2 = to_local(trace[i])
			draw_circle(p, 10 - i * 0.8, Color(couleur, 0.35 * (1.0 - i / 10.0)))
		draw_circle(Vector2.ZERO, 18, Color(couleur, 0.25))
		draw_circle(Vector2.ZERO, 9, couleur.lightened(0.3))
		draw_circle(Vector2.ZERO, 4, Color.WHITE)


class Onde:
	extends Node2D
	var couleur := Color.WHITE
	var rayon_max := 70.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta * 2.5
		if t >= 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := rayon_max * t
		draw_circle(Vector2.ZERO, r * 0.6, Color(couleur, 0.25 * (1 - t)))
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(couleur, 1 - t), 4.0 * (1 - t) + 1, true)
