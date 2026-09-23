// Package combat implémente le combat au tour par tour simultané :
// chaque camp choisit ses actions en secret, puis le tour se résout dans
// l'ordre d'initiative. Trois rangs par camp, à la Darkest Dungeon.
package combat

import (
	"math/rand"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// Types d'action.
const (
	AFrapper    = "frapper"
	AGarde      = "garde"
	ADeplacer   = "deplacer"
	AIncanter   = "incanter"
	AConcentrer = "concentrer"
)

// Types de statut.
const (
	SConsume    = "consume"
	SEntrave    = "entrave"
	SAveugle    = "aveugle"
	SAffaibli   = "affaibli"
	SVoile      = "voile"
	SRenfort    = "renfort"
	SMarque     = "marque"
	SRegen      = "regen"
	SPiege      = "piege"
	SInvocation = "invocation"
	SEcho       = "echo"
	SRiposte    = "riposte"
	SLeurre     = "leurre"
)

// NbRangs par camp.
const NbRangs = 3

// Arme d'un combattant.
type Arme struct {
	Nom       string `json:"nom"`
	Puissance int    `json:"puissance"`
	Distance  bool   `json:"distance"`
}

// Statut est un effet durable sur un combattant.
type Statut struct {
	Type    string         `json:"type"`
	Tours   int            `json:"tours"`
	Valeur  float64        `json:"valeur"`
	Element string         `json:"element,omitempty"`
	Effet   string         `json:"-"` // effet porté (piège, invocation)
	Source  string         `json:"-"` // identifiant du lanceur
	Silence bool           `json:"-"` // impossible à purifier
	Jutsu   *grammar.Jutsu `json:"-"`
	Base    float64        `json:"-"`
	CibleID string         `json:"-"`
}

// Incantation en cours : les mudras se forment sur plusieurs tours.
type Incantation struct {
	Sequence []string       `json:"sequence,omitempty"` // visible par son propre camp seulement
	Jutsu    *grammar.Jutsu `json:"-"`
	Echec    *grammar.Echec `json:"-"`
	Refus    string         `json:"-"` // conditions de légendaire non remplies
	Cible    string         `json:"cible,omitempty"`
	Progres  int            `json:"progres"`
	Total    int            `json:"total"`
	Silence  bool           `json:"silence"`
}

// Combattant : ninja joueur, PNJ ou créature.
type Combattant struct {
	ID          string       `json:"id"`
	Nom         string       `json:"nom"`
	Camp        int          `json:"camp"`
	Rang        int          `json:"rang"`
	Joueur      bool         `json:"joueur"`
	Apparence   string       `json:"apparence"`
	Niveau      int          `json:"niveau"`
	Fangan      int          `json:"fangan"`
	Gnanga      int          `json:"gnanga"`
	Manhis      int          `json:"manhis"`
	PV          int          `json:"pv"`
	PVMax       int          `json:"pv_max"`
	Souffle     int          `json:"souffle"`
	SouffleMax  int          `json:"souffle_max"`
	Element     string       `json:"element"`
	Elements    []string     `json:"elements"`
	Arme        Arme         `json:"arme"`
	Defense     int          `json:"defense"`
	Absorption  int          `json:"absorption"`
	Garde       bool         `json:"garde"`
	Statuts     []*Statut    `json:"statuts"`
	Incantation *Incantation `json:"incantation,omitempty"`

	// Connaissances (non envoyées au client).
	Jutsus   []*grammar.Jutsu  `json:"-"` // jutsus connus (pour l'IA)
	Maitrise map[string]int    `json:"-"` // clé de jutsu → maîtrise (0 à 100)
	Permis   map[string]bool   `json:"-"` // mudras que ce combattant sait former
	Contexte *grammar.Contexte `json:"-"` // pour les conditions des légendaires
	IA       string            `json:"-"` // profil d'IA ("" pour un joueur)
	Precis   bool              `json:"-"` // résonance précise (village traditionnel)
}

// Vivant indique si le combattant est encore debout.
func (f *Combattant) Vivant() bool { return f.PV > 0 }

// MudrasParTour : nombre de signes formés par tour, selon la technique.
func (f *Combattant) MudrasParTour() int { return 3 + f.Gnanga/15 }

func (f *Combattant) statut(t string) *Statut {
	for _, s := range f.Statuts {
		if s.Type == t && s.Tours > 0 {
			return s
		}
	}
	return nil
}

// Mur protège tout un camp.
type Mur struct {
	Absorption int     `json:"absorption"`
	Tours      int     `json:"tours"`
	Element    string  `json:"element"`
	Riposte    string  `json:"-"`
	Intensite  float64 `json:"-"`
	Base       float64 `json:"-"`
	Lanceur    string  `json:"-"`
}

// Action choisie pour un tour.
type Action struct {
	Acteur   string   `json:"acteur"`
	Type     string   `json:"type"`
	Cible    string   `json:"cible,omitempty"`
	Rang     int      `json:"rang,omitempty"`
	Sequence []string `json:"sequence,omitempty"`
}

// Evenement raconte ce qui s'est passé, pour le journal et les animations.
type Evenement struct {
	Type    string `json:"type"`
	Acteur  string `json:"acteur,omitempty"`
	Cible   string `json:"cible,omitempty"`
	Valeur  int    `json:"valeur,omitempty"`
	Element string `json:"element,omitempty"`
	Jutsu   string `json:"jutsu,omitempty"`
	Texte   string `json:"texte"`
}

// Decouverte d'un jutsu par un joueur pendant le combat.
type Decouverte struct {
	Joueur string         `json:"joueur"`
	Jutsu  *grammar.Jutsu `json:"jutsu"`
}

// Combat en cours.
type Combat struct {
	ID          string              `json:"id"`
	Tour        int                 `json:"tour"`
	Combattants []*Combattant       `json:"combattants"`
	Murs        [2]*Mur             `json:"murs"`
	Fini        bool                `json:"fini"`
	Vainqueur   int                 `json:"vainqueur"` // -1 tant que le combat dure
	Decouvertes []Decouverte        `json:"-"`
	Usages      map[string]int      `json:"-"` // clé de jutsu → lancers réussis du joueur
	Resonances  []grammar.Resonance `json:"-"`

	rng    *rand.Rand
	moment func() time.Time
	evts   []Evenement
	// Jutsus retardés et échos qui tombent en fin de tour.
	differes []differe
}

type differe struct {
	lanceur *Combattant
	jutsu   *grammar.Jutsu
	cible   string
	facteur float64
	tours   int
}
