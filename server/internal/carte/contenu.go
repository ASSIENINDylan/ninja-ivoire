package carte

// Contenu des cases : une case peut être libre, abriter un camp de bandits
// ou un gisement de ressource (fer, peau d'animaux, pierre, or, diamant).
// Le contenu est tiré une fois pour toutes, de façon déterministe.

// Contenus possibles, dans l'ordre d'export (0 : case libre).
const (
	Libre   = ""
	Camp    = "camp"
	Fer     = "fer"
	Peau    = "peau"
	Pierre  = "pierre"
	Or      = "or"
	Diamant = "diamant"
)

// Contenus dans l'ordre d'export.
var Contenus = []string{Libre, Camp, Fer, Peau, Pierre, Or, Diamant}

// Ressources exploitables.
var Ressources = []string{Fer, Peau, Pierre, Or, Diamant}

// NomsContenus pour l'affichage.
var NomsContenus = map[string]string{
	Libre: "Case libre", Camp: "Camp de bandits", Fer: "Gisement de fer", Peau: "Terrain de chasse (peaux)",
	Pierre: "Carrière de pierre", Or: "Filon d'or", Diamant: "Gisement de diamants",
}

// NiveauRessource : niveau de zone à partir duquel une ressource apparaît.
var NiveauRessource = map[string]int{Fer: 1, Peau: 1, Pierre: 1, Or: 3, Diamant: 6}

type poids struct {
	ressource string
	poids     int
}

// ressourcesTerrain : quelles ressources on trouve dans chaque terrain.
var ressourcesTerrain = map[string][]poids{
	Savane:       {{Pierre, 3}, {Peau, 4}, {Fer, 1}, {Diamant, 1}},
	SavaneBoisee: {{Peau, 3}, {Fer, 3}, {Pierre, 2}, {Diamant, 3}},
	Foret:        {{Peau, 4}, {Fer, 1}, {Or, 1}},
	ForetDense:   {{Peau, 3}, {Or, 2}, {Diamant, 2}},
	Montagne:     {{Fer, 4}, {Pierre, 4}, {Or, 2}, {Diamant, 3}},
	Fleuve:       {{Or, 3}, {Pierre, 2}},
	Lagune:       {{Peau, 2}, {Pierre, 1}},
	Littoral:     {{Pierre, 3}, {Peau, 1}},
}

// hasardCase : un nombre dans [0, 1) propre à une case et à un tirage.
func hasardCase(x, y, k int) float64 {
	h := uint64(x)*0x9E3779B97F4A7C15 ^ uint64(y)*0xC2B2AE3D27D4EB4F ^ uint64(k)*0x165667B19E3779F9
	h ^= h >> 33
	h *= 0xFF51AFD7ED558CCD
	h ^= h >> 33
	h *= 0xC4CEB9FE1A85EC53
	h ^= h >> 33
	return float64(h>>11) / float64(uint64(1)<<53)
}

// peupler tire le contenu de chaque case praticable sans lieu.
func (c *Carte) peupler() {
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			cel := &c.Cellules[y*L+x]
			if cel.Zone < 0 || cel.Lieu >= 0 || CoutTerrain[cel.Terrain] == 0 {
				continue
			}
			niveau := c.Zones[cel.Zone].Niveau
			u, v := hasardCase(x, y, 1), hasardCase(x, y, 2)
			pCamp := 0.05
			if niveau <= 1 {
				pCamp = 0.025
			}
			if cel.Region == "coeur" {
				pCamp = 0 // le Cœur est sûr
			}
			if u < pCamp {
				cel.Contenu = Camp
				continue
			}
			if u >= pCamp+0.22 {
				continue
			}
			var choix []poids
			total := 0
			for _, p := range ressourcesTerrain[cel.Terrain] {
				if niveau >= NiveauRessource[p.ressource] {
					choix = append(choix, p)
					total += p.poids
				}
			}
			if total == 0 {
				continue
			}
			t := v * float64(total)
			for _, p := range choix {
				if t < float64(p.poids) {
					cel.Contenu = p.ressource
					break
				}
				t -= float64(p.poids)
			}
		}
	}
}
