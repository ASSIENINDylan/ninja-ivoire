package game

import "github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"

// La forge du village : les ressources exploitées deviennent armes et
// armures. Cinq emplacements : arme, arme secondaire, tête, corps, pieds.

// Emplacements d'équipement.
const (
	EmplArme       = "arme"
	EmplSecondaire = "arme_secondaire"
	EmplTete       = "tete"
	EmplCorps      = "corps"
	EmplPieds      = "pieds"
)

// Emplacements dans l'ordre d'affichage.
var Emplacements = []string{EmplArme, EmplSecondaire, EmplTete, EmplCorps, EmplPieds}

// NomsEmplacements pour l'affichage.
var NomsEmplacements = map[string]string{
	EmplArme: "Arme", EmplSecondaire: "Arme secondaire", EmplTete: "Tête", EmplCorps: "Corps", EmplPieds: "Pieds",
}

// Objet : ce que la forge sait fabriquer.
type Objet struct {
	ID          string         `json:"id"`
	Nom         string         `json:"nom"`
	Emplacement string         `json:"emplacement"`
	Arme        string         `json:"arme,omitempty"` // nom en combat : « un sabre de fer »
	Distance    bool           `json:"distance,omitempty"`
	Cout        map[string]int `json:"cout"`
	Puissance   int            `json:"puissance,omitempty"` // ajoutée à celle de l'arme de départ
	Defense     int            `json:"defense,omitempty"`
	DefenseMag  int            `json:"defense_mag,omitempty"`
	PV          int            `json:"pv,omitempty"`
	Manhis      int            `json:"manhis,omitempty"`
}

var objetList = []Objet{
	// Armes.
	{ID: "massue_pierre", Nom: "Massue de pierre", Emplacement: EmplArme, Arme: "une massue de pierre",
		Cout: map[string]int{carte.Pierre: 8, carte.Peau: 2}, Puissance: 3},
	{ID: "sabre_fer", Nom: "Sabre de fer", Emplacement: EmplArme, Arme: "un sabre de fer",
		Cout: map[string]int{carte.Fer: 6, carte.Peau: 1}, Puissance: 5},
	{ID: "arc_chasseur", Nom: "Arc du chasseur", Emplacement: EmplArme, Arme: "un arc", Distance: true,
		Cout: map[string]int{carte.Peau: 6, carte.Fer: 2}, Puissance: 3},
	{ID: "sabre_or", Nom: "Sabre d'or", Emplacement: EmplArme, Arme: "un sabre d'or",
		Cout: map[string]int{carte.Fer: 10, carte.Or: 4}, Puissance: 9},
	{ID: "lame_diamant", Nom: "Lame de diamant", Emplacement: EmplArme, Arme: "une lame de diamant",
		Cout: map[string]int{carte.Fer: 12, carte.Or: 4, carte.Diamant: 2}, Puissance: 14},
	// Armes secondaires.
	{ID: "kunai_fer", Nom: "Kunaïs de fer", Emplacement: EmplSecondaire, Cout: map[string]int{carte.Fer: 4}, Manhis: 2},
	{ID: "shuriken_or", Nom: "Shurikens d'or", Emplacement: EmplSecondaire, Cout: map[string]int{carte.Fer: 4, carte.Or: 2}, Manhis: 4},
	// Tête.
	{ID: "bandeau_cuir", Nom: "Bandeau de cuir", Emplacement: EmplTete, Cout: map[string]int{carte.Peau: 4}, Defense: 1, DefenseMag: 1},
	{ID: "casque_fer", Nom: "Casque de fer", Emplacement: EmplTete, Cout: map[string]int{carte.Fer: 6, carte.Peau: 2}, Defense: 3},
	{ID: "diademe_or", Nom: "Diadème d'or", Emplacement: EmplTete, Cout: map[string]int{carte.Or: 4, carte.Peau: 2}, DefenseMag: 4},
	// Corps.
	{ID: "veste_cuir", Nom: "Veste de cuir", Emplacement: EmplCorps, Cout: map[string]int{carte.Peau: 8}, Defense: 2, PV: 10},
	{ID: "cuirasse_fer", Nom: "Cuirasse de fer", Emplacement: EmplCorps, Cout: map[string]int{carte.Fer: 10, carte.Peau: 4}, Defense: 5, PV: 10},
	{ID: "armure_pierre_or", Nom: "Armure de pierre et d'or", Emplacement: EmplCorps,
		Cout: map[string]int{carte.Pierre: 12, carte.Or: 6}, Defense: 6, DefenseMag: 3, PV: 20},
	{ID: "armure_diamant", Nom: "Armure de diamant", Emplacement: EmplCorps,
		Cout: map[string]int{carte.Fer: 10, carte.Or: 6, carte.Diamant: 3}, Defense: 8, DefenseMag: 6, PV: 30},
	// Pieds.
	{ID: "sandales_cuir", Nom: "Sandales de cuir", Emplacement: EmplPieds, Cout: map[string]int{carte.Peau: 4}, Manhis: 1},
	{ID: "jambieres_fer", Nom: "Jambières de fer", Emplacement: EmplPieds, Cout: map[string]int{carte.Fer: 6}, Defense: 2},
	{ID: "bottes_pierre", Nom: "Bottes de pierre", Emplacement: EmplPieds, Cout: map[string]int{carte.Pierre: 6, carte.Peau: 2}, Defense: 1, PV: 8},
}

// ObjetsParID indexe les objets.
var ObjetsParID = map[string]*Objet{}

func init() {
	for i := range objetList {
		ObjetsParID[objetList[i].ID] = &objetList[i]
	}
}

// AllObjets renvoie les objets dans l'ordre de la forge.
func AllObjets() []Objet { return objetList }
