package grammar

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

// Ce fichier est SECRET : il ne doit jamais être envoyé au client.

// Conditions cachées d'un jutsu légendaire.
type Conditions struct {
	NiveauMin  int      `json:"-"`
	Nuit       bool     `json:"-"`
	Jour       bool     `json:"-"`
	PleineLune bool     `json:"-"`
	Elements   []string `json:"-"`
}

// Contexte du lanceur au moment de l'essai.
type Contexte struct {
	Niveau   int
	Elements []string
	Moment   time.Time
}

// Verifier renvoie la raison du refus (vague, pour garder le mystère),
// ou "" si les conditions sont remplies.
func (c Conditions) Verifier(ctx Contexte) string {
	if ctx.Niveau < c.NiveauMin {
		return "Un pouvoir immense frémit… mais votre Souffle n'est pas encore assez mûr."
	}
	for _, e := range c.Elements {
		found := false
		for _, k := range ctx.Elements {
			if k == e {
				found = true
			}
		}
		if !found {
			return "Un pouvoir immense frémit… mais il réclame un élément que vous ne maîtrisez pas."
		}
	}
	if c.Nuit && !data.EstNuit(ctx.Moment) {
		return "Un pouvoir immense frémit… puis s'endort. Il semble attendre l'obscurité."
	}
	if c.Jour && data.EstNuit(ctx.Moment) {
		return "Un pouvoir immense frémit… mais la nuit l'étouffe. Il attend le jour."
	}
	if c.PleineLune && data.NomPhase(ctx.Moment) != "Pleine lune" {
		return "Un pouvoir immense frémit… Il attend que la lune soit entière."
	}
	return ""
}

// Legendaire est un jutsu conçu à la main.
type Legendaire struct {
	ID         string
	Nom        string
	Sequence   []string
	Element    string
	Fusion     bool
	Forme      string
	Effet      string
	Effet2     string
	ModsForme  []string
	ModsEffet  []string
	Puissance  float64
	Intensite  float64
	Cout       int
	Texte      string
	Conditions Conditions
}

// Jutsu construit le jutsu correspondant au légendaire.
func (l *Legendaire) Jutsu() *Jutsu {
	return &Jutsu{
		Cle:        Cle(l.Sequence),
		Nom:        l.Nom,
		Sequence:   append([]string(nil), l.Sequence...),
		Element:    l.Element,
		Fusion:     l.Fusion,
		Forme:      l.Forme,
		Effet:      l.Effet,
		Effet2:     l.Effet2,
		ModsForme:  l.ModsForme,
		ModsEffet:  l.ModsEffet,
		Legendaire: l.ID,
		Puissance:  l.Puissance,
		Intensite:  l.Intensite,
		Cout:       l.Cout,
		Soutien:    EffetSoutien(l.Effet),
		Texte:      l.Texte,
	}
}

var legendaireList = []Legendaire{
	{ID: "colere_panthere", Nom: "Colère de la Panthère",
		Sequence: []string{"panthere", "panthere", "mante", "lion", "braise"},
		Element:  "feu", Forme: data.FLame, Effet: data.XConsumer, ModsForme: []string{data.MAmplifier},
		Puissance: 4.2, Intensite: 2, Cout: 40,
		Texte:      "Le Souffle de Feu prend la forme d'une panthère qui déchire la cible et la consume longuement.",
		Conditions: Conditions{NiveauMin: 8}},
	{ID: "chant_lamantin", Nom: "Chant du Lamantin",
		Sequence: []string{"lamantin", "lamantin", "case", "kola", "fleuve"},
		Element:  "eau", Forme: data.FCercle, Effet: data.XSoigner, ModsEffet: []string{data.MEtendre},
		Puissance: 2.6, Intensite: 2, Cout: 38,
		Texte:      "Un chant venu des lagunes soigne tous les alliés et les régénère plusieurs tours. Il ne s'élève que la nuit.",
		Conditions: Conditions{NiveauMin: 10, Nuit: true}},
	{ID: "tonnerre_man", Nom: "Tonnerre de la Dent de Man",
		Sequence: []string{"aigle", "aigle", "martin_pecheur", "hache", "lion"},
		Element:  "foudre", Forme: data.FTrait, Effet: data.XBriser, ModsEffet: []string{data.MAmplifier},
		Puissance: 3.6, Intensite: 2.2, Cout: 42,
		Texte:      "La foudre tombe du sommet de la Dent de Man et pulvérise les défenses de la cible.",
		Conditions: Conditions{NiveauMin: 12}},
	{ID: "racines_fromager", Nom: "Racines du Fromager",
		Sequence: []string{"chimpanze", "chimpanze", "araignee", "liane", "braise"},
		Element:  "vegetal", Forme: data.FLien, Effet: data.XLier, Effet2: data.XConsumer,
		Puissance: 2.2, Intensite: 2.5, Cout: 36,
		Texte:      "Les racines du grand fromager enserrent la cible, l'immobilisent et l'épuisent.",
		Conditions: Conditions{NiveauMin: 10}},
	{ID: "danse_calao", Nom: "Danse du Calao",
		Sequence: []string{"calao", "calao", "martin_pecheur", "fourmi", "belier"},
		Element:  "vent", Forme: data.FTrait, Effet: data.XRepousser, ModsForme: []string{data.MMultiplier},
		Puissance: 3.0, Intensite: 1.8, Cout: 38,
		Texte:      "Une nuée de rafales en forme de calaos frappe deux fois et balaie les rangs adverses.",
		Conditions: Conditions{NiveauMin: 12}},
	{ID: "rempart_argile", Nom: "Rempart des Mosquées d'argile",
		Sequence: []string{"buffle", "buffle", "tortue", "lion", "kola"},
		Element:  "terre", Forme: data.FMur, Effet: data.XSoigner, ModsForme: []string{data.MAmplifier},
		Puissance: 3.4, Intensite: 1.6, Cout: 40,
		Texte:      "Un rempart d'argile hérissé de pieux protège tout le camp et soigne ceux qui s'y abritent.",
		Conditions: Conditions{NiveauMin: 8}},
	{ID: "harmattan_anciens", Nom: "Harmattan des Anciens",
		Sequence: []string{"scorpion", "calao", "case", "voile", "belier", "fleuve"},
		Element:  "harmattan", Fusion: true, Forme: data.FCercle, Effet: data.XAveugler, Effet2: data.XRepousser, ModsEffet: []string{data.MEtendre},
		Puissance: 3.2, Intensite: 2.4, Cout: 70,
		Texte:      "Le vent sec du Nord se lève, aveugle et disperse toute l'armée adverse.",
		Conditions: Conditions{NiveauMin: 60, Jour: true}},
	{ID: "souffle_ivoire", Nom: "Souffle d'Ivoire",
		Sequence: []string{"elephant", "elephant", "case", "kola", "racine", "baobab"},
		Element:  "ivoire", Forme: data.FCercle, Effet: data.XSoigner, Effet2: data.XRenforcer, ModsEffet: []string{data.MPersistance},
		Puissance: 6, Intensite: 3, Cout: 120,
		Texte:      "Le Souffle originel, blanc et pur, relève tous les alliés et décuple leur force.",
		Conditions: Conditions{NiveauMin: 100, PleineLune: true, Elements: []string{"ivoire"}}},
}

// Legendaires indexe les légendaires par clé de suite de mudras.
var Legendaires = map[string]*Legendaire{}

// LegendairesParID indexe les légendaires par identifiant.
var LegendairesParID = map[string]*Legendaire{}

func init() {
	for i := range legendaireList {
		l := &legendaireList[i]
		Legendaires[Cle(l.Sequence)] = l
		LegendairesParID[l.ID] = l
	}
}

// NombreLegendaires renvoie le nombre de légendaires existants.
func NombreLegendaires() int { return len(legendaireList) }

// --- Résonance -------------------------------------------------------------

// Resonance est la réaction du Souffle à un essai raté.
type Resonance struct {
	Score           int    `json:"score"` // 0 à 100
	Message         string `json:"message"`
	Indice          string `json:"indice,omitempty"`
	Ancienne        bool   `json:"ancienne"` // proche d'un légendaire
	RetourDeSouffle bool   `json:"retour_de_souffle"`
}

var messagesEchec = map[string]string{
	"element":       "Le Souffle reste incolore : il lui manque un élément pour naître.",
	"fusion":        "Deux éléments s'entrechoquent sans se mêler.",
	"forme":         "Le Souffle prend une couleur, mais aucune forme.",
	"effet":         "Une forme se dessine… puis se dissipe, faute de but.",
	"modificateurs": "Trop de signes de maîtrise étouffent le jutsu.",
	"surplus":       "Le jutsu était presque né : des signes en trop l'ont brisé.",
	"inconnu":       "Ce signe n'existe pas.",
}

// Resonner calcule la réaction du Souffle à une suite ratée. `precise`
// donne un indice supplémentaire (villages traditionnels).
func Resonner(seq []string, e *Echec, precise bool) Resonance {
	r := Resonance{Message: messagesEchec[e.Etape]}

	// Progression dans la grammaire : 3 signes suffisent pour un jutsu.
	structure := float64(e.Valides) / 3
	if structure > 1 {
		structure = 1
	}
	score := 60 * structure

	// Proximité avec un légendaire : préfixe commun le plus long.
	meilleur := 0.0
	for _, l := range legendaireList {
		p := prefixeCommun(seq, l.Sequence)
		if p >= 2 {
			ratio := float64(p) / float64(len(l.Sequence))
			if ratio > meilleur {
				meilleur = ratio
			}
		}
	}
	if meilleur > 0 {
		r.Ancienne = true
		if s := 45 + 55*meilleur; s > score {
			score = s
		}
		r.Message = "Une vibration ancienne parcourt vos mains. " + r.Message
	}
	r.Score = int(score + 0.5)
	if r.Score < 25 && len(seq) >= 4 {
		r.RetourDeSouffle = true
		r.Message += " Le Souffle se retourne contre vous !"
	}
	if precise && r.Ancienne {
		r.Indice = "Les anciens murmurent que cette voie est rare : peu de ninjas l'ont suivie jusqu'au bout."
	} else if precise && e.Position < len(seq) {
		if m := data.Mudras[seq[e.Position]]; m != nil {
			r.Indice = fmt.Sprintf("Les anciens sentent que le signe n°%d (%s) trouble le Souffle.", e.Position+1, m.Nom)
		}
	} else if precise && e.Etape != "surplus" {
		r.Indice = "Les anciens sentent qu'il manque un signe à la fin."
	}
	return r
}

func prefixeCommun(a, b []string) int {
	n := 0
	for n < len(a) && n < len(b) && a[n] == b[n] {
		n++
	}
	return n
}

// Resume donne une ligne lisible d'une suite de mudras (pour les journaux).
func Resume(seq []string) string {
	noms := make([]string, len(seq))
	for i, id := range seq {
		if m := data.Mudras[id]; m != nil {
			noms[i] = m.Nom
		} else {
			noms[i] = "?"
		}
	}
	return strings.Join(noms, " · ")
}

// SelHachage préfixe les suites avant hachage : les recettes légendaires
// voyagent vers le client sous forme d'empreintes, jamais en clair.
const SelHachage = "ninja-ivoire:"

// Empreinte renvoie l'empreinte SHA-256 (hexadécimale) d'une clé de suite.
func Empreinte(cle string) string {
	h := sha256.Sum256([]byte(SelHachage + cle))
	return hex.EncodeToString(h[:])
}

// LegendairesHaches exporte les légendaires indexés par l'empreinte de
// leur suite, et les préfixes (au moins deux signes) avec leur proximité.
func LegendairesHaches() (map[string]any, map[string]float64) {
	legs := map[string]any{}
	prefixes := map[string]float64{}
	for _, l := range legendaireList {
		legs[Empreinte(Cle(l.Sequence))] = map[string]any{
			"id": l.ID, "nom": l.Nom, "longueur": len(l.Sequence),
			"element": l.Element, "fusion": l.Fusion, "forme": l.Forme,
			"effet": l.Effet, "effet2": l.Effet2,
			"mods_forme": nonNul(l.ModsForme), "mods_effet": nonNul(l.ModsEffet),
			"puissance": l.Puissance, "intensite": l.Intensite, "cout": l.Cout, "texte": l.Texte,
			"conditions": map[string]any{
				"niveau_min": l.Conditions.NiveauMin, "nuit": l.Conditions.Nuit, "jour": l.Conditions.Jour,
				"pleine_lune": l.Conditions.PleineLune, "elements": nonNul(l.Conditions.Elements),
			},
		}
		for k := 2; k <= len(l.Sequence); k++ {
			h := Empreinte(Cle(l.Sequence[:k]))
			if r := float64(k) / float64(len(l.Sequence)); r > prefixes[h] {
				prefixes[h] = r
			}
		}
	}
	return legs, prefixes
}

func nonNul(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
