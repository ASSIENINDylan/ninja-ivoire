class_name Deplacements
extends RefCounted
## Aides d'affichage pour les déplacements (le serveur ou le moteur local
## reste seul juge : ceci ne sert qu'à griser les directions impossibles).

const DIRECTIONS := [
	[Vector2i(-1, -1), "↖"], [Vector2i(0, -1), "↑"], [Vector2i(1, -1), "↗"],
	[Vector2i(-1, 0), "←"], [Vector2i(0, 0), "•"], [Vector2i(1, 0), "→"],
	[Vector2i(-1, 1), "↙"], [Vector2i(0, 1), "↓"], [Vector2i(1, 1), "↘"],
]


static func _case(x: int, y: int):
	var c: Dictionary = Jeu.catalogue.carte
	if x < 0 or y < 0 or x >= int(c.l) or y >= int(c.h):
		return null
	var i: int = y * int(c.l) + x
	if int(c.region[i]) < 0:
		return null
	return {"zone": c.zones[int(c.zone[i])], "terrain": c.terrains[int(c.terrain[i])], "lieu": int(c.lieu[i])}


static func cout(x: int, y: int) -> int:
	var cel = _case(x, y)
	if cel == null:
		return 0
	return int(Jeu.catalogue.carte.couts.get(cel.terrain, 0))


## "" si le pas est possible, sinon la raison.
static func possible(x: int, y: int) -> String:
	var n = Jeu.ninja
	var cel = _case(x, y)
	if cel == null:
		return "Hors du pays"
	var c := cout(x, y)
	if c == 0:
		return "Infranchissable"
	if int(n.niveau) < int(cel.zone.niveau):
		return "Niveau %d requis" % int(cel.zone.niveau)
	if int(n.endurance) < c:
		return "Trop fatigué"
	return ""
