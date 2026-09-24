package combat

import (
	"fmt"
	"math"
	"strings"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// MaitriseDecouverte : maîtrise d'un jutsu qu'on vient de découvrir.
const MaitriseDecouverte = 10

// MaitrisePNJ : maîtrise par défaut des jutsus des PNJ.
const MaitrisePNJ = 30

// CoutReel : le coût en Souffle baisse avec la maîtrise (jusqu'à -30 %).
func CoutReel(j *grammar.Jutsu, maitrise int) int {
	return int(math.Round(float64(j.Cout) * (1 - 0.3*float64(maitrise)/100)))
}

func (f *Combattant) maitriseDe(j *grammar.Jutsu) int {
	if m, ok := f.Maitrise[j.Cle]; ok {
		return m
	}
	if f.Joueur {
		return MaitriseDecouverte
	}
	return MaitrisePNJ
}

// Puissance d'un jutsu pour ce lanceur :
// (8 + F·Fangan + G·Gnanga + M·Manhis) × N, modulée par la maîtrise,
// le Soleil et la Lune.
func Puissance(f *Combattant, j *grammar.Jutsu, maitrise int, cosmique float64) float64 {
	k := j.Coefs
	base := (8 + k.F*float64(f.Fangan) + k.G*float64(f.Gnanga) + k.M*float64(f.Manhis)) * k.N
	return base * (0.8 + 0.4*float64(maitrise)/100) * cosmique
}

func (c *Combat) puissance(f *Combattant, j *grammar.Jutsu, facteur float64) float64 {
	p := Puissance(f, j, f.maitriseDe(j), data.FacteurCosmique(j.Element, c.moment())) * facteur
	if j.Element == "vegetal" || j.Element == "bois_sacre" {
		p *= 1 + 0.05*math.Min(float64(c.Tour), 10) // la sève croît au fil du combat
	}
	return p
}

// incanter commence ou poursuit une incantation.
func (c *Combat) incanter(f *Combattant, a Action) {
	if len(a.Sequence) == 0 {
		if f.Incantation == nil {
			f.Garde = true
			c.emit(Evenement{Type: "garde", Acteur: f.ID, Texte: f.Nom + " se met en garde."})
			return
		}
		if a.Cible != "" {
			f.Incantation.Cible = a.Cible
		}
	} else {
		seq := append([]string(nil), a.Sequence...)
		j, e := grammar.Analyser(seq)
		refus := ""
		if j != nil && j.Legendaire != "" && f.Contexte != nil {
			refus = grammar.LegendairesParID[j.Legendaire].Conditions.Verifier(*f.Contexte)
		}
		if j != nil && j.Fusion && j.Legendaire == "" && f.Niveau < data.NiveauFusion {
			refus = fmt.Sprintf("Deux éléments veulent se fondre… mais il faut le niveau %d pour les fusionner.", data.NiveauFusion)
		}
		cout := 3 * len(seq)
		if j != nil && refus == "" {
			cout = CoutReel(j, f.maitriseDe(j))
		}
		if f.Souffle < cout {
			c.info(f, fmt.Sprintf("%s manque de Souffle (%d requis).", f.Nom, cout))
			f.Garde = !f.A("sans_garde")
			return
		}
		f.Souffle -= cout
		inc := &Incantation{Sequence: seq, Echec: e, Refus: refus, Cible: a.Cible, Total: len(seq)}
		if refus == "" {
			inc.Jutsu = j
		}
		if j != nil && j.Incassable {
			inc.Silence = true
		}
		f.Incantation = inc
	}
	inc := f.Incantation
	inc.Progres = min(inc.Total, inc.Progres+f.MudrasParTour())
	if inc.Progres < inc.Total {
		c.emit(Evenement{Type: "incantation", Acteur: f.ID, Valeur: inc.Progres, Texte: fmt.Sprintf("%s forme des mudras (%d/%d).", f.Nom, inc.Progres, inc.Total)})
		return
	}
	f.Incantation = nil
	c.liberer(f, inc)
}

// liberer : la suite est complète, le Souffle se libère.
func (c *Combat) liberer(f *Combattant, inc *Incantation) {
	if inc.Refus != "" {
		c.emit(Evenement{Type: "echec", Acteur: f.ID, Texte: inc.Refus})
		return
	}
	if inc.Jutsu == nil {
		r := grammar.Resonner(inc.Sequence, inc.Echec, f.Precis)
		if f.Joueur {
			c.Resonances = append(c.Resonances, r)
		}
		c.emit(Evenement{Type: "echec", Acteur: f.ID, Valeur: r.Score, Texte: f.Nom + " : " + r.Message})
		if r.RetourDeSouffle {
			c.emit(Evenement{Type: "retour", Acteur: f.ID, Cible: f.ID, Texte: "Retour de Souffle !"})
			c.infliger(nil, f, float64(4+2*len(inc.Sequence)), grammar.NPur, "", true)
		}
		return
	}
	j := inc.Jutsu
	if f.Joueur {
		if _, connu := f.Maitrise[j.Cle]; !connu {
			f.Maitrise[j.Cle] = MaitriseDecouverte
			c.Decouvertes = append(c.Decouvertes, Decouverte{Joueur: f.ID, Jutsu: j})
			texte := "Nouveau jutsu découvert : " + j.Nom + " !"
			if j.Legendaire != "" {
				texte = "JUTSU LÉGENDAIRE DÉCOUVERT : " + j.Nom + " !"
			}
			c.emit(Evenement{Type: "decouverte", Acteur: f.ID, Jutsu: j.Nom, Element: j.Element, Texte: texte})
		}
		c.Usages[j.Cle]++
	}
	if j.Delai {
		c.emit(Evenement{Type: "jutsu", Acteur: f.ID, Jutsu: j.Nom, Element: j.Element, Texte: f.Nom + " accumule le Souffle de " + j.Nom + " : il partira au prochain tour."})
		c.differes = append(c.differes, differe{jutsu: j, cx: contexte{lanceur: f, cibleID: inc.Cible}, facteur: 1, tours: 1})
		return
	}
	c.lancer(f, j, inc.Cible, 1, false)
}

// lancer applique un jutsu. `echo` : relance différée, sans nouvel écho.
func (c *Combat) lancer(f *Combattant, j *grammar.Jutsu, cibleID string, facteur float64, echo bool) {
	p := c.puissance(f, j, facteur)
	if !echo {
		c.emit(Evenement{Type: "jutsu", Acteur: f.ID, Jutsu: j.Nom, Element: j.Element, Valeur: int(math.Round(p)), Texte: fmt.Sprintf("%s lance %s (puissance %d) !", f.Nom, j.Nom, int(math.Round(p)))})
		if j.Echo > 0 {
			c.differes = append(c.differes, differe{jutsu: j, cx: contexte{lanceur: f, cibleID: cibleID}, facteur: j.Echo, tours: 1})
		}
	}
	if j.Element == "brume" || j.Element == "vapeur" || j.Element == "songe" {
		c.ajouterStatut(f, &Statut{Type: "esquive", Tours: 1, Valeur: 0.3, Element: j.Element, Puissance: p})
	}
	cx := contexte{
		lanceur: f, p: p, element: j.Element, maitrise: f.maitriseDe(j),
		indissipable: j.Indissipable, cibleID: cibleID, passif: true,
	}
	c.appliquer(cx, j.Effets)
}

// contexte : ce qu'il faut savoir pour appliquer des effets.
type contexte struct {
	lanceur      *Combattant
	p            float64 // puissance
	element      string
	maitrise     int
	indissipable bool
	cibleID      string      // cible choisie par le lanceur
	autre        *Combattant // attaquant (riposte) ou victime (piège)
	passif       bool        // le passif de l'élément reste à appliquer
	annule       *bool       // piège : l'action de la victime est annulée
}

// contexteCharge : le contexte d'une charge portée par un statut.
func contexteCharge(src *Combattant, s *Statut, autre *Combattant) contexte {
	return contexte{lanceur: src, p: s.Puissance, element: s.Element, maitrise: 50, indissipable: s.Indissipable, autre: autre}
}

type cibleEffet struct {
	t      *Combattant
	part   float64
	unique bool // visée seule : clones, leurres, esquive et riposte s'appliquent
}

func partSecondaire(e grammar.Effet, defaut float64) float64 {
	if e.Part > 0 {
		return e.Part
	}
	return defaut
}

// resoudre trouve les cibles d'un effet.
func (c *Combat) resoudre(cx *contexte, e grammar.Effet) []cibleEffet {
	l := cx.lanceur
	voisine := func(t *Combattant) *Combattant {
		for _, o := range c.ennemis(l) {
			if o != t && ciblable(o) && (o.Rang == t.Rang+1 || o.Rang == t.Rang-1) {
				return o
			}
		}
		return nil
	}
	switch e.Cible {
	case grammar.CSoi:
		return []cibleEffet{{l, 1, false}}
	case grammar.CAllies:
		var out []cibleEffet
		for _, a := range c.Reels(l.Camp) {
			k := 1.0
			if a != l {
				k = partSecondaire(e, 1)
			}
			out = append(out, cibleEffet{a, k, false})
		}
		return out
	case grammar.CEnnemi, grammar.CEnnemiEtendu, grammar.CContact, grammar.CContactEtendu:
		contact := e.Cible == grammar.CContact || e.Cible == grammar.CContactEtendu
		if contact && l.Rang > 2 {
			c.info(l, "Trop loin : "+l.Nom+" doit être au rang 1 ou 2 pour toucher au contact.")
			return nil
		}
		t := c.cibleEnnemie(l, cx.cibleID, contact)
		if t == nil {
			c.info(l, "Aucune cible à portée.")
			return nil
		}
		out := []cibleEffet{{t, 1, true}}
		if e.Cible == grammar.CEnnemiEtendu || e.Cible == grammar.CContactEtendu {
			if o := voisine(t); o != nil {
				out = append(out, cibleEffet{o, partSecondaire(e, 0.7), true})
			}
		}
		return out
	case grammar.CEnnemis:
		var out []cibleEffet
		for _, t := range c.ennemis(l) {
			if !t.A("disparu") {
				out = append(out, cibleEffet{t, 1, false})
			}
		}
		return out
	case grammar.CFront:
		for _, t := range c.ennemis(l) {
			if ciblable(t) {
				return []cibleEffet{{t, 1, true}}
			}
		}
	case grammar.CAleatoire:
		var l2 []*Combattant
		for _, t := range c.ennemis(l) {
			if ciblable(t) {
				l2 = append(l2, t)
			}
		}
		if len(l2) > 0 {
			return []cibleEffet{{l2[c.rng.Intn(len(l2))], 1, true}}
		}
	case grammar.CAttaquant, grammar.CDeclencheur:
		if cx.autre != nil && cx.autre.Vivant() {
			return []cibleEffet{{cx.autre, 1, false}}
		}
	}
	return nil
}

// appliquer exécute une liste d'effets.
func (c *Combat) appliquer(cx contexte, effets []grammar.Effet) {
	for _, e := range effets {
		if !cx.lanceur.Vivant() || c.Fini {
			return
		}
		c.effet(&cx, e)
	}
}

func (c *Combat) effet(cx *contexte, e grammar.Effet) {
	l := cx.lanceur
	switch e.Op {
	case grammar.OpBond:
		if l.A("immobilise") {
			c.info(l, l.Nom+" est immobilisé et ne peut pas bondir.")
			return
		}
		rang := 1
		if e.Vers != "avant" {
			rang = len(c.Vivants(l.Camp))
		}
		c.placer(l, rang)
		c.emit(Evenement{Type: "deplacement", Acteur: l.ID, Valeur: l.Rang, Texte: fmt.Sprintf("%s bondit au rang %d.", l.Nom, l.Rang)})
		return
	case grammar.OpClone:
		for i := 0; i < max(1, e.Nombre); i++ {
			if !c.creerClone(l, e.Duree, e.Valeur) {
				c.info(l, "Plus de place dans les rangs : le clone ne peut pas naître.")
				break
			}
			c.emit(Evenement{Type: "clone", Acteur: l.ID, Element: cx.element, Texte: l.Nom + " se dédouble !"})
		}
		return
	case grammar.OpSoin:
		for i := 0; i < max(1, e.Frappes); i++ {
			c.soigner(l, l, cx.p*e.Mult)
		}
		return
	case grammar.OpPurifier:
		c.purifier(l)
		return
	case grammar.OpInvocation:
		c.ajouterStatut(l, &Statut{Type: SInvocation, Tours: e.Duree, Element: cx.element, Source: l.ID, Puissance: cx.p, Indissipable: cx.indissipable, Effets: e.Effets})
		c.emit(Evenement{Type: "invoque", Acteur: l.ID, Element: cx.element, Texte: l.Nom + " invoque une créature de Souffle."})
		return
	case grammar.OpDeclencheur:
		c.ajouterStatut(l, &Statut{Type: SDeclencheur, Tours: e.Duree, Valeur: e.Valeur, Element: cx.element, Source: l.ID, Puissance: cx.p, Indissipable: cx.indissipable, Effets: e.Effets})
		c.emit(Evenement{Type: "statut", Cible: l.ID, Texte: "Le Souffle de " + l.Nom + " veille sur ses blessures."})
		return
	case grammar.OpDiffere:
		cp := *cx
		cp.passif = false
		c.differes = append(c.differes, differe{effets: e.Effets, cx: cp, tours: e.Duree})
		return
	case grammar.OpAnnuler:
		if cx.annule != nil {
			*cx.annule = true
		}
		return
	}
	cibles := c.resoudre(cx, e)
	for _, ce := range cibles {
		c.effetSur(cx, e, ce)
	}
	// Propagation à un second adversaire.
	if e.Propage > 0 && len(cibles) > 0 && cibles[0].t.Camp != l.Camp {
		var autres []*Combattant
		for _, o := range c.ennemis(l) {
			deja := false
			for _, ce := range cibles {
				deja = deja || ce.t == o
			}
			if !deja && ciblable(o) {
				autres = append(autres, o)
			}
		}
		if len(autres) > 0 {
			o := autres[c.rng.Intn(len(autres))]
			c.emit(Evenement{Type: "info", Acteur: l.ID, Cible: o.ID, Texte: "Le Souffle se propage à " + o.Nom + "."})
			c.effetSur(cx, e, cibleEffet{o, e.Propage, true})
		}
	}
}

// reussite : jet d'une entrave ou d'une illusion contre la volonté de la
// cible. La puissance du jutsu compte, comme la maîtrise.
func (c *Combat) reussite(cx *contexte, t *Combattant, bonus, part float64) bool {
	r := (8 + 0.8*float64(t.Gnanga) + 0.4*float64(t.Manhis)) * 1.1
	p := 0.55 + 0.35*(cx.p-r)/(cx.p+r) + bonus + 0.1*float64(cx.maitrise)/100
	if cx.indissipable {
		p += 0.05
	}
	p *= 0.5 + 0.5*part
	return c.chance(math.Max(0.15, math.Min(0.95, p)))
}

func (c *Combat) effetSur(cx *contexte, e grammar.Effet, ce cibleEffet) {
	l, t, k := cx.lanceur, ce.t, ce.part
	hostile := t.Camp != l.Camp
	frappe := e.Op == grammar.OpDegats || e.Op == grammar.OpDrain
	if hostile && ce.unique && !frappe {
		if t = c.atteindre(l, t, true); t == nil {
			return
		}
		hostile = t.Camp != l.Camp
	}
	switch e.Op {
	case grammar.OpDegats, grammar.OpDrain:
		for i := 0; i < max(1, e.Frappes) && l.Vivant(); i++ {
			tt := t
			if hostile && ce.unique {
				if tt = c.atteindre(l, t, true); tt == nil {
					continue
				}
			}
			if !tt.Vivant() {
				break
			}
			d := c.infliger(l, tt, cx.p*e.Mult*k, e.Nature, cx.element, false)
			if e.Op == grammar.OpDrain && d > 0 {
				c.soigner(l, l, float64(d)*e.Valeur)
			}
			if cx.passif && tt.Vivant() && tt.Camp != l.Camp {
				cx.passif = false
				c.passifElement(cx, tt, cx.p*e.Mult, d)
			}
			if ce.unique && tt.Camp != l.Camp {
				c.riposter(tt, l)
			}
		}
	case grammar.OpDot:
		c.ajouterStatut(t, &Statut{Type: SConsume, Tours: e.Duree, Valeur: cx.p * e.Mult * k, Element: cx.element, Nature: e.Nature, Source: l.ID, Puissance: cx.p, Indissipable: cx.indissipable})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Element: cx.element, Texte: t.Nom + " se consume."})
	case grammar.OpStatut:
		c.poserStatut(cx, e, t, k, hostile)
	case grammar.OpBouclier:
		v := int(math.Round(cx.p * e.Mult * k))
		t.Absorption += v
		c.emit(Evenement{Type: "bouclier", Acteur: l.ID, Cible: t.ID, Valeur: v, Element: cx.element, Texte: fmt.Sprintf("Un bouclier de Souffle couvre %s (%d).", t.Nom, v)})
	case grammar.OpDeplacer:
		if hostile && !c.reussite(cx, t, e.Valeur, k) {
			c.emit(Evenement{Type: "resiste", Cible: t.ID, Texte: t.Nom + " tient bon et ne bouge pas."})
			return
		}
		rang := len(c.Vivants(t.Camp))
		if e.Vers == "avant" {
			rang = 1
		}
		c.placer(t, rang)
		c.emit(Evenement{Type: "deplacement", Acteur: t.ID, Valeur: t.Rang, Texte: fmt.Sprintf("%s est projeté au rang %d.", t.Nom, t.Rang)})
	case grammar.OpDissiper:
		c.dissiper(cx, t)
	case grammar.OpInterrompre:
		c.interrompre(t, "par le Souffle de "+l.Nom)
	case grammar.OpPiege:
		c.ajouterStatut(t, &Statut{Type: SPiege, Tours: e.Duree, Element: cx.element, Source: l.ID, Puissance: cx.p * k, Indissipable: cx.indissipable, Effets: e.Effets})
		c.emit(Evenement{Type: "piege_pose", Acteur: l.ID, Cible: t.ID, Element: cx.element, Texte: l.Nom + " tend un piège sous les pieds de " + t.Nom + "."})
	case grammar.OpRiposte:
		c.ajouterStatut(t, &Statut{Type: SRiposte, Tours: e.Duree, Element: cx.element, Source: l.ID, Puissance: cx.p * k, Indissipable: cx.indissipable, Effets: e.Effets, nouveau: true})
		c.emit(Evenement{Type: "statut", Acteur: l.ID, Cible: t.ID, Element: cx.element, Texte: "Le Souffle de " + l.Nom + " veille sur " + t.Nom + " : qui l'attaque le paiera."})
	}
}

// textesPoses : le journal des statuts dont la valeur est en PV.
var textesPoses = map[string]string{
	"regen": "ses blessures se referment peu à peu", "sangsue": "une sangsue de Souffle le vide",
	"baume": "un baume agira après le combat", "second_souffle": "un second souffle veille",
}

var entravesAuHasard = []string{"immobilise", "desarme", "scelle", "sans_garde"}

func (c *Combat) poserStatut(cx *contexte, e grammar.Effet, t *Combattant, k float64, hostile bool) {
	l := cx.lanceur
	typ := e.Statut
	if typ == "hasard" {
		typ = entravesAuHasard[c.rng.Intn(len(entravesAuHasard))]
	}
	if hostile && grammar.StatutsControle[e.Statut] {
		bonus := e.Valeur
		if typ == "confus" || typ == "aveugle" {
			bonus = 0
		}
		if !c.reussite(cx, t, bonus, k) {
			c.emit(Evenement{Type: "resiste", Cible: t.ID, Texte: t.Nom + " résiste au Souffle de " + l.Nom + "."})
			return
		}
	}
	val := e.Valeur * k
	switch typ {
	case "regen", "sangsue", "baume", "second_souffle":
		val = cx.p * e.Valeur * k
	case "leurre":
		val = e.Valeur
	}
	tours := e.Duree
	if tours <= 0 {
		tours = 99 // tout le combat
	}
	c.ajouterStatut(t, &Statut{Type: typ, Tours: tours, Valeur: val, Element: cx.element, Source: l.ID, Puissance: cx.p, Indissipable: cx.indissipable, nouveau: true})
	texte := textesPoses[typ]
	if texte == "" {
		texte = strings.NewReplacer("{v}", fmt.Sprint(int(math.Round(val*100))), "{n}", fmt.Sprint(int(math.Round(val)))).Replace(grammar.TextesStatut[typ])
	}
	c.emit(Evenement{Type: "statut", Acteur: l.ID, Cible: t.ID, Element: cx.element, Texte: t.Nom + " : " + texte + "."})
	if typ == "scelle" || typ == "endormi" {
		c.interrompre(t, "net")
	}
}

// dissiper retire les protections d'une cible, sauf celles qu'un Souffle
// plus puissant a posées ou que le Silure a scellées ; les clones s'évanouissent.
func (c *Combat) dissiper(cx *contexte, t *Combattant) {
	var reste []*Statut
	retire, tenu := 0, 0
	for _, s := range t.Statuts {
		if Bienfaits[s.Type] && s.Tours > 0 {
			if s.Indissipable || s.Puissance > cx.p*1.25 {
				tenu++
			} else {
				retire++
				continue
			}
		}
		reste = append(reste, s)
	}
	t.Statuts = reste
	if t.Absorption > 0 {
		t.Absorption = 0
		retire++
	}
	for _, o := range c.Combattants {
		if o.Clone && o.Original == t.ID && o.Vivant() {
			c.dissiperClone(o, "Le clone de "+t.Nom+" se dissipe.")
			retire++
		}
	}
	if retire > 0 {
		c.emit(Evenement{Type: "purification", Cible: t.ID, Texte: fmt.Sprintf("Les protections de %s se dissipent (%d).", t.Nom, retire)})
	}
	if tenu > 0 {
		c.emit(Evenement{Type: "resiste", Cible: t.ID, Texte: "Certaines protections de " + t.Nom + " résistent."})
	}
}

// purifier retire les maux du lanceur (sauf ceux scellés par le Silure).
func (c *Combat) purifier(t *Combattant) {
	var reste []*Statut
	retire := 0
	for _, s := range t.Statuts {
		if Maux[s.Type] && !s.Indissipable {
			retire++
			continue
		}
		reste = append(reste, s)
	}
	t.Statuts = reste
	if retire > 0 {
		c.emit(Evenement{Type: "purification", Cible: t.ID, Texte: fmt.Sprintf("%s se purifie (%d maux effacés).", t.Nom, retire)})
	}
}

// passifElement : la signature de chaque élément, au premier coup porté.
func (c *Combat) passifElement(cx *contexte, t *Combattant, base float64, d int) {
	l := cx.lanceur
	switch cx.element {
	case "feu", "lave", "cendre":
		c.ajouterStatut(t, &Statut{Type: SConsume, Tours: 2, Valeur: base * 0.12, Element: cx.element, Nature: grammar.NMagique, Source: l.ID, Puissance: cx.p})
	case "eau", "maree":
		if d > 0 {
			c.soigner(l, l, float64(d)*0.1)
		}
	case "son", "onde":
		c.interrompre(t, "par une onde sonore")
	case "gravite", "seisme":
		if t.Rang > 1 {
			c.placer(t, 1)
			c.emit(Evenement{Type: "deplacement", Acteur: t.ID, Valeur: 1, Texte: t.Nom + " est attiré au premier rang !"})
		}
	case "sel", "cristal":
		c.dissiper(cx, t)
	case "sable", "harmattan":
		if c.chance(0.25) {
			c.ajouterStatut(t, &Statut{Type: "aveugle", Tours: 1, Valeur: 0.4, Element: cx.element, Source: l.ID, Puissance: cx.p, nouveau: true})
			c.emit(Evenement{Type: "statut", Cible: t.ID, Element: cx.element, Texte: t.Nom + " a du sable dans les yeux."})
		}
	case "foudre", "tempete", "magnetisme":
		if c.chance(0.2) {
			c.ajouterStatut(t, &Statut{Type: "immobilise", Tours: 1, Element: cx.element, Source: l.ID, Puissance: cx.p, nouveau: true})
			c.emit(Evenement{Type: "statut", Cible: t.ID, Element: cx.element, Texte: t.Nom + " est paralysé."})
		}
	case "essaim", "fleau":
		if t.Vivant() {
			c.infliger(l, t, base*0.15, grammar.NPur, cx.element, true)
		}
	}
}
