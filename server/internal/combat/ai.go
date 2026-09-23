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
)

type option struct {
	action Action
	score  float64
}

// choisirIA évalue chaque action possible et garde la meilleure.
// L'IA lit la situation : elle soigne les blessés, profite des faiblesses
// élémentaires, et cherche à briser les longues incantations adverses.
func (c *Combat) choisirIA(f *Combattant) Action {
	if f.Incantation != nil {
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
	if !(f.Arme.Distance == false && (f.Rang > 2 || f.statut(SEntrave) != nil)) {
		for _, t := range ennemis {
			if !f.Arme.Distance && t.Rang > 2 {
				continue
			}
			est := float64(f.Arme.Puissance+f.Fangan) * 40 / (40 + defenseDe(t))
			ajouter(Action{Type: AFrapper, Cible: t.ID}, c.valeurDegats(t, est, 1))
		}
	}

	// Jutsus.
	if f.IA != IABete {
		mpt := f.MudrasParTour()
		for _, j := range f.Jutsus {
			if CoutReel(j, f.maitriseDe(j)) > f.Souffle {
				continue
			}
			tours := float64((j.Longueur() + mpt - 1) / mpt)
			base := c.puissance(f, j, 1)
			seq := j.Sequence
			if j.Soutien {
				if s := c.valeurSoutien(f, j, base); s > 0 {
					cible := plusBlesse(c.Vivants(f.Camp))
					ajouter(Action{Type: AIncanter, Sequence: seq, Cible: cible.ID}, s/tours)
				}
				continue
			}
			switch j.Forme {
			case data.FMur, data.FArmure, data.FDouble:
				v := base * 0.3
				if menace > 0 || f.PV*2 < f.PVMax {
					v = base*0.8 + menace
				}
				if (j.Forme == data.FMur && c.Murs[f.Camp] != nil) || (j.Forme == data.FArmure && f.Absorption > 0) {
					v *= 0.2
				}
				ajouter(Action{Type: AIncanter, Sequence: seq}, v/tours)
				continue
			case data.FCercle, data.FInvocation:
				total := 0.0
				for _, t := range ennemis {
					total += c.valeurDegats(t, base*data.Multiplier(j.Element, t.Element), tours)
				}
				if j.Forme == data.FInvocation {
					total *= 2.2
				}
				ajouter(Action{Type: AIncanter, Sequence: seq}, total/tours+bonusEffet(j, base))
				continue
			}
			for _, t := range ennemis {
				if j.Forme == data.FLame && (f.Rang > 2 || t.Rang > 2) {
					continue
				}
				v := c.valeurDegats(t, base*data.Multiplier(j.Element, t.Element), tours)
				if t.Incantation != nil && interromptJutsu(j) && tours <= float64(t.Incantation.Total-t.Incantation.Progres+1) {
					v += 12 * float64(t.Incantation.Total)
				}
				ajouter(Action{Type: AIncanter, Sequence: seq, Cible: t.ID}, v/tours+bonusEffet(j, base))
			}
		}
	}

	// Garde, concentration, déplacement.
	garde := 2.0
	if f.PV*10 < f.PVMax*3 && menace > 0 {
		garde = 10 + menace
	}
	ajouter(Action{Type: AGarde}, garde)
	if f.IA != IABete && f.Souffle*3 < f.SouffleMax {
		ajouter(Action{Type: AConcentrer}, 6)
	}
	if !f.Arme.Distance && f.Rang > 2 {
		ajouter(Action{Type: ADeplacer, Rang: 1}, 8)
	}

	best := opts[0]
	for _, o := range opts[1:] {
		if o.score > best.score {
			best = o
		}
	}
	return best.action
}

func defenseDe(t *Combattant) float64 {
	d := float64(t.Defense) + float64(t.Fangan)*0.5
	if t.statut(SAffaibli) != nil {
		d *= 0.5
	}
	return d
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

func interromptJutsu(j *grammar.Jutsu) bool {
	return j.Element == "son" || j.Element == "onde" || j.Effet == data.XRepousser || j.Effet == data.XBriser ||
		j.Effet2 == data.XRepousser || j.Effet2 == data.XBriser
}

func bonusEffet(j *grammar.Jutsu, base float64) float64 {
	b := 0.0
	for _, e := range []string{j.Effet, j.Effet2} {
		switch e {
		case data.XConsumer:
			b += base * 0.5
		case data.XLier, data.XAveugler, data.XMarquer:
			b += base * 0.3
		case data.XDrainer, data.XBriser:
			b += base * 0.2
		}
	}
	return b
}

func (c *Combat) valeurSoutien(f *Combattant, j *grammar.Jutsu, base float64) float64 {
	switch j.Effet {
	case data.XSoigner:
		manque := 0.0
		for _, a := range c.Vivants(f.Camp) {
			if a.PV*10 < a.PVMax*6 {
				manque += float64(a.PVMax - a.PV)
			}
		}
		return math.Min(manque, base*1.5) * 1.2
	case data.XRenforcer:
		if f.statut(SRenfort) == nil {
			return base * 0.4
		}
	case data.XDissimuler:
		if f.statut(SVoile) == nil {
			return base * 0.3
		}
	}
	return 0
}
