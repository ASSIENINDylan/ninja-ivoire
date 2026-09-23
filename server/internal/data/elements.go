// Package data contient le catalogue statique du jeu : éléments, mudras,
// régions. C'est la source de vérité partagée par la grammaire et le combat.
package data

// Tier est le rang d'un élément.
type Tier string

const (
	TierBase     Tier = "base"
	TierRare     Tier = "rare"
	TierMythique Tier = "mythique"
)

// Horizon indique quand un élément est le plus utile.
type Horizon string

const (
	Court    Horizon = "court"
	Moyen    Horizon = "moyen"
	Long     Horizon = "long"
	Cyclique Horizon = "cyclique"
)

// Element décrit un élément manipulable par le Souffle.
type Element struct {
	ID      string   `json:"id"`
	Nom     string   `json:"nom"`
	De      string   `json:"de"` // complément de nom : « de Feu », « d'Eau »
	Tier    Tier     `json:"tier"`
	Role    string   `json:"role"`
	Horizon Horizon  `json:"horizon"`
	Fort    []string `json:"fort"`   // éléments contre lesquels il est fort
	Faible  []string `json:"faible"` // éléments contre lesquels il est faible
	Fusion  []string `json:"fusion,omitempty"`
	Couleur string   `json:"couleur"`
}

var elementList = []Element{
	// --- 16 éléments de base ---
	{ID: "feu", Nom: "Feu", De: "de Feu", Tier: TierBase, Role: "Gros dégâts, brûlure", Horizon: Court, Fort: []string{"vegetal", "essaim"}, Faible: []string{"eau", "sable"}, Couleur: "#e2572b"},
	{ID: "eau", Nom: "Eau", De: "d'Eau", Tier: TierBase, Role: "Polyvalence, soins", Horizon: Moyen, Fort: []string{"feu", "sable"}, Faible: []string{"terre", "foudre"}, Couleur: "#2f86c9"},
	{ID: "vent", Nom: "Vent", De: "de Vent", Tier: TierBase, Role: "Vitesse, initiative, portée", Horizon: Court, Fort: []string{"brume", "essaim"}, Faible: []string{"venin", "gravite"}, Couleur: "#9fd8c4"},
	{ID: "terre", Nom: "Terre", De: "de Terre", Tier: TierBase, Role: "Murs, armure, fortifications", Horizon: Long, Fort: []string{"foudre", "eau"}, Faible: []string{"vegetal", "metal"}, Couleur: "#a0703c"},
	{ID: "foudre", Nom: "Foudre", De: "de Foudre", Tier: TierBase, Role: "Perce, paralyse, agit en premier", Horizon: Court, Fort: []string{"eau", "metal"}, Faible: []string{"terre", "sable"}, Couleur: "#f2d64b"},
	{ID: "vegetal", Nom: "Végétal", De: "de Sève", Tier: TierBase, Role: "Pièges, entraves, croissance", Horizon: Long, Fort: []string{"terre", "sable"}, Faible: []string{"feu", "metal"}, Couleur: "#4f9d45"},
	{ID: "metal", Nom: "Métal", De: "de Métal", Tier: TierBase, Role: "Armes, forge, artisanat", Horizon: Moyen, Fort: []string{"vegetal", "terre"}, Faible: []string{"foudre", "son"}, Couleur: "#a9b4bd"},
	{ID: "son", Nom: "Son", De: "de Son", Tier: TierBase, Role: "Interrompt les mudras, tambours de soutien", Horizon: Moyen, Fort: []string{"metal", "lune"}, Faible: []string{"brume", "venin"}, Couleur: "#d98bd4"},
	{ID: "sable", Nom: "Sable", De: "de Sable", Tier: TierBase, Role: "Aveugle, use les défenses", Horizon: Moyen, Fort: []string{"feu", "foudre"}, Faible: []string{"eau", "vegetal"}, Couleur: "#dcb877"},
	{ID: "venin", Nom: "Venin", De: "de Venin", Tier: TierBase, Role: "Dégâts cumulatifs sur la durée", Horizon: Long, Fort: []string{"son", "vent"}, Faible: []string{"sel", "soleil"}, Couleur: "#7fc23a"},
	{ID: "brume", Nom: "Brume", De: "de Brume", Tier: TierBase, Role: "Cache ses actions, esquive", Horizon: Moyen, Fort: []string{"son", "sel"}, Faible: []string{"vent", "soleil"}, Couleur: "#b7c3cf"},
	{ID: "sel", Nom: "Sel", De: "de Sel", Tier: TierBase, Role: "Purifie, annule les effets, repousse les esprits", Horizon: Long, Fort: []string{"venin", "lune"}, Faible: []string{"brume", "gravite"}, Couleur: "#f4f1ea"},
	{ID: "essaim", Nom: "Essaim", De: "d'Essaim", Tier: TierBase, Role: "Nuées, éclaireurs, harcèlement", Horizon: Long, Fort: []string{"soleil", "gravite"}, Faible: []string{"feu", "vent"}, Couleur: "#c29a2e"},
	{ID: "soleil", Nom: "Soleil", De: "de Soleil", Tier: TierBase, Role: "Plus fort à midi (heure réelle)", Horizon: Cyclique, Fort: []string{"brume", "venin"}, Faible: []string{"lune", "essaim"}, Couleur: "#ffb534"},
	{ID: "lune", Nom: "Lune", De: "de Lune", Tier: TierBase, Role: "Illusions, plus forte la nuit et à la pleine lune", Horizon: Cyclique, Fort: []string{"soleil", "gravite"}, Faible: []string{"son", "sel"}, Couleur: "#8ea4ff"},
	{ID: "gravite", Nom: "Gravité", De: "de Gravité", Tier: TierBase, Role: "Déplace les ennemis entre les rangs", Horizon: Moyen, Fort: []string{"vent", "sel"}, Faible: []string{"lune", "essaim"}, Couleur: "#6b4fa3"},

	// --- 16 éléments rares (fusions) ---
	{ID: "lave", Nom: "Lave", De: "de Lave", Tier: TierRare, Fusion: []string{"feu", "terre"}, Role: "Dégâts et terrain brûlant", Horizon: Long, Couleur: "#ff5a1f"},
	{ID: "glace", Nom: "Glace", De: "de Glace", Tier: TierRare, Fusion: []string{"eau", "vent"}, Role: "Gel, entrave, armure", Horizon: Moyen, Couleur: "#aee7ff"},
	{ID: "vapeur", Nom: "Vapeur", De: "de Vapeur", Tier: TierRare, Fusion: []string{"feu", "eau"}, Role: "Brûlure et dissimulation", Horizon: Moyen, Couleur: "#e8e3e0"},
	{ID: "magnetisme", Nom: "Magnétisme", De: "de Magnétisme", Tier: TierRare, Fusion: []string{"foudre", "metal"}, Role: "Désarme, neutralise la technologie", Horizon: Moyen, Couleur: "#5ec8d8"},
	{ID: "tempete", Nom: "Tempête", De: "de Tempête", Tier: TierRare, Fusion: []string{"vent", "foudre"}, Role: "Dégâts de zone", Horizon: Court, Couleur: "#7c8cff"},
	{ID: "cristal", Nom: "Cristal", De: "de Cristal", Tier: TierRare, Fusion: []string{"sel", "soleil"}, Role: "Renvoie les jutsus, stocke le Souffle", Horizon: Long, Couleur: "#e0f7ff"},
	{ID: "acide", Nom: "Acide", De: "d'Acide", Tier: TierRare, Fusion: []string{"venin", "eau"}, Role: "Détruit armures et équipements", Horizon: Moyen, Couleur: "#b4f03c"},
	{ID: "bois_sacre", Nom: "Bois sacré", De: "de Bois sacré", Tier: TierRare, Fusion: []string{"vegetal", "soleil"}, Role: "Soins massifs, croissance explosive", Horizon: Long, Couleur: "#8bc34a"},
	{ID: "onde", Nom: "Onde de choc", De: "d'Onde", Tier: TierRare, Fusion: []string{"son", "vent"}, Role: "Repousse et étourdit un rang", Horizon: Court, Couleur: "#f09ae0"},
	{ID: "cendre", Nom: "Cendre", De: "de Cendre", Tier: TierRare, Fusion: []string{"feu", "vent"}, Role: "Aveugle et étouffe", Horizon: Long, Couleur: "#8a817c"},
	{ID: "crepuscule", Nom: "Crépuscule", De: "de Crépuscule", Tier: TierRare, Fusion: []string{"soleil", "lune"}, Role: "Change le cycle jour/nuit du combat", Horizon: Cyclique, Couleur: "#d76b8a"},
	{ID: "songe", Nom: "Songe", De: "de Songe", Tier: TierRare, Fusion: []string{"brume", "lune"}, Role: "Illusions profondes", Horizon: Moyen, Couleur: "#a78bfa"},
	{ID: "fleau", Nom: "Fléau", De: "de Fléau", Tier: TierRare, Fusion: []string{"essaim", "venin"}, Role: "Épidémie qui se propage", Horizon: Long, Couleur: "#6f8f2a"},
	{ID: "seisme", Nom: "Séisme", De: "de Séisme", Tier: TierRare, Fusion: []string{"terre", "gravite"}, Role: "Brise positions et fortifications", Horizon: Court, Couleur: "#7a5534"},
	{ID: "maree", Nom: "Marée", De: "de Marée", Tier: TierRare, Fusion: []string{"eau", "lune"}, Role: "Vagues qui montent de tour en tour", Horizon: Long, Couleur: "#2b6cb0"},
	{ID: "harmattan", Nom: "Harmattan", De: "d'Harmattan", Tier: TierRare, Fusion: []string{"sable", "vent"}, Role: "Affaiblit tout le camp adverse", Horizon: Moyen, Couleur: "#d9a55b"},

	// --- 8 éléments mythiques ---
	{ID: "ivoire", Nom: "Ivoire", De: "d'Ivoire", Tier: TierMythique, Role: "Le Souffle originel", Horizon: Long, Couleur: "#fff8e7"},
	{ID: "esprit", Nom: "Esprit", De: "d'Esprit", Tier: TierMythique, Role: "Lien avec les ancêtres", Horizon: Long, Couleur: "#c6f1ff"},
	{ID: "lumiere", Nom: "Lumière", De: "de Lumière", Tier: TierMythique, Role: "Révélation, guérison", Horizon: Moyen, Couleur: "#fffbd0"},
	{ID: "ombre", Nom: "Ombre", De: "d'Ombre", Tier: TierMythique, Role: "Absorption, peur", Horizon: Moyen, Couleur: "#2a2233"},
	{ID: "vie", Nom: "Vie", De: "de Vie", Tier: TierMythique, Role: "Régénération", Horizon: Long, Couleur: "#7fffa0"},
	{ID: "temps", Nom: "Temps", De: "du Temps", Tier: TierMythique, Role: "Accélérer, ralentir", Horizon: Cyclique, Couleur: "#e6c07b"},
	{ID: "vide", Nom: "Vide", De: "du Vide", Tier: TierMythique, Role: "Efface, annule", Horizon: Court, Couleur: "#111018"},
	{ID: "astre", Nom: "Astre", De: "des Astres", Tier: TierMythique, Role: "Puissance cosmique", Horizon: Cyclique, Couleur: "#b9a7ff"},
}

// Elements indexe les éléments par identifiant.
var Elements = map[string]*Element{}

// fusionIndex associe une paire ORDONNÉE d'éléments de base à l'élément rare :
// l'ordre des signes compte, « Feu puis Terre » donne la Lave, pas l'inverse.
var fusionIndex = map[[2]string]string{}

func init() {
	for i := range elementList {
		e := &elementList[i]
		Elements[e.ID] = e
	}
	// Les éléments rares héritent des forces de leurs deux composants.
	// Ils ne gardent que les faiblesses communes aux deux : ils sont plus sûrs.
	for i := range elementList {
		e := &elementList[i]
		if e.Tier != TierRare {
			continue
		}
		a, b := Elements[e.Fusion[0]], Elements[e.Fusion[1]]
		e.Fort = union(a.Fort, b.Fort, e.Fusion)
		e.Faible = intersect(a.Faible, b.Faible)
		fusionIndex[[2]string{a.ID, b.ID}] = e.ID
	}
}

// AllElements renvoie les éléments dans l'ordre du catalogue.
func AllElements() []Element { return elementList }

// FusionOf renvoie l'élément rare issu de deux éléments de base enchaînés
// dans cet ordre, ou "".
func FusionOf(a, b string) string { return fusionIndex[[2]string{a, b}] }

// Multiplier renvoie le multiplicateur de dégâts d'un élément attaquant
// contre l'élément principal de la cible.
func Multiplier(attaque, cible string) float64 {
	a := Elements[attaque]
	if a == nil || cible == "" {
		return 1
	}
	if a.Tier == TierMythique {
		return 1.25
	}
	if contains(a.Fort, cible) {
		return 1.5
	}
	if contains(a.Faible, cible) {
		return 0.67
	}
	return 1
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func union(a, b, exclude []string) []string {
	var out []string
	seen := map[string]bool{}
	for _, x := range exclude {
		seen[x] = true
	}
	for _, x := range append(append([]string{}, a...), b...) {
		if !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}

func intersect(a, b []string) []string {
	var out []string
	for _, x := range a {
		if contains(b, x) {
			out = append(out, x)
		}
	}
	return out
}
