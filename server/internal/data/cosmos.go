package data

import (
	"math"
	"time"
)

// Le Soleil et la Lune suivent l'heure réelle du serveur.

const moisSynodique = 29.530588853 // jours

// nouvelleLuneReference : nouvelle lune du 6 janvier 2000 à 18 h 14 UTC.
var nouvelleLuneReference = time.Date(2000, 1, 6, 18, 14, 0, 0, time.UTC)

// PhaseLune renvoie la phase de la lune entre 0 (nouvelle lune) et 1
// (lune suivante) ; 0,5 est la pleine lune.
func PhaseLune(t time.Time) float64 {
	jours := t.Sub(nouvelleLuneReference).Hours() / 24
	p := math.Mod(jours/moisSynodique, 1)
	if p < 0 {
		p++
	}
	return p
}

// Illumination renvoie la part éclairée de la lune (0 à 1).
func Illumination(t time.Time) float64 {
	return (1 - math.Cos(2*math.Pi*PhaseLune(t))) / 2
}

// NomPhase donne le nom de la phase lunaire.
func NomPhase(t time.Time) string {
	p := PhaseLune(t)
	switch {
	case p < 0.03 || p >= 0.97:
		return "Nouvelle lune"
	case p < 0.22:
		return "Premier croissant"
	case p < 0.28:
		return "Premier quartier"
	case p < 0.47:
		return "Lune gibbeuse croissante"
	case p < 0.53:
		return "Pleine lune"
	case p < 0.72:
		return "Lune gibbeuse décroissante"
	case p < 0.78:
		return "Dernier quartier"
	default:
		return "Dernier croissant"
	}
}

// heureDecimale renvoie l'heure locale sous forme décimale (13 h 30 → 13,5).
func heureDecimale(t time.Time) float64 {
	return float64(t.Hour()) + float64(t.Minute())/60
}

// EstNuit : de 19 h à 6 h.
func EstNuit(t time.Time) bool {
	h := heureDecimale(t)
	return h >= 19 || h < 6
}

// FacteurSoleil : 1,3 à midi, 0,7 à minuit, variation douce entre les deux.
func FacteurSoleil(t time.Time) float64 {
	h := heureDecimale(t)
	return 1 + 0.3*math.Cos((h-12)/24*2*math.Pi)
}

// FacteurLune : fort la nuit, et d'autant plus que la lune est pleine.
// De 0,7 (plein jour, nouvelle lune) à 1,45 (nuit de pleine lune).
func FacteurLune(t time.Time) float64 {
	nuit := (1 - math.Cos((heureDecimale(t)-12)/24*2*math.Pi)) / 2 // 0 à midi, 1 à minuit
	return 0.7 + 0.45*nuit + 0.3*Illumination(t)*nuit
}

// FacteurCosmique renvoie le multiplicateur de puissance d'un élément selon
// l'heure. Seuls le Soleil, la Lune et leurs fusions sont concernés.
func FacteurCosmique(element string, t time.Time) float64 {
	switch element {
	case "soleil", "cristal", "bois_sacre":
		return FacteurSoleil(t)
	case "lune", "songe", "maree":
		return FacteurLune(t)
	case "crepuscule":
		return math.Max(FacteurSoleil(t), FacteurLune(t))
	}
	return 1
}
