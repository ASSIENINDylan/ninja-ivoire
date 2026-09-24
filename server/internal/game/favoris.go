package game

import (
	"errors"
	"sort"
)

// FavorisMax : nombre de jutsus favoris, ceux qu'on a sous la main en combat.
const FavorisMax = 5

// Erreurs des favoris.
var (
	ErrJutsuInconnu  = errors.New("ce jutsu n'est pas dans votre grimoire")
	ErrFavorisPleins = errors.New("5 jutsus favoris au maximum : retirez-en un d'abord")
)

// EstFavori indique si un jutsu fait partie des favoris.
func (n *Ninja) EstFavori(cle string) bool {
	for _, f := range n.Favoris {
		if f == cle {
			return true
		}
	}
	return false
}

// ChoisirFavori ajoute ou retire un jutsu des favoris.
func (n *Ninja) ChoisirFavori(cle string, favori bool) error {
	if n.Grimoire[cle] == nil {
		return ErrJutsuInconnu
	}
	if !favori {
		reste := []string{}
		for _, f := range n.Favoris {
			if f != cle {
				reste = append(reste, f)
			}
		}
		n.Favoris = reste
		return nil
	}
	if n.EstFavori(cle) {
		return nil
	}
	if len(n.Favoris) >= FavorisMax {
		return ErrFavorisPleins
	}
	n.Favoris = append(n.Favoris, cle)
	return nil
}

// initialiserFavoris : les sauvegardes d'avant les favoris reçoivent les
// premiers jutsus découverts ; les favoris disparus du grimoire sont retirés.
func (n *Ninja) initialiserFavoris() {
	if n.Favoris == nil {
		connus := make([]*JutsuConnu, 0, len(n.Grimoire))
		for _, k := range n.Grimoire {
			connus = append(connus, k)
		}
		sort.Slice(connus, func(i, j int) bool { return connus[i].Decouvert.Before(connus[j].Decouvert) })
		n.Favoris = []string{}
		for _, k := range connus {
			if len(n.Favoris) < FavorisMax {
				n.Favoris = append(n.Favoris, k.Cle)
			}
		}
	}
	gardes := []string{}
	for _, f := range n.Favoris {
		if n.Grimoire[f] != nil {
			gardes = append(gardes, f)
		}
	}
	n.Favoris = gardes
}

// Favori ajoute ou retire un jutsu des favoris.
func (p *Partie) Favori(cle string, favori bool) (*NinjaVue, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.Ninja == nil {
		return nil, ErrPasDeNinja
	}
	if err := p.Ninja.ChoisirFavori(cle, favori); err != nil {
		return nil, err
	}
	return p.vueNinja(), p.sauver()
}
