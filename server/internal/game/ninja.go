// Package game relie les règles (grammaire, combat) à la progression du
// ninja : création, grimoire, maîtrise, niveaux, rencontres et sauvegarde.
package game

import (
	"errors"
	"strings"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// Constantes de progression.
const (
	NiveauMax         = 100
	PalierElement     = 20 // un élément au choix tous les 20 niveaux
	PointsParNiveau   = 3
	AttributDepart    = 8
	BonusRegion       = 3
	MaitriseParchemin = 50 // parchemin acheté à l'académie (étape 6)
	MaitriseMax       = 100
)

// JutsuConnu est une entrée du grimoire : un jutsu reste pour toujours
// dans la mémoire du ninja.
type JutsuConnu struct {
	Cle        string    `json:"cle"`
	Sequence   []string  `json:"sequence"`
	Nom        string    `json:"nom"`
	Element    string    `json:"element"`
	Legendaire bool      `json:"legendaire"`
	Maitrise   int       `json:"maitrise"`
	Usages     int       `json:"usages"`
	Decouvert  time.Time `json:"decouvert"`
}

// Ninja est le personnage du joueur.
type Ninja struct {
	Nom              string                 `json:"nom"`
	Region           string                 `json:"region"`
	TypeVillage      string                 `json:"type_village"`
	Village          string                 `json:"village"`
	Niveau           int                    `json:"niveau"`
	XP               int                    `json:"xp"`
	Points           int                    `json:"points"`
	Fangan           int                    `json:"fangan"`
	Gnanga           int                    `json:"gnanga"`
	Manhis           int                    `json:"manhis"`
	Elements         []string               `json:"elements"`
	ElementsAChoisir int                    `json:"elements_a_choisir"`
	Grimoire         map[string]*JutsuConnu `json:"grimoire"`
	Favoris          []string               `json:"favoris"` // au plus 5 clés de jutsus
	Dje              int                    `json:"dje"`
	Arme             combat.Arme            `json:"arme"`
	Victoires        int                    `json:"victoires"`
	Position         [2]int                 `json:"position"`
	PV               int                    `json:"pv"`     // les blessures restent d'un combat à l'autre
	PVMaj            int64                  `json:"pv_maj"` // dernière régénération
	Endurance        int                    `json:"endurance"`
	EnduranceMaj     int64                  `json:"endurance_maj"`
	Explore          string                 `json:"explore"`
	Defaites         int                    `json:"defaites"`
	Exploitation     map[string]*Metier     `json:"exploitation"`  // niveau d'exploitation par ressource
	Sac              map[string]int         `json:"sac"`           // ressources portées (perdues à la défaite, comme l'équipement)
	Coffre           map[string]int         `json:"coffre"`        // ressources à l'abri au village
	Objets           []string               `json:"objets"`        // objets forgés non portés (dans le sac)
	CoffreObjets     []string               `json:"coffre_objets"` // objets rangés au coffre du village
	Equipement       map[string]string      `json:"equipement"`    // emplacement → objet porté
	Gisements        map[string]*Gisement   `json:"gisements"`     // gisements entamés
	Camps            map[string]int64       `json:"camps"`         // camps vaincus → date de retour
	Creation         time.Time              `json:"creation"`
}

// Erreurs de création et de progression.
var (
	ErrNom        = errors.New("le nom doit faire entre 2 et 20 caractères")
	ErrRegion     = errors.New("région inconnue ou non jouable")
	ErrVillage    = errors.New("type de village inconnu")
	ErrPoints     = errors.New("pas assez de points à répartir")
	ErrElement    = errors.New("élément indisponible")
	ErrPasDeChoix = errors.New("aucun élément à choisir pour l'instant")
)

// NouveauNinja crée un ninja de niveau 1 dans une région et un village.
func NouveauNinja(nom, region, typeVillage string) (*Ninja, error) {
	nom = strings.TrimSpace(nom)
	if n := len([]rune(nom)); n < 2 || n > 20 {
		return nil, ErrNom
	}
	r := data.Regions[region]
	if r == nil || !r.Jouable {
		return nil, ErrRegion
	}
	tv := data.TypesVillage[typeVillage]
	if tv == nil {
		return nil, ErrVillage
	}
	n := &Ninja{
		Nom: nom, Region: region, TypeVillage: typeVillage,
		Village: r.Villages[data.VillageIndex(typeVillage)],
		Niveau:  1,
		Fangan:  AttributDepart, Gnanga: AttributDepart, Manhis: AttributDepart,
		Elements: []string{r.Element},
		Grimoire: map[string]*JutsuConnu{},
		Favoris:  []string{},
		Dje:      50,
		Arme:     combat.Arme{Nom: "un sabre court", Puissance: 6 + tv.BonusArme},
		Creation: time.Now(),
	}
	n.initialiserCarte(n.Creation)
	n.initialiserRessources()
	switch r.Attribut {
	case data.Fangan:
		n.Fangan += BonusRegion
	case data.Gnanga:
		n.Gnanga += BonusRegion
	case data.Manhis:
		n.Manhis += BonusRegion
	}
	return n, nil
}

// XPPourNiveau : expérience nécessaire pour passer du niveau n au suivant.
func XPPourNiveau(n int) int { return 40*n + 8*n*n }

// PVMax du ninja.
func (n *Ninja) PVMax() int {
	pv := 60 + n.Fangan*4 + n.Niveau*6
	return pv*(100+data.TypesVillage[n.TypeVillage].BonusPV)/100 + n.bonus().PV
}

// SouffleMax du ninja.
func (n *Ninja) SouffleMax() int {
	s := 40 + n.Gnanga*3 + n.Niveau*2
	return s * (100 + data.TypesVillage[n.TypeVillage].BonusSouffle) / 100
}

// NombreLegendaires connus.
func (n *Ninja) NombreLegendaires() int {
	k := 0
	for _, j := range n.Grimoire {
		if j.Legendaire {
			k++
		}
	}
	return k
}

// ElementsMax : 1 de départ + 1 tous les 20 niveaux + 1 par légendaire connu.
func (n *Ninja) ElementsMax() int {
	return 1 + n.Niveau/PalierElement + n.NombreLegendaires()
}

// MudrasPermis : les mudras que le ninja sait former.
func (n *Ninja) MudrasPermis() map[string]bool {
	p := map[string]bool{}
	for _, m := range data.AllMudras() {
		if data.Unlocked(&m, n.Niveau, n.Elements) {
			p[m.ID] = true
		}
	}
	return p
}

// GagnerXP ajoute de l'expérience et renvoie le nombre de niveaux gagnés.
func (n *Ninja) GagnerXP(xp int) int {
	bonus := data.TypesVillage[n.TypeVillage].BonusXP
	n.XP += xp * (100 + bonus) / 100
	gagnes := 0
	for n.Niveau < NiveauMax && n.XP >= XPPourNiveau(n.Niveau) {
		n.XP -= XPPourNiveau(n.Niveau)
		n.Niveau++
		gagnes++
		n.Points += PointsParNiveau
		// L'attribut favorisé par la région grandit tout seul.
		switch data.Regions[n.Region].Attribut {
		case data.Fangan:
			n.Fangan++
		case data.Gnanga:
			n.Gnanga++
		case data.Manhis:
			n.Manhis++
		}
		if n.Niveau%PalierElement == 0 {
			n.ElementsAChoisir++
		}
	}
	if n.Niveau == NiveauMax {
		n.XP = 0
	}
	return gagnes
}

// Repartir distribue des points d'attribut.
func (n *Ninja) Repartir(fangan, gnanga, manhis int) error {
	if fangan < 0 || gnanga < 0 || manhis < 0 || fangan+gnanga+manhis > n.Points {
		return ErrPoints
	}
	n.Fangan += fangan
	n.Gnanga += gnanga
	n.Manhis += manhis
	n.Points -= fangan + gnanga + manhis
	return nil
}

// ChoisirElement apprend un nouvel élément de base.
func (n *Ninja) ChoisirElement(id string) error {
	if n.ElementsAChoisir <= 0 {
		return ErrPasDeChoix
	}
	e := data.Elements[id]
	if e == nil || e.Tier != data.TierBase {
		return ErrElement
	}
	for _, k := range n.Elements {
		if k == id {
			return ErrElement
		}
	}
	n.Elements = append(n.Elements, id)
	if n.ElementsAChoisir > 0 {
		n.ElementsAChoisir--
	}
	return nil
}

// Apprendre inscrit un jutsu au grimoire (s'il n'y est pas déjà).
// Renvoie true si c'est une nouveauté.
func (n *Ninja) Apprendre(j *grammar.Jutsu, maitrise int) bool {
	if ex, ok := n.Grimoire[j.Cle]; ok {
		if maitrise > ex.Maitrise {
			ex.Maitrise = maitrise
		}
		return false
	}
	n.Grimoire[j.Cle] = &JutsuConnu{
		Cle: j.Cle, Sequence: j.Sequence, Nom: j.Nom, Element: j.Element,
		Legendaire: j.Legendaire != "", Maitrise: maitrise, Decouvert: time.Now(),
	}
	if j.Legendaire != "" {
		// Chaque légendaire connu ouvre un élément de plus.
		n.ElementsAChoisir++
	}
	// Les premières découvertes deviennent favorites, jusqu'à cinq.
	if len(n.Favoris) < FavorisMax {
		n.Favoris = append(n.Favoris, j.Cle)
	}
	return true
}

// Pratiquer augmente la maîtrise d'un jutsu après usage : rapide au début,
// de plus en plus lente vers 100.
func (n *Ninja) Pratiquer(cle string, fois int) {
	j := n.Grimoire[cle]
	if j == nil {
		return
	}
	for i := 0; i < fois && j.Maitrise < MaitriseMax; i++ {
		j.Maitrise += max(1, (MaitriseMax-j.Maitrise)/20)
		j.Usages++
	}
	if j.Maitrise > MaitriseMax {
		j.Maitrise = MaitriseMax
	}
}

// Contexte du ninja pour les conditions des légendaires.
func (n *Ninja) Contexte(t time.Time) grammar.Contexte {
	return grammar.Contexte{Niveau: n.Niveau, Elements: n.Elements, Moment: t}
}

// Combattant construit le combattant du joueur.
func (n *Ninja) Combattant(t time.Time) *combat.Combattant {
	maitrise := map[string]int{}
	for k, j := range n.Grimoire {
		maitrise[k] = j.Maitrise
	}
	ctx := n.Contexte(t)
	b := n.bonus()
	return &combat.Combattant{
		ID: "joueur", Nom: n.Nom, Camp: 0, Rang: 1, Joueur: true, Apparence: "ninja_" + n.TypeVillage,
		Niveau: n.Niveau, Fangan: n.Fangan, Gnanga: n.Gnanga, Manhis: n.Manhis + b.Manhis,
		PV: max(1, min(n.PV, n.PVMax())), PVMax: n.PVMax(), Souffle: n.SouffleMax(), SouffleMax: n.SouffleMax(),
		Element: n.Elements[0], Elements: n.Elements, Arme: n.ArmePortee(),
		Defense: n.Fangan/2 + b.Defense, DefenseMag: n.Gnanga/2 + b.DefenseMag,
		Maitrise: maitrise, Permis: n.MudrasPermis(), Contexte: &ctx,
		Precis: data.TypesVillage[n.TypeVillage].Resonance,
	}
}

// RegenPVSecondes : il faut une demi-heure réelle pour guérir entièrement.
const RegenPVSecondes = 1800

// MajPV : les blessures guérissent avec le temps.
func (n *Ninja) MajPV(t time.Time) {
	pvMax := n.PVMax()
	if n.PV <= 0 || n.PVMaj == 0 {
		n.PV = pvMax // sauvegarde d'avant les blessures durables
	}
	if n.PV >= pvMax {
		n.PV = pvMax
		n.PVMaj = t.Unix()
		return
	}
	gain := int(float64(pvMax) * float64(t.Unix()-n.PVMaj) / RegenPVSecondes)
	if gain > 0 {
		n.PV = min(pvMax, n.PV+gain)
		n.PVMaj = t.Unix()
	}
}
