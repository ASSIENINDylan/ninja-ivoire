class_name Pal
extends RefCounted
## Palette et thème de Ninja Ivoire : clair et coloré, comme un pagne au
## soleil. IVOIRE et IVOIRE_DOUX sont les couleurs du texte (encre sombre) ;
## CLAIR sert au texte posé sur une couleur vive.

const FOND := Color("f6efe2")
const FOND_2 := Color("fbf7ef")
const PANNEAU := Color("ffffff")
const PANNEAU_2 := Color("f5eddf")
const BORD := Color("e0cfb2")
const IVOIRE := Color("2b221d")
const IVOIRE_DOUX := Color("62564c")
const GRIS := Color("998d81")
const CLAIR := Color("ffffff")
const OR := Color("b67a1f")
const OR_VIF := Color("e8840f")
const OCRE := Color("d0662b")
const SANG := Color("d23c2c")
const VIE := Color("e5543f")
const SOUFFLE := Color("2f8fd8")
const VERT := Color("2f9e4f")
const INDIGO := Color("4453b8")
const TURQUOISE := Color("1fa7a0")
const ROSE := Color("d9468f")

const CATEGORIES := {
	"element": Color("e2572b"),
	"forme": Color("d6961e"),
	"effet": Color("2f9e4f"),
	"modificateur": Color("4f6fe0"),
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
	var survol := boite(Color("fff3de"), OR_VIF, 8, 1, 10)
	survol.content_margin_left = 18
	survol.content_margin_right = 18
	var presse := boite(Color("ffe4bd"), OR_VIF, 8, 2, 10)
	presse.content_margin_left = 18
	presse.content_margin_right = 18
	var inactif := boite(Color("f3eee6"), Color("e8dfd1"), 8, 1, 10)
	inactif.content_margin_left = 18
	inactif.content_margin_right = 18
	t.set_stylebox("normal", "Button", bouton)
	t.set_stylebox("hover", "Button", survol)
	t.set_stylebox("pressed", "Button", presse)
	t.set_stylebox("disabled", "Button", inactif)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", IVOIRE)
	t.set_color("font_hover_color", "Button", OCRE)
	t.set_color("font_pressed_color", "Button", OCRE)
	t.set_color("font_disabled_color", "Button", Color("b9aea2"))

	t.set_stylebox("panel", "PanelContainer", boite(Color(PANNEAU, 0.95), BORD, 12, 1, 18))
	t.set_stylebox("panel", "Panel", boite(Color(PANNEAU, 0.95), BORD, 12, 1, 18))

	var champ := boite(PANNEAU, BORD, 8, 1, 12)
	t.set_stylebox("normal", "LineEdit", champ)
	t.set_stylebox("focus", "LineEdit", boite(PANNEAU, OR_VIF, 8, 2, 12))
	t.set_color("font_color", "LineEdit", IVOIRE)
	t.set_color("caret_color", "LineEdit", OR_VIF)
	t.set_font_size("font_size", "LineEdit", 22)

	t.set_stylebox("background", "ProgressBar", boite(Color("efe6d6"), Color("e0d3bd"), 5, 1, 0))
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

	t.set_stylebox("panel", "TooltipPanel", boite(PANNEAU, OR_VIF, 6, 1, 10))
	t.set_color("font_color", "TooltipLabel", IVOIRE)
	return t
