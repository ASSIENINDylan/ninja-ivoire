package combat

import (
	"math"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// Profils d'IA.
const (
	IABete  = "bete"  // ne fait que frapper et avancer
	IANinja = "ninja" // utilise tout son arsenal
	IAClone = "clone" // un clone imite son original : il frappe
)

type option struct {
	action Action
	score  float64
}

// choisirIA évalue chaque action possible et garde la meilleure. L'IA lit
// la situation : elle soigne ses blessures, entrave qui menace, scelle les
// longues incantations et profite des faiblesses élémentaires.
func (c *Combat) choisirIA(f *Combattant) Action {
	if f.Incantation != nil && !f.A("scelle") {
		return Action{Acteur: f.ID, Type: AIncanter}
	}
	var opts []option
	ajouter := func(a Action, s float64) {
		a.Acteur = f.ID
		opts = append(opts, option{a, s * (0.9 + c.rng.Float64()*0.2)})
	}
	ennemis := c.ennemis(f)
	menace := c.menaceIncantation(ennemis)

	// Frapper.
	if !f.A("desarme") && (f.Arme.Distance || f.Rang <= 2) {
		for _, t := range ennemis {
			if !ciblable(t) || (!f.Arme.Distance && t.Rang > 2) {
				continue
			}
			est := float64(f.Arme.Puissance+f.Fangan) * facteurDefense(t, grammar.NPhysique)
			ajouter(Action{Type: AFrapper, Cible: t.ID}, c.valeurDegats(t, est, 1))
		}
	}

	// Jutsus.
	if f.IA == IANinja && !f.A("scelle") {
		mpt := f.MudrasParTour()
		for _, j := range f.Jutsus {
			if CoutReel(j, f.maitriseDe(j)) > f.Souffle {
				continue
			}
			tours := float64((j.Longueur() + mpt - 1) / mpt)
			p := c.puissance(f, j, 1)
			cibles := []*Combattant{nil}
			if !j.Soutien {
				cibles = nil
				for _, t := range ennemis {
					if ciblable(t) {
						cibles = append(cibles, t)
					}
				}
			}
			for _, t := range cibles {
				v := 0.0
				for _, e := range j.Effets {
					v += c.valeurEffet(f, e, t, p, tours)
				}
				if j.Delai {
					v *= 0.8
				}
				id := ""
				if t != nil {
					id = t.ID
				}
				ajouter(Action{Type: AIncanter, Sequence: j.Sequence, Cible: id}, v/tours)
			}
		}
	}

	// Garde, concentration, déplacement.
	garde := 2.0
	if f.PV*10 < f.PVMax*3 && menace > 0 {
		garde = 10 + menace
	}
	if !f.A("sans_garde") {
		ajouter(Action{Type: AGarde}, garde)
	}
	if f.IA == IANinja && f.Souffle*3 < f.SouffleMax {
		ajouter(Action{Type: AConcentrer}, 6)
	}
	if !f.Arme.Distance && f.Rang > 2 && !f.A("immobilise") {
		ajouter(Action{Type: ADeplacer, Rang: 1}, 8)
	}
	if len(opts) == 0 {
		return Action{Acteur: f.ID, Type: AGarde}
	}
	best := opts[0]
	for _, o := range opts[1:] {
		if o.score > best.score {
			best = o
		}
	}
	return best.action
}

// valeurDegats : les dégâts valent plus s'ils achèvent la cible ou
// s'ils brisent une incantation.
func (c *Combat) valeurDegats(t *Combattant, est, tours float64) float64 {
	v := est
	if float64(t.PV) <= est {
		v *= 2
	}
	if inc := t.Incantation; inc != nil && !inc.Silence && est*100 >= float64(t.PVMax*12) && tours <= 1 {
		v += 10 * float64(inc.Total)
	}
	return v
}

// menaceIncantation mesure le danger des incantations adverses en cours.
func (c *Combat) menaceIncantation(ennemis []*Combattant) float64 {
	m := 0.0
	for _, e := range ennemis {
		if e.Incantation != nil {
			m += 4 * float64(e.Incantation.Total)
		}
	}
	return m
}

func manque(f *Combattant) float64 { return float64(f.PVMax - f.PV) }

// valeurEffet estime ce que rapporte un effet (en « PV équivalents »).
func (c *Combat) valeurEffet(f *Combattant, e grammar.Effet, t *Combattant, p, tours float64) float64 {
	ennemis := c.ennemis(f)
	nbCibles := 1.0
	switch e.Cible {
	case grammar.CEnnemis:
		nbCibles = float64(len(ennemis))
	case grammar.CEnnemiEtendu, grammar.CContactEtendu:
		nbCibles = 1.5
	case grammar.CAllies:
		nbCibles = float64(len(c.Reels(f.Camp)))
	}
	if t == nil && len(ennemis) > 0 {
		t = ennemis[0]
	}
	if (e.Cible == grammar.CContact || e.Cible == grammar.CContactEtendu) && (f.Rang > 2 || (t != nil && t.Rang > 2)) {
		return 0
	}
	danger := 1.0
	if f.PV*2 < f.PVMax {
		danger = 2
	}
	switch e.Op {
	case grammar.OpDegats, grammar.OpDrain:
		if t == nil {
			return 0
		}
		est := p * e.Mult * float64(max(1, e.Frappes)) * facteurDefense(t, e.Nature)
		if e.Nature != grammar.NPur {
			est *= data.Multiplier(f.Element, t.Element)
		}
		v := c.valeurDegats(t, est, tours) * nbCibles
		if e.Op == grammar.OpDrain {
			v += math.Min(est*e.Valeur, manque(f)) * danger * 0.6
		}
		return v
	case grammar.OpDot:
		return p * e.Mult * float64(e.Duree) * 0.7 * nbCibles
	case grammar.OpSoin:
		if f.PV*10 > f.PVMax*7 {
			return 0
		}
		return math.Min(p*e.Mult, manque(f)) * danger
	case grammar.OpBouclier:
		if f.Absorption > 0 {
			return 0
		}
		return p * e.Mult * 0.5 * nbCibles * danger
	case grammar.OpStatut:
		return c.valeurStatut(f, e, t, p) * nbCibles
	case grammar.OpDeplacer:
		return 4
	case grammar.OpBond:
		return 1
	case grammar.OpClone:
		return 10 * float64(max(1, e.Nombre)) * danger
	case grammar.OpDissiper:
		if t == nil {
			return 0
		}
		n := 0
		for _, s := range t.Statuts {
			if Bienfaits[s.Type] {
				n++
			}
		}
		return 8 * float64(n)
	case grammar.OpPurifier:
		n := 0
		for _, s := range f.Statuts {
			if Maux[s.Type] {
				n++
			}
		}
		return 8 * float64(n)
	case grammar.OpInterrompre:
		if t != nil && t.Incantation != nil && !t.Incantation.Silence {
			return 10 + 5*float64(t.Incantation.Total)
		}
		return 0
	case grammar.OpRiposte, grammar.OpPiege, grammar.OpInvocation, grammar.OpDeclencheur, grammar.OpDiffere:
		v := 0.0
		for _, x := range e.Effets {
			v += c.valeurEffet(f, x, t, p, tours)
		}
		switch e.Op {
		case grammar.OpInvocation:
			v *= float64(e.Duree) * 0.8
		case grammar.OpRiposte:
			v *= 1.2
		case grammar.OpPiege:
			v *= 0.8
		case grammar.OpDeclencheur:
			v *= 0.6
		default:
			v *= 0.9
		}
		return v
	}
	return 0
}

func (c *Combat) valeurStatut(f *Combattant, e grammar.Effet, t *Combattant, p float64) float64 {
	d := float64(max(1, e.Duree))
	danger := 1.0
	if f.PV*2 < f.PVMax {
		danger = 2
	}
	sur := f
	if e.Cible != grammar.CSoi && e.Cible != grammar.CAllies {
		sur = t
	}
	if sur == nil || sur.A(e.Statut) {
		return 0
	}
	chance := 1.0
	if grammar.StatutsControle[e.Statut] {
		chance = 0.6
	}
	switch e.Statut {
	case "def_phys", "def_mag":
		return 6 * e.Valeur * d * danger * 3
	case "renvoi":
		return 8 * e.Valeur * d
	case "parade", "reflet", "deviation":
		return 9 * danger
	case "esquive":
		return 12 * e.Valeur * d * danger
	case "intangible_phys", "intangible_mag", "invisible":
		return 7 * d * danger
	case "disparu":
		return 5 * danger * danger
	case "leurre":
		return 6 * e.Valeur * danger
	case "regen":
		return math.Min(p*e.Valeur*d, manque(f)) * 0.8
	case "baume":
		return p * e.Valeur * 0.15
	case "second_souffle":
		return 6 * danger * danger
	case "marque":
		return p * e.Valeur * d * 0.8
	case "sangsue":
		return p * e.Valeur * d
	case "scelle":
		v := 6.0 * d
		if sur.Incantation != nil {
			v += 5 * float64(sur.Incantation.Total)
		}
		return v * chance
	case "desarme":
		return 7 * d * chance
	case "endormi":
		return 10 * d * chance
	case "confus", "aveugle":
		return 14 * e.Valeur * d * chance
	case "egare":
		return 5 * d * chance
	case "immobilise", "sans_garde", "hasard":
		return 4 * d * chance
	case "retenu":
		return 1
	}
	return 0
}
