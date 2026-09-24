// Commande exporter-regles : écrit les règles du jeu en JSON pour le moteur
// local du client (client/donnees/regles.json), et des vecteurs de test qui
// garantissent que le moteur GDScript donne exactement les mêmes résultats.
//
//	go run ./cmd/exporter-regles -sortie ../client/donnees -tests ../client/tests
package main

import (
	"encoding/json"
	"flag"
	"log"
	"math/rand"
	"os"
	"path/filepath"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/api"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/game"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

func main() {
	sortie := flag.String("sortie", "../client/donnees", "dossier des règles")
	tests := flag.String("tests", "../client/tests", "dossier des vecteurs de test (vide : aucun)")
	flag.Parse()

	ecrire(filepath.Join(*sortie, "regles.json"), regles(), true)
	if *tests != "" {
		ecrire(filepath.Join(*tests, "vecteurs_grammaire.json"), vecteurs(), false)
	}
}

func regles() map[string]any {
	var fusions [][3]string
	for _, e := range data.AllElements() {
		if e.Tier == data.TierRare {
			fusions = append(fusions, [3]string{e.Fusion[0], e.Fusion[1], e.ID})
		}
	}
	var mudras []map[string]any
	for _, m := range data.AllMudras() {
		mudras = append(mudras, map[string]any{"id": m.ID, "nom": m.Nom, "categorie": m.Categorie, "ref": m.Ref, "niveau": m.Niveau})
	}
	var rencontres []map[string]any
	for _, r := range game.AllRencontres() {
		var ennemis []map[string]any
		for _, m := range r.Ennemis {
			ennemis = append(ennemis, map[string]any{
				"nom": m.Nom, "apparence": m.Apparence, "element": m.Element, "ia": m.IA,
				"fangan": m.Fangan, "gnanga": m.Gnanga, "manhis": m.Manhis, "pv": m.PV,
				"arme": m.Arme, "jutsus": m.Jutsus,
			})
		}
		rencontres = append(rencontres, map[string]any{
			"id": r.ID, "nom": r.Nom, "lieu": r.Lieu, "description": r.Description,
			"niveau": r.Niveau, "xp": r.XP, "dje": r.Dje, "ennemis": ennemis,
		})
	}
	legs, prefixes := grammar.LegendairesHaches()
	return map[string]any{
		"version":    api.Version,
		"elements":   data.AllElements(),
		"fusions":    fusions,
		"mudras":     mudras,
		"regions":    data.AllRegions(),
		"villages":   data.AllTypesVillage(),
		"rencontres": rencontres,
		"sauvages":   game.Sauvages,
		"carte":      carte.Monde.Export(),
		"grammaire":  grammar.Tables(),
		"legendaires": map[string]any{
			"sel": grammar.SelHachage, "recettes": legs, "prefixes": prefixes, "nombre": grammar.NombreLegendaires(),
		},
		"constantes": map[string]any{
			"niveau_max": game.NiveauMax, "palier_element": game.PalierElement,
			"points_par_niveau": game.PointsParNiveau, "attribut_depart": game.AttributDepart,
			"bonus_region": game.BonusRegion, "maitrise_parchemin": game.MaitriseParchemin,
			"maitrise_max": game.MaitriseMax, "maitrise_decouverte": combat.MaitriseDecouverte,
			"maitrise_pnj": combat.MaitrisePNJ, "tour_max": combat.TourMax,
			"niveau_fusion": data.NiveauFusion, "nb_rangs": combat.NbRangs,
			"favoris_max": game.FavorisMax, "endurance_max": game.EnduranceMax, "regen_secondes": game.RegenSecondes,
			"chance_rencontre": game.ChanceRencontre, "rayon_vision": game.RayonVision,
			"regen_pv_secondes": game.RegenPVSecondes, "rangs_max": combat.RangsMax,
		},
		"statuts": map[string]any{"bienfaits": combat.Bienfaits, "maux": combat.Maux},
	}
}

// vecteurs : des suites variées et ce que la grammaire Go en fait.
func vecteurs() []map[string]any {
	var ids, elems, formes, effets, mods []string
	for _, m := range data.AllMudras() {
		ids = append(ids, m.ID)
		switch m.Categorie {
		case data.CatElement:
			elems = append(elems, m.ID)
		case data.CatForme:
			formes = append(formes, m.ID)
		case data.CatEffet:
			effets = append(effets, m.ID)
		case data.CatModificateur:
			mods = append(mods, m.ID)
		}
	}
	rng := rand.New(rand.NewSource(42))
	pick := func(l []string) string { return l[rng.Intn(len(l))] }
	var suites [][]string
	// Suites aléatoires (surtout invalides).
	for i := 0; i < 1500; i++ {
		n := 1 + rng.Intn(8)
		s := make([]string, n)
		for k := range s {
			s[k] = pick(ids)
		}
		suites = append(suites, s)
	}
	// Suites qui suivent la grammaire (surtout valides), avec fusions.
	for i := 0; i < 1500; i++ {
		s := []string{pick(elems)}
		if rng.Intn(4) == 0 {
			s = append(s, pick(elems))
		}
		s = append(s, pick(formes))
		for rng.Intn(3) == 0 {
			s = append(s, pick(mods))
		}
		s = append(s, pick(effets))
		if rng.Intn(3) == 0 {
			s = append(s, pick(effets))
		}
		for rng.Intn(3) == 0 {
			s = append(s, pick(mods))
		}
		if len(s) <= grammar.LongueurMax {
			suites = append(suites, s)
		}
	}
	// Légendaires et quasi-légendaires.
	suites = append(suites,
		[]string{"panthere", "panthere", "mante", "lion", "braise"},
		[]string{"panthere", "panthere", "mante"},
		[]string{"scorpion", "calao", "case", "voile", "belier", "fleuve"},
		[]string{"elephant", "elephant", "case", "kola", "racine", "baobab"},
		[]string{"lamantin", "lamantin", "case", "kola"},
	)
	var out []map[string]any
	for _, s := range suites {
		v := map[string]any{"sequence": s}
		j, e := grammar.Analyser(s)
		if j != nil {
			v["jutsu"] = j
			// Puissance pour un combattant de référence (maîtrise 40, ciel neutre).
			ref := &combat.Combattant{Fangan: 10, Gnanga: 12, Manhis: 8}
			v["puissance_ref"] = combat.Puissance(ref, j, 40, 1)
		} else {
			v["echec"] = e
			v["resonance"] = grammar.Resonner(s, e, false)
			v["resonance_precise"] = grammar.Resonner(s, e, true)
		}
		out = append(out, v)
	}
	return out
}

func ecrire(chemin string, v any, lisible bool) {
	if err := os.MkdirAll(filepath.Dir(chemin), 0o755); err != nil {
		log.Fatal(err)
	}
	var b []byte
	var err error
	if lisible {
		b, err = json.MarshalIndent(v, "", " ")
	} else {
		b, err = json.Marshal(v)
	}
	if err != nil {
		log.Fatal(err)
	}
	if err := os.WriteFile(chemin, b, 0o644); err != nil {
		log.Fatal(err)
	}
	log.Printf("écrit : %s (%d octets)", chemin, len(b))
}
