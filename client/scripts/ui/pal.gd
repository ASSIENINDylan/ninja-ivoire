class_name Pal
extends RefCounted
## Palette et thème de Ninja Ivoire : ivoire, or, terre et indigo nocturne.

const FOND := Color("0e0b0d")
const FOND_2 := Color("1a1216")
const PANNEAU := Color("21181c")
const PANNEAU_2 := Color("2c2026")
const BORD := Color("4a3a33")
const IVOIRE := Color("f2e8d5")
const IVOIRE_DOUX := Color("c9bda8")
const GRIS := Color("8a7f74")
const OR := Color("c9a25b")
const OR_VIF := Color("e8c47a")
const OCRE := Color("b8612f")
const SANG := Color("c0392b")
const VIE := Color("c94f3d")
const SOUFFLE := Color("5aa9e6")
const VERT := Color("6fbf73")
const INDIGO := Color("1d2340")

const CATEGORIES := {
	"element": Color("e2572b"),
	"forme": Color("c9a25b"),
	"effet": Color("6fbf73"),
	"modificateur": Color("8ea4ff"),
}

const NOMS_CATEGORIES := {
	"element": "Éléments",
	"forme": "Formes",
	"effet": "Effets",
	"modificateur": "Modificateurs",
}

static var police_titre: Font = preload("res://assets/fonts/Marcellus-Regular.ttf")
static var police_texte: Font = preload("res://assets/fonts/Outfit.ttf")


static func boite(fond: Color, bord: Color = BORD, rayon: int = 10, epaisseur: int = 1, marge: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(epaisseur)
	s.set_corner_radius_all(rayon)
	s.set_content_margin_all(marge)
	s.anti_aliasing = true
	return s


static func creer_theme() -> Theme:
	var t := Theme.new()
	t.default_font = police_texte
	t.default_font_size = 18

	t.set_color("font_color", "Label", IVOIRE)

	var bouton := boite(PANNEAU_2, BORD, 8, 1, 10)
	bouton.content_margin_left = 18
	bouton.content_margin_right = 18
	var survol := boite(Color("3a2a2e"), OR, 8, 1, 10)
	survol.content_margin_left = 18
	survol.content_margin_right = 18
	var presse := boite(Color("4a3528"), OR_VIF, 8, 2, 10)
	presse.content_margin_left = 18
	presse.content_margin_right = 18
	var inactif := boite(Color("1c1519"), Color("30272a"), 8, 1, 10)
	inactif.content_margin_left = 18
	inactif.content_margin_right = 18
	t.set_stylebox("normal", "Button", bouton)
	t.set_stylebox("hover", "Button", survol)
	t.set_stylebox("pressed", "Button", presse)
	t.set_stylebox("disabled", "Button", inactif)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", IVOIRE)
	t.set_color("font_hover_color", "Button", OR_VIF)
	t.set_color("font_pressed_color", "Button", OR_VIF)
	t.set_color("font_disabled_color", "Button", Color("6b6058"))

	t.set_stylebox("panel", "PanelContainer", boite(Color(PANNEAU, 0.92), BORD, 12, 1, 18))
	t.set_stylebox("panel", "Panel", boite(Color(PANNEAU, 0.92), BORD, 12, 1, 18))

	var champ := boite(Color("150f12"), BORD, 8, 1, 12)
	t.set_stylebox("normal", "LineEdit", champ)
	t.set_stylebox("focus", "LineEdit", boite(Color("150f12"), OR, 8, 1, 12))
	t.set_color("font_color", "LineEdit", IVOIRE)
	t.set_color("caret_color", "LineEdit", OR_VIF)
	t.set_font_size("font_size", "LineEdit", 22)

	t.set_stylebox("background", "ProgressBar", boite(Color("140e11"), Color("2d2327"), 5, 1, 0))
	t.set_stylebox("fill", "ProgressBar", boite(OR, OR, 5, 0, 0))
	t.set_color("font_color", "ProgressBar", IVOIRE)

	t.set_color("default_color", "RichTextLabel", IVOIRE_DOUX)
	t.set_font("normal_font", "RichTextLabel", police_texte)
	t.set_font("bold_font", "RichTextLabel", police_titre)
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)

	var barre := StyleBoxFlat.new()
	barre.bg_color = Color(OR, 0.35)
	barre.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", barre)
	t.set_stylebox("grabber_highlight", "VScrollBar", barre)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	t.set_stylebox("panel", "TooltipPanel", boite(Color("150f12"), OR, 6, 1, 10))
	t.set_color("font_color", "TooltipLabel", IVOIRE)
	return t
