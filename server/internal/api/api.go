// Package api expose la partie au client Godot en JSON sur HTTP.
package api

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/carte"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/combat"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/game"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/grammar"
)

// Version du protocole, vérifiée par le client.
const Version = "0.1.0"

// MudraPublic : ce que le client sait d'un mudra. Le sens exact des
// formes, effets et modificateurs n'est pas révélé : il se découvre.
type MudraPublic struct {
	ID        string         `json:"id"`
	Nom       string         `json:"nom"`
	Categorie data.Categorie `json:"categorie"`
	Niveau    int            `json:"niveau"`
	Element   string         `json:"element,omitempty"`
}

// Catalogue : données publiques du jeu.
type Catalogue struct {
	Version     string             `json:"version"`
	Regions     []data.Region      `json:"regions"`
	Villages    []data.TypeVillage `json:"villages"`
	Elements    []data.Element     `json:"elements"`
	Mudras      []MudraPublic      `json:"mudras"`
	NiveauMax   int                `json:"niveau_max"`
	Carte       map[string]any     `json:"carte"`
	Legendaires int                `json:"legendaires"`
}

func catalogue() Catalogue {
	c := Catalogue{
		Version: Version, Regions: data.AllRegions(), Villages: data.AllTypesVillage(),
		Elements: data.AllElements(), NiveauMax: game.NiveauMax,
		Legendaires: grammar.NombreLegendaires(), Carte: carte.Monde.Export(),
	}
	for _, m := range data.AllMudras() {
		mp := MudraPublic{ID: m.ID, Nom: m.Nom, Categorie: m.Categorie, Niveau: m.Niveau}
		if m.Categorie == data.CatElement {
			mp.Element = m.Ref
		}
		c.Mudras = append(c.Mudras, mp)
	}
	return c
}

// Serveur HTTP de la partie.
type Serveur struct {
	partie *game.Partie
	mux    *http.ServeMux
}

// Nouveau crée le serveur.
func Nouveau(p *game.Partie) *Serveur {
	s := &Serveur{partie: p, mux: http.NewServeMux()}
	cat := catalogue()
	s.mux.HandleFunc("GET /api/sante", func(w http.ResponseWriter, r *http.Request) {
		ecrire(w, map[string]string{"etat": "ok", "jeu": "ninja-ivoire", "version": Version})
	})
	s.mux.HandleFunc("GET /api/catalogue", func(w http.ResponseWriter, r *http.Request) { ecrire(w, cat) })
	s.mux.HandleFunc("GET /api/etat", func(w http.ResponseWriter, r *http.Request) { ecrire(w, p.Etat()) })
	s.mux.HandleFunc("POST /api/ninja", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Nom, Region, Village string }
		if lire(w, r, &req) {
			repondre(w)(p.Creer(req.Nom, req.Region, req.Village))
		}
	})
	s.mux.HandleFunc("DELETE /api/ninja", func(w http.ResponseWriter, r *http.Request) {
		if err := p.Abandonner(); err != nil {
			erreur(w, err)
			return
		}
		ecrire(w, map[string]bool{"ok": true})
	})
	s.mux.HandleFunc("POST /api/ninja/attributs", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Fangan, Gnanga, Manhis int }
		if lire(w, r, &req) {
			repondre(w)(p.Repartir(req.Fangan, req.Gnanga, req.Manhis))
		}
	})
	s.mux.HandleFunc("POST /api/ninja/element", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Element string }
		if lire(w, r, &req) {
			repondre(w)(p.ChoisirElement(req.Element))
		}
	})
	s.mux.HandleFunc("POST /api/ninja/favori", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Cle    string
			Favori bool
		}
		if lire(w, r, &req) {
			repondre(w)(p.Favori(req.Cle, req.Favori))
		}
	})
	s.mux.HandleFunc("POST /api/dojo", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Sequence []string }
		if lire(w, r, &req) {
			repondre(w)(p.Dojo(req.Sequence))
		}
	})
	s.mux.HandleFunc("GET /api/rencontres", func(w http.ResponseWriter, r *http.Request) { ecrire(w, p.ListeRencontres()) })
	s.mux.HandleFunc("POST /api/combat", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Rencontre string }
		if lire(w, r, &req) {
			repondre(w)(p.DemarrerCombat(req.Rencontre))
		}
	})
	s.mux.HandleFunc("POST /api/combat/action", func(w http.ResponseWriter, r *http.Request) {
		var a combat.Action
		if lire(w, r, &a) {
			repondre(w)(p.Agir(a))
		}
	})
	s.mux.HandleFunc("POST /api/combat/fuite", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Fuir())
	})
	s.mux.HandleFunc("POST /api/carte/deplacer", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ X, Y int }
		if lire(w, r, &req) {
			repondre(w)(p.Deplacer(req.X, req.Y))
		}
	})
	s.mux.HandleFunc("POST /api/carte/reposer", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Reposer())
	})
	s.mux.HandleFunc("POST /api/carte/defier", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Defier())
	})
	s.mux.HandleFunc("POST /api/carte/exploiter", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Exploiter())
	})
	s.mux.HandleFunc("POST /api/carte/affronter", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Affronter())
	})
	s.mux.HandleFunc("POST /api/carte/ignorer", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Ignorer())
	})
	s.mux.HandleFunc("POST /api/carte/camp", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.AttaquerCamp())
	})
	s.mux.HandleFunc("POST /api/village/deposer", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Deposer())
	})
	s.mux.HandleFunc("POST /api/village/reprendre", func(w http.ResponseWriter, r *http.Request) {
		repondre(w)(p.Reprendre())
	})
	s.mux.HandleFunc("POST /api/forge/fabriquer", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Objet string }
		if lire(w, r, &req) {
			repondre(w)(p.Fabriquer(req.Objet))
		}
	})
	s.mux.HandleFunc("POST /api/equipement/equiper", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Objet string }
		if lire(w, r, &req) {
			repondre(w)(p.Equiper(req.Objet))
		}
	})
	s.mux.HandleFunc("POST /api/equipement/retirer", func(w http.ResponseWriter, r *http.Request) {
		var req struct{ Emplacement string }
		if lire(w, r, &req) {
			repondre(w)(p.Retirer(req.Emplacement))
		}
	})
	return s
}

// ServeHTTP implémente http.Handler.
func (s *Serveur) ServeHTTP(w http.ResponseWriter, r *http.Request) { s.mux.ServeHTTP(w, r) }

func lire(w http.ResponseWriter, r *http.Request, v any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<16)
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		http.Error(w, `{"erreur":"requête illisible"}`, http.StatusBadRequest)
		return false
	}
	return true
}

func ecrire(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("écriture de la réponse : %v", err)
	}
}

func erreur(w http.ResponseWriter, err error) {
	code := http.StatusBadRequest
	if errors.Is(err, game.ErrPasDeNinja) || errors.Is(err, game.ErrPasDeCombat) {
		code = http.StatusConflict
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{"erreur": err.Error()})
}

// repondre fabrique un écrivain pour les méthodes (valeur, erreur).
func repondre(w http.ResponseWriter) func(any, error) {
	return func(v any, err error) {
		if err != nil {
			erreur(w, err)
			return
		}
		ecrire(w, v)
	}
}
