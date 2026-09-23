// Commande ninja-server : serveur local du prototype de Ninja Ivoire.
// Le client Godot le lance automatiquement au démarrage.
package main

import (
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/api"
	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/game"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:7777", "adresse d'écoute")
	save := flag.String("save", filepath.Join(dossierDonnees(), "ninja.save.json"), "fichier de sauvegarde")
	journal := flag.String("log", filepath.Join(dossierDonnees(), "serveur.log"), "fichier journal (vide : console seulement)")
	flag.Parse()

	if *journal != "" {
		if err := os.MkdirAll(filepath.Dir(*journal), 0o755); err == nil {
			if f, err := os.OpenFile(*journal, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644); err == nil {
				defer f.Close()
				log.SetOutput(io.MultiWriter(os.Stderr, f))
			}
		}
	}

	p, err := game.Charger(*save)
	if err != nil {
		log.Fatalf("ERREUR : chargement de la sauvegarde %s : %v", *save, err)
	}
	// On ouvre le port nous-mêmes pour signaler clairement s'il est occupé.
	ln, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatalf("ERREUR : impossible d'écouter sur %s (port déjà utilisé ?) : %v", *addr, err)
	}
	srv := &http.Server{
		Handler:           api.Nouveau(p),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("Ninja Ivoire %s — serveur local sur http://%s (sauvegarde : %s)", api.Version, ln.Addr(), *save)
	log.Fatal(srv.Serve(ln))
}

func dossierDonnees() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = "."
	}
	return filepath.Join(dir, "NinjaIvoire")
}
