package combat

import (
	"errors"
	"fmt"
	"math"
	"math/rand"
	"sort"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// TourMax : au-delà, le combat est déclaré nul.
const TourMax = 60

// Erreurs de validation des actions.
var (
	ErrFini          = errors.New("le combat est terminé")
	ErrActeur        = errors.New("combattant inconnu ou hors de combat")
	ErrMudraInterdit = errors.New("vous ne savez pas encore former ce mudra")
	ErrSequence      = errors.New("suite de mudras trop longue")
	ErrAction        = errors.New("action inconnue")
)

// Nouveau prépare un combat. `moment` donne l'heure réelle (Soleil, Lune).
func Nouveau(id string, combattants []*Combattant, graine int64, moment func() time.Time) *Combat {
	if moment == nil {
		moment = time.Now
	}
	c := &Combat{
		ID:          id,
		Combattants: combattants,
		Vainqueur:   -1,
		Usages:      map[string]int{},
		rng:         rand.New(rand.NewSource(graine)),
		moment:      moment,
	}
	for _, f := range combattants {
		if f.Maitrise == nil {
			f.Maitrise = map[string]int{}
		}
	}
	c.compacter(0)
	c.compacter(1)
	return c
}

// Get renvoie un combattant par identifiant.
func (c *Combat) Get(id string) *Combattant {
	for _, f := range c.Combattants {
		if f.ID == id {
			return f
		}
	}
	return nil
}

// Vivants renvoie les combattants debout d'un camp, du rang 1 au rang 3.
func (c *Combat) Vivants(camp int) []*Combattant {
	var out []*Combattant
	for _, f := range c.Combattants {
		if f.Camp == camp && f.Vivant() {
			out = append(out, f)
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].Rang < out[j].Rang })
	return out
}

func (c *Combat) compacter(camp int) {
	for i, f := range c.Vivants(camp) {
		f.Rang = i + 1
	}
}

func (c *Combat) emit(e Evenement) { c.evts = append(c.evts, e) }

func (c *Combat) nom(id string) string {
	if f := c.Get(id); f != nil {
		return f.Nom
	}
	return "?"
}

// JouerTour résout un tour. `actions` contient les choix des joueurs ;
// l'IA décide pour les autres combattants.
func (c *Combat) JouerTour(actions []Action) ([]Evenement, error) {
	if c.Fini {
		return nil, ErrFini
	}
	choix := map[string]Action{}
	for _, a := range actions {
		f := c.Get(a.Acteur)
		if f == nil || !f.Vivant() || !f.Joueur {
			return nil, ErrActeur
		}
		if err := c.valider(f, a); err != nil {
			return nil, err
		}
		choix[f.ID] = a
	}
	c.evts = nil
	c.Tour++
	for _, f := range c.Combattants {
		if !f.Vivant() {
			continue
		}
		f.Garde = false
		if _, ok := choix[f.ID]; ok {
			continue
		}
		if f.Joueur {
			if f.Incantation != nil {
				choix[f.ID] = Action{Acteur: f.ID, Type: AIncanter}
			} else {
				choix[f.ID] = Action{Acteur: f.ID, Type: AGarde}
			}
		} else {
			choix[f.ID] = c.choisirIA(f)
		}
	}
	for _, f := range c.initiative(choix) {
		if c.Fini || !f.Vivant() {
			continue
		}
		c.executer(f, choix[f.ID])
		c.verifierFin()
	}
	if !c.Fini {
		c.finDeTour()
		c.verifierFin()
	}
	return c.evts, nil
}

func (c *Combat) valider(f *Combattant, a Action) error {
	switch a.Type {
	case AFrapper, AGarde, ADeplacer, AConcentrer:
		return nil
	case AIncanter:
		if len(a.Sequence) > grammar.LongueurMax {
			return ErrSequence
		}
		for _, id := range a.Sequence {
			if data.Mudras[id] == nil || (f.Permis != nil && !f.Permis[id]) {
				return ErrMudraInterdit
			}
		}
		return nil
	}
	return ErrAction
}

// initiative trie les combattants : la garde d'abord, puis l'agilité.
func (c *Combat) initiative(choix map[string]Action) []*Combattant {
	type entree struct {
		f     *Combattant
		score float64
	}
	var l []entree
	for _, f := range c.Combattants {
		if !f.Vivant() {
			continue
		}
		s := float64(f.Manhis) + c.rng.Float64()*6
		switch f.Element {
		case "vent":
			s += 4
		case "foudre":
			s += 3
		}
		if f.statut(SEntrave) != nil {
			s *= 0.5
		}
		if choix[f.ID].Type == AGarde {
			s += 1000
		}
		l = append(l, entree{f, s})
	}
	sort.SliceStable(l, func(i, j int) bool { return l[i].score > l[j].score })
	out := make([]*Combattant, len(l))
	for i, e := range l {
		out[i] = e.f
	}
	return out
}

func (c *Combat) executer(f *Combattant, a Action) {
	if a.Type != AIncanter && f.Incantation != nil {
		f.Incantation = nil
		c.emit(Evenement{Type: "abandon", Acteur: f.ID, Texte: f.Nom + " abandonne son incantation."})
	}
	if s := f.statut(SPiege); s != nil && (a.Type == AFrapper || a.Type == AIncanter || a.Type == ADeplacer) {
		c.declencherPiege(f, s)
		if !f.Vivant() {
			return
		}
	}
	switch a.Type {
	case AGarde:
		f.Garde = true
		c.emit(Evenement{Type: "garde", Acteur: f.ID, Texte: f.Nom + " se met en garde."})
	case AConcentrer:
		gain := f.SouffleMax*15/100 + f.Gnanga
		f.Souffle = min(f.SouffleMax, f.Souffle+gain)
		c.emit(Evenement{Type: "concentration", Acteur: f.ID, Valeur: gain, Texte: fmt.Sprintf("%s se concentre et rassemble son Souffle (+%d).", f.Nom, gain)})
	case ADeplacer:
		if f.statut(SEntrave) != nil {
			c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: f.Nom + " est entravé et ne peut pas bouger."})
			return
		}
		c.placer(f, a.Rang)
		c.emit(Evenement{Type: "deplacement", Acteur: f.ID, Valeur: f.Rang, Texte: fmt.Sprintf("%s passe au rang %d.", f.Nom, f.Rang)})
	case AFrapper:
		c.frapper(f, a.Cible)
	case AIncanter:
		c.incanter(f, a)
	}
}

// placer met un combattant au rang voulu en échangeant avec l'occupant.
func (c *Combat) placer(f *Combattant, rang int) {
	vivants := c.Vivants(f.Camp)
	if rang < 1 {
		rang = 1
	}
	if rang > len(vivants) {
		rang = len(vivants)
	}
	for _, o := range vivants {
		if o.Rang == rang && o != f {
			o.Rang = f.Rang
		}
	}
	f.Rang = rang
}

func (c *Combat) ennemis(f *Combattant) []*Combattant { return c.Vivants(1 - f.Camp) }

// cibleEnnemie choisit la cible demandée si elle est valide, sinon la
// première cible atteignable.
func (c *Combat) cibleEnnemie(f *Combattant, id string, contact bool) *Combattant {
	atteignable := func(t *Combattant) bool { return !contact || t.Rang <= 2 }
	if t := c.Get(id); t != nil && t.Vivant() && t.Camp != f.Camp && atteignable(t) {
		return t
	}
	for _, t := range c.ennemis(f) {
		if atteignable(t) {
			return t
		}
	}
	return nil
}

func (c *Combat) chance(pct float64) bool { return c.rng.Float64()*100 < pct }

func esquive(t *Combattant) float64 {
	e := math.Min(35, float64(t.Manhis)*0.8)
	if t.statut(SVoile) != nil {
		e += 50
	}
	if t.statut(SEntrave) != nil {
		e /= 2
	}
	return e
}

func (c *Combat) frapper(f *Combattant, cibleID string) {
	contact := !f.Arme.Distance
	if contact && f.statut(SEntrave) != nil {
		c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: f.Nom + " est entravé et ne peut pas frapper au contact."})
		return
	}
	if contact && f.Rang > 2 {
		c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: f.Nom + " est trop loin pour frapper au contact."})
		return
	}
	t := c.cibleEnnemie(f, cibleID, contact)
	if t == nil {
		c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: f.Nom + " ne trouve aucune cible à portée."})
		return
	}
	if s := f.statut(SAveugle); s != nil && c.chance(s.Valeur*100) {
		c.emit(Evenement{Type: "rate", Acteur: f.ID, Cible: t.ID, Texte: f.Nom + ", aveuglé, frappe dans le vide."})
		return
	}
	if c.intercepter(f, t) {
		return
	}
	if c.chance(esquive(t)) {
		c.emit(Evenement{Type: "esquive", Acteur: f.ID, Cible: t.ID, Texte: t.Nom + " esquive le coup de " + f.Nom + "."})
		return
	}
	brut := float64(f.Arme.Puissance+f.Fangan) * (0.85 + c.rng.Float64()*0.3)
	crit := c.chance(float64(f.Manhis) * 0.7)
	if crit {
		brut *= 1.5
	}
	if s := f.statut(SRenfort); s != nil {
		brut *= 1 + s.Valeur
	}
	texte := f.Nom + " frappe " + t.Nom
	if crit {
		texte += " (coup critique)"
	}
	c.emit(Evenement{Type: "frappe", Acteur: f.ID, Cible: t.ID, Texte: texte + " avec " + f.Arme.Nom + "."})
	c.infliger(f, t, brut, "", false)
	if contact {
		c.riposter(t, f)
	}
}

// intercepter : un double absorbe une attaque visant un seul combattant.
func (c *Combat) intercepter(f, t *Combattant) bool {
	s := t.statut(SLeurre)
	if s == nil {
		return false
	}
	s.Tours = 0
	c.emit(Evenement{Type: "leurre", Acteur: f.ID, Cible: t.ID, Texte: "Le double de " + t.Nom + " encaisse l'attaque et se dissipe !"})
	if s.Effet != "" && f.Vivant() {
		c.appliquerEffet(t, f, s.Effet, s.Valeur, s.Base, 0, effetOpts{element: s.Element})
	}
	return true
}

// riposter : armure ou mur à riposte contre un attaquant au contact.
func (c *Combat) riposter(t, attaquant *Combattant) {
	if !attaquant.Vivant() {
		return
	}
	if s := t.statut(SRiposte); s != nil {
		c.emit(Evenement{Type: "riposte", Acteur: t.ID, Cible: attaquant.ID, Element: s.Element, Texte: "L'armure de " + t.Nom + " riposte !"})
		c.infliger(t, attaquant, s.Base*0.4, s.Element, true)
		if attaquant.Vivant() {
			c.appliquerEffet(t, attaquant, s.Effet, s.Valeur, s.Base, 0, effetOpts{element: s.Element})
		}
	}
	if m := c.Murs[t.Camp]; m != nil && m.Riposte != "" && attaquant.Vivant() {
		lanceur := c.Get(m.Lanceur)
		if lanceur == nil {
			lanceur = t
		}
		c.emit(Evenement{Type: "riposte", Acteur: lanceur.ID, Cible: attaquant.ID, Element: m.Element, Texte: "Le mur riposte contre " + attaquant.Nom + " !"})
		c.appliquerEffet(lanceur, attaquant, m.Riposte, m.Intensite, m.Base, 0, effetOpts{element: m.Element})
	}
}

// infliger applique des dégâts après défense, garde et absorptions.
// `element` vide : attaque d'arme. `direct` : ignore défense et absorptions.
func (c *Combat) infliger(src, t *Combattant, brut float64, element string, direct bool) int {
	if !t.Vivant() {
		return 0
	}
	dmg := brut
	if !direct {
		if element != "" {
			dmg *= data.Multiplier(element, t.Element)
		}
		if s := t.statut(SMarque); s != nil {
			dmg *= 1 + s.Valeur
		}
		def := float64(t.Defense) + float64(t.Fangan)*0.5
		if t.statut(SAffaibli) != nil {
			def *= 0.5
		}
		if element != "" {
			def *= 0.5 // les jutsus percent en partie les armures
			if element == "metal" || element == "foudre" {
				def *= 0.5
			}
		}
		dmg *= 40 / (40 + def)
		if t.Garde {
			dmg *= 0.5
		}
	}
	d := int(math.Round(dmg))
	if d < 1 {
		d = 1
	}
	if !direct && t.Absorption > 0 {
		a := min(t.Absorption, d)
		t.Absorption -= a
		d -= a
		c.emit(Evenement{Type: "absorption", Cible: t.ID, Valeur: a, Texte: fmt.Sprintf("L'armure de Souffle de %s absorbe %d.", t.Nom, a)})
	}
	if m := c.Murs[t.Camp]; !direct && m != nil && d > 0 {
		a := min(m.Absorption, d)
		m.Absorption -= a
		d -= a
		c.emit(Evenement{Type: "absorption", Cible: t.ID, Valeur: a, Texte: fmt.Sprintf("Le mur absorbe %d.", a)})
		if m.Absorption <= 0 {
			c.Murs[t.Camp] = nil
			c.emit(Evenement{Type: "mur_brise", Cible: t.ID, Texte: "Le mur s'effondre !"})
		}
	}
	if d <= 0 {
		return 0
	}
	t.PV -= d
	srcID := ""
	if src != nil {
		srcID = src.ID
	}
	c.emit(Evenement{Type: "degats", Acteur: srcID, Cible: t.ID, Valeur: d, Element: element, Texte: fmt.Sprintf("%s perd %d PV.", t.Nom, d)})
	if t.PV <= 0 {
		c.mourir(t)
		return d
	}
	if t.Incantation != nil && !t.Incantation.Silence && d*100 >= t.PVMax*12 {
		c.interrompre(t, "sous la violence du coup")
	}
	return d
}

func (c *Combat) interrompre(t *Combattant, raison string) {
	if t.Incantation == nil || t.Incantation.Silence {
		return
	}
	t.Incantation = nil
	c.emit(Evenement{Type: "interruption", Cible: t.ID, Texte: "L'incantation de " + t.Nom + " est brisée " + raison + " !"})
}

func (c *Combat) mourir(t *Combattant) {
	t.PV = 0
	t.Incantation = nil
	t.Statuts = nil
	t.Rang = 0
	c.emit(Evenement{Type: "mort", Cible: t.ID, Texte: t.Nom + " tombe."})
	c.compacter(t.Camp)
}

func (c *Combat) soigner(f, t *Combattant, montant float64) {
	if !t.Vivant() {
		return
	}
	v := int(math.Round(montant))
	if v < 1 {
		v = 1
	}
	v = min(v, t.PVMax-t.PV)
	t.PV += v
	c.emit(Evenement{Type: "soin", Acteur: f.ID, Cible: t.ID, Valeur: v, Texte: fmt.Sprintf("%s récupère %d PV.", t.Nom, v)})
}

// ajouterStatut ajoute ou rafraîchit un statut.
func (c *Combat) ajouterStatut(t *Combattant, s *Statut) {
	if !t.Vivant() {
		return
	}
	if ex := t.statut(s.Type); ex != nil && s.Type != SPiege && s.Type != SInvocation {
		if s.Type == SConsume && s.Element == "venin" {
			ex.Valeur += s.Valeur // le venin s'accumule
		} else {
			ex.Valeur = math.Max(ex.Valeur, s.Valeur)
		}
		ex.Tours = max(ex.Tours, s.Tours)
		ex.Silence = ex.Silence || s.Silence
		return
	}
	t.Statuts = append(t.Statuts, s)
}

func (c *Combat) verifierFin() {
	if c.Fini {
		return
	}
	a, b := len(c.Vivants(0)), len(c.Vivants(1))
	switch {
	case b == 0:
		c.Fini, c.Vainqueur = true, 0
	case a == 0:
		c.Fini, c.Vainqueur = true, 1
	case c.Tour >= TourMax:
		c.Fini, c.Vainqueur = true, 2
	}
	if c.Fini {
		texte := map[int]string{0: "Victoire !", 1: "Défaite…", 2: "Match nul : les deux camps sont épuisés."}[c.Vainqueur]
		c.emit(Evenement{Type: "fin", Valeur: c.Vainqueur, Texte: texte})
	}
}

func (c *Combat) finDeTour() {
	// Jutsus retardés et échos.
	var reste []differe
	for _, d := range c.differes {
		d.tours--
		if d.tours > 0 {
			reste = append(reste, d)
			continue
		}
		if d.lanceur.Vivant() {
			c.emit(Evenement{Type: "differe", Acteur: d.lanceur.ID, Jutsu: d.jutsu.Nom, Element: d.jutsu.Element, Texte: "Le " + d.jutsu.Nom + " de " + d.lanceur.Nom + " frappe à nouveau !"})
			c.lancer(d.lanceur, d.jutsu, d.cible, d.facteur, true)
		}
	}
	c.differes = reste

	for _, f := range c.Combattants {
		if !f.Vivant() {
			continue
		}
		for _, s := range f.Statuts {
			if s.Tours <= 0 || !f.Vivant() {
				continue
			}
			switch s.Type {
			case SConsume:
				c.emit(Evenement{Type: "consume", Cible: f.ID, Element: s.Element, Texte: f.Nom + " se consume."})
				c.infliger(nil, f, s.Valeur, s.Element, true)
			case SRegen:
				c.soigner(f, f, s.Valeur)
			case SInvocation:
				c.invocationFrappe(f, s)
			}
			s.Tours--
		}
		var gardes []*Statut
		for _, s := range f.Statuts {
			if s.Tours > 0 {
				gardes = append(gardes, s)
			}
		}
		f.Statuts = gardes
		if f.Vivant() {
			f.Souffle = min(f.SouffleMax, f.Souffle+3+f.Gnanga/4)
		}
	}
	for camp, m := range c.Murs {
		if m != nil {
			m.Tours--
			if m.Tours <= 0 {
				c.Murs[camp] = nil
				c.emit(Evenement{Type: "mur_fin", Texte: "Le mur se dissipe."})
			}
		}
	}
}

func (c *Combat) invocationFrappe(f *Combattant, s *Statut) {
	ennemis := c.ennemis(f)
	if len(ennemis) == 0 {
		return
	}
	t := ennemis[c.rng.Intn(len(ennemis))]
	c.emit(Evenement{Type: "invocation", Acteur: f.ID, Cible: t.ID, Element: s.Element, Texte: "La créature de Souffle de " + f.Nom + " attaque " + t.Nom + "."})
	d := c.infliger(f, t, s.Base, s.Element, false)
	if t.Vivant() && s.Effet != "" {
		c.appliquerEffet(f, t, s.Effet, s.Valeur*0.5, s.Base, d, effetOpts{element: s.Element})
	}
}

func (c *Combat) declencherPiege(f *Combattant, s *Statut) {
	s.Tours = 0
	lanceur := c.Get(s.Source)
	if lanceur == nil {
		lanceur = f
	}
	c.emit(Evenement{Type: "piege", Acteur: lanceur.ID, Cible: f.ID, Element: s.Element, Texte: f.Nom + " déclenche un piège !"})
	d := c.infliger(lanceur, f, s.Base, s.Element, false)
	if f.Vivant() && s.Effet != "" {
		c.appliquerEffet(lanceur, f, s.Effet, s.Valeur, s.Base, d, effetOpts{element: s.Element})
	}
}

// Vue renvoie l'état du combat tel qu'un camp a le droit de le voir :
// les suites de mudras adverses restent cachées.
func (c *Combat) Vue(camp int) *Combat {
	v := *c
	v.Combattants = make([]*Combattant, len(c.Combattants))
	for i, f := range c.Combattants {
		cp := *f
		if f.Incantation != nil {
			inc := *f.Incantation
			if f.Camp != camp {
				inc.Sequence = nil
				inc.Cible = ""
			}
			cp.Incantation = &inc
		}
		v.Combattants[i] = &cp
	}
	return &v
}
