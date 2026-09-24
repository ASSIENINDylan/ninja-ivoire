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
const LongueurMax = 7

// Jutsu est le résultat d'une suite de mudras valide.
type Jutsu struct {
	Cle        string   `json:"cle"`
	Nom        string   `json:"nom"`
	Nature     string   `json:"nature"` // nom descriptif : « Lame de Feu dévorante »
	Sequence   []string `json:"sequence"`
	Element    string   `json:"element"`
	Fusion     bool     `json:"fusion"`
	Forme      string   `json:"forme"`
	Effet      string   `json:"effet"`
	Effet2     string   `json:"effet2,omitempty"`
	ModsForme  []string `json:"mods_forme,omitempty"`
	ModsEffet  []string `json:"mods_effet,omitempty"`
	Legendaire string   `json:"legendaire,omitempty"` // identifiant du légendaire

	// Profil de combat (voir profil.go).
	Type         string  `json:"type"`                    // degats, defense, entrave, illusion, soin
	DegatsNature string  `json:"degats_nature,omitempty"` // physique, magique, pur
	Coefs        Coefs   `json:"coefs"`
	Effets       []Effet `json:"effets"`
	Delai        bool    `json:"delai,omitempty"`        // part au tour suivant
	Echo         float64 `json:"echo,omitempty"`         // rejoué au tour suivant (part de la puissance)
	Incassable   bool    `json:"incassable,omitempty"`   // incantation impossible à interrompre
	Indissipable bool    `json:"indissipable,omitempty"` // effets impossibles à dissiper

	Cout    int    `json:"cout"`    // en Souffle
	Soutien bool   `json:"soutien"` // vise le lanceur ou son camp
	Texte   string `json:"texte"`
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

// EstSoutien : le jutsu ne vise que le lanceur ou son camp.
func EstSoutien(j *Jutsu) bool {
	for _, e := range j.Effets {
		if e.Cible != CSoi && e.Cible != CAllies {
			return false
		}
	}
	return true
}

// calculer fixe le profil, le coût, le nom et le texte.
func calculer(j *Jutsu) {
	profiler(j)
	n := len(j.Sequence)
	cout := 5 + 4*float64(n)
	for _, m := range j.ModsForme {
		if m == data.MAmplifier {
			cout *= 1.3
		}
	}
	for _, m := range j.ModsEffet {
		if m == data.MAmplifier {
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
	j.Soutien = EstSoutien(j)
	j.Nom = nommer(j)
	j.Nature = nature(j)
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

// nature donne le nom descriptif d'un jutsu, qui dit ce qu'il fait.
func nature(j *Jutsu) string {
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

// Tables renvoie les tables de la grammaire (puissances, noms, textes),
// pour les exporter vers le moteur local du client.
func Tables() map[string]any {
	noms := map[string]any{}
	for k, v := range nomsFormes {
		noms[k] = map[string]any{"nom": v.nom, "feminin": v.feminin}
	}
	return map[string]any{
		"noms_formes":       noms,
		"adj_effet":         adjEffet,
		"prefixe_mod_forme": prefixeModForme,
		"suffixe_mod_effet": suffixeModEffet,
		"messages_echec":    messagesEchec,
		"noms":              tablesNoms(),
		"max_modificateurs": MaxModificateurs,
		"longueur_max":      LongueurMax,
		"cellules":          Cellules,
		"type_effet":        TypeEffet,
		"nature_effet":      NatureEffet,
		"bases_type":        basesType,
		"inclinaisons":      tablesInclinaisons(),
		"sel_signature":     SelSignature,
		"textes_cible":      textesCible,
		"textes_statut":     TextesStatut,
		"noms_types":        NomsTypes,
		"statuts_controle":  StatutsControle,
		"statuts_drapeau":   StatutsDrapeau,
	}
}

func tablesInclinaisons() map[string]any {
	el := map[string]any{}
	for id := range data.Elements {
		f, g, m := InclinaisonElement(id)
		el[id] = []float64{f, g, m}
	}
	fo := map[string]any{}
	for id, t := range inclinaisonsForme {
		fo[id] = []float64{t.F, t.G, t.M}
	}
	return map[string]any{"elements": el, "formes": fo}
}
