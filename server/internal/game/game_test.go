package game

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"
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

func TestModeTestNiveau(t *testing.T) {
	p := nouvellePartie(t)
	depart := *p.Ninja
	v, err := p.PasserAuNiveau(40)
	if err != nil {
		t.Fatal(err)
	}
	n := p.Ninja
	if n.Niveau != 40 || n.XP != 0 || n.Points != depart.Points+39*PointsParNiveau || n.ElementsAChoisir != 2 {
		t.Fatalf("niveau 40 attendu avec 117 points et 2 éléments à choisir : niv %d, points %d, choix %d", n.Niveau, n.Points, n.ElementsAChoisir)
	}
	if gain := n.Fangan + n.Gnanga + n.Manhis - depart.Fangan - depart.Gnanga - depart.Manhis; gain != 39 {
		t.Errorf("l'attribut de la région gagne 1 par niveau : +%d", gain)
	}
	if n.PV != n.PVMax() || v.Niveau != 40 {
		t.Errorf("le ninja est soigné et la vue à jour : PV %d/%d", n.PV, n.PVMax())
	}
	for _, c := range []int{40, 12, 101} {
		if _, err := p.PasserAuNiveau(c); err != ErrNiveauTest {
			t.Errorf("niveau %d refusé attendu : %v", c, err)
		}
	}
	if _, err := p.Repartir(100, 10, 7); err != nil || n.Points != 0 {
		t.Errorf("répartition libre des 117 points : %v, reste %d", err, n.Points)
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

func TestCarteDeplacements(t *testing.T) {
	p := nouvellePartie(t)
	p.Hasard = func() float64 { return 0.99 } // pas de rencontre
	n := p.Ninja
	v := n.VillageNatal()
	if n.Position != [2]int{v.X, v.Y} || n.Endurance != EnduranceMax {
		t.Fatalf("le ninja doit naître dans son village : %v / %v", n.Position, v)
	}
	if _, err := p.Deplacer(v.X+2, v.Y); err != ErrPasAdjacent {
		t.Errorf("deux cases d'un coup : %v", err)
	}
	// Un pas vers une case voisine praticable de niveau 1.
	var cible [2]int
	cout := 0
	for dy := -1; dy <= 1 && cout == 0; dy++ {
		for dx := -1; dx <= 1 && cout == 0; dx++ {
			cel := carte.Monde.Case(v.X+dx, v.Y+dy)
			if (dx != 0 || dy != 0) && cel != nil && carte.CoutTerrain[cel.Terrain] > 0 && carte.Monde.Zones[cel.Zone].Niveau == 1 {
				cible, cout = [2]int{v.X + dx, v.Y + dy}, carte.CoutTerrain[cel.Terrain]
			}
		}
	}
	res, err := p.Deplacer(cible[0], cible[1])
	if err != nil || n.Position != cible || n.Endurance != EnduranceMax-cout || res.Combat != nil {
		t.Fatalf("pas raté : %v, position %v, endurance %d", err, n.Position, n.Endurance)
	}
	// L'endurance revient avec le temps.
	now := p.Maintenant()
	p.Maintenant = func() time.Time { return now.Add(10 * time.Minute) }
	n.MajEndurance(p.Maintenant())
	if n.Endurance != EnduranceMax {
		t.Errorf("endurance après 10 minutes : %d", n.Endurance)
	}
	// Une rencontre en chemin (hors des lieux) lance un combat.
	p.Hasard = func() float64 { return 0 }
	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			x, y := n.Position[0]+dx, n.Position[1]+dy
			cel := carte.Monde.Case(x, y)
			if (dx == 0 && dy == 0) || cel == nil || cel.Lieu >= 0 || carte.CoutTerrain[cel.Terrain] == 0 || carte.Monde.Zones[cel.Zone].Niveau > 1 {
				continue
			}
			res, err = p.Deplacer(x, y)
			if err != nil || res.Combat == nil {
				t.Fatalf("rencontre attendue : %v", err)
			}
			if _, err := p.Deplacer(v.X, v.Y); err != ErrCombatEnCours {
				t.Errorf("on ne se déplace pas pendant un combat : %v", err)
			}
			ici := n.Position
			res2, _ := p.Fuir()
			if !res2.Fin.Defaite || n.Position != ici {
				t.Errorf("qui fuit reste où il est, sans renaître : %v", n.Position)
			}
			return
		}
	}
	t.Fatal("aucune case sauvage autour du village")
}

func TestCarteNiveauxReposEtDefis(t *testing.T) {
	p := nouvellePartie(t)
	n := p.Ninja
	// Une zone de niveau 20, visitée par un ninja de niveau 1.
	for _, z := range carte.Monde.Zones {
		if z.Region == n.Region && z.Niveau == 20 {
			for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, -1}, {1, -1}, {-1, 1}} {
				x, y := z.X+d[0], z.Y+d[1]
				if cel := carte.Monde.Case(x, y); cel != nil && carte.CoutTerrain[cel.Terrain] > 0 {
					n.Position = [2]int{x, y}
					if _, err := p.Deplacer(z.X, z.Y); err == nil {
						t.Error("une zone de niveau 20 doit être interdite au niveau 1")
					}
					break
				}
			}
		}
	}
	// Repos : au village oui, en brousse non.
	v := n.VillageNatal()
	n.Position = [2]int{v.X, v.Y}
	n.Endurance = 3
	if _, err := p.Reposer(); err != nil || n.Endurance != EnduranceMax {
		t.Errorf("repos au village : %v", err)
	}
	// Défi du lieu mythique des Lagunes.
	l := carte.Monde.LieuID("faubourgs_neo_ebrie")
	n.Position = [2]int{l.X, l.Y}
	if _, err := p.Defier(); err == nil {
		t.Error("les faubourgs demandent un niveau plus élevé")
	}
	n.Niveau = l.Niveau
	res, err := p.Defier()
	if err != nil || res.Combat == nil || res.Rencontre != "Patrouille du Cercle d'Acier" {
		t.Errorf("défi : %v %+v", err, res)
	}
}

func TestFavoris(t *testing.T) {
	p := nouvellePartie(t)
	suites := [][]string{
		{"lamantin", "martin_pecheur", "liane"}, {"lamantin", "martin_pecheur", "kola"},
		{"lamantin", "martin_pecheur", "braise"}, {"lamantin", "mante", "liane"},
		{"lamantin", "mante", "braise"}, {"lamantin", "tortue", "kola"},
	}
	for _, s := range suites {
		if _, err := p.Dojo(s); err != nil {
			t.Fatal(err)
		}
	}
	n := p.Ninja
	if len(n.Favoris) != FavorisMax || n.EstFavori("lamantin>tortue>kola") {
		t.Fatalf("les cinq premières découvertes sont favorites : %v", n.Favoris)
	}
	if _, err := p.Favori("lamantin>tortue>kola", true); err != ErrFavorisPleins {
		t.Errorf("pas plus de cinq favoris : %v", err)
	}
	if _, err := p.Favori("lamantin>martin_pecheur>liane", false); err != nil {
		t.Fatal(err)
	}
	v, err := p.Favori("lamantin>tortue>kola", true)
	if err != nil || !n.EstFavori("lamantin>tortue>kola") || len(n.Favoris) != FavorisMax {
		t.Errorf("échange de favori : %v %v", err, n.Favoris)
	}
	nb := 0
	for _, j := range v.Jutsus {
		if j.Favori {
			nb++
		}
	}
	if nb != FavorisMax {
		t.Errorf("la vue marque %d favoris", nb)
	}
	if _, err := p.Favori("panthere>mante>braise", true); err != ErrJutsuInconnu {
		t.Errorf("un jutsu inconnu ne peut pas être favori : %v", err)
	}
}

func TestSeulsLesFavorisEnCombat(t *testing.T) {
	p := nouvellePartie(t)
	n := p.Ninja
	connus := [][]string{
		{"lamantin", "martin_pecheur", "braise"}, {"lamantin", "martin_pecheur", "kola"}, {"lamantin", "mante", "braise"},
		{"lamantin", "mante", "liane"}, {"lamantin", "tortue", "kola"}, {"lamantin", "tortue", "braise"},
	}
	for _, seq := range connus {
		if _, err := p.Dojo(seq); err != nil {
			t.Fatal(err)
		}
	}
	if len(n.Favoris) != FavorisMax || n.EstFavori("lamantin>tortue>braise") {
		t.Fatalf("favoris : %v", n.Favoris)
	}
	if _, err := p.DemarrerCombat("chacals"); err != nil {
		t.Fatal(err)
	}
	if _, err := p.Agir(combat.Action{Type: combat.AIncanter, Sequence: connus[5]}); err != ErrPasFavori {
		t.Errorf("un jutsu connu hors des favoris doit être refusé : %v", err)
	}
	if _, err := p.Agir(combat.Action{Type: combat.AIncanter, Sequence: connus[0]}); err != nil {
		t.Errorf("un favori doit passer : %v", err)
	}
	if _, err := p.Agir(combat.Action{Type: combat.AIncanter, Sequence: []string{"lamantin", "martin_pecheur", "liane"}}); err != nil && err != ErrPasDeCombat {
		t.Errorf("une suite inconnue doit passer (découverte) : %v", err)
	}
}

func TestBlessuresDurables(t *testing.T) {
	p := nouvellePartie(t)
	n := p.Ninja
	now := p.Maintenant()
	n.MajPV(now)
	n.PV = n.PVMax() / 2
	n.PVMaj = now.Unix()
	if c := n.Combattant(now); c.PV != n.PVMax()/2 {
		t.Errorf("le combat doit commencer avec les blessures : %d", c.PV)
	}
	n.MajPV(now.Add(RegenPVSecondes * time.Second))
	if n.PV != n.PVMax() {
		t.Errorf("après une demi-heure, le ninja est guéri : %d/%d", n.PV, n.PVMax())
	}
}
