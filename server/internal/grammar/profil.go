package grammar

import (
	"crypto/sha256"
	"math"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

// Le profil de combat d'un jutsu.
//
// Chaque jutsu appartient à l'un des cinq types, donné par son mudra d'effet :
//
//	dégâts   : Braise (magiques), Hache (physiques), Kaolin (purs)
//	défense  : Racine
//	entrave  : Bélier (mouvement, fuite), Liane (frapper, garde, mudras)
//	illusion : Voile (tromper), Feuille (se rendre insaisissable)
//	soin     : Kola (soins), Moustique (drain, soins après le combat)
//
// La forme choisit l'effet précis dans une table de 10 × 10 cellules,
// toutes différentes. Les modificateurs transforment l'effet, et leur ordre
// compte : le premier signe de maîtrise pèse plus lourd que le second.
// Enfin les coefficients (Fangan, Gnanga, Manhis) dépendent du type, de
// l'élément, de la forme et de la suite exacte : deux jutsus n'ont jamais
// la même valeur.

// Types de jutsu.
const (
	TDegats   = "degats"
	TDefense  = "defense"
	TEntrave  = "entrave"
	TIllusion = "illusion"
	TSoin     = "soin"
)

// Natures des dégâts.
const (
	NPhysique = "physique"
	NMagique  = "magique"
	NPur      = "pur"
)

// Opérations élémentaires d'un effet.
const (
	OpDegats      = "degats"      // dégâts directs
	OpDot         = "dot"         // brûlure : dégâts par tour
	OpStatut      = "statut"      // statut durable
	OpBouclier    = "bouclier"    // PV temporaires
	OpSoin        = "soin"        // soigne le lanceur
	OpDrain       = "drain"       // dégâts, dont une part soigne le lanceur
	OpDeplacer    = "deplacer"    // déplace une cible (repousser, attirer)
	OpBond        = "bond"        // le lanceur change de rang
	OpClone       = "clone"       // clones indiscernables du lanceur
	OpDissiper    = "dissiper"    // retire les protections d'une cible
	OpPurifier    = "purifier"    // retire les maux du lanceur
	OpInterrompre = "interrompre" // brise une incantation
	OpRiposte     = "riposte"     // qui frappe la cible subit la charge
	OpPiege       = "piege"       // la cible déclenche la charge en agissant
	OpInvocation  = "invocation"  // une créature applique la charge chaque tour
	OpDeclencheur = "declencheur" // la charge part quand le lanceur faiblit
	OpDiffere     = "differe"     // la charge part plus tard
	OpAnnuler     = "annuler"     // annule l'action de la victime d'un piège
)

// Cibles d'un effet.
const (
	CSoi           = "soi"
	CAllies        = "allies"
	CEnnemi        = "ennemi"
	CEnnemiEtendu  = "ennemi_etendu"
	CContact       = "contact"
	CContactEtendu = "contact_etendu"
	CEnnemis       = "ennemis"
	CFront         = "front"
	CAleatoire     = "aleatoire"
	CAttaquant     = "attaquant"
	CDeclencheur   = "declencheur"
)

// Effet : une opération élémentaire. Les montants (Mult) sont des parts de
// la puissance du jutsu au moment du lancer.
type Effet struct {
	Op      string  `json:"op"`
	Cible   string  `json:"cible,omitempty"`
	Nature  string  `json:"nature,omitempty"`
	Mult    float64 `json:"mult,omitempty"`
	Frappes int     `json:"frappes,omitempty"`
	Statut  string  `json:"statut,omitempty"`
	Duree   int     `json:"duree,omitempty"`
	Valeur  float64 `json:"valeur,omitempty"`
	Vers    string  `json:"vers,omitempty"`
	Nombre  int     `json:"nombre,omitempty"`
	Part    float64 `json:"part,omitempty"`    // part reçue par les cibles secondaires (voisine, alliés)
	Propage float64 `json:"propage,omitempty"` // part propagée à un second adversaire
	Effets  []Effet `json:"effets,omitempty"`  // charge (riposte, piège, invocation…)
}

// Coefs : puissance = (8 + F·Fangan + G·Gnanga + M·Manhis) × N.
type Coefs struct {
	F float64 `json:"f"`
	G float64 `json:"g"`
	M float64 `json:"m"`
	N float64 `json:"n"`
}

// TypeEffet : le type de jutsu donné par chaque mudra d'effet.
var TypeEffet = map[string]string{
	data.XConsumer: TDegats, data.XBriser: TDegats, data.XMarquer: TDegats,
	data.XRenforcer: TDefense,
	data.XRepousser: TEntrave, data.XLier: TEntrave,
	data.XAveugler: TIllusion, data.XDissimuler: TIllusion,
	data.XSoigner: TSoin, data.XDrainer: TSoin,
}

// NatureEffet : la nature des dégâts des jutsus de dégâts.
var NatureEffet = map[string]string{
	data.XConsumer: NMagique, data.XBriser: NPhysique, data.XMarquer: NPur,
}

// Statuts hostiles soumis à un jet de résistance (entraves, illusions).
var StatutsControle = map[string]bool{
	"immobilise": true, "retenu": true, "desarme": true, "scelle": true, "sans_garde": true,
	"confus": true, "endormi": true, "aveugle": true, "egare": true, "hasard": true,
}

// StatutsDrapeau : statuts à usage unique, sans valeur.
var StatutsDrapeau = map[string]bool{"parade": true, "reflet": true, "deviation": true}

// --- Constructeurs de la table ------------------------------------------

func deg(cible string, mult float64) Effet {
	return Effet{Op: OpDegats, Cible: cible, Mult: mult, Frappes: 1}
}
func degN(cible, nature string, mult float64) Effet {
	return Effet{Op: OpDegats, Cible: cible, Nature: nature, Mult: mult, Frappes: 1}
}
func dot(cible string, mult float64, duree int) Effet {
	return Effet{Op: OpDot, Cible: cible, Mult: mult, Duree: duree}
}
func st(cible, statut string, duree int, valeur float64) Effet {
	return Effet{Op: OpStatut, Cible: cible, Statut: statut, Duree: duree, Valeur: valeur}
}
func bouclier(cible string, mult float64) Effet {
	return Effet{Op: OpBouclier, Cible: cible, Mult: mult}
}
func soin(mult float64) Effet { return Effet{Op: OpSoin, Cible: CSoi, Mult: mult} }
func drain(cible, nature string, mult, ratio float64) Effet {
	return Effet{Op: OpDrain, Cible: cible, Nature: nature, Mult: mult, Valeur: ratio, Frappes: 1}
}
func deplacer(cible, vers string) Effet { return Effet{Op: OpDeplacer, Cible: cible, Vers: vers} }
func bond(vers string) Effet            { return Effet{Op: OpBond, Cible: CSoi, Vers: vers} }
func clone(n, duree int) Effet {
	return Effet{Op: OpClone, Cible: CSoi, Nombre: n, Duree: duree, Valeur: 0.3}
}
func simple(op, cible string) Effet { return Effet{Op: op, Cible: cible} }
func charge(op, cible string, duree int, valeur float64, effets ...Effet) Effet {
	return Effet{Op: op, Cible: cible, Duree: duree, Valeur: valeur, Effets: effets}
}

// Cellules : l'effet de chaque couple effet × forme.
var Cellules = map[string]map[string][]Effet{}

func init() {
	// Les trois effets de dégâts partagent un gabarit ; seule la nature
	// change (magique, physique, pure), et avec elle les coefficients.
	degats := func() map[string][]Effet {
		return map[string][]Effet{
			data.FTrait:      {deg(CEnnemi, 1.0)},
			data.FLame:       {deg(CContact, 1.35)},
			data.FMur:        {charge(OpRiposte, CAllies, 3, 0, deg(CAttaquant, 0.5))},
			data.FCercle:     {deg(CEnnemis, 0.55)},
			data.FDouble:     {deg(CEnnemi, 0.6), clone(1, 1)},
			data.FLien:       {deg(CEnnemi, 0.35), dot(CEnnemi, 0.3, 3)},
			data.FArmure:     {bouclier(CSoi, 0.5), charge(OpRiposte, CSoi, 3, 0, deg(CAttaquant, 0.45))},
			data.FPiege:      {charge(OpPiege, CEnnemi, 3, 0, deg(CDeclencheur, 1.3))},
			data.FInvocation: {charge(OpInvocation, CSoi, 3, 0, deg(CAleatoire, 0.45))},
			data.FPas:        {bond("avant"), deg(CFront, 0.8)},
		}
	}
	Cellules[data.XConsumer] = degats()
	Cellules[data.XBriser] = degats()
	Cellules[data.XMarquer] = degats()

	Cellules[data.XRenforcer] = map[string][]Effet{
		data.FTrait:      {st(CSoi, "def_mag", 3, 0.35)},
		data.FLame:       {st(CSoi, "def_phys", 3, 0.35)},
		data.FMur:        {st(CAllies, "def_phys", 2, 0.25), st(CAllies, "def_mag", 2, 0.25)},
		data.FCercle:     {bouclier(CAllies, 0.45)},
		data.FDouble:     {st(CSoi, "renvoi", 3, 0.35)},
		data.FLien:       {bouclier(CSoi, 1.1)},
		data.FArmure:     {st(CSoi, "def_phys", 4, 0.3), st(CSoi, "def_mag", 4, 0.3)},
		data.FPiege:      {st(CSoi, "parade", 3, 1)},
		data.FInvocation: {charge(OpInvocation, CSoi, 3, 0, bouclier(CSoi, 0.3))},
		data.FPas:        {bond("arriere"), bouclier(CSoi, 0.6)},
	}

	Cellules[data.XRepousser] = map[string][]Effet{
		data.FTrait:      {deplacer(CEnnemi, "arriere"), simple(OpInterrompre, CEnnemi)},
		data.FLame:       {st(CContact, "immobilise", 2, 0)},
		data.FMur:        {st(CEnnemis, "retenu", 3, 0), st(CEnnemis, "immobilise", 1, 0)},
		data.FCercle:     {deplacer(CEnnemis, "arriere"), simple(OpInterrompre, CEnnemis)},
		data.FDouble:     {deplacer(CEnnemi, "avant"), st(CEnnemi, "immobilise", 2, 0)},
		data.FLien:       {st(CEnnemi, "immobilise", 3, 0), st(CEnnemi, "retenu", 4, 0)},
		data.FArmure:     {charge(OpRiposte, CSoi, 3, 0, st(CAttaquant, "immobilise", 2, 0))},
		data.FPiege:      {charge(OpPiege, CEnnemi, 3, 0, st(CDeclencheur, "immobilise", 2, 0), st(CDeclencheur, "retenu", 3, 0))},
		data.FInvocation: {charge(OpInvocation, CSoi, 3, 0, st(CAleatoire, "immobilise", 1, 0))},
		data.FPas:        {bond("avant"), deplacer(CFront, "arriere")},
	}

	Cellules[data.XLier] = map[string][]Effet{
		data.FTrait:      {st(CEnnemi, "desarme", 2, 0)},
		data.FLame:       {degN(CContact, NPhysique, 0.3), st(CContact, "sans_garde", 3, 0)},
		data.FMur:        {st(CEnnemis, "desarme", 1, 0)},
		data.FCercle:     {st(CEnnemis, "scelle", 1, 0), simple(OpInterrompre, CEnnemis)},
		data.FDouble:     {st(CEnnemi, "desarme", 2, 0), st(CEnnemi, "sans_garde", 2, 0)},
		data.FLien:       {st(CEnnemi, "scelle", 3, 0), simple(OpInterrompre, CEnnemi)},
		data.FArmure:     {charge(OpRiposte, CSoi, 3, 0, st(CAttaquant, "desarme", 2, 0))},
		data.FPiege:      {charge(OpPiege, CEnnemi, 3, 0, st(CDeclencheur, "scelle", 2, 0))},
		data.FInvocation: {charge(OpInvocation, CSoi, 3, 0, st(CAleatoire, "hasard", 1, 0))},
		data.FPas:        {bond("avant"), st(CFront, "scelle", 2, 0)},
	}

	Cellules[data.XAveugler] = map[string][]Effet{
		data.FTrait:      {st(CEnnemi, "confus", 2, 0.5)},
		data.FLame:       {st(CContact, "aveugle", 3, 0.5)},
		data.FMur:        {st(CEnnemis, "egare", 2, 0)},
		data.FCercle:     {st(CAllies, "esquive", 2, 0.35)},
		data.FDouble:     {clone(1, 3)},
		data.FLien:       {st(CEnnemi, "endormi", 2, 0)},
		data.FArmure:     {st(CSoi, "reflet", 3, 1)},
		data.FPiege:      {charge(OpPiege, CEnnemi, 3, 0, simple(OpAnnuler, CDeclencheur))},
		data.FInvocation: {clone(2, 2)},
		data.FPas:        {bond("arriere"), st(CSoi, "invisible", 1, 0)},
	}

	Cellules[data.XDissimuler] = map[string][]Effet{
		data.FTrait:      {st(CSoi, "deviation", 3, 1)},
		data.FLame:       {simple(OpDissiper, CContact), st(CSoi, "esquive", 1, 0.3)},
		data.FMur:        {st(CAllies, "intangible_mag", 1, 0)},
		data.FCercle:     {st(CAllies, "intangible_phys", 1, 0)},
		data.FDouble:     {st(CSoi, "intangible_mag", 2, 0)},
		data.FLien:       {simple(OpDissiper, CEnnemi), st(CEnnemi, "marque", 3, 0.2)},
		data.FArmure:     {st(CSoi, "intangible_phys", 2, 0)},
		data.FPiege:      {st(CSoi, "disparu", 1, 0)},
		data.FInvocation: {st(CSoi, "leurre", 3, 2)},
		data.FPas:        {bond("arriere"), st(CSoi, "esquive", 2, 0.8)},
	}

	Cellules[data.XSoigner] = map[string][]Effet{
		data.FTrait:      {soin(1.0)},
		data.FLame:       {soin(0.6), simple(OpPurifier, CSoi)},
		data.FMur:        {st(CSoi, "regen", 4, 0.3)},
		data.FCercle:     {soin(0.5), st(CSoi, "regen", 2, 0.25)},
		data.FDouble:     {charge(OpDeclencheur, CSoi, 4, 0.3, soin(1.4))},
		data.FLien:       {charge(OpDiffere, CSoi, 2, 0, soin(1.8))},
		data.FArmure:     {bouclier(CSoi, 0.3), st(CSoi, "regen", 3, 0.4)},
		data.FPiege:      {charge(OpRiposte, CSoi, 3, 0, soin(0.4))},
		data.FInvocation: {charge(OpInvocation, CSoi, 3, 0, soin(0.35))},
		data.FPas:        {bond("arriere"), soin(0.7)},
	}

	Cellules[data.XDrainer] = map[string][]Effet{
		data.FTrait:      {drain(CEnnemi, NMagique, 0.7, 0.6)},
		data.FLame:       {drain(CContact, NPhysique, 0.9, 0.5)},
		data.FMur:        {st(CSoi, "baume", 0, 1.5)},
		data.FCercle:     {drain(CEnnemis, NMagique, 0.3, 0.5)},
		data.FDouble:     {st(CSoi, "second_souffle", 5, 0.5)},
		data.FLien:       {st(CEnnemi, "sangsue", 3, 0.3)},
		data.FArmure:     {charge(OpRiposte, CSoi, 3, 0, drain(CAttaquant, NPur, 0.3, 1.0))},
		data.FPiege:      {charge(OpPiege, CEnnemi, 3, 0, drain(CDeclencheur, NMagique, 1.0, 0.6))},
		data.FInvocation: {charge(OpInvocation, CSoi, 3, 0, drain(CAleatoire, NMagique, 0.3, 0.6))},
		data.FPas:        {bond("arriere"), st(CSoi, "baume", 0, 0.8)},
	}
}

// --- Coefficients ----------------------------------------------------------

type inclinaison struct{ F, G, M float64 }

// basesType : les coefficients de départ de chaque type (et nature).
var basesType = map[string]Coefs{
	"degats_" + NPhysique: {F: 1.0, G: 0.15, M: 0.45, N: 1.0},
	"degats_" + NMagique:  {F: 0.15, G: 1.05, M: 0.35, N: 1.0},
	"degats_" + NPur:      {F: 0.35, G: 0.35, M: 0.35, N: 0.85},
	TDefense:              {F: 0.7, G: 0.5, M: 0.2, N: 1.2},
	TEntrave:              {F: 0.2, G: 0.8, M: 0.5, N: 1.0},
	TIllusion:             {F: 0.2, G: 0.6, M: 0.9, N: 1.0},
	TSoin:                 {F: 0.4, G: 0.9, M: 0.2, N: 1.3},
}

// inclinaisonsElement : chaque élément penche vers un attribut.
var inclinaisonsElement = map[string]inclinaison{
	"feu": {0.05, 0.15, 0}, "eau": {0, 0.1, 0.05}, "vent": {0, 0, 0.15}, "terre": {0.15, 0, -0.05},
	"foudre": {0, 0.05, 0.12}, "vegetal": {0.08, 0.08, -0.04}, "metal": {0.12, 0.04, 0}, "son": {-0.04, 0.12, 0.06},
	"sable": {0.06, 0, 0.08}, "venin": {-0.05, 0.08, 0.1}, "brume": {-0.05, 0.05, 0.14}, "sel": {0.03, 0.1, 0.03},
	"essaim": {0, 0.03, 0.13}, "soleil": {0.1, 0.1, -0.05}, "lune": {-0.05, 0.14, 0.04}, "gravite": {0.14, 0.06, -0.08},
	"ivoire": {0.12, 0.12, 0.12}, "esprit": {0, 0.2, 0.05}, "lumiere": {0.05, 0.18, 0.05}, "ombre": {0.05, 0.05, 0.18},
	"vie": {0.15, 0.1, 0}, "temps": {0, 0.1, 0.2}, "vide": {0.18, 0.05, 0.05}, "astre": {0.08, 0.16, 0.08},
}

// inclinaisonsForme : une lame demande de la force, un pas de l'agilité…
var inclinaisonsForme = map[string]inclinaison{
	data.FTrait: {0, 0, 0.08}, data.FLame: {0.1, 0, 0}, data.FMur: {0.06, 0.03, 0},
	data.FCercle: {0, 0.08, 0}, data.FDouble: {0, 0, 0.1}, data.FLien: {0, 0.06, 0.04},
	data.FArmure: {0.08, 0, 0.02}, data.FPiege: {0.02, 0.06, 0.02}, data.FInvocation: {0, 0.1, 0},
	data.FPas: {0, 0, 0.12},
}

// InclinaisonElement : un élément rare hérite de ses deux parents.
func InclinaisonElement(id string) (float64, float64, float64) {
	if t, ok := inclinaisonsElement[id]; ok {
		return t.F, t.G, t.M
	}
	e := data.Elements[id]
	if e == nil || len(e.Fusion) != 2 {
		return 0, 0, 0
	}
	a, b := inclinaisonsElement[e.Fusion[0]], inclinaisonsElement[e.Fusion[1]]
	return (a.F + b.F) / 2 * 1.25, (a.G + b.G) / 2 * 1.25, (a.M + b.M) / 2 * 1.25
}

// SelSignature : la signature d'une suite fait varier ses coefficients.
const SelSignature = "ninja-ivoire:signature:"

func arrondi2(x float64) float64 { return math.Round(x*100) / 100 }
func arrondi3(x float64) float64 { return math.Round(x*1000) / 1000 }

// forceModificateur : le premier signe de maîtrise pèse plus que le second.
func forceModificateur(i int) float64 {
	if i == 0 {
		return 1
	}
	return 0.6
}

// profiler calcule le type, la nature, les coefficients et les effets.
func profiler(j *Jutsu) {
	j.Type = TypeEffet[j.Effet]
	j.DegatsNature = NatureEffet[j.Effet]
	eff := clonerEffets(Cellules[j.Effet][j.Forme])
	fixerNature(eff, j.DegatsNature)
	if j.Effet2 != "" {
		e2 := clonerEffets(Cellules[j.Effet2][j.Forme])
		fixerNature(e2, NatureEffet[j.Effet2])
		eff = append(eff, affaiblir(e2)...)
	}

	cle := "degats_" + j.DegatsNature
	if j.Type != TDegats {
		cle = j.Type
	}
	b := basesType[cle]
	n := b.N * (1 + 0.12*float64(len(j.Sequence)-3))
	switch data.Elements[j.Element].Tier {
	case data.TierRare:
		n *= 1.3
	case data.TierMythique:
		n *= 1.6
	}

	k := 0 // rang du modificateur dans la suite
	for _, m := range j.ModsForme {
		s := forceModificateur(k)
		k++
		switch m {
		case data.MAmplifier:
			n *= 1 + 0.35*s
		case data.MEtendre:
			n *= 1 - 0.15*s
			elargir(eff, s)
		case data.MMultiplier:
			n *= 1 - 0.1*s
			multiplier(eff)
		case data.MRetarder:
			n *= 1 + 0.5*s
			j.Delai = true
		case data.MSilence:
			n *= 1 - 0.05*s
			j.Incassable = true
		case data.MPersistance:
			j.Echo = arrondi2(0.5 * s)
		}
	}
	for _, m := range j.ModsEffet {
		s := forceModificateur(k)
		k++
		switch m {
		case data.MAmplifier:
			// Les effets s'intensifient ; les dégâts un peu moins.
			for i := range eff {
				if eff[i].Op == OpDegats || eff[i].Op == OpDrain {
					eff[i].Mult *= 1 + 0.2*s
				} else {
					amplifier(&eff[i], 1+0.4*s)
				}
			}
		case data.MEtendre:
			// Les effets s'étendent à une cible voisine ou à tout le camp ;
			// sinon, ils gagnent un peu d'ampleur.
			if !elargir(eff, s) {
				for i := range eff {
					amplifier(&eff[i], 1+0.1*s)
				}
			}
		case data.MMultiplier:
			// L'effet se propage à un second adversaire ; sinon, il se renouvelle
			// deux tours plus tard.
			if !propager(eff, arrondi2(0.5*s)) {
				rappel := sansBond(clonerEffets(eff))
				for i := range rappel {
					amplifier(&rappel[i], 0.5+0.5*s)
				}
				eff = append(eff, Effet{Op: OpDiffere, Cible: CSoi, Duree: 2, Effets: rappel})
			}
		case data.MRetarder:
			eff = retarder(eff, 1+0.6*s)
		case data.MPersistance:
			// Les effets durent deux fois plus ; faute de durée, ils reviennent
			// affaiblis au tour suivant.
			if !allonger(eff, func(d int) int { return 2*d + int(s) }) {
				rappel := sansBond(clonerEffets(eff))
				for i := range rappel {
					rappel[i].Mult *= 0.4 * s
					rappel[i].Valeur *= 0.4 * s
				}
				eff = append(eff, Effet{Op: OpDiffere, Cible: CSoi, Duree: 1, Effets: rappel})
			}
		case data.MSilence:
			j.Indissipable = true
		}
	}
	arrondirEffets(eff)
	j.Effets = eff

	ef, eg, em := InclinaisonElement(j.Element)
	tf := inclinaisonsForme[j.Forme]
	sig := sha256.Sum256([]byte(SelSignature + j.Cle))
	jit := func(i int) float64 { return 0.9 + 0.2*float64(sig[i])/255 }
	j.Coefs = Coefs{
		F: arrondi3(math.Max(0.05, (b.F+ef+tf.F)*jit(0))),
		G: arrondi3(math.Max(0.05, (b.G+eg+tf.G)*jit(1))),
		M: arrondi3(math.Max(0.05, (b.M+em+tf.M)*jit(2))),
		N: arrondi3(n),
	}
}

// ciblesUniques : cibles d'un seul adversaire.
var ciblesUniques = map[string]bool{CEnnemi: true, CContact: true, CEnnemiEtendu: true, CContactEtendu: true, CFront: true}

// allonger change la durée des effets durables (pas le délai d'un effet
// différé) ; renvoie false s'il n'y en a aucun.
func allonger(l []Effet, f func(int) int) bool {
	ok := false
	for i := range l {
		if l[i].Duree > 0 && l[i].Op != OpDiffere {
			l[i].Duree = f(l[i].Duree)
			ok = true
		}
	}
	return ok
}

func clonerEffets(l []Effet) []Effet {
	out := make([]Effet, len(l))
	for i, e := range l {
		out[i] = e
		if e.Effets != nil {
			out[i].Effets = clonerEffets(e.Effets)
		}
	}
	return out
}

// fixerNature donne leur nature aux dégâts qui n'en ont pas.
func fixerNature(l []Effet, nature string) {
	if nature == "" {
		nature = NMagique
	}
	for i := range l {
		if (l[i].Op == OpDegats || l[i].Op == OpDot || l[i].Op == OpDrain) && l[i].Nature == "" {
			l[i].Nature = nature
		}
		fixerNature(l[i].Effets, nature)
	}
}

// affaiblir : l'effet secondaire agit à moitié, un tour de moins, sans bond.
func affaiblir(l []Effet) []Effet {
	var out []Effet
	for _, e := range l {
		if e.Op == OpBond {
			continue
		}
		e.Mult *= 0.5
		switch {
		case e.Op == OpDeclencheur, e.Op == OpStatut && StatutsDrapeau[e.Statut]:
			// seuils et parades restent entiers
		case e.Op == OpStatut && e.Statut == "leurre":
			e.Valeur = math.Max(1, e.Valeur-1)
		default:
			e.Valeur *= 0.7
		}
		if e.Duree > 1 {
			e.Duree--
		}
		if e.Nombre > 1 {
			e.Nombre--
		}
		e.Effets = affaiblirCharge(e.Effets)
		out = append(out, e)
	}
	return out
}

func affaiblirCharge(l []Effet) []Effet {
	for i := range l {
		l[i].Mult *= 0.5
		if l[i].Duree > 1 {
			l[i].Duree--
		}
	}
	return l
}

// elargir : la forme touche plus large ; renvoie false si rien ne change.
func elargir(l []Effet, s float64) bool {
	ok := false
	for i := range l {
		e := &l[i]
		avant := e.Cible
		switch e.Cible {
		case CEnnemi:
			e.Cible = CEnnemiEtendu
		case CContact:
			e.Cible = CContactEtendu
		case CSoi:
			if e.Op == OpStatut || e.Op == OpBouclier || e.Op == OpRiposte {
				e.Cible = CAllies
			}
		}
		if e.Cible != avant {
			e.Part, ok = arrondi2(0.7*s), true
		}
	}
	return ok
}

// propager : les effets sur un seul adversaire touchent aussi un second
// adversaire (charges comprises) ; renvoie false si rien ne change.
func propager(l []Effet, part float64) bool {
	ok := false
	for i := range l {
		e := &l[i]
		if e.Op == OpBond || e.Op == OpClone || e.Op == OpDiffere {
			continue
		}
		switch e.Cible {
		case CEnnemi, CContact, CEnnemiEtendu, CContactEtendu, CFront, CAleatoire, CAttaquant, CDeclencheur:
			e.Propage, ok = part, true
		}
		if propager(e.Effets, part) {
			ok = true
		}
	}
	return ok
}

func sansBond(l []Effet) []Effet {
	var out []Effet
	for _, e := range l {
		if e.Op != OpBond {
			out = append(out, e)
		}
	}
	return out
}

// multiplier : la forme frappe deux fois, ou se dédouble.
func multiplier(l []Effet) {
	for i := range l {
		e := &l[i]
		switch e.Op {
		case OpDegats, OpDrain:
			e.Frappes *= 2
			e.Mult *= 0.6
		case OpClone:
			e.Nombre++
		case OpInvocation, OpPiege, OpRiposte, OpDeclencheur:
			e.Duree++
			for k := range e.Effets {
				if e.Effets[k].Op == OpDegats || e.Effets[k].Op == OpDrain {
					e.Effets[k].Frappes = 2
					e.Effets[k].Mult *= 0.6
				}
			}
		case OpStatut, OpBouclier, OpSoin, OpDot:
			e.Mult *= 1.2
			e.Valeur *= 1.2
		}
	}
}

// amplifier intensifie un effet. Les entraves sans valeur gagnent des
// chances de réussite ; les leurres, un leurre de plus.
func amplifier(e *Effet, f float64) {
	e.Mult *= f
	switch {
	case e.Op == OpStatut && e.Statut == "leurre":
		e.Valeur++
	case e.Op == OpStatut && StatutsDrapeau[e.Statut]:
	case (e.Op == OpStatut && StatutsControle[e.Statut] || e.Op == OpDeplacer) && e.Valeur == 0:
		e.Valeur = arrondi2((f - 1) / 2)
	default:
		e.Valeur *= f
	}
	for i := range e.Effets {
		amplifier(&e.Effets[i], f)
	}
}

// retarder : les effets partent au tour suivant, plus forts (les bonds,
// clones et déplacements restent immédiats).
func retarder(l []Effet, f float64) []Effet {
	var now, plus []Effet
	for _, e := range l {
		switch e.Op {
		case OpBond, OpClone, OpDeplacer, OpInterrompre:
			now = append(now, e)
		default:
			amplifier(&e, f)
			plus = append(plus, e)
		}
	}
	if len(plus) > 0 {
		now = append(now, Effet{Op: OpDiffere, Cible: CSoi, Duree: 1, Effets: plus})
	}
	return now
}

func arrondirEffets(l []Effet) {
	for i := range l {
		l[i].Mult = arrondi2(l[i].Mult)
		l[i].Valeur = arrondi2(l[i].Valeur)
		arrondirEffets(l[i].Effets)
	}
}
