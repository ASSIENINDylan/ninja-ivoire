package game

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
)

func nouvellePartie(t *testing.T) *Partie {
	t.Helper()
	p, err := Charger(filepath.Join(t.TempDir(), "ninja.save.json"))
	if err != nil {
		t.Fatal(err)
	}
	p.Maintenant = func() time.Time { return time.Date(2026, 9, 23, 12, 0, 0, 0, time.Local) }
	if _, err := p.Creer("Aya", "lagunes", "futuriste"); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestCreationSelonRegionEtVillage(t *testing.T) {
	p := nouvellePartie(t)
	n := p.Ninja
	if n.Elements[0] != "eau" || n.Manhis != AttributDepart+BonusRegion {
		t.Errorf("les Lagunes donnent l'Eau et l'agilité : %+v", n)
	}
	if n.Village != "Néo-Ébrié" || n.SouffleMax() >= 40+n.Gnanga*3+2 {
		t.Errorf("un village futuriste affaiblit le Souffle : %s %d", n.Village, n.SouffleMax())
	}
	if _, err := p.Creer("Autre", "lagunes", "moderne"); err != ErrNinjaExiste {
		t.Errorf("attendu ErrNinjaExiste, obtenu %v", err)
	}
}

func TestDojoEtSauvegarde(t *testing.T) {
	p := nouvellePartie(t)
	r, err := p.Dojo([]string{"lamantin", "martin_pecheur", "liane"})
	if err != nil || !r.Valide || !r.Nouveau {
		t.Fatalf("découverte attendue : %+v %v", r, err)
	}
	r, _ = p.Dojo([]string{"lamantin", "martin_pecheur", "liane"})
	if r.Nouveau {
		t.Error("un jutsu connu ne se redécouvre pas")
	}
	if _, err := p.Dojo([]string{"panthere", "martin_pecheur", "liane"}); err != combat.ErrMudraInterdit {
		t.Errorf("un ninja de l'Eau ne forme pas le signe du Feu : %v", err)
	}
	p2, err := Charger(p.chemin)
	if err != nil || len(p2.Ninja.Grimoire) != 1 {
		t.Fatalf("le grimoire doit survivre à la sauvegarde : %v", err)
	}
}

func TestNiveauxEtElements(t *testing.T) {
	n, _ := NouveauNinja("Yao", "levant", "moderne")
	total := 0
	for lv := 1; lv < 20; lv++ {
		total += XPPourNiveau(lv)
	}
	n.GagnerXP(total*100/115 + 1) // le village moderne donne +15 %
	if n.Niveau != 20 || n.ElementsAChoisir != 1 || n.Points != 19*PointsParNiveau {
		t.Fatalf("niveau 20 attendu avec un élément à choisir : niv %d, choix %d, points %d", n.Niveau, n.ElementsAChoisir, n.Points)
	}
	if err := n.ChoisirElement("terre"); err != ErrElement {
		t.Error("on ne choisit pas deux fois le même élément")
	}
	if err := n.ChoisirElement("son"); err != nil || len(n.Elements) != 2 {
		t.Errorf("choix du Son : %v", err)
	}
	if err := n.ChoisirElement("feu"); err != ErrPasDeChoix {
		t.Error("un seul élément tous les 20 niveaux")
	}
}

func TestCombatComplet(t *testing.T) {
	p := nouvellePartie(t)
	if _, err := p.DemarrerCombat("brigand"); err != ErrNiveauTropBas {
		t.Errorf("la zone du brigand demande le niveau 2 : %v", err)
	}
	if _, err := p.DemarrerCombat("chacals"); err != nil {
		t.Fatal(err)
	}
	var res *TourResultat
	for i := 0; i < combat.TourMax && (res == nil || res.Fin == nil); i++ {
		var err error
		res, err = p.Agir(combat.Action{Type: combat.AFrapper, Cible: "pnj1"})
		if err != nil {
			t.Fatal(err)
		}
	}
	if res.Fin == nil {
		t.Fatal("le combat aurait dû se terminer")
	}
	if res.Fin.Victoire && p.Ninja.Victoires != 1 {
		t.Error("victoire non comptée")
	}
}
