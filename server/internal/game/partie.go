package game

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// Erreurs de partie.
var (
	ErrPasDeNinja    = errors.New("aucun ninja : créez-en un d'abord")
	ErrNinjaExiste   = errors.New("un ninja existe déjà")
	ErrCombatEnCours = errors.New("un combat est déjà en cours")
	ErrPasDeCombat   = errors.New("aucun combat en cours")
	ErrRencontre     = errors.New("rencontre inconnue")
	ErrNiveauTropBas = errors.New("niveau trop bas pour cette zone")
)

// Partie : la partie locale d'un joueur (prototype hors ligne).
type Partie struct {
	mu        sync.Mutex
	chemin    string
	Ninja     *Ninja
	combat    *combat.Combat
	rencontre *Rencontre
	vus       int // découvertes du combat déjà inscrites au grimoire
	// Maintenant donne l'heure réelle (remplaçable dans les tests).
	Maintenant func() time.Time
}

// Charger ouvre (ou crée) la sauvegarde.
func Charger(chemin string) (*Partie, error) {
	p := &Partie{chemin: chemin, Maintenant: time.Now}
	b, err := os.ReadFile(chemin)
	if errors.Is(err, os.ErrNotExist) {
		return p, nil
	}
	if err != nil {
		return nil, err
	}
	var n Ninja
	if err := json.Unmarshal(b, &n); err != nil {
		return nil, err
	}
	if n.Nom != "" {
		if n.Grimoire == nil {
			n.Grimoire = map[string]*JutsuConnu{}
		}
		p.Ninja = &n
	}
	return p, nil
}

func (p *Partie) sauver() error {
	if p.chemin == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(p.chemin), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(p.Ninja, "", "  ")
	if err != nil {
		return err
	}
	tmp := p.chemin + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, p.chemin)
}

// --- Vues envoyées au client ---------------------------------------------

// JutsuVue : un jutsu tel que le joueur le voit dans son grimoire.
type JutsuVue struct {
	Cle        string   `json:"cle"`
	Nom        string   `json:"nom"`
	Sequence   []string `json:"sequence"`
	Element    string   `json:"element"`
	Forme      string   `json:"forme"`
	Soutien    bool     `json:"soutien"`
	Legendaire bool     `json:"legendaire"`
	Texte      string   `json:"texte"`
	Cout       int      `json:"cout"`
	Tours      int      `json:"tours"`
	Maitrise   int      `json:"maitrise"`
	Usages     int      `json:"usages"`
}

// NinjaVue : le ninja et ses valeurs calculées.
type NinjaVue struct {
	*Ninja
	RegionNom     string     `json:"region_nom"`
	PVMax         int        `json:"pv_max"`
	SouffleMax    int        `json:"souffle_max"`
	XPProchain    int        `json:"xp_prochain"`
	MudrasParTour int        `json:"mudras_par_tour"`
	ElementsMax   int        `json:"elements_max"`
	Permis        []string   `json:"permis"`
	Jutsus        []JutsuVue `json:"jutsus"`
}

func (p *Partie) vueJutsu(j *grammar.Jutsu) JutsuVue {
	m := combat.MaitriseDecouverte
	usages := 0
	if k := p.Ninja.Grimoire[j.Cle]; k != nil {
		m, usages = k.Maitrise, k.Usages
	}
	mpt := 3 + p.Ninja.Gnanga/15
	return JutsuVue{
		Cle: j.Cle, Nom: j.Nom, Sequence: j.Sequence, Element: j.Element, Forme: j.Forme,
		Soutien: j.Soutien, Legendaire: j.Legendaire != "", Texte: j.Texte,
		Cout: combat.CoutReel(j, m), Tours: (j.Longueur() + mpt - 1) / mpt,
		Maitrise: m, Usages: usages,
	}
}

func (p *Partie) vueNinja() *NinjaVue {
	n := p.Ninja
	if n == nil {
		return nil
	}
	v := &NinjaVue{
		Ninja: n, RegionNom: data.Regions[n.Region].Nom,
		PVMax: n.PVMax(), SouffleMax: n.SouffleMax(), XPProchain: XPPourNiveau(n.Niveau),
		MudrasParTour: 3 + n.Gnanga/15, ElementsMax: n.ElementsMax(),
	}
	for id := range n.MudrasPermis() {
		v.Permis = append(v.Permis, id)
	}
	sort.Strings(v.Permis)
	connus := make([]*JutsuConnu, 0, len(n.Grimoire))
	for _, k := range n.Grimoire {
		connus = append(connus, k)
	}
	sort.Slice(connus, func(i, j int) bool { return connus[i].Decouvert.Before(connus[j].Decouvert) })
	for _, k := range connus {
		if j, e := grammar.Analyser(k.Sequence); e == nil {
			v.Jutsus = append(v.Jutsus, p.vueJutsu(j))
		}
	}
	return v
}

// Etat : ce que le client affiche au démarrage.
type Etat struct {
	Ninja  *NinjaVue      `json:"ninja"`
	Combat *combat.Combat `json:"combat"`
	Ciel   Ciel           `json:"ciel"`
}

// Ciel : l'heure, la lune et leurs effets.
type Ciel struct {
	Heure         string  `json:"heure"`
	Nuit          bool    `json:"nuit"`
	PhaseLune     string  `json:"phase_lune"`
	Illumination  float64 `json:"illumination"`
	FacteurSoleil float64 `json:"facteur_soleil"`
	FacteurLune   float64 `json:"facteur_lune"`
}

// LeCiel décrit le ciel à cet instant.
func LeCiel(t time.Time) Ciel {
	return Ciel{
		Heure: t.Format("15:04"), Nuit: data.EstNuit(t), PhaseLune: data.NomPhase(t),
		Illumination: data.Illumination(t), FacteurSoleil: data.FacteurSoleil(t), FacteurLune: data.FacteurLune(t),
	}
}

// Etat renvoie l'état courant.
func (p *Partie) Etat() Etat {
	p.mu.Lock()
	defer p.mu.Unlock()
	e := Etat{Ninja: p.vueNinja(), Ciel: LeCiel(p.Maintenant())}
	if p.combat != nil {
		e.Combat = p.combat.Vue(0)
	}
	return e
}

// --- Création et progression ---------------------------------------------

// Creer crée le ninja du joueur.
func (p *Partie) Creer(nom, region, typeVillage string) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja != nil {
		return nil, ErrNinjaExiste
	}
	n, err := NouveauNinja(nom, region, typeVillage)
	if err != nil {
		return nil, err
	}
	p.Ninja = n
	return p.vueNinja(), p.sauver()
}

// Abandonner supprime le ninja (prototype : pour recommencer).
func (p *Partie) Abandonner() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.Ninja, p.combat, p.rencontre = nil, nil, nil
	if p.chemin == "" {
		return nil
	}
	err := os.Remove(p.chemin)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

// Repartir distribue des points d'attribut.
func (p *Partie) Repartir(f, g, m int) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja == nil {
		return nil, ErrPasDeNinja
	}
	if err := p.Ninja.Repartir(f, g, m); err != nil {
		return nil, err
	}
	return p.vueNinja(), p.sauver()
}

// ChoisirElement apprend un nouvel élément.
func (p *Partie) ChoisirElement(id string) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja == nil {
		return nil, ErrPasDeNinja
	}
	if err := p.Ninja.ChoisirElement(id); err != nil {
		return nil, err
	}
	return p.vueNinja(), p.sauver()
}

// --- Dojo ----------------------------------------------------------------

// ResultatDojo : ce que donne un essai de mudras au dojo.
type ResultatDojo struct {
	Valide    bool               `json:"valide"`
	Nouveau   bool               `json:"nouveau"`
	Jutsu     *JutsuVue          `json:"jutsu,omitempty"`
	Resonance *grammar.Resonance `json:"resonance,omitempty"`
	Refus     string             `json:"refus,omitempty"`
	Message   string             `json:"message"`
	Ninja     *NinjaVue          `json:"ninja"`
}

// Dojo : on essaie une suite de mudras sans danger.
func (p *Partie) Dojo(seq []string) (*ResultatDojo, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if len(seq) > grammar.LongueurMax {
		return nil, combat.ErrSequence
	}
	permis := n.MudrasPermis()
	for _, id := range seq {
		if !permis[id] {
			return nil, combat.ErrMudraInterdit
		}
	}
	r := &ResultatDojo{}
	j, e := grammar.Analyser(seq)
	if j != nil {
		if j.Legendaire != "" {
			r.Refus = grammar.LegendairesParID[j.Legendaire].Conditions.Verifier(n.Contexte(p.Maintenant()))
		} else if j.Fusion && n.Niveau < data.NiveauFusion {
			r.Refus = "Deux éléments veulent se fondre… mais il faut un Souffle plus mûr pour les fusionner."
		}
	}
	switch {
	case r.Refus != "":
		r.Message = r.Refus
	case j != nil:
		r.Valide = true
		r.Nouveau = n.Apprendre(j, combat.MaitriseDecouverte)
		v := p.vueJutsu(j)
		r.Jutsu = &v
		switch {
		case r.Nouveau && j.Legendaire != "":
			r.Message = "JUTSU LÉGENDAIRE DÉCOUVERT : " + j.Nom + " ! Un nouvel élément s'offre à vous."
		case r.Nouveau:
			r.Message = "Nouveau jutsu découvert : " + j.Nom + " !"
		default:
			r.Message = "Vous connaissez déjà ce jutsu : " + j.Nom + "."
		}
	default:
		res := grammar.Resonner(seq, e, data.TypesVillage[n.TypeVillage].Resonance)
		r.Resonance = &res
		r.Message = res.Message
	}
	r.Ninja = p.vueNinja()
	return r, p.sauver()
}

// --- Combat --------------------------------------------------------------

// RencontreVue : une rencontre et son accessibilité.
type RencontreVue struct {
	*Rencontre
	Accessible bool `json:"accessible"`
}

// ListeRencontres renvoie les rencontres et si elles sont accessibles.
func (p *Partie) ListeRencontres() []RencontreVue {
	p.mu.Lock()
	defer p.mu.Unlock()
	var out []RencontreVue
	for _, r := range rencontreList {
		out = append(out, RencontreVue{Rencontre: r, Accessible: p.Ninja != nil && p.Ninja.Niveau >= r.Niveau})
	}
	return out
}

// DemarrerCombat lance une rencontre.
func (p *Partie) DemarrerCombat(id string) (*combat.Combat, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja == nil {
		return nil, ErrPasDeNinja
	}
	if p.combat != nil && !p.combat.Fini {
		return nil, ErrCombatEnCours
	}
	r := Rencontres[id]
	if r == nil {
		return nil, ErrRencontre
	}
	if p.Ninja.Niveau < r.Niveau {
		return nil, ErrNiveauTropBas
	}
	moment := p.Maintenant()
	fighters := append([]*combat.Combattant{p.Ninja.Combattant(moment)}, r.Instancier()...)
	p.combat = combat.Nouveau(id, fighters, moment.UnixNano(), p.Maintenant)
	p.rencontre = r
	p.vus = 0
	return p.combat.Vue(0), nil
}

// FinCombat : récompenses et progression.
type FinCombat struct {
	Victoire      bool           `json:"victoire"`
	Nul           bool           `json:"nul"`
	XP            int            `json:"xp"`
	Dje           int            `json:"dje"`
	NiveauxGagnes int            `json:"niveaux_gagnes"`
	Maitrise      map[string]int `json:"maitrise"` // nom du jutsu → maîtrise atteinte
	Message       string         `json:"message"`
}

// TourResultat : ce que renvoie une action de combat.
type TourResultat struct {
	Evenements []combat.Evenement `json:"evenements"`
	Combat     *combat.Combat     `json:"combat"`
	Fin        *FinCombat         `json:"fin,omitempty"`
	Ninja      *NinjaVue          `json:"ninja"`
}

// Agir joue un tour de combat avec l'action du joueur.
func (p *Partie) Agir(a combat.Action) (*TourResultat, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.combat == nil || p.combat.Fini {
		return nil, ErrPasDeCombat
	}
	a.Acteur = "joueur"
	evts, err := p.combat.JouerTour([]combat.Action{a})
	if err != nil {
		return nil, err
	}
	// Les découvertes sont inscrites tout de suite : elles ne se perdent pas.
	for ; p.vus < len(p.combat.Decouvertes); p.vus++ {
		p.Ninja.Apprendre(p.combat.Decouvertes[p.vus].Jutsu, combat.MaitriseDecouverte)
	}
	res := &TourResultat{Evenements: evts, Combat: p.combat.Vue(0)}
	if p.combat.Fini {
		res.Fin = p.terminer()
	}
	res.Ninja = p.vueNinja()
	return res, p.sauver()
}

// Fuir abandonne le combat : c'est une défaite.
func (p *Partie) Fuir() (*TourResultat, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.combat == nil || p.combat.Fini {
		return nil, ErrPasDeCombat
	}
	p.combat.Fini, p.combat.Vainqueur = true, 1
	res := &TourResultat{
		Evenements: []combat.Evenement{{Type: "fin", Valeur: 1, Texte: p.Ninja.Nom + " prend la fuite."}},
		Combat:     p.combat.Vue(0),
		Fin:        p.terminer(),
	}
	res.Ninja = p.vueNinja()
	return res, p.sauver()
}

func (p *Partie) terminer() *FinCombat {
	c, n, r := p.combat, p.Ninja, p.rencontre
	fin := &FinCombat{Maitrise: map[string]int{}}
	// La pratique paie, même dans la défaite.
	for cle, fois := range c.Usages {
		n.Pratiquer(cle, fois)
		if k := n.Grimoire[cle]; k != nil {
			fin.Maitrise[k.Nom] = k.Maitrise
		}
	}
	switch c.Vainqueur {
	case 0:
		fin.Victoire = true
		fin.XP, fin.Dje = r.XP, r.Dje
		n.Dje += r.Dje
		n.Victoires++
		fin.NiveauxGagnes = n.GagnerXP(r.XP)
		fin.Message = "Victoire ! Vous gagnez de l'expérience et des Djê."
	case 2:
		fin.Nul = true
		fin.XP = r.XP / 4
		fin.NiveauxGagnes = n.GagnerXP(fin.XP)
		fin.Message = "Match nul. Les deux camps se retirent, épuisés."
	default:
		n.Defaites++
		fin.Message = "Défaite. Vous renaissez dans votre village. (Quand l'inventaire existera, vos objets iront au vainqueur.)"
	}
	return fin
}
