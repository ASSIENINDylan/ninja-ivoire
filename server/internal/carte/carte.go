package carte

import (
	"fmt"
	"math"
	"sort"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

// Dimensions de la grille : des cases d'environ 15 km.
const (
	LonMin = -8.70
	LatMax = 10.75
	Pas    = 0.14
	L      = 45 // colonnes
	H      = 47 // lignes
)

// Terrains.
const (
	Savane       = "savane"
	SavaneBoisee = "savane_boisee"
	Foret        = "foret"
	ForetDense   = "foret_dense"
	Montagne     = "montagne"
	Fleuve       = "fleuve"
	Lac          = "lac"
	Lagune       = "lagune"
	Littoral     = "littoral"
)

// Terrains dans l'ordre d'export.
var Terrains = []string{Savane, SavaneBoisee, Foret, ForetDense, Montagne, Fleuve, Lac, Lagune, Littoral}

// CoutTerrain : endurance nécessaire pour entrer dans une case. 0 : infranchissable.
var CoutTerrain = map[string]int{
	Savane: 1, SavaneBoisee: 1, Littoral: 1, Foret: 2, Fleuve: 2, Lagune: 2,
	ForetDense: 3, Montagne: 3, Lac: 0,
}

// NomsTerrains pour l'affichage.
var NomsTerrains = map[string]string{
	Savane: "Savane", SavaneBoisee: "Savane boisée", Foret: "Forêt", ForetDense: "Forêt dense",
	Montagne: "Montagne", Fleuve: "Fleuve", Lac: "Lac", Lagune: "Lagune", Littoral: "Littoral",
}

// Niveaux des zones sans village, de la plus proche d'un village à la plus
// lointaine. Les zones qui abritent un village sont toujours de niveau 1.
var (
	NiveauxZones      = []int{3, 6, 10, 14, 20}
	NiveauxZonesCoeur = []int{2, 4, 6, 9, 12}
)

// Cellule : une case de la carte.
type Cellule struct {
	Region  string `json:"region"` // "" : hors du pays
	Zone    int    `json:"zone"`   // indice dans Carte.Zones, -1 hors du pays
	Terrain string `json:"terrain"`
	Lieu    int    `json:"lieu"` // indice dans Carte.Lieux, -1 sinon
}

// Zone : un morceau de région, qui peut changer de mains lors des sièges.
type Zone struct {
	ID     string `json:"id"`
	Region string `json:"region"`
	Rang   int    `json:"rang"` // 0 à 7, du plus proche au plus lointain
	Nom    string `json:"nom"`
	Niveau int    `json:"niveau"`
	X      int    `json:"x"`
	Y      int    `json:"y"`
}

// Lieu : village, ville, lieu mythique ou portail.
type Lieu struct {
	ID          string `json:"id"`
	Nom         string `json:"nom"`
	Type        string `json:"type"` // village, ville, mythique, portail
	Region      string `json:"region"`
	X           int    `json:"x"`
	Y           int    `json:"y"`
	TypeVillage string `json:"type_village,omitempty"`
	Niveau      int    `json:"niveau"`
	Rencontre   string `json:"rencontre,omitempty"`
	Description string `json:"description,omitempty"`
}

// Carte du monde.
type Carte struct {
	L        int       `json:"l"`
	H        int       `json:"h"`
	LonMin   float64   `json:"lon_min"`
	LatMax   float64   `json:"lat_max"`
	Pas      float64   `json:"pas"`
	Cellules []Cellule `json:"-"`
	Zones    []Zone    `json:"zones"`
	Lieux    []Lieu    `json:"lieux"`
	Contour  []Point   `json:"-"`
}

// Monde : la carte, calculée une fois pour toutes.
var Monde = generer()

// Dans indique si (x, y) est dans la grille.
func Dans(x, y int) bool { return x >= 0 && y >= 0 && x < L && y < H }

// Case renvoie la cellule (x, y), ou nil hors de la grille ou du pays.
func (c *Carte) Case(x, y int) *Cellule {
	if !Dans(x, y) {
		return nil
	}
	cel := &c.Cellules[y*L+x]
	if cel.Region == "" {
		return nil
	}
	return cel
}

// Centre renvoie le point géographique du centre de la case (x, y).
func Centre(x, y int) Point {
	return Point{LonMin + (float64(x)+0.5)*Pas, LatMax - (float64(y)+0.5)*Pas}
}

// CaseDe renvoie la case qui contient un point géographique.
func CaseDe(p Point) (int, int) {
	return int(math.Floor((p.Lon - LonMin) / Pas)), int(math.Floor((LatMax - p.Lat) / Pas))
}

// LieuID renvoie un lieu par identifiant.
func (c *Carte) LieuID(id string) *Lieu {
	for i := range c.Lieux {
		if c.Lieux[i].ID == id {
			return &c.Lieux[i]
		}
	}
	return nil
}

// VillageDe renvoie le lieu d'un village par région et type.
func (c *Carte) VillageDe(region, typeVillage string) *Lieu {
	for i := range c.Lieux {
		l := &c.Lieux[i]
		if l.Type == "village" && l.Region == region && l.TypeVillage == typeVillage {
			return l
		}
	}
	return nil
}

// --- Génération ------------------------------------------------------------

func generer() *Carte {
	c := &Carte{L: L, H: H, LonMin: LonMin, LatMax: LatMax, Pas: Pas, Contour: contour}
	c.Cellules = make([]Cellule, L*H)

	// 1. Régions : case la plus proche parmi les graines de chaque région
	//    (son centre et ses trois villages, qui y sont donc toujours).
	type graine struct {
		region string
		p      Point
	}
	var graines []graine
	for _, r := range data.AllRegions() {
		graines = append(graines, graine{r.ID, centresRegions[r.ID]})
		for _, p := range emplacementsVillages[r.ID] {
			graines = append(graines, graine{r.ID, p})
		}
	}
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			cel := &c.Cellules[y*L+x]
			cel.Zone, cel.Lieu = -1, -1
			p := Centre(x, y)
			if !dansPolygone(p, contour) {
				continue
			}
			best, dmin := "", math.Inf(1)
			for _, g := range graines {
				if d := dist(p, g.p); d < dmin {
					best, dmin = g.region, d
				}
			}
			cel.Region = best
			cel.Terrain = terrain(p)
		}
	}

	// 2. Lieux : villages, lieux mythiques, portails, puis villes.
	occupe := map[[2]int]bool{}
	ajouter := func(l Lieu) {
		// On glisse le lieu sur la case praticable la plus proche.
		l.X, l.Y = c.praticableProche(l.X, l.Y, occupe)
		occupe[[2]int{l.X, l.Y}] = true
		c.Lieux = append(c.Lieux, l)
		c.Cellules[l.Y*L+l.X].Lieu = len(c.Lieux) - 1
	}
	for _, r := range data.AllRegions() {
		for i, tv := range data.AllTypesVillage() {
			x, y := CaseDe(emplacementsVillages[r.ID][i])
			ajouter(Lieu{ID: "village_" + r.ID + "_" + tv.ID, Nom: r.Villages[i], Type: "village",
				Region: r.ID, X: x, Y: y, TypeVillage: tv.ID, Niveau: 1})
		}
	}
	for _, m := range lieuxMythiques {
		x, y := CaseDe(m.Point)
		ajouter(Lieu{ID: m.ID, Nom: m.Nom, Type: "mythique", X: x, Y: y, Niveau: m.Niveau,
			Rencontre: m.Rencontre, Description: m.Description})
	}

	// 3. Zones : huit par région, par regroupement des cases.
	c.decouperZones()

	// 4. Portails : sur la frontière de chaque région en guerre, face au Cœur.
	for _, r := range data.AllRegions() {
		if !r.Jouable {
			continue
		}
		x, y := c.portail(r.ID)
		ajouter(Lieu{ID: "portail_" + r.ID, Nom: "Portail des " + r.Nom, Type: "portail", X: x, Y: y,
			Niveau: 15, Rencontre: "portail",
			Description: "Le portail de la région. Chaque vendredi soir, on peut le forcer pour lancer un siège."})
	}

	// 5. Villes réelles, sur les cases encore libres.
	for _, v := range villes {
		x, y := CaseDe(v.Point)
		if cel := c.Case(x, y); cel == nil || occupe[[2]int{x, y}] || CoutTerrain[cel.Terrain] == 0 {
			continue
		}
		ajouter(Lieu{ID: "ville_" + slug(v.Nom), Nom: v.Nom, Type: "ville", X: x, Y: y, Niveau: 1})
	}
	for i := range c.Lieux {
		l := &c.Lieux[i]
		cel := c.Case(l.X, l.Y)
		l.Region = cel.Region
		if l.Type != "village" && l.Type != "portail" && c.Zones[cel.Zone].Niveau > l.Niveau {
			l.Niveau = c.Zones[cel.Zone].Niveau
		}
	}
	return c
}

func (c *Carte) praticableProche(x, y int, occupe map[[2]int]bool) (int, int) {
	for r := 0; r < 6; r++ {
		for dy := -r; dy <= r; dy++ {
			for dx := -r; dx <= r; dx++ {
				cel := c.Case(x+dx, y+dy)
				if cel != nil && CoutTerrain[cel.Terrain] > 0 && !occupe[[2]int{x + dx, y + dy}] {
					return x + dx, y + dy
				}
			}
		}
	}
	return x, y
}

// decouperZones : huit zones par région (k-moyennes déterministes), classées
// de la plus proche des villages à la plus lointaine.
func (c *Carte) decouperZones() {
	for _, r := range data.AllRegions() {
		var cases [][2]int
		for y := 0; y < H; y++ {
			for x := 0; x < L; x++ {
				if cel := c.Case(x, y); cel != nil && cel.Region == r.ID {
					cases = append(cases, [2]int{x, y})
				}
			}
		}
		// Graines : les trois villages (fixes), puis les cases les plus éloignées.
		var villages [][2]int
		for _, l := range c.Lieux {
			if l.Type == "village" && l.Region == r.ID {
				villages = append(villages, [2]int{l.X, l.Y})
			}
		}
		var centres [][2]float64
		for _, v := range villages {
			centres = append(centres, [2]float64{float64(v[0]), float64(v[1])})
		}
		fixes := len(centres)
		for len(centres) < 8 {
			best, dbest := cases[0], -1.0
			for _, cs := range cases {
				dmin := math.Inf(1)
				for _, ce := range centres {
					dmin = math.Min(dmin, d2(cs, ce))
				}
				if dmin > dbest {
					best, dbest = cs, dmin
				}
			}
			centres = append(centres, [2]float64{float64(best[0]), float64(best[1])})
		}
		appart := make([]int, len(cases))
		for iter := 0; iter < 25; iter++ {
			for i, cs := range cases {
				k, dmin := 0, math.Inf(1)
				for j, ce := range centres {
					if d := d2(cs, ce); d < dmin {
						k, dmin = j, d
					}
				}
				appart[i] = k
			}
			somme := make([][3]float64, 8)
			for i, cs := range cases {
				somme[appart[i]][0] += float64(cs[0])
				somme[appart[i]][1] += float64(cs[1])
				somme[appart[i]][2]++
			}
			for j := fixes; j < len(centres); j++ {
				if somme[j][2] > 0 {
					centres[j] = [2]float64{somme[j][0] / somme[j][2], somme[j][1] / somme[j][2]}
				}
			}
		}
		// Les zones des villages d'abord, puis les autres par distance au
		// village le plus proche.
		distVillage := func(j int) float64 {
			d := math.Inf(1)
			for _, v := range villages {
				d = math.Min(d, d2(v, centres[j]))
			}
			return d
		}
		ordre := []int{0, 1, 2, 3, 4, 5, 6, 7}
		sort.SliceStable(ordre, func(a, b int) bool {
			va, vb := ordre[a] < fixes, ordre[b] < fixes
			if va != vb {
				return va
			}
			return distVillage(ordre[a]) < distVillage(ordre[b])
		})
		rang := make([]int, 8)
		for rg, j := range ordre {
			rang[j] = rg
		}
		niveaux := NiveauxZones
		if !r.Jouable {
			niveaux = NiveauxZonesCoeur
		}
		base := len(c.Zones)
		for rg, j := range ordre {
			// La case la plus proche du centre représente la zone.
			rep, dmin := cases[0], math.Inf(1)
			for i, cs := range cases {
				if appart[i] == j {
					if d := d2(cs, centres[j]); d < dmin {
						rep, dmin = cs, d
					}
				}
			}
			niv := 1
			if rg >= fixes {
				niv = niveaux[rg-fixes]
			}
			c.Zones = append(c.Zones, Zone{ID: fmt.Sprintf("%s_%d", r.ID, rg+1), Region: r.ID, Rang: rg,
				Niveau: niv, X: rep[0], Y: rep[1]})
		}
		for i, cs := range cases {
			c.Cellules[cs[1]*L+cs[0]].Zone = base + rang[appart[i]]
		}
	}
	c.nommerZones()
}

// nommerZones : chaque zone prend le nom d'une vraie ville, la plus proche
// de son centre, sans doublon.
func (c *Carte) nommerZones() {
	pris := map[string]bool{}
	for i := range c.Zones {
		z := &c.Zones[i]
		centre := Centre(z.X, z.Y)
		// On préfère une ville située dans la zone elle-même.
		best, dmin := "", math.Inf(1)
		for _, v := range villes {
			if pris[v.Nom] {
				continue
			}
			d := dist(centre, v.Point)
			x, y := CaseDe(v.Point)
			if cel := c.Case(x, y); cel != nil && cel.Zone == i {
				d -= 10
			}
			if d < dmin {
				best, dmin = v.Nom, d
			}
		}
		pris[best] = true
		z.Nom = best
	}
}

func (c *Carte) portail(region string) (int, int) {
	var cr, cc [2]float64
	var nr, nc float64
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			cel := c.Case(x, y)
			if cel == nil {
				continue
			}
			if cel.Region == region {
				cr[0], cr[1], nr = cr[0]+float64(x), cr[1]+float64(y), nr+1
			} else if cel.Region == "coeur" {
				cc[0], cc[1], nc = cc[0]+float64(x), cc[1]+float64(y), nc+1
			}
		}
	}
	cible := [2]float64{(cr[0]/nr + cc[0]/nc) / 2, (cr[1]/nr + cc[1]/nc) / 2}
	best, dmin := [2]int{-1, -1}, math.Inf(1)
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			cel := c.Case(x, y)
			if cel == nil || cel.Region != region || cel.Lieu >= 0 || CoutTerrain[cel.Terrain] == 0 {
				continue
			}
			// Une case frontalière d'une autre région.
			frontiere := false
			for _, v := range voisins(x, y) {
				if o := c.Case(v[0], v[1]); o != nil && o.Region != region {
					frontiere = true
				}
			}
			if frontiere {
				if d := d2([2]int{x, y}, cible); d < dmin {
					best, dmin = [2]int{x, y}, d
				}
			}
		}
	}
	return best[0], best[1]
}

// terrain déduit de la géographie réelle (simplifiée).
func terrain(p Point) string {
	switch {
	case distSegments(p, lacKossou) < 0.12:
		return Lac
	case p.Lat < 5.45 && p.Lon > -5.3 && p.Lon < -3.0 && distSegments(p, contour[30:]) < 0.22:
		return Lagune
	case distSegments(p, append(append([]Point{}, contour[30:]...), contour[0])) < 0.16:
		return Littoral
	}
	for _, f := range fleuves {
		if distSegments(p, f) < 0.075 {
			return Fleuve
		}
	}
	switch {
	case dist(p, Point{-7.60, 7.45}) < 0.5, dist(p, Point{-8.35, 7.60}) < 0.35, dist(p, Point{-7.70, 8.20}) < 0.25:
		return Montagne
	case dist(p, Point{-7.20, 5.75}) < 0.55:
		return ForetDense
	case p.Lat < 6.9, p.Lat < 7.6 && p.Lon < -6.3, p.Lat < 7.3 && p.Lon > -3.8:
		return Foret
	case p.Lat < 8.1:
		return SavaneBoisee
	}
	return Savane
}

// --- Géométrie ----------------------------------------------------------------

func dist(a, b Point) float64 { return math.Hypot(a.Lon-b.Lon, a.Lat-b.Lat) }

func d2(a [2]int, b [2]float64) float64 {
	dx, dy := float64(a[0])-b[0], float64(a[1])-b[1]
	return dx*dx + dy*dy
}

func d2f(a, b [2]float64) float64 {
	dx, dy := a[0]-b[0], a[1]-b[1]
	return dx*dx + dy*dy
}

func distSegment(p, a, b Point) float64 {
	dx, dy := b.Lon-a.Lon, b.Lat-a.Lat
	l2 := dx*dx + dy*dy
	t := 0.0
	if l2 > 0 {
		t = math.Max(0, math.Min(1, ((p.Lon-a.Lon)*dx+(p.Lat-a.Lat)*dy)/l2))
	}
	return dist(p, Point{a.Lon + t*dx, a.Lat + t*dy})
}

func distSegments(p Point, pts []Point) float64 {
	d := math.Inf(1)
	for i := 0; i+1 < len(pts); i++ {
		d = math.Min(d, distSegment(p, pts[i], pts[i+1]))
	}
	return d
}

func dansPolygone(p Point, poly []Point) bool {
	dedans := false
	for i, j := 0, len(poly)-1; i < len(poly); j, i = i, i+1 {
		a, b := poly[i], poly[j]
		if (a.Lat > p.Lat) != (b.Lat > p.Lat) && p.Lon < (b.Lon-a.Lon)*(p.Lat-a.Lat)/(b.Lat-a.Lat)+a.Lon {
			dedans = !dedans
		}
	}
	return dedans
}

func voisins(x, y int) [][2]int {
	var v [][2]int
	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			if dx != 0 || dy != 0 {
				v = append(v, [2]int{x + dx, y + dy})
			}
		}
	}
	return v
}

func slug(s string) string {
	out := []rune{}
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			out = append(out, r)
		case r >= 'A' && r <= 'Z':
			out = append(out, r+32)
		case r == 'é' || r == 'è' || r == 'É':
			out = append(out, 'e')
		case r == 'ï':
			out = append(out, 'i')
		default:
			out = append(out, '_')
		}
	}
	return string(out)
}

// Export : la carte sous une forme compacte, pour le client. Chaque case
// est décrite par quatre tableaux (région, zone, terrain, lieu) ; -1 hors du
// pays ou sans lieu.
func (c *Carte) Export() map[string]any {
	var regions []string
	for _, r := range data.AllRegions() {
		regions = append(regions, r.ID)
	}
	idx := func(l []string, v string) int {
		for i, x := range l {
			if x == v {
				return i
			}
		}
		return -1
	}
	n := L * H
	reg, zon, ter, lie := make([]int, n), make([]int, n), make([]int, n), make([]int, n)
	for i, cel := range c.Cellules {
		reg[i], zon[i], ter[i], lie[i] = idx(regions, cel.Region), cel.Zone, idx(Terrains, cel.Terrain), cel.Lieu
	}
	var cont [][2]float64
	for _, p := range c.Contour {
		cont = append(cont, [2]float64{p.Lon, p.Lat})
	}
	var fl [][][2]float64
	for _, f := range fleuves {
		var l [][2]float64
		for _, p := range f {
			l = append(l, [2]float64{p.Lon, p.Lat})
		}
		fl = append(fl, l)
	}
	return map[string]any{
		"l": L, "h": H, "lon_min": LonMin, "lat_max": LatMax, "pas": Pas,
		"regions": regions, "terrains": Terrains, "noms_terrains": NomsTerrains, "couts": CoutTerrain,
		"region": reg, "zone": zon, "terrain": ter, "lieu": lie,
		"zones": c.Zones, "lieux": c.Lieux, "contour": cont, "fleuves": fl,
	}
}
