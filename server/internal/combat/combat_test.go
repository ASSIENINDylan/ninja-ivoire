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
	batteur.Jutsus = []*grammar.Jutsu{jutsu(t, "tambour", "martin_pecheur", "braise")}
	c := Nouveau("t", []*Combattant{joueur, batteur}, 3, midi)
	evts, err := c.JouerTour([]Action{{Acteur: "joueur", Type: AIncanter, Sequence: []string{"panthere", "mante", "lion", "braise", "liane"}}})
	if err != nil {
		t.Fatal(err)
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
