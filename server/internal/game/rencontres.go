package game

import (
	"fmt"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// ModelePNJ décrit un adversaire.
type ModelePNJ struct {
	Nom       string
	Apparence string
	Element   string
	IA        string
	Fangan    int // attributs au niveau 1 ; ils grandissent avec le niveau
	Gnanga    int
	Manhis    int
	PV        int
	Arme      combat.Arme
	Jutsus    [][]string // suites de mudras connues
}

// Rencontre est un combat proposé au joueur.
type Rencontre struct {
	ID          string       `json:"id"`
	Nom         string       `json:"nom"`
	Lieu        string       `json:"lieu"`
	Description string       `json:"description"`
	Niveau      int          `json:"niveau"`
	Ennemis     []*ModelePNJ `json:"-"`
	Noms        []string     `json:"ennemis"`
	XP          int          `json:"xp"`
	Dje         int          `json:"dje"`
}

var (
	chacal = &ModelePNJ{Nom: "Chacal", Apparence: "chacal", IA: combat.IABete, Fangan: 7, Manhis: 12, PV: 50,
		Arme: combat.Arme{Nom: "ses crocs", Puissance: 5}}
	brigandLagune = &ModelePNJ{Nom: "Brigand des lagunes", Apparence: "brigand", Element: "eau", IA: combat.IANinja, Fangan: 9, Gnanga: 8, Manhis: 9, PV: 75,
		Arme:   combat.Arme{Nom: "une machette", Puissance: 7},
		Jutsus: [][]string{{"lamantin", "martin_pecheur", "liane"}}}
	renegat = &ModelePNJ{Nom: "Apprenti renégat", Apparence: "ninja_renegat", Element: "foudre", IA: combat.IANinja, Fangan: 9, Gnanga: 10, Manhis: 11, PV: 85,
		Arme:   combat.Arme{Nom: "des dagues", Puissance: 7},
		Jutsus: [][]string{{"aigle", "martin_pecheur", "braise"}, {"aigle", "mante", "liane"}}}
	espritTai = &ModelePNJ{Nom: "Esprit de la forêt de Taï", Apparence: "esprit", Element: "vegetal", IA: combat.IANinja, Fangan: 8, Gnanga: 14, Manhis: 8, PV: 130,
		Arme:   combat.Arme{Nom: "ses branches", Puissance: 6},
		Jutsus: [][]string{{"chimpanze", "araignee", "liane", "braise"}, {"chimpanze", "tortue", "kola"}, {"chimpanze", "martin_pecheur", "kola"}}}
	droneAcier = &ModelePNJ{Nom: "Drone du Cercle d'Acier", Apparence: "drone", Element: "metal", IA: combat.IANinja, Fangan: 8, Gnanga: 9, Manhis: 14, PV: 70,
		Arme:   combat.Arme{Nom: "un laser", Puissance: 8, Distance: true},
		Jutsus: [][]string{{"enclume", "martin_pecheur", "hache"}}}
	cyberNinja = &ModelePNJ{Nom: "Ninja cybernétique", Apparence: "cyborg", Element: "foudre", IA: combat.IANinja, Fangan: 12, Gnanga: 10, Manhis: 12, PV: 120,
		Arme:   combat.Arme{Nom: "une lame à plasma", Puissance: 10},
		Jutsus: [][]string{{"aigle", "mante", "lion", "hache"}, {"aigle", "pangolin", "liane"}}}
	adepteSansVisage = &ModelePNJ{Nom: "Adepte Sans-Visage", Apparence: "sans_visage", Element: "lune", IA: combat.IANinja, Fangan: 8, Gnanga: 15, Manhis: 11, PV: 100,
		Arme:   combat.Arme{Nom: "une faucille", Puissance: 7},
		Jutsus: [][]string{{"hibou", "martin_pecheur", "voile", "liane"}, {"hibou", "case", "braise"}, {"hibou", "martin_pecheur", "kola"}}}
	batteurSansVisage = &ModelePNJ{Nom: "Batteur Sans-Visage", Apparence: "sans_visage", Element: "son", IA: combat.IANinja, Fangan: 9, Gnanga: 13, Manhis: 12, PV: 90,
		Arme:   combat.Arme{Nom: "un tambour de guerre", Puissance: 6, Distance: true},
		Jutsus: [][]string{{"tambour", "martin_pecheur", "belier"}, {"tambour", "case", "racine"}}}
	pantherePNJ = &ModelePNJ{Nom: "Panthère des bois", Apparence: "chacal", IA: combat.IABete, Fangan: 11, Manhis: 16, PV: 85,
		Arme: combat.Arme{Nom: "ses griffes", Puissance: 8}}
	gardePortail = &ModelePNJ{Nom: "Gardien du portail", Apparence: "gardien", Element: "terre", IA: combat.IANinja, Fangan: 16, Gnanga: 12, Manhis: 8, PV: 260,
		Arme:   combat.Arme{Nom: "une massue de pierre", Puissance: 12},
		Jutsus: [][]string{{"buffle", "tortue", "lion", "belier"}, {"buffle", "mante", "hache"}, {"buffle", "case", "liane"}}}
)

var rencontreList = []*Rencontre{
	{ID: "chacals", Nom: "Chacals affamés", Lieu: "Savane des Hautes Savanes", Niveau: 1, XP: 40, Dje: 10,
		Description: "Deux chacals rôdent autour du village. Un bon premier combat.",
		Ennemis:     []*ModelePNJ{chacal, chacal}},
	{ID: "brigand", Nom: "Brigand des lagunes", Lieu: "Mangroves de la lagune Ébrié", Niveau: 2, XP: 70, Dje: 25,
		Description: "Un brigand qui connaît quelques signes d'Eau rançonne les pêcheurs.",
		Ennemis:     []*ModelePNJ{brigandLagune}},
	{ID: "renegat", Nom: "Apprenti renégat", Lieu: "Sentiers des cascades de Man", Niveau: 3, XP: 110, Dje: 40,
		Description: "Un apprenti a fui son académie avec des secrets de Foudre.",
		Ennemis:     []*ModelePNJ{renegat}},
	{ID: "esprit_tai", Nom: "Esprit de la forêt", Lieu: "Cœur de la forêt de Taï", Niveau: 5, XP: 180, Dje: 60,
		Description: "Un esprit ancien protège la forêt. Il soigne ses blessures et enserre ses proies.",
		Ennemis:     []*ModelePNJ{espritTai}},
	{ID: "cercle_acier", Nom: "Patrouille du Cercle d'Acier", Lieu: "Faubourgs de Néo-Ébrié", Niveau: 7, XP: 280, Dje: 90,
		Description: "Deux drones escortent un ninja cybernétique. Le Cercle d'Acier veut remplacer le Souffle par la machine.",
		Ennemis:     []*ModelePNJ{cyberNinja, droneAcier, droneAcier}},
	{ID: "sans_visage", Nom: "Rituel des Sans-Visage", Lieu: "Rives du lac de Kossou", Niveau: 10, XP: 420, Dje: 130,
		Description: "Des adeptes tentent de réveiller un esprit scellé. Leurs tambours brisent les incantations.",
		Ennemis:     []*ModelePNJ{adepteSansVisage, batteurSansVisage, adepteSansVisage}},
	{ID: "panthere", Nom: "Panthère des bois", Lieu: "Forêts du Sud", Niveau: 3, XP: 100, Dje: 30,
		Description: "Une panthère silencieuse chasse entre les fromagers.",
		Ennemis:     []*ModelePNJ{pantherePNJ}},
	{ID: "portail", Nom: "Gardien du portail", Lieu: "Portail de région", Niveau: 15, XP: 800, Dje: 300,
		Description: "Le gardien d'un portail de région. Chaque vendredi soir, il faut le vaincre pour lancer un siège.",
		Ennemis:     []*ModelePNJ{gardePortail}},
}

// Rencontres indexe les rencontres.
var Rencontres = map[string]*Rencontre{}

func init() {
	for _, r := range rencontreList {
		Rencontres[r.ID] = r
		for _, e := range r.Ennemis {
			r.Noms = append(r.Noms, e.Nom)
		}
	}
}

// Sauvages : les rencontres possibles en chemin, selon le terrain.
var Sauvages = map[string][]string{
	"savane":        {"chacals"},
	"savane_boisee": {"chacals", "renegat"},
	"foret":         {"panthere", "brigand"},
	"foret_dense":   {"panthere", "esprit_tai"},
	"montagne":      {"renegat"},
	"fleuve":        {"brigand"},
	"lagune":        {"brigand"},
	"littoral":      {"brigand"},
}

// Recompenses : expérience et Djê d'une rencontre à un niveau donné.
func (r *Rencontre) Recompenses(niveau int) (int, int) {
	niveau = max(1, niveau)
	return r.XP * niveau / r.Niveau, r.Dje * niveau / r.Niveau
}

// AllRencontres renvoie les rencontres dans l'ordre.
func AllRencontres() []*Rencontre { return rencontreList }

// Instancier crée les combattants d'une rencontre au niveau demandé
// (celui de la zone où elle a lieu).
func (r *Rencontre) Instancier(niveau int) []*combat.Combattant {
	var out []*combat.Combattant
	for i, m := range r.Ennemis {
		lv := max(1, niveau)
		f := &combat.Combattant{
			ID: fmt.Sprintf("pnj%d", i+1), Nom: m.Nom, Camp: 1, Rang: i + 1, Apparence: m.Apparence,
			Niveau: lv, Fangan: m.Fangan + lv, Gnanga: m.Gnanga + lv, Manhis: m.Manhis + lv/2,
			Element: m.Element, IA: m.IA, Arme: m.Arme,
		}
		if m.Element != "" {
			f.Elements = []string{m.Element}
		}
		f.PVMax = m.PV + lv*8
		f.PV = f.PVMax
		f.SouffleMax = 40 + f.Gnanga*3
		f.Souffle = f.SouffleMax
		f.Defense = f.Fangan / 2
		for _, seq := range m.Jutsus {
			if j, e := grammar.Analyser(seq); e == nil {
				f.Jutsus = append(f.Jutsus, j)
			}
		}
		out = append(out, f)
	}
	return out
}
