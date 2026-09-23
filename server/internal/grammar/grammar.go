// Package grammar transforme une suite de mudras en jutsu.
//
// Une phrase de mudras suit l'ordre :
//
//	Élément [Élément] → Forme → (Modificateurs de forme) → Effet → (Effet secondaire) → (Modificateurs d'effet)
//
// Deux mudras d'élément enchaînés forment un élément rare (fusion). Un
// modificateur placé après la forme agit sur la forme ; placé après les
// effets, il agit sur les effets. Au plus deux modificateurs par jutsu.
//
// Les jutsus légendaires sont des suites précises, parfois hors grammaire,
// qui ne vivent que sur le serveur (voir legendaires.go).
package grammar

import (
	"strings"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

// MaxModificateurs par jutsu.
const MaxModificateurs = 2

// LongueurMax d'une suite de mudras.
const LongueurMax = 8

// Jutsu est le résultat d'une suite de mudras valide.
type Jutsu struct {
	Cle        string   `json:"cle"`
	Nom        string   `json:"nom"`
	Sequence   []string `json:"sequence"`
	Element    string   `json:"element"`
	Fusion     bool     `json:"fusion"`
	Forme      string   `json:"forme"`
	Effet      string   `json:"effet"`
	Effet2     string   `json:"effet2,omitempty"`
	ModsForme  []string `json:"mods_forme,omitempty"`
	ModsEffet  []string `json:"mods_effet,omitempty"`
	Legendaire string   `json:"legendaire,omitempty"` // identifiant du légendaire
	// Puissance relative de la forme (1 = un trait simple).
	Puissance float64 `json:"puissance"`
	// Intensité relative de l'effet (1 = normale).
	Intensite float64 `json:"intensite"`
	Cout      int     `json:"cout"` // en Souffle
	Soutien   bool    `json:"soutien"`
	Texte     string  `json:"texte"`
}

// Longueur renvoie le nombre de mudras du jutsu.
func (j *Jutsu) Longueur() int { return len(j.Sequence) }

// Echec décrit pourquoi une suite n'a rien donné.
type Echec struct {
	Etape    string `json:"etape"`    // element, fusion, forme, effet, modificateurs, surplus, inconnu
	Position int    `json:"position"` // indice (0-based) du signe fautif
	Valides  int    `json:"valides"`  // nombre de signes acceptés avant l'échec
}

// Cle construit la clé canonique d'une suite de mudras.
func Cle(seq []string) string { return strings.Join(seq, ">") }

// Analyser transforme une suite de mudras en jutsu, ou explique l'échec.
// Les légendaires sont reconnus en premier.
func Analyser(seq []string) (*Jutsu, *Echec) {
	if len(seq) == 0 {
		return nil, &Echec{Etape: "element"}
	}
	if len(seq) > LongueurMax {
		return nil, &Echec{Etape: "surplus", Position: LongueurMax, Valides: LongueurMax}
	}
	for i, id := range seq {
		if data.Mudras[id] == nil {
			return nil, &Echec{Etape: "inconnu", Position: i, Valides: i}
		}
	}
	if l := Legendaires[Cle(seq)]; l != nil {
		return l.Jutsu(), nil
	}

	j := &Jutsu{Sequence: append([]string(nil), seq...), Cle: Cle(seq)}
	i := 0
	cat := func(k int) data.Categorie {
		if k >= len(seq) {
			return ""
		}
		return data.Mudras[seq[k]].Categorie
	}
	ref := func(k int) string { return data.Mudras[seq[k]].Ref }

	// 1. Élément, éventuellement fusionné.
	if cat(i) != data.CatElement {
		return nil, &Echec{Etape: "element", Position: i, Valides: i}
	}
	j.Element = ref(i)
	i++
	if cat(i) == data.CatElement {
		rare := data.FusionOf(j.Element, ref(i))
		if rare == "" || data.Elements[j.Element].Tier != data.TierBase {
			return nil, &Echec{Etape: "fusion", Position: i, Valides: i}
		}
		j.Element, j.Fusion = rare, true
		i++
	}

	// 2. Forme.
	if cat(i) != data.CatForme {
		return nil, &Echec{Etape: "forme", Position: i, Valides: i}
	}
	j.Forme = ref(i)
	i++

	// 3. Modificateurs de forme.
	vus := map[string]bool{}
	for cat(i) == data.CatModificateur {
		if len(vus) >= MaxModificateurs || vus[ref(i)] {
			return nil, &Echec{Etape: "modificateurs", Position: i, Valides: i}
		}
		vus[ref(i)] = true
		j.ModsForme = append(j.ModsForme, ref(i))
		i++
	}

	// 4. Effet principal, puis effet secondaire facultatif.
	if cat(i) != data.CatEffet {
		return nil, &Echec{Etape: "effet", Position: i, Valides: i}
	}
	j.Effet = ref(i)
	i++
	if cat(i) == data.CatEffet {
		if ref(i) == j.Effet {
			return nil, &Echec{Etape: "effet", Position: i, Valides: i}
		}
		j.Effet2 = ref(i)
		i++
	}

	// 5. Modificateurs d'effet.
	for cat(i) == data.CatModificateur {
		if len(vus) >= MaxModificateurs || vus[ref(i)] {
			return nil, &Echec{Etape: "modificateurs", Position: i, Valides: i}
		}
		vus[ref(i)] = true
		j.ModsEffet = append(j.ModsEffet, ref(i))
		i++
	}

	if i != len(seq) {
		return nil, &Echec{Etape: "surplus", Position: i, Valides: i}
	}

	calculer(j)
	return j, nil
}

// Puissance de base de chaque forme.
var puissanceForme = map[string]float64{
	data.FTrait:      1.0,
	data.FLame:       1.4,
	data.FMur:        1.2,
	data.FCercle:     0.6,
	data.FDouble:     0.5,
	data.FLien:       0.5,
	data.FArmure:     1.0,
	data.FPiege:      1.3,
	data.FInvocation: 0.45,
	data.FPas:        0.5,
}

// EffetSoutien : effets qui visent les alliés.
func EffetSoutien(e string) bool {
	return e == data.XSoigner || e == data.XRenforcer || e == data.XDissimuler
}

// FormeDefensive : formes qui protègent le lanceur ou son camp.
func FormeDefensive(f string) bool {
	return f == data.FMur || f == data.FArmure || f == data.FDouble || f == data.FPas
}

func facteurTier(element string) float64 {
	switch data.Elements[element].Tier {
	case data.TierRare:
		return 1.35
	case data.TierMythique:
		return 1.7
	}
	return 1
}

// calculer fixe la puissance, l'intensité, le coût, le nom et le texte.
func calculer(j *Jutsu) {
	n := len(j.Sequence)
	// Plus la suite est longue, plus le jutsu est puissant.
	j.Puissance = puissanceForme[j.Forme] * (1 + 0.15*float64(n-3)) * facteurTier(j.Element)
	j.Intensite = 1
	cout := 5 + 4*float64(n)
	for _, m := range j.ModsForme {
		if m == data.MAmplifier {
			j.Puissance *= 1.4
			cout *= 1.3
		}
	}
	for _, m := range j.ModsEffet {
		if m == data.MAmplifier {
			j.Intensite *= 1.5
			cout *= 1.2
		}
	}
	switch data.Elements[j.Element].Tier {
	case data.TierRare:
		cout *= 1.5
	case data.TierMythique:
		cout *= 2
	}
	j.Cout = int(cout + 0.5)
	j.Soutien = EffetSoutien(j.Effet)
	j.Nom = nommer(j)
	j.Texte = decrire(j)
}

// --- Nommage -------------------------------------------------------------

type nomForme struct {
	nom     string
	feminin bool
}

var nomsFormes = map[string]nomForme{
	data.FTrait:      {"Trait", false},
	data.FLame:       {"Lame", true},
	data.FMur:        {"Mur", false},
	data.FCercle:     {"Cercle", false},
	data.FDouble:     {"Double", false},
	data.FLien:       {"Lien", false},
	data.FArmure:     {"Armure", true},
	data.FPiege:      {"Piège", false},
	data.FInvocation: {"Invocation", true},
	data.FPas:        {"Pas", false},
}

var adjEffet = map[string][2]string{
	data.XConsumer:   {"dévorant", "dévorante"},
	data.XLier:       {"entravant", "entravante"},
	data.XSoigner:    {"guérisseur", "guérisseuse"},
	data.XAveugler:   {"aveuglant", "aveuglante"},
	data.XRepousser:  {"déferlant", "déferlante"},
	data.XDrainer:    {"vampire", "vampire"},
	data.XBriser:     {"brisant", "brisante"},
	data.XDissimuler: {"voilé", "voilée"},
	data.XRenforcer:  {"fortifiant", "fortifiante"},
	data.XMarquer:    {"marqueur", "marqueuse"},
}

var prefixeModForme = map[string][2]string{
	data.MAmplifier:   {"Grand", "Grande"},
	data.MEtendre:     {"Vaste", "Vaste"},
	data.MMultiplier:  {"Triple", "Triple"},
	data.MRetarder:    {"Patient", "Patiente"},
	data.MSilence:     {"Muet", "Muette"},
	data.MPersistance: {"Éternel", "Éternelle"},
}

var suffixeModEffet = map[string][2]string{
	data.MAmplifier:   {"au paroxysme", "au paroxysme"},
	data.MEtendre:     {"sans fin", "sans fin"},
	data.MMultiplier:  {"contagieux", "contagieuse"},
	data.MRetarder:    {"à retardement", "à retardement"},
	data.MSilence:     {"invisible", "invisible"},
	data.MPersistance: {"tenace", "tenace"},
}

func genre(f bool) int {
	if f {
		return 1
	}
	return 0
}

func nommer(j *Jutsu) string {
	nf := nomsFormes[j.Forme]
	g := genre(nf.feminin)
	var parts []string
	for _, m := range j.ModsForme {
		parts = append(parts, prefixeModForme[m][g])
	}
	parts = append(parts, nf.nom, data.Elements[j.Element].De, adjEffet[j.Effet][g])
	if j.Effet2 != "" {
		parts = append(parts, "et", adjEffet[j.Effet2][g])
	}
	for _, m := range j.ModsEffet {
		parts = append(parts, suffixeModEffet[m][g])
	}
	return strings.Join(parts, " ")
}

// --- Description ---------------------------------------------------------

var texteForme = map[string]string{
	data.FTrait:      "Un projectile qui frappe une cible à n'importe quel rang.",
	data.FLame:       "Une lame de Souffle qui frappe fort au corps à corps (rangs 1 et 2).",
	data.FMur:        "Un mur qui protège tout le camp et absorbe les coups.",
	data.FCercle:     "Une onde qui touche tous les adversaires, plus faiblement.",
	data.FDouble:     "Un double qui détourne la prochaine attaque.",
	data.FLien:       "Un lien qui touche peu mais renforce l'effet.",
	data.FArmure:     "Une armure qui absorbe les coups portés au lanceur.",
	data.FPiege:      "Un piège qui se déclenche quand la cible agit.",
	data.FInvocation: "Une créature de Souffle qui attaque pendant trois tours.",
	data.FPas:        "Un déplacement éclair : le lanceur change de rang et esquive.",
}

var texteEffet = map[string]string{
	data.XConsumer:   "consume la cible pendant 3 tours",
	data.XLier:       "entrave la cible (lente, ne peut ni frapper au contact ni bouger)",
	data.XSoigner:    "soigne un allié",
	data.XAveugler:   "aveugle la cible (40 % de chances de rater)",
	data.XRepousser:  "repousse la cible d'un rang et brise son incantation",
	data.XDrainer:    "rend au lanceur une partie des dégâts et du Souffle",
	data.XBriser:     "brise les défenses et l'incantation de la cible",
	data.XDissimuler: "rend un allié insaisissable (esquive, actions cachées)",
	data.XRenforcer:  "renforce les dégâts d'un allié",
	data.XMarquer:    "marque la cible, qui subit plus de dégâts",
}

var texteModificateur = map[string][2]string{
	data.MAmplifier:   {"forme amplifiée", "effet amplifié"},
	data.MEtendre:     {"atteint une cible voisine", "effet prolongé de 2 tours"},
	data.MMultiplier:  {"frappe deux fois", "effet propagé à une autre cible"},
	data.MRetarder:    {"frappe au tour suivant, plus fort", "effet retardé mais doublé"},
	data.MSilence:     {"incantation impossible à interrompre", "effet impossible à purifier"},
	data.MPersistance: {"la forme persiste un tour de plus", "effet deux fois plus long"},
}

func decrire(j *Jutsu) string {
	s := texteForme[j.Forme] + " Effet : " + texteEffet[j.Effet]
	if j.Effet2 != "" {
		s += ", puis " + texteEffet[j.Effet2] + " (atténué)"
	}
	s += "."
	var mods []string
	for _, m := range j.ModsForme {
		mods = append(mods, texteModificateur[m][0])
	}
	for _, m := range j.ModsEffet {
		mods = append(mods, texteModificateur[m][1])
	}
	if len(mods) > 0 {
		s += " Modificateurs : " + strings.Join(mods, ", ") + "."
	}
	return s
}
