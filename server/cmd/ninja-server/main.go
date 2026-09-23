// Commande ninja-server : serveur local du prototype de Ninja Ivoire.
// Le client Godot le lance automatiquement au démarrage.
package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/api"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/game"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:7777", "adresse d'écoute")
	save := flag.String("save", defautSauvegarde(), "fichier de sauvegarde")
	flag.Parse()

	p, err := game.Charger(*save)
	if err != nil {
		log.Fatalf("chargement de la sauvegarde %s : %v", *save, err)
	}
	srv := &http.Server{
		Addr:              *addr,
		Handler:           api.Nouveau(p),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("Ninja Ivoire %s — serveur local sur http://%s (sauvegarde : %s)", api.Version, *addr, *save)
	log.Fatal(srv.ListenAndServe())
}

func defautSauvegarde() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = "."
	}
	return filepath.Join(dir, "NinjaIvoire", "ninja.save.json")
}
