package combat

import (
	"testing"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

func midi() time.Time { return time.Date(2026, 9, 23, 12, 0, 0, 0, time.Local) }

func ninja(id string, camp int, element string) *Combattant {
	return &Combattant{
		ID: id, Nom: id, Camp: camp, Rang: 1, Niveau: 5,
		Fangan: 10, Gnanga: 10, Manhis: 10,
		PV: 120, PVMax: 120, Souffle: 100, SouffleMax: 100,
		Element: element, Elements: []string{element},
		Arme: Arme{Nom: "un sabre", Puissance: 8}, IA: IANinja,
	}
}

func jutsu(t *testing.T, seq ...string) *grammar.Jutsu {
	j, e := grammar.Analyser(seq)
	if e != nil {
		t.Fatalf("suite invalide %v : %+v", seq, e)
	}
	return j
}

func TestCombatSeTermine(t *testing.T) {
	joueur := ninja("joueur", 0, "feu")
	joueur.Joueur, joueur.IA = true, ""
	bandit := ninja("bandit", 1, "vegetal")
	bandit.Jutsus = []*grammar.Jutsu{jutsu(t, "chimpanze", "martin_pecheur", "liane")}
	c := Nouveau("t", []*Combattant{joueur, bandit}, 1, midi)
	for i := 0; i < TourMax && !c.Fini; i++ {
		if _, err := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"panthere", "martin_pecheur", "braise"}, Cible: "bandit"}}); err != nil {
			t.Fatal(err)
		}
	}
	if !c.Fini || c.Vainqueur != 0 {
		t.Fatalf("le Feu devrait vaincre le Végétal : fini=%v vainqueur=%d", c.Fini, c.Vainqueur)
	}
	if len(c.Decouvertes) != 1 || c.Usages["panthere>martin_pecheur>braise"] == 0 {
		t.Errorf("découverte non enregistrée : %+v", c.Decouvertes)
	}
}

func TestIncantationLongueInterrompue(t *testing.T) {
	joueur := ninja("joueur", 0, "feu")
	joueur.Joueur, joueur.IA = true, ""
	joueur.Gnanga = 0 // 3 mudras par tour : une suite de 5 prend 2 tours
	batteur := ninja("batteur", 1, "son")
	batteur.Gnanga = 30
	batteur.Manhis, joueur.Manhis = 40, 0 // le batteur agit toujours avant
	joueur.PV, joueur.PVMax = 400, 400
	batteur.Jutsus = []*grammar.Jutsu{jutsu(t, "tambour", "martin_pecheur", "braise")}
	c := Nouveau("t", []*Combattant{joueur, batteur}, 3, midi)
	evts, err := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"panthere", "mante", "lion", "braise", "liane"}}})
	if err != nil {
		t.Fatal(err)
	}
	if joueur.Incantation != nil {
		suite, _ := c.JouerTour(nil)
		evts = append(evts, suite...)
	}
	interrompu := false
	for _, e := range evts {
		if e.Type == "interruption" && e.Cible == "joueur" {
			interrompu = true
		}
	}
	if !interrompu || joueur.Incantation != nil {
		t.Errorf("l'IA aurait dû briser l'incantation avec le Son ; événements : %+v", evts)
	}
}

func TestMudraInterdit(t *testing.T) {
	joueur := ninja("joueur", 0, "feu")
	joueur.Joueur = true
	joueur.Permis = map[string]bool{"panthere": true, "martin_pecheur": true, "braise": true}
	c := Nouveau("t", []*Combattant{joueur, ninja("x", 1, "eau")}, 1, midi)
	_, err := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"lamantin", "martin_pecheur", "braise"}}})
	if err != ErrMudraInterdit {
		t.Errorf("attendu ErrMudraInterdit, obtenu %v", err)
	}
}

func TestVueCacheLesMudrasAdverses(t *testing.T) {
	joueur := ninja("joueur", 0, "feu")
	adv := ninja("adv", 1, "eau")
	adv.Incantation = &Incantation{Sequence: []string{"lamantin", "case", "braise"}, Progres: 1, Total: 3}
	c := Nouveau("t", []*Combattant{joueur, adv}, 1, midi)
	v := c.Vue(0)
	if v.Get("adv").Incantation.Sequence != nil {
		t.Error("le joueur ne doit pas voir les mudras de l'adversaire")
	}
	if c.Get("adv").Incantation.Sequence == nil {
		t.Error("la vue ne doit pas modifier l'état réel")
	}
}

func TestEchecDonneUneResonance(t *testing.T) {
	joueur := ninja("joueur", 0, "feu")
	joueur.Joueur, joueur.IA = true, ""
	c := Nouveau("t", []*Combattant{joueur, ninja("adv", 1, "eau")}, 1, midi)
	if _, err := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"panthere", "panthere", "mante"}}}); err != nil {
		t.Fatal(err)
	}
	if len(c.Resonances) != 1 || !c.Resonances[0].Ancienne {
		t.Errorf("une résonance ancienne était attendue : %+v", c.Resonances)
	}
}

func TestLegendaireRefuseSousLeNiveau(t *testing.T) {
	joueur := ninja("joueur", 0, "feu")
	joueur.Joueur, joueur.IA = true, ""
	joueur.Niveau = 3
	joueur.Contexte = &grammar.Contexte{Niveau: 3, Elements: []string{"feu"}, Moment: midi()}
	c := Nouveau("t", []*Combattant{joueur, ninja("adv", 1, "eau")}, 1, midi)
	evts, _ := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"panthere", "panthere", "mante", "lion", "braise"}}})
	evts2, _ := c.JouerTour(nil)
	for _, e := range append(evts, evts2...) {
		if e.Type == "decouverte" {
			t.Fatal("un légendaire ne doit pas être découvert sous le niveau requis")
		}
	}
}

func joueurSeul(t *testing.T, element string) *Combattant {
	j := ninja("joueur", 0, element)
	j.Joueur, j.IA = true, ""
	return j
}

// lancerDirect applique un jutsu sans incantation (pour tester ses effets).
func lancerDirect(c *Combat, f *Combattant, j *grammar.Jutsu, cible string) []Evenement {
	c.evts = nil
	c.lancer(f, j, cible, 1, false)
	return c.evts
}

func TestDegatsPursIgnorentLaDefense(t *testing.T) {
	j := joueurSeul(t, "feu")
	cible := ninja("mur", 1, "terre")
	cible.Defense, cible.DefenseMag, cible.Manhis = 200, 200, 0
	c := Nouveau("t", []*Combattant{j, cible}, 1, midi)
	avant := cible.PV
	lancerDirect(c, j, jutsu(t, "panthere", "martin_pecheur", "hache"), "mur")
	phys := avant - cible.PV
	avant = cible.PV
	lancerDirect(c, j, jutsu(t, "panthere", "martin_pecheur", "kaolin"), "mur")
	pur := avant - cible.PV
	if pur <= phys*3 {
		t.Errorf("les dégâts purs devraient traverser l'armure : physiques %d, purs %d", phys, pur)
	}
}

func TestIntangibleEtClone(t *testing.T) {
	j := joueurSeul(t, "brume")
	adv := ninja("adv", 1, "eau")
	c := Nouveau("t", []*Combattant{j, adv}, 1, midi)
	lancerDirect(c, j, jutsu(t, "cameleon", "pangolin", "feuille"), "") // intangible physique
	if !j.A("intangible_phys") {
		t.Fatal("le lanceur devrait être insensible aux dégâts physiques")
	}
	pv := j.PV
	c.infliger(adv, j, 50, grammar.NPhysique, "", false)
	if j.PV != pv {
		t.Error("des dégâts physiques ont traversé l'intangibilité")
	}
	c.infliger(adv, j, 50, grammar.NMagique, "eau", false)
	if j.PV == pv {
		t.Error("les dégâts magiques devraient toucher")
	}

	lancerDirect(c, j, jutsu(t, "cameleon", "perroquet", "voile"), "") // clone indiscernable
	if len(c.Vivants(0)) != 2 {
		t.Fatalf("un clone était attendu : %d combattants", len(c.Vivants(0)))
	}
	vue := c.Vue(1)
	var vus []*Combattant
	for _, f := range vue.Combattants {
		if f.Camp == 0 && f.Vivant() {
			vus = append(vus, f)
		}
	}
	if len(vus) != 2 || vus[0].Clone || vus[1].Clone || vus[0].PV != vus[1].PV || vus[0].Nom != vus[1].Nom {
		t.Errorf("l'adversaire ne doit pas distinguer le clone : %+v %+v", vus[0], vus[1])
	}
	if !c.Vue(0).Get("joueur2").Clone {
		t.Error("le joueur doit reconnaître son propre clone")
	}
}

func TestEntravesBloquentLesActions(t *testing.T) {
	j := joueurSeul(t, "feu")
	adv := ninja("adv", 1, "eau")
	adv.IA = IABete
	c := Nouveau("t", []*Combattant{j, adv}, 1, midi)
	c.ajouterStatut(j, &Statut{Type: "scelle", Tours: 2})
	evts, _ := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"panthere", "martin_pecheur", "braise"}}})
	for _, e := range evts {
		if e.Type == "jutsu" && e.Acteur == "joueur" {
			t.Fatal("des mains scellées ne forment pas de mudras")
		}
	}
	c.ajouterStatut(j, &Statut{Type: "desarme", Tours: 2})
	pv := adv.PV
	c.JouerTour([]Action{{Acteur: "joueur", Type: AFrapper, Cible: "adv"}})
	if adv.PV != pv {
		t.Error("un ninja désarmé ne frappe pas")
	}
}

func TestSoinDuLanceurEtBaume(t *testing.T) {
	j := joueurSeul(t, "eau")
	j.PV = 40
	c := Nouveau("t", []*Combattant{j, ninja("adv", 1, "feu")}, 1, midi)
	lancerDirect(c, j, jutsu(t, "lamantin", "martin_pecheur", "kola"), "")
	if j.PV <= 40 {
		t.Error("le soin devrait soigner le lanceur")
	}
	lancerDirect(c, j, jutsu(t, "lamantin", "tortue", "moustique"), "")
	if j.Baume() <= 0 {
		t.Error("un baume devrait attendre la fin du combat")
	}
}

func TestEntraveDependDeLaPuissance(t *testing.T) {
	reussites := func(gnanga int) int {
		n := 0
		for g := int64(0); g < 200; g++ {
			j := joueurSeul(t, "vegetal")
			j.Gnanga = gnanga
			adv := ninja("adv", 1, "eau")
			c := Nouveau("t", []*Combattant{j, adv}, g, midi)
			lancerDirect(c, j, jutsu(t, "chimpanze", "araignee", "liane"), "adv")
			if adv.A("scelle") {
				n++
			}
		}
		return n
	}
	faible, fort := reussites(2), reussites(40)
	if fort <= faible {
		t.Errorf("un Souffle plus fort devrait mieux sceller : %d contre %d", fort, faible)
	}
}
