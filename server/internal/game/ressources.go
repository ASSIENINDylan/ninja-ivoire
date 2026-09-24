package game

import (
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

// Ressources et camps de bandits, à la manière d'Albion Online : chaque
// ressource a son propre niveau d'exploitation, qui augmente la quantité
// récoltée. En exploitant, on peut être attaqué par des bandits ou croiser
// un autre ninja, que l'on peut affronter.

// Réglages de l'exploitation.
const (
	GisementMax           = 5    // récoltes avant épuisement
	GisementRegenSecondes = 600  // un point de gisement toutes les 10 minutes
	CoutExploitation      = 2    // endurance par récolte
	ChanceEvenement       = 0.2  // bandits ou ninja pendant une récolte
	ChancePresence        = 0.12 // un ninja déjà sur le gisement à l'arrivée
	ChanceCampRepere      = 0.35 // les bandits repèrent qui entre dans leur camp
	CampReposSecondes     = 1800 // un camp vaincu se reforme en 30 minutes
	NiveauMetierMax       = 100
)

// RendementBase : quantité récoltée au niveau 1 d'exploitation.
var RendementBase = map[string]float64{carte.Fer: 2, carte.Peau: 2, carte.Pierre: 3, carte.Or: 1, carte.Diamant: 1}

// XPMetier : expérience d'exploitation gagnée par récolte.
var XPMetier = map[string]int{carte.Fer: 3, carte.Peau: 2, carte.Pierre: 2, carte.Or: 4, carte.Diamant: 6}

// NomsRessources pour l'affichage.
var NomsRessources = map[string]string{
	carte.Fer: "Fer", carte.Peau: "Peau d'animal", carte.Pierre: "Pierre", carte.Or: "Or", carte.Diamant: "Diamant",
}

// XPPourMetier : expérience d'exploitation pour passer du niveau n au suivant.
func XPPourMetier(n int) int { return 8 * n }

// Erreurs des ressources.
var (
	ErrPasDeRessource = errors.New("il n'y a rien à exploiter ici")
	ErrEpuise         = errors.New("le gisement est épuisé : il se reconstitue d'un point toutes les 10 minutes")
	ErrFatigue        = errors.New("trop fatigué pour exploiter : il faut 2 d'endurance")
	ErrPasDeCamp      = errors.New("il n'y a pas de camp de bandits actif ici")
	ErrPersonne       = errors.New("personne à affronter ici")
	ErrHorsVillage    = errors.New("il faut être dans son village")
	ErrObjetInconnu   = errors.New("objet inconnu")
	ErrRessources     = errors.New("pas assez de ressources (sac et coffre)")
	ErrPasLObjet      = errors.New("vous n'avez pas cet objet")
	ErrEmplacement    = errors.New("emplacement inconnu ou vide")
)

// Metier : niveau d'exploitation d'une ressource.
type Metier struct {
	Niveau int `json:"niveau"`
	XP     int `json:"xp"`
}

// Gisement : l'état d'un gisement exploité.
type Gisement struct {
	Reste int   `json:"reste"`
	Maj   int64 `json:"maj"`
}

// Presence : un ninja croisé sur un gisement. Il n'est pas de votre équipe :
// vous pouvez l'affronter, même s'il vient de votre village.
type Presence struct {
	Nom         string `json:"nom"`
	Region      string `json:"region"`
	RegionNom   string `json:"region_nom"`
	Village     string `json:"village"`
	TypeVillage string `json:"type_village"`
	Element     string `json:"element"`
	Niveau      int    `json:"niveau"`
	MemeVillage bool   `json:"meme_village"`
	X           int    `json:"x"`
	Y           int    `json:"y"`
}

var prenoms = []string{"Kouassi", "Aya", "Yao", "Adjoua", "Konan", "Awa", "Bakary", "Mariam", "Séry", "Gnahoré",
	"Zadi", "Tanoh", "Amani", "Fanta", "Drissa", "Affoué", "Koffi", "Akissi", "Siaka", "Nahounou"}

func cleCase(x, y int) string { return fmt.Sprintf("%d,%d", x, y) }

// initialiserRessources : sauvegardes d'avant les ressources.
func (n *Ninja) initialiserRessources() {
	if n.Exploitation == nil {
		n.Exploitation = map[string]*Metier{}
	}
	for _, r := range carte.Ressources {
		if n.Exploitation[r] == nil {
			n.Exploitation[r] = &Metier{Niveau: 1}
		}
	}
	for _, m := range []*map[string]int{&n.Sac, &n.Coffre} {
		if *m == nil {
			*m = map[string]int{}
		}
	}
	if n.Objets == nil {
		n.Objets = []string{}
	}
	if n.CoffreObjets == nil {
		n.CoffreObjets = []string{}
	}
	if n.Equipement == nil {
		n.Equipement = map[string]string{}
	}
	if n.Gisements == nil {
		n.Gisements = map[string]*Gisement{}
	}
	if n.Camps == nil {
		n.Camps = map[string]int64{}
	}
}

// gisement renvoie l'état d'un gisement, reconstitué avec le temps.
func (n *Ninja) gisement(x, y int, t time.Time) *Gisement {
	k := cleCase(x, y)
	g := n.Gisements[k]
	if g == nil {
		return &Gisement{Reste: GisementMax, Maj: t.Unix()}
	}
	if g.Reste < GisementMax {
		gain := int((t.Unix() - g.Maj) / GisementRegenSecondes)
		if gain > 0 {
			g.Reste = min(GisementMax, g.Reste+gain)
			g.Maj += int64(gain) * GisementRegenSecondes
		}
	}
	if g.Reste >= GisementMax {
		delete(n.Gisements, k) // un gisement plein n'a pas besoin d'être retenu
		return &Gisement{Reste: GisementMax, Maj: t.Unix()}
	}
	return g
}

// Rendement : quantité récoltée selon le niveau d'exploitation. `h1` et
// `h2` sont deux tirages dans [0, 1). Le diamant peut ne rien donner.
func Rendement(ressource string, niveau int, h1, h2 float64) int {
	if ressource == carte.Diamant && h2 > 0.45+0.02*float64(niveau) {
		return 0
	}
	q := RendementBase[ressource] * (1 + 0.25*float64(niveau-1)) * (0.8 + 0.4*h1)
	return max(1, int(math.Round(q)))
}

// gagnerMetier ajoute de l'expérience d'exploitation ; renvoie les niveaux gagnés.
func (n *Ninja) gagnerMetier(r string, xp int) int {
	m := n.Exploitation[r]
	m.XP += xp
	gagnes := 0
	for m.Niveau < NiveauMetierMax && m.XP >= XPPourMetier(m.Niveau) {
		m.XP -= XPPourMetier(m.Niveau)
		m.Niveau++
		gagnes++
	}
	return gagnes
}

func (p *Partie) celluleActuelle() *carte.Cellule {
	return carte.Monde.Case(p.Ninja.Position[0], p.Ninja.Position[1])
}

// Exploiter récolte la ressource de la case.
func (p *Partie) Exploiter() (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if p.combat != nil && !p.combat.Fini {
		return nil, ErrCombatEnCours
	}
	cel := p.celluleActuelle()
	r := cel.Contenu
	if RendementBase[r] == 0 {
		return nil, ErrPasDeRessource
	}
	now := p.Maintenant()
	x, y := n.Position[0], n.Position[1]
	g := n.gisement(x, y, now)
	if g.Reste <= 0 {
		return nil, ErrEpuise
	}
	n.MajEndurance(now)
	if n.Endurance < CoutExploitation {
		return nil, ErrFatigue
	}
	if n.Endurance == EnduranceMax {
		n.EnduranceMaj = now.Unix()
	}
	n.Endurance -= CoutExploitation
	if g.Reste == GisementMax {
		g.Maj = now.Unix()
	}
	g.Reste--
	n.Gisements[cleCase(x, y)] = g

	m := n.Exploitation[r]
	q := Rendement(r, m.Niveau, p.Hasard(), p.Hasard())
	n.Sac[r] += q
	montee := n.gagnerMetier(r, XPMetier[r])
	res := &ResultatCarte{Gain: map[string]int{r: q}}
	if q > 0 {
		res.Message = fmt.Sprintf("Vous exploitez : +%d %s.", q, NomsRessources[r])
	} else {
		res.Message = "Vous fouillez la terre… sans trouver de diamant cette fois."
	}
	if montee > 0 {
		res.Message += fmt.Sprintf(" Exploitation (%s) : niveau %d !", strings.ToLower(NomsRessources[r]), m.Niveau)
	}
	// Pendant la récolte, on n'est jamais tout à fait seul.
	if p.Hasard() < ChanceEvenement {
		zone := carte.Monde.Zones[cel.Zone]
		if cel.Region != "coeur" && p.Hasard() < 0.55 {
			rc := Rencontres["bandits"]
			res.Combat = p.demarrer(rc, zone.Niveau)
			res.Rencontre = rc.Nom
			res.Message += " Des bandits surgissent et veulent votre récolte !"
		} else {
			p.presence = p.nouvellePresence(x, y, zone.Niveau)
			res.Message += " " + p.presence.Nom + " arrive sur le gisement."
		}
	}
	res.Ninja = p.vueNinja()
	return res, p.sauver()
}

// nouvellePresence : un ninja de passage, de votre village ou d'ailleurs.
func (p *Partie) nouvellePresence(x, y, niveau int) *Presence {
	n := p.Ninja
	pr := &Presence{X: x, Y: y, Nom: prenoms[int(p.Hasard()*float64(len(prenoms)))%len(prenoms)]}
	pr.Niveau = max(1, niveau-1+int(p.Hasard()*3))
	if p.Hasard() < 0.5 {
		pr.Region, pr.TypeVillage, pr.MemeVillage = n.Region, n.TypeVillage, true
	} else {
		var autres []*data.Region
		for _, r := range data.AllRegions() {
			if r.Jouable && r.ID != n.Region {
				r := r
				autres = append(autres, &r)
			}
		}
		reg := autres[int(p.Hasard()*float64(len(autres)))%len(autres)]
		tv := data.AllTypesVillage()[int(p.Hasard()*3)%3]
		pr.Region, pr.TypeVillage = reg.ID, tv.ID
	}
	reg := data.Regions[pr.Region]
	pr.RegionNom = reg.Nom
	pr.Village = reg.Villages[data.VillageIndex(pr.TypeVillage)]
	pr.Element = reg.Element
	return pr
}

// ninjaErrant : la rencontre contre un ninja croisé sur un gisement.
func ninjaErrant(pr *Presence) *Rencontre {
	m := data.MudraOfElement[pr.Element]
	modele := &ModelePNJ{
		Nom: pr.Nom, Apparence: "ninja_" + pr.TypeVillage, Element: pr.Element, IA: combat.IANinja,
		Fangan: 9, Gnanga: 10, Manhis: 10, PV: 90, Arme: combat.Arme{Nom: "un sabre", Puissance: 7},
		Jutsus: [][]string{{m, "martin_pecheur", "braise"}, {m, "mante", "liane"}, {m, "martin_pecheur", "kola"}},
	}
	return &Rencontre{ID: "ninja_errant", Nom: pr.Nom + " (" + pr.Village + ")", Niveau: 1, XP: 45, Dje: 15,
		Ennemis: []*ModelePNJ{modele}, Noms: []string{pr.Nom}}
}

// Affronter : on défie le ninja présent sur la case.
func (p *Partie) Affronter() (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja == nil {
		return nil, ErrPasDeNinja
	}
	if p.combat != nil && !p.combat.Fini {
		return nil, ErrCombatEnCours
	}
	pr := p.presence
	if pr == nil || pr.X != p.Ninja.Position[0] || pr.Y != p.Ninja.Position[1] {
		return nil, ErrPersonne
	}
	p.presence = nil
	rc := ninjaErrant(pr)
	vue := p.demarrer(rc, pr.Niveau)
	return &ResultatCarte{Ninja: p.vueNinja(), Combat: vue, Rencontre: rc.Nom, Message: "Vous défiez " + pr.Nom + " !"}, nil
}

// Ignorer : on laisse passer le ninja présent.
func (p *Partie) Ignorer() (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja == nil {
		return nil, ErrPasDeNinja
	}
	msg := "Il n'y a personne."
	if p.presence != nil {
		msg = p.presence.Nom + " poursuit sa route."
	}
	p.presence = nil
	return &ResultatCarte{Ninja: p.vueNinja(), Message: msg}, nil
}

// campActif : le camp de la case n'a pas été vaincu récemment.
func (n *Ninja) campActif(x, y int, t time.Time) bool {
	fin, ok := n.Camps[cleCase(x, y)]
	if ok && t.Unix() >= fin {
		delete(n.Camps, cleCase(x, y))
		return true
	}
	return !ok
}

// AttaquerCamp : on attaque le camp de bandits de la case.
func (p *Partie) AttaquerCamp() (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if p.combat != nil && !p.combat.Fini {
		return nil, ErrCombatEnCours
	}
	cel := p.celluleActuelle()
	if cel.Contenu != carte.Camp || !n.campActif(n.Position[0], n.Position[1], p.Maintenant()) {
		return nil, ErrPasDeCamp
	}
	vue := p.lancerCamp(cel)
	return &ResultatCarte{Ninja: p.vueNinja(), Combat: vue, Rencontre: Rencontres["camp_bandits"].Nom, Message: "Vous attaquez le camp de bandits !"}, nil
}

func (p *Partie) lancerCamp(cel *carte.Cellule) *combat.Combat {
	vue := p.demarrer(Rencontres["camp_bandits"], carte.Monde.Zones[cel.Zone].Niveau)
	p.campCle = cleCase(p.Ninja.Position[0], p.Ninja.Position[1])
	return vue
}

// butinCamp : ce que rapporte un camp vaincu.
func (p *Partie) butinCamp() map[string]int {
	b := map[string]int{carte.Fer: 1 + int(p.Hasard()*3), carte.Peau: 1 + int(p.Hasard()*3)}
	if p.Hasard() < 0.25 {
		b[carte.Or] = 1
	}
	return b
}

// --- Coffre du village ---------------------------------------------------------

func (p *Partie) dansSonVillage() bool {
	l := p.lieuActuel()
	n := p.Ninja
	return l != nil && l.Type == "village" && l.Region == n.Region && l.TypeVillage == n.TypeVillage
}

// Deposer met tout le sac au coffre du village : ce qui est au coffre n'est
// jamais perdu.
func (p *Partie) Deposer() (*NinjaVue, error) {
	return p.transferer(true)
}

// Reprendre remet tout le coffre dans le sac.
func (p *Partie) Reprendre() (*NinjaVue, error) {
	return p.transferer(false)
}

func (p *Partie) transferer(deposer bool) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if !p.dansSonVillage() {
		return nil, ErrHorsVillage
	}
	de, vers := n.Sac, n.Coffre
	if !deposer {
		de, vers = n.Coffre, n.Sac
	}
	for r, q := range de {
		vers[r] += q
		delete(de, r)
	}
	return p.vueNinja(), p.sauver()
}

// RangerObjet met au coffre un objet du sac : il ne sera jamais perdu.
func (p *Partie) RangerObjet(id string) (*NinjaVue, error) {
	return p.deplacerObjet(id, true)
}

// SortirObjet reprend un objet du coffre dans le sac.
func (p *Partie) SortirObjet(id string) (*NinjaVue, error) {
	return p.deplacerObjet(id, false)
}

func (p *Partie) deplacerObjet(id string, ranger bool) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if !p.dansSonVillage() {
		return nil, ErrHorsVillage
	}
	de, vers := &n.Objets, &n.CoffreObjets
	if !ranger {
		de, vers = &n.CoffreObjets, &n.Objets
	}
	i := indexOf(*de, id)
	if i < 0 {
		return nil, ErrPasLObjet
	}
	*de = append((*de)[:i], (*de)[i+1:]...)
	*vers = append(*vers, id)
	return p.vueNinja(), p.sauver()
}

// --- Forge et équipement ---------------------------------------------------------

// Fabriquer forge un objet au village, avec les ressources du coffre puis du sac.
func (p *Partie) Fabriquer(id string) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	o := ObjetsParID[id]
	if o == nil {
		return nil, ErrObjetInconnu
	}
	if !p.dansSonVillage() {
		return nil, ErrHorsVillage
	}
	for r, q := range o.Cout {
		if n.Coffre[r]+n.Sac[r] < q {
			return nil, ErrRessources
		}
	}
	for r, q := range o.Cout {
		pris := min(q, n.Coffre[r])
		n.Coffre[r] -= pris
		n.Sac[r] -= q - pris
		for _, m := range []map[string]int{n.Coffre, n.Sac} {
			if m[r] == 0 {
				delete(m, r)
			}
		}
	}
	n.Objets = append(n.Objets, id)
	return p.vueNinja(), p.sauver()
}

// Equiper porte un objet du sac ; l'objet qu'il remplace retourne au sac.
func (p *Partie) Equiper(id string) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	i := indexOf(n.Objets, id)
	if i < 0 {
		return nil, ErrPasLObjet
	}
	o := ObjetsParID[id]
	n.Objets = append(n.Objets[:i], n.Objets[i+1:]...)
	if ancien := n.Equipement[o.Emplacement]; ancien != "" {
		n.Objets = append(n.Objets, ancien)
	}
	n.Equipement[o.Emplacement] = id
	return p.vueNinja(), p.sauver()
}

// Retirer range au sac l'objet porté à un emplacement.
func (p *Partie) Retirer(emplacement string) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	id := n.Equipement[emplacement]
	if id == "" {
		return nil, ErrEmplacement
	}
	delete(n.Equipement, emplacement)
	n.Objets = append(n.Objets, id)
	return p.vueNinja(), p.sauver()
}

func indexOf(l []string, v string) int {
	for i, x := range l {
		if x == v {
			return i
		}
	}
	return -1
}

// Bonus : ce que l'équipement porté ajoute au ninja.
type Bonus struct{ Defense, DefenseMag, PV, Manhis int }

func (n *Ninja) bonus() Bonus {
	var b Bonus
	emps := make([]string, 0, len(n.Equipement))
	for e := range n.Equipement {
		emps = append(emps, e)
	}
	sort.Strings(emps)
	for _, e := range emps {
		if o := ObjetsParID[n.Equipement[e]]; o != nil {
			b.Defense += o.Defense
			b.DefenseMag += o.DefenseMag
			b.PV += o.PV
			b.Manhis += o.Manhis
		}
	}
	return b
}

// ArmePortee : l'arme en main (celle de la forge, ou le sabre de départ).
func (n *Ninja) ArmePortee() combat.Arme {
	a := n.Arme
	if o := ObjetsParID[n.Equipement[EmplArme]]; o != nil {
		a = combat.Arme{Nom: o.Arme, Puissance: n.Arme.Puissance + o.Puissance, Distance: o.Distance}
	}
	return a
}
