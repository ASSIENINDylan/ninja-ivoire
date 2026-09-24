package combat

import (
	"errors"
	"fmt"
	"math"
	"math/rand"
	"sort"
	"strconv"
	"strings"
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

// Vivants renvoie les combattants debout d'un camp, par rang.
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

// Reels : les combattants debout d'un camp, sans les clones.
func (c *Combat) Reels(camp int) []*Combattant {
	var out []*Combattant
	for _, f := range c.Vivants(camp) {
		if !f.Clone {
			out = append(out, f)
		}
	}
	return out
}

func (c *Combat) compacter(camp int) {
	for i, f := range c.Vivants(camp) {
		f.Rang = i + 1
	}
}

func (c *Combat) emit(e Evenement) { c.evts = append(c.evts, e) }

func (c *Combat) chance(p float64) bool { return c.rng.Float64() < p }

// JouerTour résout un tour. `actions` contient les choix des joueurs ;
// l'IA décide pour les autres combattants (clones compris).
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
		if f.A("immobilise") {
			s *= 0.7
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

func (c *Combat) info(f *Combattant, texte string) {
	c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: texte})
}

func (c *Combat) executer(f *Combattant, a Action) {
	if a.Type != AIncanter && f.Incantation != nil {
		f.Incantation = nil
		c.emit(Evenement{Type: "abandon", Acteur: f.ID, Texte: f.Nom + " abandonne son incantation."})
	}
	if f.A("endormi") {
		c.info(f, f.Nom+" dort profondément.")
		return
	}
	// Un piège se déclenche dès que la victime agit.
	if s := f.statut(SPiege); s != nil {
		if c.declencherPiege(f, s) || !f.Vivant() {
			return
		}
	}
	if s := f.statut("confus"); s != nil && a.Type != AGarde && c.chance(s.Valeur) {
		c.frappeConfuse(f)
		return
	}
	switch a.Type {
	case AGarde:
		if f.A("sans_garde") {
			c.info(f, f.Nom+" ne parvient pas à se mettre en garde.")
			return
		}
		f.Garde = true
		c.emit(Evenement{Type: "garde", Acteur: f.ID, Texte: f.Nom + " se met en garde."})
	case AConcentrer:
		gain := f.SouffleMax*15/100 + f.Gnanga
		f.Souffle = min(f.SouffleMax, f.Souffle+gain)
		c.emit(Evenement{Type: "concentration", Acteur: f.ID, Valeur: gain, Texte: fmt.Sprintf("%s se concentre et rassemble son Souffle (+%d).", f.Nom, gain)})
	case ADeplacer:
		if f.A("immobilise") {
			c.info(f, f.Nom+" est immobilisé et ne peut pas changer de rang.")
			return
		}
		c.placer(f, a.Rang)
		c.emit(Evenement{Type: "deplacement", Acteur: f.ID, Valeur: f.Rang, Texte: fmt.Sprintf("%s passe au rang %d.", f.Nom, f.Rang)})
	case AFrapper:
		if f.A("desarme") {
			c.info(f, f.Nom+" est désarmé et ne peut pas frapper.")
			return
		}
		c.frapper(f, a.Cible)
	case AIncanter:
		if f.A("scelle") {
			f.Incantation = nil
			c.info(f, "Les mains de "+f.Nom+" sont scellées : impossible de former des mudras.")
			return
		}
		c.incanter(f, a)
	}
}

// frappeConfuse : un combattant confus frappe son propre camp.
func (c *Combat) frappeConfuse(f *Combattant) {
	camp := c.Reels(f.Camp)
	if f.Clone {
		camp = append(camp, f)
	}
	t := camp[c.rng.Intn(len(camp))]
	quoi := t.Nom
	if t == f {
		quoi = "dans le vide et se blesse"
	}
	c.emit(Evenement{Type: "frappe", Acteur: f.ID, Cible: t.ID, Texte: f.Nom + ", confus, frappe " + quoi + " !"})
	c.infliger(f, t, float64(f.Arme.Puissance+f.Fangan)*0.8, grammar.NPhysique, "", false)
}

// placer met un combattant au rang voulu en échangeant avec l'occupant.
func (c *Combat) placer(f *Combattant, rang int) {
	vivants := c.Vivants(f.Camp)
	rang = max(1, min(rang, len(vivants)))
	for _, o := range vivants {
		if o.Rang == rang && o != f {
			o.Rang = f.Rang
		}
	}
	f.Rang = rang
}

func (c *Combat) ennemis(f *Combattant) []*Combattant { return c.Vivants(1 - f.Camp) }

// ciblable : un adversaire qu'on peut viser seul.
func ciblable(t *Combattant) bool {
	return t.Vivant() && !t.A("invisible") && !t.A("disparu")
}

// cibleEnnemie choisit la cible demandée si elle est valide, sinon la
// première cible atteignable. Un combattant égaré vise au hasard.
func (c *Combat) cibleEnnemie(f *Combattant, id string, contact bool) *Combattant {
	var possibles []*Combattant
	for _, t := range c.ennemis(f) {
		if ciblable(t) && (!contact || t.Rang <= 2) {
			possibles = append(possibles, t)
		}
	}
	if len(possibles) == 0 {
		return nil
	}
	if f.A("egare") {
		return possibles[c.rng.Intn(len(possibles))]
	}
	for _, t := range possibles {
		if t.ID == id {
			return t
		}
	}
	return possibles[0]
}

func esquive(t *Combattant) float64 {
	e := math.Min(0.35, float64(t.Manhis)*0.008)
	if s := t.statut("esquive"); s != nil {
		e += s.Valeur
	}
	if t.A("immobilise") {
		e /= 2
	}
	return math.Min(0.9, e)
}

// atteindre applique les protections d'une cible visée seule : clone,
// leurres, déviation, reflet, parade, esquive. Renvoie la cible finale,
// ou nil si l'attaque est perdue.
func (c *Combat) atteindre(a, t *Combattant, jutsu bool) *Combattant {
	if t.Clone {
		c.dissiperClone(t, "L'attaque traverse "+t.Nom+" : ce n'était qu'un clone !")
		return nil
	}
	if s := t.statut("leurre"); s != nil && s.Valeur >= 1 {
		s.Valeur--
		if s.Valeur < 1 {
			s.Tours = 0
		}
		c.emit(Evenement{Type: "esquive", Acteur: a.ID, Cible: t.ID, Texte: "Un leurre de " + t.Nom + " encaisse l'attaque et se dissipe !"})
		return nil
	}
	if s := t.statut("deviation"); s != nil {
		s.Tours = 0
		var autres []*Combattant
		for _, o := range c.Reels(a.Camp) {
			if o != a {
				autres = append(autres, o)
			}
		}
		if len(autres) == 0 {
			c.emit(Evenement{Type: "esquive", Acteur: a.ID, Cible: t.ID, Texte: t.Nom + " détourne l'attaque, qui se perd."})
			return nil
		}
		o := autres[c.rng.Intn(len(autres))]
		c.emit(Evenement{Type: "esquive", Acteur: a.ID, Cible: o.ID, Texte: t.Nom + " détourne l'attaque sur " + o.Nom + " !"})
		return o
	}
	if s := t.statut("reflet"); s != nil && jutsu {
		s.Tours = 0
		c.emit(Evenement{Type: "reflet", Acteur: t.ID, Cible: a.ID, Texte: t.Nom + " renvoie le jutsu à " + a.Nom + " !"})
		return a
	}
	if s := t.statut("parade"); s != nil {
		s.Tours = 0
		c.emit(Evenement{Type: "esquive", Acteur: a.ID, Cible: t.ID, Texte: t.Nom + " pare entièrement le coup."})
		return nil
	}
	if s := a.statut("aveugle"); s != nil && c.chance(s.Valeur) {
		c.emit(Evenement{Type: "rate", Acteur: a.ID, Cible: t.ID, Texte: a.Nom + ", aveuglé, frappe dans le vide."})
		return nil
	}
	e := esquive(t)
	if jutsu {
		e /= 2
	}
	if c.chance(e) {
		c.emit(Evenement{Type: "esquive", Acteur: a.ID, Cible: t.ID, Texte: t.Nom + " esquive."})
		return nil
	}
	return t
}

func (c *Combat) frapper(f *Combattant, cibleID string) {
	contact := !f.Arme.Distance
	if contact && f.Rang > 2 {
		c.info(f, f.Nom+" est trop loin pour frapper au contact.")
		return
	}
	t := c.cibleEnnemie(f, cibleID, contact)
	if t == nil {
		c.info(f, f.Nom+" ne trouve aucune cible à portée.")
		return
	}
	t = c.atteindre(f, t, false)
	if t == nil {
		return
	}
	brut := float64(f.Arme.Puissance+f.Fangan) * (0.85 + c.rng.Float64()*0.3)
	crit := c.chance(float64(f.Manhis) * 0.007)
	if crit {
		brut *= 1.5
	}
	texte := f.Nom + " frappe " + t.Nom
	if crit {
		texte += " (coup critique)"
	}
	c.emit(Evenement{Type: "frappe", Acteur: f.ID, Cible: t.ID, Texte: texte + " avec " + f.Arme.Nom + "."})
	c.infliger(f, t, brut, grammar.NPhysique, "", false)
	c.riposter(t, f)
}

// riposter : les charges de riposte de la cible frappent l'attaquant.
func (c *Combat) riposter(t, attaquant *Combattant) {
	if t.Camp == attaquant.Camp || !t.Vivant() {
		return
	}
	for _, s := range append([]*Statut(nil), t.Statuts...) {
		if s.Type != SRiposte || s.Tours <= 0 || !attaquant.Vivant() {
			continue
		}
		src := c.Get(s.Source)
		if src == nil || !src.Vivant() {
			src = t
		}
		c.emit(Evenement{Type: "riposte", Acteur: t.ID, Cible: attaquant.ID, Element: s.Element, Texte: "Le Souffle de " + t.Nom + " riposte contre " + attaquant.Nom + " !"})
		c.appliquer(contexteCharge(src, s, attaquant), s.Effets)
	}
}

// facteurDefense : part des dégâts qui traverse la défense.
func facteurDefense(t *Combattant, nature string) float64 {
	switch nature {
	case grammar.NPhysique:
		f := 40 / (40 + float64(t.Defense) + float64(t.Fangan)*0.6)
		if s := t.statut("def_phys"); s != nil {
			f *= 1 - math.Min(0.8, s.Valeur)
		}
		return f
	case grammar.NMagique:
		f := 40 / (40 + float64(t.DefenseMag) + float64(t.Gnanga)*0.6)
		if s := t.statut("def_mag"); s != nil {
			f *= 1 - math.Min(0.8, s.Valeur)
		}
		return f
	}
	return 1 // les dégâts purs ignorent toute défense
}

// infliger applique des dégâts. `direct` : brûlures et renvois, qui
// ignorent défenses, garde et boucliers.
func (c *Combat) infliger(src, t *Combattant, brut float64, nature, element string, direct bool) int {
	if !t.Vivant() {
		return 0
	}
	if t.Clone {
		c.dissiperClone(t, t.Nom+" se dissipe : ce n'était qu'un clone !")
		return 0
	}
	if t.A("disparu") {
		c.emit(Evenement{Type: "esquive", Cible: t.ID, Texte: t.Nom + " a disparu : rien ne l'atteint."})
		return 0
	}
	if (nature == grammar.NPhysique && t.A("intangible_phys")) || (nature == grammar.NMagique && t.A("intangible_mag")) {
		c.emit(Evenement{Type: "esquive", Cible: t.ID, Texte: "Les dégâts " + nature + "s traversent " + t.Nom + " sans l'atteindre."})
		return 0
	}
	dmg := brut
	if nature != grammar.NPur && element != "" {
		dmg *= data.Multiplier(element, t.Element)
	}
	if s := t.statut("marque"); s != nil {
		dmg *= 1 + s.Valeur
	}
	if !direct {
		dmg *= facteurDefense(t, nature)
		if t.Garde && nature != grammar.NPur {
			dmg *= 0.5
		}
	}
	d := max(1, int(math.Round(dmg)))
	if !direct && t.Absorption > 0 {
		a := min(t.Absorption, d)
		t.Absorption -= a
		d -= a
		c.emit(Evenement{Type: "absorption", Cible: t.ID, Valeur: a, Texte: fmt.Sprintf("Le bouclier de %s absorbe %d.", t.Nom, a)})
		if d == 0 {
			return 0
		}
	}
	t.PV -= d
	srcID := ""
	if src != nil {
		srcID = src.ID
	}
	c.emit(Evenement{Type: "degats", Acteur: srcID, Cible: t.ID, Valeur: d, Element: element, Texte: fmt.Sprintf("%s perd %d PV (%s).", t.Nom, d, nature)})
	if s := t.statut("endormi"); s != nil {
		s.Tours = 0
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " se réveille !"})
	}
	if s := t.statut("renvoi"); s != nil && !direct && src != nil && src != t && src.Vivant() {
		c.emit(Evenement{Type: "riposte", Acteur: t.ID, Cible: src.ID, Texte: t.Nom + " renvoie une part des dégâts."})
		c.infliger(t, src, float64(d)*s.Valeur, grammar.NPur, "", true)
	}
	if t.PV <= 0 {
		s := t.statut("second_souffle")
		if s == nil {
			c.mourir(t)
			return d
		}
		s.Tours = 0
		t.PV = 1
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " refuse de tomber : second souffle !"})
		c.soigner(t, t, s.Valeur)
	}
	if t.Incantation != nil && !t.Incantation.Silence && d*100 >= t.PVMax*12 {
		c.interrompre(t, "sous la violence du coup")
	}
	if s := t.statut(SDeclencheur); s != nil && float64(t.PV) < s.Valeur*float64(t.PVMax) {
		s.Tours = 0
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: "Le Souffle de " + t.Nom + " réagit à ses blessures !"})
		c.appliquer(contexteCharge(t, s, src), s.Effets)
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
	// Les clones d'un combattant tombé se dissipent.
	for _, o := range c.Combattants {
		if o.Clone && o.Original == t.ID && o.Vivant() {
			c.dissiperClone(o, "")
		}
	}
	c.compacter(t.Camp)
}

func (c *Combat) soigner(f, t *Combattant, montant float64) {
	if !t.Vivant() {
		return
	}
	v := min(max(1, int(math.Round(montant))), t.PVMax-t.PV)
	if v <= 0 {
		return
	}
	t.PV += v
	c.emit(Evenement{Type: "soin", Acteur: f.ID, Cible: t.ID, Valeur: v, Texte: fmt.Sprintf("%s récupère %d PV.", t.Nom, v)})
}

// ajouterStatut ajoute ou rafraîchit un statut.
func (c *Combat) ajouterStatut(t *Combattant, s *Statut) {
	if !t.Vivant() {
		return
	}
	cumulable := s.Type == SPiege || s.Type == SInvocation || s.Type == SRiposte || s.Type == SDeclencheur || s.Type == "sangsue"
	if ex := t.statut(s.Type); ex != nil && !cumulable {
		switch {
		case s.Type == "baume" || s.Type == "leurre" || s.Type == SConsume && s.Element == "venin":
			ex.Valeur += s.Valeur // le venin s'accumule, comme les baumes et les leurres
		default:
			ex.Valeur = math.Max(ex.Valeur, s.Valeur)
		}
		ex.Tours = max(ex.Tours, s.Tours)
		ex.Puissance = math.Max(ex.Puissance, s.Puissance)
		ex.Indissipable = ex.Indissipable || s.Indissipable
		ex.nouveau = ex.nouveau || s.nouveau
		return
	}
	t.Statuts = append(t.Statuts, s)
}

// --- Clones ------------------------------------------------------------------

// creerClone : un double du lanceur, indiscernable pour l'adversaire.
func (c *Combat) creerClone(f *Combattant, tours int, force float64) bool {
	if len(c.Vivants(f.Camp)) >= RangsMax {
		return false
	}
	base := strings.TrimRight(f.ID, "0123456789")
	n := 2
	for _, o := range c.Combattants {
		if k, err := strconv.Atoi(strings.TrimPrefix(o.ID, base)); err == nil && strings.HasPrefix(o.ID, base) && k >= n {
			n = k + 1
		}
	}
	cl := &Combattant{
		ID: fmt.Sprintf("%s%d", base, n), Nom: f.Nom, Camp: f.Camp, Apparence: f.Apparence,
		Niveau: f.Niveau, Fangan: int(float64(f.Fangan) * force), Gnanga: f.Gnanga, Manhis: f.Manhis,
		PV: f.PV, PVMax: f.PVMax, Souffle: f.Souffle, SouffleMax: f.SouffleMax,
		Element: f.Element, Elements: f.Elements, Defense: f.Defense, DefenseMag: f.DefenseMag,
		Arme:  Arme{Nom: f.Arme.Nom, Puissance: int(float64(f.Arme.Puissance) * force), Distance: f.Arme.Distance},
		Clone: true, Original: f.ID, ToursClone: tours, IA: IAClone, Maitrise: map[string]int{},
	}
	cl.Rang = len(c.Vivants(f.Camp)) + 1
	c.Combattants = append(c.Combattants, cl)
	// Le clone prend une place au hasard : l'adversaire ne sait plus qui est qui.
	c.placer(cl, 1+c.rng.Intn(len(c.Vivants(f.Camp))))
	return true
}

func (c *Combat) dissiperClone(t *Combattant, texte string) {
	t.PV = 0
	t.Statuts = nil
	t.Incantation = nil
	if texte != "" {
		c.emit(Evenement{Type: "clone_dissipe", Cible: t.ID, Texte: texte})
	}
	c.compacter(t.Camp)
}

func (c *Combat) verifierFin() {
	if c.Fini {
		return
	}
	a, b := len(c.Reels(0)), len(c.Reels(1))
	switch {
	case b == 0:
		c.Fini, c.Vainqueur = true, 0
	case a == 0:
		c.Fini, c.Vainqueur = true, 1
	case c.Tour >= TourMax:
		c.Fini, c.Vainqueur = true, 2
	}
	if c.Fini {
		for _, f := range c.Combattants {
			if f.Clone && f.Vivant() {
				c.dissiperClone(f, "")
			}
		}
		texte := map[int]string{0: "Victoire !", 1: "Défaite…", 2: "Match nul : les deux camps sont épuisés."}[c.Vainqueur]
		c.emit(Evenement{Type: "fin", Valeur: c.Vainqueur, Texte: texte})
	}
}

func (c *Combat) finDeTour() {
	// Jutsus retardés, échos et effets différés.
	var reste, dus []differe
	for _, d := range c.differes {
		d.tours--
		if d.tours > 0 {
			reste = append(reste, d)
		} else {
			dus = append(dus, d)
		}
	}
	c.differes = reste
	for _, d := range dus {
		if !d.cx.lanceur.Vivant() || c.Fini {
			continue
		}
		if d.jutsu != nil {
			c.emit(Evenement{Type: "differe", Acteur: d.cx.lanceur.ID, Jutsu: d.jutsu.Nom, Element: d.jutsu.Element, Texte: "Le " + d.jutsu.Nom + " de " + d.cx.lanceur.Nom + " se libère !"})
			c.lancer(d.cx.lanceur, d.jutsu, d.cx.cibleID, d.facteur, true)
		} else {
			c.emit(Evenement{Type: "differe", Acteur: d.cx.lanceur.ID, Element: d.cx.element, Texte: "Le Souffle différé de " + d.cx.lanceur.Nom + " se libère."})
			c.appliquer(d.cx, d.effets)
		}
		c.verifierFin()
	}

	for _, f := range append([]*Combattant(nil), c.Combattants...) {
		if !f.Vivant() || c.Fini {
			continue
		}
		for _, s := range append([]*Statut(nil), f.Statuts...) {
			if s.Tours <= 0 || !f.Vivant() {
				continue
			}
			switch s.Type {
			case SConsume:
				c.emit(Evenement{Type: "consume", Cible: f.ID, Element: s.Element, Texte: f.Nom + " se consume."})
				c.infliger(nil, f, s.Valeur, s.Nature, s.Element, true)
			case "sangsue":
				src := c.Get(s.Source)
				d := c.infliger(src, f, s.Valeur, grammar.NMagique, s.Element, true)
				if src != nil && d > 0 {
					c.soigner(src, src, float64(d))
				}
			case "regen":
				c.soigner(f, f, s.Valeur)
			case SInvocation:
				c.emit(Evenement{Type: "invocation", Acteur: f.ID, Element: s.Element, Texte: "La créature de Souffle de " + f.Nom + " agit."})
				c.appliquer(contexteCharge(f, s, nil), s.Effets)
			}
			if s.nouveau {
				s.nouveau = false
				continue
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
		if f.Clone && f.Vivant() {
			f.ToursClone--
			if f.ToursClone <= 0 {
				c.dissiperClone(f, "Un clone de "+f.Nom+" se dissipe.")
				continue
			}
		}
		if f.Vivant() {
			f.Souffle = min(f.SouffleMax, f.Souffle+3+f.Gnanga/4)
		}
		c.verifierFin()
	}
}

func (c *Combat) declencherPiege(f *Combattant, s *Statut) (annule bool) {
	s.Tours = 0
	src := c.Get(s.Source)
	if src == nil || !src.Vivant() {
		return false
	}
	c.emit(Evenement{Type: "piege", Acteur: src.ID, Cible: f.ID, Element: s.Element, Texte: f.Nom + " déclenche un piège !"})
	cx := contexteCharge(src, s, f)
	cx.annule = &annule
	c.appliquer(cx, s.Effets)
	if annule {
		c.info(f, "L'action de "+f.Nom+" est annulée.")
	}
	return annule
}

// Vue renvoie l'état du combat tel qu'un camp a le droit de le voir : les
// suites de mudras adverses restent cachées, et les clones adverses sont
// indiscernables de leur original.
func (c *Combat) Vue(camp int) *Combat {
	v := *c
	v.Combattants = nil
	for _, f := range c.Combattants {
		if f.Clone && !f.Vivant() {
			continue // un clone dissipé disparaît sans laisser de corps
		}
		cp := *f
		if f.Camp != camp && f.Clone && f.Vivant() {
			if o := c.Get(f.Original); o != nil && o.Vivant() {
				cp = *o
				cp.ID, cp.Rang = f.ID, f.Rang
			}
			cp.Clone = false
		}
		if cp.Incantation != nil {
			inc := *cp.Incantation
			if f.Camp != camp {
				inc.Sequence = nil
				inc.Cible = ""
			}
			cp.Incantation = &inc
		}
		v.Combattants = append(v.Combattants, &cp)
	}
	return &v
}
