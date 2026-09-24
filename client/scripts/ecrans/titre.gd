extends Ecran
## Écran titre : démarre le serveur local, puis propose de jouer.

var _statut: Label
var _boutons: VBoxContainer
var _braises: Braises


func construire() -> void:
	_braises = Braises.new()
	_braises.set_anchors_preset(Control.PRESET_FULL_RECT)
	_braises.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_braises)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(v)

	var embleme := Embleme.new()
	embleme.custom_minimum_size = Vector2(200, 200)
	embleme.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(embleme)

	var titre := UI.label("NINJA IVOIRE", 86, Pal.IVOIRE, true)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titre)
	var sous := UI.label("Le Souffle, les signes et les sept régions", 22, Pal.OR)
	sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sous)
	v.add_child(UI.frise(520))
	v.add_child(UI.espace(10))

	_boutons = UI.vbox(12)
	_boutons.custom_minimum_size.x = 380
	_boutons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_boutons)

	_statut = UI.label("Éveil du Souffle…", 16, Pal.IVOIRE_DOUX)
	_statut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_statut)

	var version := UI.label("Prototype 0.4 — jutsus, carte, ressources et forge", 13, Pal.GRIS)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-420, -34)
	add_child(version)

	_demarrer()


func _demarrer() -> void:
	var err := await Jeu.demarrer_serveur()
	if err == "":
		err = await Jeu.charger()
	if err != "":
		_statut.text = err
		_statut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_statut.custom_minimum_size.x = 760
		_statut.add_theme_color_override("font_color", Color("e8806f"))
		_boutons.add_child(UI.bouton("Ouvrir le dossier du jeu", func(): OS.shell_open(Jeu.dossier_jeu())))
		_boutons.add_child(UI.bouton("Réessayer", func():
			for c in _boutons.get_children():
				c.queue_free()
			_statut.text = "Éveil du Souffle…"
			_demarrer()))
		_boutons.add_child(UI.bouton("Quitter", Jeu.quitter))
		return
	_statut.text = "Prêt."
	if Jeu.ninja != null:
		var n = Jeu.ninja
		_boutons.add_child(UI.bouton_principal("Continuer — %s, niveau %d" % [n.nom, n.niveau], func(): Jeu.aller("village" if n.situation.village else "carte"), 22))
	else:
		_boutons.add_child(UI.bouton_principal("Créer mon ninja", func(): Jeu.aller("creation"), 22))
	_boutons.add_child(UI.bouton("Quitter", Jeu.quitter))


## Emblème : un losange ivoire cerclé d'or, avec le point du Souffle.
class Embleme:
	extends Control
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.45
		for i in 6:
			draw_circle(c, r * (0.6 + i * 0.1), Color(Pal.OR, 0.025))
		var ext := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
		draw_polyline(ext, Pal.OR, 3.0, true)
		var ri := r * 0.55
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -ri), c + Vector2(ri, 0), c + Vector2(0, ri), c + Vector2(-ri, 0)]), Color("fff4de"))
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * ri, c + d * r, Pal.OR, 2.0, true)
		var pulse := 0.5 + 0.5 * sin(t * 2.0)
		draw_circle(c, r * 0.12 + pulse * 3.0, Color("e2572b", 0.35))
		draw_circle(c, r * 0.1, Color("e2572b"))
		UI.dessiner_glyphe(self, c, ri * 0.75, "ivoire", Color(Pal.OR, 0.7), 2.0)


## Braises qui montent lentement.
class Braises:
	extends Control
	var parts: Array = []
	var rng := RandomNumberGenerator.new()

	func _process(delta: float) -> void:
		if parts.size() < 70 and rng.randf() < 0.6:
			parts.append({"p": Vector2(rng.randf() * size.x, size.y + 10), "v": Vector2(rng.randf_range(-10, 10), rng.randf_range(-50, -20)), "r": rng.randf_range(1.0, 2.8), "vie": 0.0, "max": rng.randf_range(6, 14)})
		for p in parts:
			p.p += p.v * delta
			p.p.x += sin(p.vie * 1.5 + p.r) * 12 * delta
			p.vie += delta
		parts = parts.filter(func(p): return p.vie < p.max)
		queue_redraw()

	func _draw() -> void:
		for p in parts:
			var a: float = sin(PI * p.vie / p.max)
			draw_circle(p.p, p.r * 2.5, Color(0.95, 0.5, 0.2, 0.08 * a))
			draw_circle(p.p, p.r, Color(1.0, 0.72, 0.4, 0.7 * a))
