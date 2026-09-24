package game

import (
	"testing"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"
)

// placer met le ninja sur la première case explorable ayant ce contenu.
func placerSur(t *testing.T, p *Partie, contenu string) (int, int) {
	t.Helper()
	for y := 0; y < carte.H; y++ {
		for x := 0; x < carte.L; x++ {
			cel := carte.Monde.Case(x, y)
			if cel != nil && cel.Contenu == contenu && cel.Region != "coeur" {
				p.Ninja.Position = [2]int{x, y}
				p.Ninja.Niveau = 30
				return x, y
			}
		}
	}
	t.Fatalf("aucune case %q", contenu)
	return 0, 0
}

func TestRendementCroitAvecLeNiveau(t *testing.T) {
	for _, r := range carte.Ressources {
		if Rendement(r, 20, 0.5, 0) <= Rendement(r, 1, 0.5, 0) {
			t.Errorf("%s : le niveau d'exploitation doit augmenter la récolte", r)
		}
	}
	if Rendement(carte.Diamant, 1, 0.5, 0.99) != 0 {
		t.Error("le diamant peut ne rien donner")
	}
}

func TestExploiterUnGisement(t *testing.T) {
	p := nouvellePartie(t)
	n := p.Ninja
	p.Hasard = func() float64 { return 0.9 } // pas d'événement
	if _, err := p.Exploiter(); err != ErrPasDeRessource {
		t.Errorf("rien à exploiter au village : %v", err)
	}
	placerSur(t, p, carte.Fer)
	for i := 0; i < GisementMax; i++ {
		res, err := p.Exploiter()
		if err != nil {
			t.Fatal(err)
		}
		if res.Gain[carte.Fer] <= 0 {
			t.Fatalf("récolte vide : %+v", res)
		}
	}
	if n.Sac[carte.Fer] < GisementMax || n.Exploitation[carte.Fer].Niveau < 2 {
		t.Errorf("sac %v, métier %+v", n.Sac, n.Exploitation[carte.Fer])
	}
	if _, err := p.Exploiter(); err != ErrEpuise {
		t.Errorf("le gisement devrait être épuisé : %v", err)
	}
	now := p.Maintenant()
	p.Maintenant = func() time.Time { return now.Add(GisementRegenSecondes * time.Second) }
	if _, err := p.Exploiter(); err != nil {
		t.Errorf("le gisement se reconstitue : %v", err)
	}
}

func TestEvenementsPendantLExploitation(t *testing.T) {
	p := nouvellePartie(t)
	placerSur(t, p, carte.Peau)
	p.Hasard = func() float64 { return 0.1 } // événement, puis bandits
	res, err := p.Exploiter()
	if err != nil || res.Combat == nil {
		t.Fatalf("des bandits devaient surgir : %v %+v", err, res)
	}
	p.Fuir()
	p.Hasard = func() float64 { return 0.6 } // pas d'événement… sauf si < 0.2
	seq := []float64{0.5, 0.5, 0.1, 0.9, 0.3, 0.2, 0.3, 0.4}
	i := 0
	p.Hasard = func() float64 { v := seq[i%len(seq)]; i++; return v }
	res, err = p.Exploiter()
	if err != nil || p.presence == nil || res.Ninja.Situation.Presence == nil {
		t.Fatalf("un ninja devait arriver : %v %+v", err, res)
	}
	res, err = p.Affronter()
	if err != nil || res.Combat == nil {
		t.Fatalf("on peut affronter tout ninja présent : %v", err)
	}
}

func TestCampForgeEtDefaite(t *testing.T) {
	p := nouvellePartie(t)
	n := p.Ninja
	placerSur(t, p, carte.Camp)
	res, err := p.AttaquerCamp()
	if err != nil || res.Combat == nil {
		t.Fatalf("attaque du camp : %v", err)
	}
	// Victoire forcée : le camp est vaincu et pillé.
	p.combat.Fini, p.combat.Vainqueur = true, 0
	fin := p.terminer()
	if len(fin.Butin) == 0 || n.campActif(n.Position[0], n.Position[1], p.Maintenant()) {
		t.Errorf("butin %v ; le camp devrait être vaincu", fin.Butin)
	}
	// Forge au village.
	v := n.VillageNatal()
	n.Position = [2]int{v.X, v.Y}
	if _, err := p.Fabriquer("sabre_fer"); err != ErrRessources {
		t.Errorf("pas assez de fer : %v", err)
	}
	n.Sac[carte.Fer] = 3
	n.Coffre[carte.Fer] = 5
	n.Sac[carte.Peau] = 1
	if _, err := p.Fabriquer("sabre_fer"); err != nil {
		t.Fatal(err)
	}
	if n.Coffre[carte.Fer] != 0 || n.Sac[carte.Fer] != 2 {
		t.Errorf("le coffre sert en premier : coffre %v sac %v", n.Coffre, n.Sac)
	}
	base := n.Combattant(p.Maintenant()).Arme.Puissance
	if _, err := p.Equiper("sabre_fer"); err != nil {
		t.Fatal(err)
	}
	if c := n.Combattant(p.Maintenant()); c.Arme.Puissance <= base || c.Arme.Nom != "un sabre de fer" {
		t.Errorf("l'arme forgée compte en combat : %+v", c.Arme)
	}
	// Défaite : le sac et les objets non portés sont perdus, pas le coffre.
	n.Coffre[carte.Pierre] = 7
	n.Objets = []string{"bandeau_cuir"}
	p.DemarrerCombat("chacals")
	p.combat.Fini, p.combat.Vainqueur = true, 1
	p.terminer()
	if len(n.Sac) != 0 || len(n.Objets) != 0 || n.Coffre[carte.Pierre] != 7 || n.Equipement[EmplArme] != "sabre_fer" {
		t.Errorf("après défaite : sac %v objets %v coffre %v équipement %v", n.Sac, n.Objets, n.Coffre, n.Equipement)
	}
}
