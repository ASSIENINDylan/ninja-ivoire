package grammar

import (
	"encoding/json"
	"hash/fnv"
	"testing"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

func TestJutsuSimple(t *testing.T) {
	j, e := Analyser([]string{"panthere", "martin_pecheur", "braise"})
	if e != nil {
		t.Fatalf("échec inattendu : %+v", e)
	}
	if j.Nom != "Braise : Dard du frelon" || j.Nature != "Trait de Feu dévorant" {
		t.Errorf("nom = %q, nature = %q", j.Nom, j.Nature)
	}
	if j.Element != "feu" || j.Forme != data.FTrait || j.Effet != data.XConsumer {
		t.Errorf("jutsu mal analysé : %+v", j)
	}
}

func TestOrdreDesModificateursCompte(t *testing.T) {
	a, _ := Analyser([]string{"panthere", "mante", "lion", "braise"})
	b, _ := Analyser([]string{"panthere", "mante", "braise", "lion"})
	if a == nil || b == nil {
		t.Fatal("les deux suites devraient être valides")
	}
	if a.Nom == b.Nom || a.Coefs.N == b.Coefs.N {
		t.Errorf("l'ordre ne change rien : %q / %q", a.Nom, b.Nom)
	}
	if a.Nom != "Braise : Grand Croc de la hyène" || b.Nom != "Braise : Croc de la hyène — au paroxysme" {
		t.Errorf("noms : %q / %q", a.Nom, b.Nom)
	}
}

func TestNomsPoetiques(t *testing.T) {
	j, _ := Analyser([]string{"lamantin", "araignee", "liane", "braise", "fleuve"})
	if j.Nom != "Lagune : Toile d'Ananzè, qui dévore — sans fin" {
		t.Errorf("nom = %q", j.Nom)
	}
	for id, v := range voies {
		if data.Elements[id] == nil || v == "" {
			t.Errorf("voie sans élément : %q", id)
		}
	}
	if len(voies) != len(data.AllElements()) {
		t.Errorf("%d voies pour %d éléments", len(voies), len(data.AllElements()))
	}
}

func TestFusionOrdonnee(t *testing.T) {
	j, e := Analyser([]string{"panthere", "buffle", "mante", "braise"})
	if e != nil || j.Element != "lave" || !j.Fusion {
		t.Fatalf("Feu puis Terre devrait donner la Lave : %+v %+v", j, e)
	}
	if _, e := Analyser([]string{"buffle", "panthere", "mante", "braise"}); e == nil || e.Etape != "fusion" {
		t.Errorf("Terre puis Feu ne devrait rien donner : %+v", e)
	}
}

func TestEchecs(t *testing.T) {
	cas := map[string][]string{
		"element":       {"mante", "braise"},
		"forme":         {"panthere", "braise"},
		"effet":         {"panthere", "mante"},
		"surplus":       {"panthere", "mante", "braise", "liane", "kola"},
		"modificateurs": {"panthere", "mante", "lion", "fleuve", "braise", "fourmi"},
		"fusion":        {"panthere", "panthere", "martin_pecheur", "kola"},
	}
	for etape, seq := range cas {
		if _, e := Analyser(seq); e == nil || e.Etape != etape {
			t.Errorf("%v : attendu %q, obtenu %+v", seq, etape, e)
		}
	}
}

func TestLegendaireReconnuEtConditions(t *testing.T) {
	seq := []string{"panthere", "panthere", "mante", "lion", "braise"}
	j, e := Analyser(seq)
	if e != nil || j.Legendaire != "colere_panthere" {
		t.Fatalf("légendaire non reconnu : %+v %+v", j, e)
	}
	c := Legendaires[Cle(seq)].Conditions
	if c.Verifier(Contexte{Niveau: 3, Moment: time.Now()}) == "" {
		t.Error("un ninja de niveau 3 ne devrait pas pouvoir le lancer")
	}
	if c.Verifier(Contexte{Niveau: 9, Moment: time.Now()}) != "" {
		t.Error("un ninja de niveau 9 devrait pouvoir le lancer")
	}
}

func TestResonanceGuideVersLesLegendaires(t *testing.T) {
	seq := []string{"panthere", "panthere", "mante", "braise"}
	_, e := Analyser(seq)
	if e == nil {
		t.Fatal("la suite devrait échouer")
	}
	r := Resonner(seq, e, false)
	if !r.Ancienne || r.Score < 60 {
		t.Errorf("résonance ancienne attendue : %+v", r)
	}
	loin := []string{"mante", "braise", "liane", "kola"}
	_, e = Analyser(loin)
	r = Resonner(loin, e, true)
	if r.Ancienne || !r.RetourDeSouffle || r.Indice == "" {
		t.Errorf("résonance faible attendue avec retour de Souffle : %+v", r)
	}
}

// TestNombreDeJutsus énumère toute la grammaire et vérifie qu'elle offre
// bien des milliers de jutsus différents, chacun accepté par l'analyseur.
func TestNombreDeJutsus(t *testing.T) {
	var elems [][]string // un ou deux mudras d'élément
	for _, m := range data.AllMudras() {
		if m.Categorie == data.CatElement {
			elems = append(elems, []string{m.ID})
		}
	}
	for _, e := range data.AllElements() {
		if e.Tier == data.TierRare {
			elems = append(elems, []string{data.MudraOfElement[e.Fusion[0]], data.MudraOfElement[e.Fusion[1]]})
		}
	}
	var formes, effets, mods []string
	for _, m := range data.AllMudras() {
		switch m.Categorie {
		case data.CatForme:
			formes = append(formes, m.ID)
		case data.CatEffet:
			effets = append(effets, m.ID)
		case data.CatModificateur:
			mods = append(mods, m.ID)
		}
	}
	// Placements de 0 à 2 modificateurs distincts entre les deux emplacements.
	type placement struct{ avant, apres []string }
	places := []placement{{}}
	for _, a := range mods {
		places = append(places, placement{avant: []string{a}}, placement{apres: []string{a}})
		for _, b := range mods {
			if a != b {
				places = append(places,
					placement{avant: []string{a, b}},
					placement{avant: []string{a}, apres: []string{b}},
					placement{apres: []string{a, b}})
			}
		}
	}

	familles := map[string]bool{}
	profils := map[uint64][]string{} // empreinte du profil de combat → suite
	collisions := 0
	sansModificateur := map[string]bool{}
	total := 0
	for _, el := range elems {
		for _, f := range formes {
			for _, x1 := range effets {
				for _, x2 := range append([]string{""}, effets...) {
					if x2 == x1 {
						continue
					}
					for _, p := range places {
						seq := append(append([]string{}, el...), f)
						seq = append(seq, p.avant...)
						seq = append(seq, x1)
						if x2 != "" {
							seq = append(seq, x2)
						}
						seq = append(seq, p.apres...)
						j, e := Analyser(seq)
						if e != nil {
							t.Fatalf("suite rejetée : %v (%+v)", seq, e)
						}
						total++
						// Aucun autre jutsu ne doit avoir exactement le même effet en
						// combat : élément, structure et coefficients compris.
						h := empreinteProfil(j)
						if prec, ok := profils[h]; ok {
							collisions++
							if collisions < 5 {
								t.Errorf("même effet en combat : %v et %v", prec, seq)
							}
						}
						profils[h] = seq
						familles[j.Element+"/"+j.Forme+"/"+j.Effet] = true
						if len(p.avant)+len(p.apres) == 0 {
							if sansModificateur[j.Nom] && j.Legendaire == "" {
								t.Fatalf("deux jutsus portent le même nom : %q", j.Nom)
							}
							sansModificateur[j.Nom] = true
						}
					}
				}
			}
		}
	}
	t.Logf("familles : %d · sans modificateur : %d · total : %d · profils : %d · collisions : %d", len(familles), len(sansModificateur), total, len(profils), collisions)
	if len(familles) != 4000 || total < 4_000_000 {
		t.Errorf("attendu 4 000 familles et plus de 4 millions de jutsus, obtenu %d et %d", len(familles), total)
	}
}

func empreinteProfil(j *Jutsu) uint64 {
	b, _ := json.Marshal(map[string]any{
		"element": j.Element, "type": j.Type, "nature": j.DegatsNature, "coefs": j.Coefs, "effets": j.Effets,
		"delai": j.Delai, "echo": j.Echo, "incassable": j.Incassable, "indissipable": j.Indissipable,
	})
	h := fnv.New64a()
	h.Write(b)
	return h.Sum64()
}

// TestCellulesToutesDifferentes : les 100 couples forme × effet donnent
// 100 effets différents (les trois effets de dégâts diffèrent par la nature).
func TestCellulesToutesDifferentes(t *testing.T) {
	vus := map[string]string{}
	for x, formes := range Cellules {
		for f, l := range formes {
			b, _ := json.Marshal(l)
			k := NatureEffet[x] + string(b)
			if prec, ok := vus[k]; ok {
				t.Errorf("%s/%s et %s : même effet", x, f, prec)
			}
			vus[k] = x + "/" + f
		}
	}
	if len(vus) != 100 {
		t.Errorf("%d cellules distinctes", len(vus))
	}
}

func TestTypesEtNatures(t *testing.T) {
	cas := map[string][2]string{
		"braise": {TDegats, NMagique}, "hache": {TDegats, NPhysique}, "kaolin": {TDegats, NPur},
		"racine": {TDefense, ""}, "belier": {TEntrave, ""}, "liane": {TEntrave, ""},
		"voile": {TIllusion, ""}, "feuille": {TIllusion, ""}, "kola": {TSoin, ""}, "moustique": {TSoin, ""},
	}
	for x, attendu := range cas {
		j, e := Analyser([]string{"panthere", "martin_pecheur", x})
		if e != nil {
			t.Fatal(e)
		}
		if j.Type != attendu[0] || j.DegatsNature != attendu[1] {
			t.Errorf("%s : %s/%s, attendu %v", x, j.Type, j.DegatsNature, attendu)
		}
		if len(j.Effets) == 0 || j.Texte == "" {
			t.Errorf("%s : profil vide", x)
		}
	}
	// Les soins ne visent que le lanceur.
	for f := range Cellules[data.XSoigner] {
		for _, e := range Cellules[data.XSoigner][f] {
			if e.Op == OpSoin && e.Cible != CSoi {
				t.Errorf("soin qui vise %s", e.Cible)
			}
		}
	}
}

func TestCoefficientsPropresAChaqueJutsu(t *testing.T) {
	a, _ := Analyser([]string{"panthere", "martin_pecheur", "braise"})
	b, _ := Analyser([]string{"panthere", "martin_pecheur", "hache"})
	c, _ := Analyser([]string{"buffle", "martin_pecheur", "hache"})
	if a.Coefs.G <= a.Coefs.F || b.Coefs.F <= b.Coefs.G {
		t.Errorf("les dégâts magiques suivent le Gnanga, les physiques le Fangan : %+v / %+v", a.Coefs, b.Coefs)
	}
	if b.Coefs == c.Coefs {
		t.Errorf("deux éléments, mêmes coefficients : %+v", b.Coefs)
	}
}

func TestLongueurMaximale(t *testing.T) {
	seq := []string{"panthere", "buffle", "mante", "lion", "fleuve", "braise", "liane"}
	if _, e := Analyser(seq); e != nil {
		t.Errorf("7 mudras devraient suffire : %+v", e)
	}
	if _, e := Analyser(append(seq, "kola")); e == nil || e.Etape != "surplus" {
		t.Errorf("8 mudras devraient échouer : %+v", e)
	}
}
