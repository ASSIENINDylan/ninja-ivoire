package data

// Attribut de base d'un ninja.
type Attribut string

const (
	Fangan Attribut = "fangan" // force
	Gnanga Attribut = "gnanga" // technique
	Manhis Attribut = "manhis" // agilité
)

// Region est l'une des sept régions de la carte.
type Region struct {
	ID       string   `json:"id"`
	Nom      string   `json:"nom"`
	Geo      string   `json:"geo"`
	Element  string   `json:"element"`
	Attribut Attribut `json:"attribut"`
	Jouable  bool     `json:"jouable"`
	Paysage  string   `json:"paysage"`
	Couleur  string   `json:"couleur"`
	Villages []string `json:"villages"` // traditionnel, moderne, futuriste
}

// TypeVillage est le niveau technologique d'un village.
type TypeVillage struct {
	ID           string `json:"id"`
	Nom          string `json:"nom"`
	Avantages    string `json:"avantages"`
	Defauts      string `json:"defauts"`
	BonusPV      int    `json:"bonus_pv"`      // en %
	BonusSouffle int    `json:"bonus_souffle"` // en %
	BonusXP      int    `json:"bonus_xp"`      // en %
	BonusArme    int    `json:"bonus_arme"`    // puissance de l'arme de départ
	Resonance    bool   `json:"resonance"`     // résonance plus précise au dojo
}

// Noms de villages provisoires : ils seront choisis avec Terence.
var regionList = []Region{
	{ID: "lagunes", Nom: "Lagunes", Geo: "Sud-Est : Abidjan, Grand-Bassam, Assinie", Element: "eau", Attribut: Manhis, Jouable: true, Paysage: "Littoral, lagunes, mangroves", Couleur: "#2f86c9",
		Villages: []string{"Village des Palétuviers", "Port-Lagune", "Néo-Ébrié"}},
	{ID: "cote_ouest", Nom: "Côte Ouest", Geo: "Sud-Ouest : San-Pédro, Sassandra, forêt de Taï", Element: "vegetal", Attribut: Gnanga, Jouable: true, Paysage: "Forêt primaire, côte sauvage", Couleur: "#4f9d45",
		Villages: []string{"Village des Fromagers", "Sassandra-Cité", "Taï-Prime"}},
	{ID: "montagnes", Nom: "Montagnes", Geo: "Ouest : Man, Danané, mont Nimba", Element: "foudre", Attribut: Manhis, Jouable: true, Paysage: "Montagnes, cascades", Couleur: "#f2d64b",
		Villages: []string{"Village des Cascades", "Dent-de-Man", "Nimba-Orbitale"}},
	{ID: "hautes_savanes", Nom: "Hautes Savanes", Geo: "Nord-Ouest : Odienné, Séguéla", Element: "vent", Attribut: Fangan, Jouable: true, Paysage: "Savane arborée, plateaux", Couleur: "#9fd8c4",
		Villages: []string{"Village des Plateaux", "Séguéla-Carrefour", "Denguélé-Station"}},
	{ID: "savanes_nord", Nom: "Savanes du Nord", Geo: "Nord : Korhogo, Ferkessédougou, Kong", Element: "feu", Attribut: Fangan, Jouable: true, Paysage: "Savane, collines, cités anciennes", Couleur: "#e2572b",
		Villages: []string{"Village des Collines", "Kong-la-Neuve", "Korhogo-Nova"}},
	{ID: "levant", Nom: "Levant", Geo: "Est : Bondoukou, Abengourou, parc de la Comoé", Element: "terre", Attribut: Gnanga, Jouable: true, Paysage: "Forêt et savane, grande réserve", Couleur: "#a0703c",
		Villages: []string{"Village des Mosquées d'argile", "Abengourou-Marché", "Comoé-Arcologie"}},
	{ID: "coeur", Nom: "Cœur", Geo: "Centre : Yamoussoukro, Bouaké, lac de Kossou", Element: "", Jouable: false, Paysage: "Terre neutre, lacs, fleuve Bandama", Couleur: "#f4efe6",
		Villages: []string{"Village du Lac", "Bouaké-Marché", "Yamoussoukro-Céleste"}},
}

var typeVillageList = []TypeVillage{
	{ID: "traditionnel", Nom: "Traditionnel", Avantages: "Souffle plus puissant, accès aux lieux mythiques, résonance plus précise au dojo", Defauts: "Peu d'équipement, économie lente", BonusSouffle: 20, Resonance: true},
	{ID: "moderne", Nom: "Moderne", Avantages: "Équilibre, commerce, formation plus rapide (+15 % d'expérience)", Defauts: "N'excelle dans aucun domaine", BonusXP: 15, BonusPV: 5, BonusArme: 2},
	{ID: "futuriste", Nom: "Futuriste", Avantages: "Implants, meilleure arme de départ, plus de points de vie", Defauts: "Souffle affaibli par la technologie, vulnérable à la Foudre", BonusPV: 20, BonusSouffle: -15, BonusArme: 5},
}

// Regions indexe les régions par identifiant.
var Regions = map[string]*Region{}

// TypesVillage indexe les types de village.
var TypesVillage = map[string]*TypeVillage{}

func init() {
	for i := range regionList {
		Regions[regionList[i].ID] = &regionList[i]
	}
	for i := range typeVillageList {
		TypesVillage[typeVillageList[i].ID] = &typeVillageList[i]
	}
}

// AllRegions renvoie les régions dans l'ordre du catalogue.
func AllRegions() []Region { return regionList }

// AllTypesVillage renvoie les trois types de village.
func AllTypesVillage() []TypeVillage { return typeVillageList }

// VillageIndex renvoie l'indice (0, 1, 2) d'un type de village.
func VillageIndex(typeID string) int {
	for i, t := range typeVillageList {
		if t.ID == typeID {
			return i
		}
	}
	return -1
}
