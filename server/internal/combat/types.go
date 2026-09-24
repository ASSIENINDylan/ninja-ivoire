// Package combat implémente le combat au tour par tour simultané :
// chaque camp choisit ses actions en secret, puis le tour se résout dans
// l'ordre d'initiative. Trois rangs par camp, à la Darkest Dungeon.
//
// Les jutsus sont décrits par des effets élémentaires (voir
// grammar/profil.go) que le moteur interprète : dégâts physiques, magiques
// ou purs, défenses, entraves, illusions et soins.
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

// Statuts propres au moteur (les autres viennent des jutsus).
const (
	SConsume     = "consume"     // brûlure : dégâts par tour
	SPiege       = "piege"       // piège posé sur un adversaire
	SRiposte     = "riposte"     // charge contre qui attaque
	SInvocation  = "invocation"  // créature de Souffle
	SDeclencheur = "declencheur" // charge quand le lanceur faiblit
)

// NbRangs par camp ; les clones peuvent porter un camp à RangsMax.
const (
	NbRangs  = 3
	RangsMax = 4
)

// Bienfaits : statuts qu'une dissipation peut retirer.
var Bienfaits = map[string]bool{
	"def_phys": true, "def_mag": true, "renvoi": true, "parade": true, "esquive": true,
	"reflet": true, "deviation": true, "intangible_phys": true, "intangible_mag": true,
	"invisible": true, "disparu": true, "leurre": true, "regen": true, "baume": true,
	"second_souffle": true, SRiposte: true, SInvocation: true, SDeclencheur: true,
}

// Maux : statuts qu'une purification peut retirer.
var Maux = map[string]bool{
	SConsume: true, "sangsue": true, "immobilise": true, "retenu": true, "desarme": true,
	"scelle": true, "sans_garde": true, "confus": true, "endormi": true, "aveugle": true,
	"egare": true, "marque": true, SPiege: true,
}

// Arme d'un combattant.
type Arme struct {
	Nom       string `json:"nom"`
	Puissance int    `json:"puissance"`
	Distance  bool   `json:"distance"`
}

// Statut est un effet durable sur un combattant.
type Statut struct {
	Type         string          `json:"type"`
	Tours        int             `json:"tours"`
	Valeur       float64         `json:"valeur"`
	Element      string          `json:"element,omitempty"`
	Nature       string          `json:"-"`
	Source       string          `json:"-"` // identifiant du lanceur
	Puissance    float64         `json:"-"` // puissance du jutsu d'origine
	Indissipable bool            `json:"-"`
	Effets       []grammar.Effet `json:"-"` // charge (piège, riposte, invocation…)
	nouveau      bool            // posé ce tour-ci : ne s'use pas avant le tour suivant
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

// Combattant : ninja joueur, PNJ, créature ou clone.
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
	Defense     int          `json:"defense"`     // armure (dégâts physiques)
	DefenseMag  int          `json:"defense_mag"` // garde du Souffle (dégâts magiques)
	Absorption  int          `json:"absorption"`  // bouclier : PV temporaires
	Garde       bool         `json:"garde"`
	Statuts     []*Statut    `json:"statuts"`
	Incantation *Incantation `json:"incantation,omitempty"`
	Clone       bool         `json:"clone,omitempty"` // visible par son propre camp seulement
	Original    string       `json:"-"`
	ToursClone  int          `json:"-"`

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

// A indique si le combattant porte un statut actif.
func (f *Combattant) A(t string) bool { return f.statut(t) != nil }

func (f *Combattant) statut(t string) *Statut {
	for _, s := range f.Statuts {
		if s.Type == t && s.Tours > 0 {
			return s
		}
	}
	return nil
}

// Baume : les soins qui s'appliqueront à la fin du combat.
func (f *Combattant) Baume() int {
	total := 0.0
	for _, s := range f.Statuts {
		if s.Type == "baume" && s.Tours > 0 {
			total += s.Valeur
		}
	}
	return int(total + 0.5)
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
	Fini        bool                `json:"fini"`
	Vainqueur   int                 `json:"vainqueur"` // -1 tant que le combat dure
	Decouvertes []Decouverte        `json:"-"`
	Usages      map[string]int      `json:"-"` // clé de jutsu → lancers réussis du joueur
	Resonances  []grammar.Resonance `json:"-"`

	rng    *rand.Rand
	moment func() time.Time
	evts   []Evenement
	// Jutsus retardés, échos et effets différés qui tombent en fin de tour.
	differes []differe
}

type differe struct {
	jutsu   *grammar.Jutsu  // jutsu entier (retard, écho)…
	effets  []grammar.Effet // … ou seulement des effets
	cx      contexte
	facteur float64
	tours   int
}
