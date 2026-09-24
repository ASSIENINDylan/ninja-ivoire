package game

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
)

// Réglages des déplacements.
const (
	EnduranceMax    = 60
	RegenSecondes   = 60 // un point d'endurance par minute réelle
	ChanceRencontre = 0.15
	RayonVision     = 2
)

// Erreurs de déplacement.
var (
	ErrPasAdjacent = errors.New("on ne se déplace que d'une case à la fois")
	ErrHorsPays    = errors.New("impossible de quitter le pays")
	ErrInfranchi   = errors.New("le lac barre la route")
	ErrPasDeRepos  = errors.New("on ne se repose que dans un village de sa région ou du Cœur")
	ErrRienADefier = errors.New("il n'y a personne à défier ici")
)

// initialiserCarte place le ninja dans son village (nouveau ninja, ou
// sauvegarde d'avant la carte).
func (n *Ninja) initialiserCarte(t time.Time) {
	if len(n.Explore) == carte.L*carte.H {
		return
	}
	v := n.VillageNatal()
	n.Position = [2]int{v.X, v.Y}
	n.Endurance = EnduranceMax
	n.EnduranceMaj = t.Unix()
	n.Explore = strings.Repeat("0", carte.L*carte.H)
	for _, l := range carte.Monde.Lieux {
		if l.Type == "village" && (l.Region == n.Region || l.Region == "coeur") {
			n.Reveler(l.X, l.Y, 1)
		}
	}
	n.Reveler(v.X, v.Y, RayonVision+2)
}

// VillageNatal renvoie le village du ninja.
func (n *Ninja) VillageNatal() *carte.Lieu {
	return carte.Monde.VillageDe(n.Region, n.TypeVillage)
}

// Reveler dissipe le brouillard autour d'une case.
func (n *Ninja) Reveler(x, y, rayon int) {
	b := []byte(n.Explore)
	for dy := -rayon; dy <= rayon; dy++ {
		for dx := -rayon; dx <= rayon; dx++ {
			if carte.Dans(x+dx, y+dy) {
				b[(y+dy)*carte.L+x+dx] = '1'
			}
		}
	}
	n.Explore = string(b)
}

// MajEndurance ajoute l'endurance regagnée depuis la dernière mise à jour.
func (n *Ninja) MajEndurance(t time.Time) {
	if n.Endurance >= EnduranceMax {
		n.Endurance = EnduranceMax
		n.EnduranceMaj = t.Unix()
		return
	}
	gain := (t.Unix() - n.EnduranceMaj) / RegenSecondes
	if gain > 0 {
		n.Endurance = min(EnduranceMax, n.Endurance+int(gain))
		n.EnduranceMaj += gain * RegenSecondes
	}
}

// Renaitre : après une défaite, le ninja se réveille dans son village.
func (n *Ninja) Renaitre(t time.Time) {
	v := n.VillageNatal()
	n.Position = [2]int{v.X, v.Y}
	n.Endurance = EnduranceMax
	n.EnduranceMaj = t.Unix()
}

// peutSeReposer : villages de sa région, et villages du Cœur (zone sûre).
func (n *Ninja) peutSeReposer(l *carte.Lieu) bool {
	return l != nil && l.Type == "village" && (l.Region == n.Region || l.Region == "coeur")
}

// ResultatCarte : ce que renvoie une action sur la carte.
type ResultatCarte struct {
	Ninja     *NinjaVue      `json:"ninja"`
	Message   string         `json:"message"`
	Combat    *combat.Combat `json:"combat,omitempty"`
	Rencontre string         `json:"rencontre,omitempty"` // nom de la rencontre
}

// Deplacer avance le ninja d'une case (huit directions).
func (p *Partie) Deplacer(x, y int) (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if p.combat != nil && !p.combat.Fini {
		return nil, ErrCombatEnCours
	}
	dx, dy := x-n.Position[0], y-n.Position[1]
	if dx < -1 || dx > 1 || dy < -1 || dy > 1 || (dx == 0 && dy == 0) {
		return nil, ErrPasAdjacent
	}
	cel := carte.Monde.Case(x, y)
	if cel == nil {
		return nil, ErrHorsPays
	}
	cout := carte.CoutTerrain[cel.Terrain]
	if cout == 0 {
		return nil, ErrInfranchi
	}
	zone := carte.Monde.Zones[cel.Zone]
	if n.Niveau < zone.Niveau {
		return nil, fmt.Errorf("les environs de %s sont trop dangereux : niveau %d requis", zone.Nom, zone.Niveau)
	}
	now := p.Maintenant()
	n.MajEndurance(now)
	if n.Endurance < cout {
		return nil, fmt.Errorf("trop fatigué : il faut %d d'endurance (un point par minute, ou repos au village)", cout)
	}
	ancienne := carte.Monde.Case(n.Position[0], n.Position[1]).Zone
	if n.Endurance == EnduranceMax {
		n.EnduranceMaj = now.Unix()
	}
	n.Endurance -= cout
	n.Position = [2]int{x, y}
	n.Reveler(x, y, RayonVision)

	res := &ResultatCarte{}
	switch {
	case cel.Lieu >= 0:
		res.Message = "Vous arrivez à " + carte.Monde.Lieux[cel.Lieu].Nom + "."
	case cel.Zone != ancienne:
		res.Message = fmt.Sprintf("Vous entrez dans les environs de %s (niveau %d).", zone.Nom, zone.Niveau)
	}
	// En pleine nature, on peut faire une mauvaise rencontre.
	if choix := Sauvages[cel.Terrain]; cel.Lieu < 0 && len(choix) > 0 && p.Hasard() < ChanceRencontre {
		r := Rencontres[choix[int(p.Hasard()*float64(len(choix)))%len(choix)]]
		res.Combat = p.demarrer(r, zone.Niveau)
		res.Rencontre = r.Nom
		res.Message = r.Nom + " vous barre la route !"
	}
	res.Ninja = p.vueNinja()
	return res, p.sauver()
}

// Reposer rend toute l'endurance, dans un village ami.
func (p *Partie) Reposer() (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if !n.peutSeReposer(p.lieuActuel()) {
		return nil, ErrPasDeRepos
	}
	n.Endurance = EnduranceMax
	n.EnduranceMaj = p.Maintenant().Unix()
	return &ResultatCarte{Ninja: p.vueNinja(), Message: "Vous vous reposez : votre endurance est au maximum."}, p.sauver()
}

// Defier lance la rencontre du lieu où se trouve le ninja.
func (p *Partie) Defier() (*ResultatCarte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	n := p.Ninja
	if n == nil {
		return nil, ErrPasDeNinja
	}
	if p.combat != nil && !p.combat.Fini {
		return nil, ErrCombatEnCours
	}
	l := p.lieuActuel()
	if l == nil || l.Rencontre == "" {
		return nil, ErrRienADefier
	}
	if n.Niveau < l.Niveau {
		return nil, fmt.Errorf("%s : niveau %d requis", l.Nom, l.Niveau)
	}
	r := Rencontres[l.Rencontre]
	vue := p.demarrer(r, l.Niveau)
	return &ResultatCarte{Ninja: p.vueNinja(), Combat: vue, Rencontre: r.Nom, Message: l.Nom + " : le combat commence."}, nil
}

func (p *Partie) lieuActuel() *carte.Lieu {
	cel := carte.Monde.Case(p.Ninja.Position[0], p.Ninja.Position[1])
	if cel == nil || cel.Lieu < 0 {
		return nil
	}
	return &carte.Monde.Lieux[cel.Lieu]
}

// SituationVue : où se trouve le ninja.
type SituationVue struct {
	Terrain      string      `json:"terrain"`
	TerrainNom   string      `json:"terrain_nom"`
	Zone         carte.Zone  `json:"zone"`
	Lieu         *carte.Lieu `json:"lieu,omitempty"`
	Repos        bool        `json:"repos"`   // peut se reposer ici
	Village      bool        `json:"village"` // est dans son propre village
	EnduranceMax int         `json:"endurance_max"`
	RegenDans    int         `json:"regen_dans"` // secondes avant le prochain point
}

func (p *Partie) situation() *SituationVue {
	n := p.Ninja
	cel := carte.Monde.Case(n.Position[0], n.Position[1])
	s := &SituationVue{Terrain: cel.Terrain, TerrainNom: carte.NomsTerrains[cel.Terrain],
		Zone: carte.Monde.Zones[cel.Zone], EnduranceMax: EnduranceMax}
	if l := p.lieuActuel(); l != nil {
		s.Lieu = l
		s.Repos = n.peutSeReposer(l)
		s.Village = l.Type == "village" && l.Region == n.Region && l.TypeVillage == n.TypeVillage
	}
	if n.Endurance < EnduranceMax {
		s.RegenDans = int(n.EnduranceMaj + RegenSecondes - p.Maintenant().Unix())
	}
	return s
}
