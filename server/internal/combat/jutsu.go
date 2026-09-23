package combat

import (
	"fmt"
	"math"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// MaitriseDecouverte : maîtrise d'un jutsu qu'on vient de découvrir.
const MaitriseDecouverte = 10

// MaitrisePNJ : maîtrise par défaut des jutsus des PNJ.
const MaitrisePNJ = 30

func aMod(mods []string, m string) bool {
	for _, x := range mods {
		if x == m {
			return true
		}
	}
	return false
}

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
			c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: fmt.Sprintf("%s manque de Souffle (%d requis).", f.Nom, cout)})
			f.Garde = true
			return
		}
		f.Souffle -= cout
		inc := &Incantation{Sequence: seq, Echec: e, Refus: refus, Cible: a.Cible, Total: len(seq)}
		if refus == "" {
			inc.Jutsu = j
		}
		if j != nil && aMod(j.ModsForme, data.MSilence) {
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
			c.infliger(nil, f, float64(4+2*len(inc.Sequence)), "", true)
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
	if aMod(j.ModsForme, data.MRetarder) {
		c.emit(Evenement{Type: "jutsu", Acteur: f.ID, Jutsu: j.Nom, Element: j.Element, Texte: f.Nom + " prépare " + j.Nom + " : il frappera au prochain tour."})
		c.differes = append(c.differes, differe{lanceur: f, jutsu: j, cible: inc.Cible, facteur: 1.6, tours: 1})
		return
	}
	c.lancer(f, j, inc.Cible, 1, false)
}

// puissance calcule la valeur de base d'un jutsu pour ce lanceur.
func (c *Combat) puissance(f *Combattant, j *grammar.Jutsu, facteur float64) float64 {
	m := float64(f.maitriseDe(j))
	base := (12 + float64(f.Gnanga)*1.6 + float64(f.Niveau)*1.2) * j.Puissance * (0.8 + 0.4*m/100)
	base *= data.FacteurCosmique(j.Element, c.moment()) * facteur
	if j.Element == "vegetal" || j.Element == "bois_sacre" {
		base *= 1 + 0.05*math.Min(float64(c.Tour), 10) // la sève croît au fil du combat
	}
	if s := f.statut(SRenfort); s != nil {
		base *= 1 + s.Valeur
	}
	return base
}

// lancer applique un jutsu. `echo` : relance différée, sans nouvel écho.
func (c *Combat) lancer(f *Combattant, j *grammar.Jutsu, cibleID string, facteur float64, echo bool) {
	base := c.puissance(f, j, facteur)
	if !echo {
		c.emit(Evenement{Type: "jutsu", Acteur: f.ID, Jutsu: j.Nom, Element: j.Element, Texte: f.Nom + " lance " + j.Nom + " !"})
	}
	if !echo && aMod(j.ModsForme, data.MPersistance) {
		c.differes = append(c.differes, differe{lanceur: f, jutsu: j, cible: cibleID, facteur: 0.5, tours: 1})
	}
	if j.Element == "brume" || j.Element == "vapeur" || j.Element == "songe" {
		c.ajouterStatut(f, &Statut{Type: SVoile, Tours: 1, Valeur: 0.5, Element: j.Element})
	}
	if j.Soutien {
		c.lancerSoutien(f, j, cibleID, base)
		return
	}
	opts := optsDe(j)
	switch j.Forme {
	case data.FCercle:
		for _, t := range c.ennemis(f) {
			c.toucher(f, t, j, base, opts, false)
		}
	case data.FMur:
		abs := base * 1.5
		if j.Element == "terre" || j.Element == "seisme" || j.Element == "lave" {
			abs *= 1.3
		}
		c.Murs[f.Camp] = &Mur{Absorption: int(abs), Tours: 2 + opts.bonus, Element: j.Element, Riposte: j.Effet, Intensite: j.Intensite, Base: base, Lanceur: f.ID}
		c.emit(Evenement{Type: "mur", Acteur: f.ID, Valeur: int(abs), Element: j.Element, Texte: fmt.Sprintf("Un mur se dresse devant le camp de %s (%d).", f.Nom, int(abs))})
	case data.FArmure:
		abs := int(base * 1.2)
		f.Absorption += abs
		c.ajouterStatut(f, &Statut{Type: SRiposte, Tours: 3 + opts.bonus, Valeur: j.Intensite, Base: base, Effet: j.Effet, Element: j.Element})
		c.emit(Evenement{Type: "armure", Acteur: f.ID, Valeur: abs, Element: j.Element, Texte: fmt.Sprintf("%s se couvre d'une armure de Souffle (%d).", f.Nom, abs)})
	case data.FDouble:
		c.ajouterStatut(f, &Statut{Type: SLeurre, Tours: 2 + opts.bonus, Valeur: j.Intensite, Base: base, Effet: j.Effet, Element: j.Element})
		c.emit(Evenement{Type: "double", Acteur: f.ID, Element: j.Element, Texte: f.Nom + " crée un double."})
	case data.FPas:
		if f.Rang > 1 {
			c.placer(f, 1)
		} else {
			c.placer(f, NbRangs)
		}
		c.ajouterStatut(f, &Statut{Type: SVoile, Tours: 1, Valeur: 0.5, Element: j.Element})
		c.emit(Evenement{Type: "deplacement", Acteur: f.ID, Valeur: f.Rang, Texte: fmt.Sprintf("%s bondit au rang %d.", f.Nom, f.Rang)})
		if t := c.cibleEnnemie(f, "", true); t != nil {
			c.toucher(f, t, j, base, opts, true)
		}
	case data.FInvocation:
		c.ajouterStatut(f, &Statut{Type: SInvocation, Tours: 3 + opts.bonus, Valeur: j.Intensite, Base: base, Effet: j.Effet, Element: j.Element})
		c.emit(Evenement{Type: "invoque", Acteur: f.ID, Element: j.Element, Texte: f.Nom + " invoque une créature de Souffle."})
	case data.FPiege:
		t := c.cibleEnnemie(f, cibleID, false)
		if t == nil {
			return
		}
		c.ajouterStatut(t, &Statut{Type: SPiege, Tours: 3, Valeur: j.Intensite, Base: base * 1.2, Effet: j.Effet, Element: j.Element, Source: f.ID})
		c.emit(Evenement{Type: "piege_pose", Acteur: f.ID, Cible: t.ID, Element: j.Element, Texte: f.Nom + " tend un piège sous les pieds de " + t.Nom + "."})
	default: // trait, lame, lien
		contact := j.Forme == data.FLame
		if contact && f.Rang > 2 {
			c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: "Trop loin : la lame de Souffle se dissipe."})
			return
		}
		t := c.cibleEnnemie(f, cibleID, contact)
		if t == nil {
			c.emit(Evenement{Type: "info", Acteur: f.ID, Texte: "Aucune cible à portée."})
			return
		}
		cibles := []*Combattant{t}
		if aMod(j.ModsForme, data.MEtendre) {
			for _, o := range c.ennemis(f) {
				if o != t && (o.Rang == t.Rang+1 || o.Rang == t.Rang-1) {
					cibles = append(cibles, o)
					break
				}
			}
		}
		for i, cible := range cibles {
			b := base
			if i > 0 {
				b *= 0.7
			}
			c.toucher(f, cible, j, b, opts, contact)
		}
	}
}

// effetOpts : modulation des effets par les modificateurs.
type effetOpts struct {
	bonus    int     // tours en plus
	mult     int     // multiplicateur de durée
	silence  bool    // impossible à purifier
	propage  bool    // effet propagé à une autre cible
	lien     bool    // forme Lien : effet renforcé
	intensMu float64 // multiplicateur d'intensité supplémentaire
	element  string  // élément du jutsu (le venin s'accumule)
}

func optsDe(j *grammar.Jutsu) effetOpts {
	o := effetOpts{mult: 1, intensMu: 1, element: j.Element}
	for _, m := range j.ModsEffet {
		switch m {
		case data.MEtendre:
			o.bonus += 2
		case data.MPersistance, data.MRetarder:
			o.mult = 2
		case data.MSilence:
			o.silence = true
		case data.MMultiplier:
			o.propage = true
		}
	}
	if j.Forme == data.FLien {
		o.lien = true
		o.bonus++
		o.intensMu = 1.5
	}
	return o
}

func (o effetOpts) duree(n int) int {
	m := o.mult
	if m == 0 {
		m = 1
	}
	return (n + o.bonus) * m
}

// toucher : un jutsu offensif atteint une cible.
func (c *Combat) toucher(f, t *Combattant, j *grammar.Jutsu, base float64, opts effetOpts, contact bool) {
	if !t.Vivant() {
		return
	}
	frappes, mult := 1, 1.0
	if aMod(j.ModsForme, data.MMultiplier) {
		frappes, mult = 2, 0.6
	}
	for n := 0; n < frappes && t.Vivant(); n++ {
		if j.Forme != data.FCercle {
			if c.intercepter(f, t) {
				continue
			}
			if j.Forme == data.FTrait && c.chance(esquive(t)/2) {
				c.emit(Evenement{Type: "esquive", Acteur: f.ID, Cible: t.ID, Texte: t.Nom + " esquive le jutsu."})
				continue
			}
		}
		d := c.infliger(f, t, base*mult, j.Element, false)
		if !t.Vivant() {
			break
		}
		c.passifElement(f, t, j, base*mult, d)
		c.appliquerEffet(f, t, j.Effet, j.Intensite*opts.intensMu, base, d, opts)
		if j.Effet2 != "" && t.Vivant() {
			c.appliquerEffet(f, t, j.Effet2, j.Intensite*opts.intensMu*0.6, base, d, opts)
		}
		if contact {
			c.riposter(t, f)
		}
	}
	if opts.propage && f.Vivant() {
		for _, o := range c.ennemis(f) {
			if o != t {
				c.emit(Evenement{Type: "info", Acteur: f.ID, Cible: o.ID, Texte: "L'effet se propage à " + o.Nom + "."})
				c.appliquerEffet(f, o, j.Effet, j.Intensite*0.7, base, 0, effetOpts{mult: 1, intensMu: 1})
				break
			}
		}
	}
}

// passifElement : la signature de chaque élément.
func (c *Combat) passifElement(f, t *Combattant, j *grammar.Jutsu, base float64, d int) {
	switch j.Element {
	case "feu", "lave", "cendre":
		if j.Effet != data.XConsumer {
			c.ajouterStatut(t, &Statut{Type: SConsume, Tours: 2, Valeur: base * 0.12, Element: j.Element})
		}
	case "eau", "maree":
		c.soigner(f, f, float64(d)*0.1)
	case "son", "onde":
		c.interrompre(t, "par une onde sonore")
	case "gravite", "seisme":
		if t.Rang > 1 {
			c.placer(t, 1)
			c.emit(Evenement{Type: "deplacement", Acteur: t.ID, Valeur: 1, Texte: t.Nom + " est attiré au premier rang !"})
		}
	case "sel", "cristal":
		c.purifier(t)
	case "sable", "harmattan":
		if c.chance(25) {
			c.ajouterStatut(t, &Statut{Type: SAveugle, Tours: 1, Valeur: 0.4, Element: j.Element})
		}
	case "foudre", "tempete", "magnetisme":
		if c.chance(20) {
			c.ajouterStatut(t, &Statut{Type: SEntrave, Tours: 1, Element: j.Element})
			c.emit(Evenement{Type: "statut", Cible: t.ID, Element: j.Element, Texte: t.Nom + " est paralysé."})
		}
	case "essaim", "fleau":
		if t.Vivant() {
			c.infliger(f, t, base*0.15, j.Element, true)
		}
	}
}

// purifier retire les bienfaits d'une cible (sauf ceux scellés par le Silence).
func (c *Combat) purifier(t *Combattant) {
	var reste []*Statut
	retire := false
	for _, s := range t.Statuts {
		bienfait := s.Type == SVoile || s.Type == SRenfort || s.Type == SRegen || s.Type == SRiposte
		if bienfait && !s.Silence {
			retire = true
			continue
		}
		reste = append(reste, s)
	}
	t.Statuts = reste
	if t.Absorption > 0 {
		t.Absorption = 0
		retire = true
	}
	if retire {
		c.emit(Evenement{Type: "purification", Cible: t.ID, Texte: "Le Sel purifie " + t.Nom + " : ses protections s'effacent."})
	}
}

// appliquerEffet applique un effet de jutsu. Les effets de soutien placés
// en second sur un jutsu offensif profitent au lanceur.
func (c *Combat) appliquerEffet(f, t *Combattant, effet string, intens, base float64, degats int, o effetOpts) {
	if effet == "" {
		return
	}
	if o.mult == 0 {
		o.mult = 1
	}
	switch effet {
	case data.XConsumer:
		c.ajouterStatut(t, &Statut{Type: SConsume, Tours: o.duree(3), Valeur: base * 0.25 * intens, Element: o.element, Silence: o.silence})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " est rongé par le Souffle."})
	case data.XLier:
		c.ajouterStatut(t, &Statut{Type: SEntrave, Tours: o.duree(2), Silence: o.silence})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " est entravé."})
	case data.XAveugler:
		c.ajouterStatut(t, &Statut{Type: SAveugle, Tours: o.duree(2), Valeur: math.Min(0.7, 0.4*intens), Silence: o.silence})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " est aveuglé."})
	case data.XRepousser:
		if t.Rang < len(c.Vivants(t.Camp)) {
			c.placer(t, t.Rang+1)
			c.emit(Evenement{Type: "deplacement", Acteur: t.ID, Valeur: t.Rang, Texte: t.Nom + " est repoussé au rang " + fmt.Sprint(t.Rang) + "."})
		}
		c.interrompre(t, "par le choc")
	case data.XDrainer:
		c.soigner(f, f, float64(degats)*0.5*intens)
		gain := int(float64(degats) * 0.2 * intens)
		f.Souffle = min(f.SouffleMax, f.Souffle+gain)
	case data.XBriser:
		c.ajouterStatut(t, &Statut{Type: SAffaibli, Tours: o.duree(3), Valeur: 0.5, Silence: o.silence})
		t.Absorption = 0
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: "Les défenses de " + t.Nom + " sont brisées."})
		c.interrompre(t, "net")
	case data.XMarquer:
		c.ajouterStatut(t, &Statut{Type: SMarque, Tours: o.duree(3), Valeur: 0.25 * intens, Silence: o.silence})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " est marqué."})
	// Effets de soutien en effet secondaire : ils profitent au lanceur.
	case data.XSoigner:
		c.soigner(f, f, math.Max(float64(degats)*0.4, base*0.2)*intens)
	case data.XRenforcer:
		c.ajouterStatut(f, &Statut{Type: SRenfort, Tours: o.duree(2), Valeur: 0.2 * intens})
	case data.XDissimuler:
		c.ajouterStatut(f, &Statut{Type: SVoile, Tours: o.duree(1), Valeur: 0.5})
	}
}

// lancerSoutien : jutsu dont l'effet principal vise les alliés.
func (c *Combat) lancerSoutien(f *Combattant, j *grammar.Jutsu, cibleID string, base float64) {
	opts := optsDe(j)
	allies := c.Vivants(f.Camp)
	var cibles []*Combattant
	switch j.Forme {
	case data.FCercle, data.FMur, data.FInvocation:
		cibles = allies
	case data.FArmure, data.FPas, data.FDouble:
		cibles = []*Combattant{f}
	default:
		t := c.Get(cibleID)
		if t == nil || !t.Vivant() || t.Camp != f.Camp {
			t = plusBlesse(allies)
		}
		cibles = []*Combattant{t}
	}
	switch j.Forme {
	case data.FMur:
		abs := int(base * 1.2)
		c.Murs[f.Camp] = &Mur{Absorption: abs, Tours: 2 + opts.bonus, Element: j.Element, Lanceur: f.ID}
		c.emit(Evenement{Type: "mur", Acteur: f.ID, Valeur: abs, Element: j.Element, Texte: fmt.Sprintf("Un mur protecteur se dresse (%d).", abs)})
	case data.FArmure:
		f.Absorption += int(base)
	case data.FPas:
		if f.Rang > 1 {
			c.placer(f, f.Rang-1)
		} else {
			c.placer(f, NbRangs)
		}
	case data.FDouble:
		c.ajouterStatut(f, &Statut{Type: SLeurre, Tours: 2})
	}
	for _, t := range cibles {
		c.soutenir(f, t, j.Effet, j.Intensite*opts.intensMu, base, opts, j.Forme == data.FInvocation)
		if EffetSoutienSecondaire(j.Effet2) {
			c.soutenir(f, t, j.Effet2, j.Intensite*0.6, base, opts, false)
		}
	}
}

// EffetSoutienSecondaire : l'effet secondaire d'un soutien est-il aussi un soutien ?
func EffetSoutienSecondaire(e string) bool { return e != "" && grammar.EffetSoutien(e) }

func (c *Combat) soutenir(f, t *Combattant, effet string, intens, base float64, o effetOpts, durable bool) {
	switch effet {
	case data.XSoigner:
		if durable || o.bonus > 0 || o.mult > 1 {
			c.ajouterStatut(t, &Statut{Type: SRegen, Tours: o.duree(3), Valeur: base * 0.3 * intens})
		}
		if !durable {
			c.soigner(f, t, base*0.9*intens)
		}
	case data.XRenforcer:
		c.ajouterStatut(t, &Statut{Type: SRenfort, Tours: o.duree(3), Valeur: 0.25 * intens, Silence: o.silence})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " est renforcé."})
	case data.XDissimuler:
		c.ajouterStatut(t, &Statut{Type: SVoile, Tours: o.duree(2), Valeur: 0.5, Silence: o.silence})
		c.emit(Evenement{Type: "statut", Cible: t.ID, Texte: t.Nom + " se fond dans le Souffle."})
	}
}

func plusBlesse(l []*Combattant) *Combattant {
	var best *Combattant
	for _, f := range l {
		if best == nil || float64(f.PV)/float64(f.PVMax) < float64(best.PV)/float64(best.PVMax) {
			best = f
		}
	}
	return best
}
