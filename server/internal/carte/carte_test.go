package carte

import (
	"strings"
	"testing"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

func TestCarteCoherente(t *testing.T) {
	c := Monde
	cases := 0
	parTerrain := map[string]int{}
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			if cel := c.Case(x, y); cel != nil {
				cases++
				parTerrain[cel.Terrain]++
				if cel.Zone < 0 || c.Zones[cel.Zone].Region != cel.Region {
					t.Fatalf("case (%d,%d) : zone %d incohérente", x, y, cel.Zone)
				}
			}
		}
	}
	t.Logf("%d cases · terrains %v · %d zones · %d lieux", cases, parTerrain, len(c.Zones), len(c.Lieux))
	if cases < 1200 || cases > 1700 {
		t.Errorf("nombre de cases inattendu : %d", cases)
	}
	for _, tr := range Terrains {
		if parTerrain[tr] == 0 {
			t.Errorf("aucune case de %s", tr)
		}
	}
	if len(c.Zones) != 7*8 {
		t.Errorf("%d zones au lieu de 56", len(c.Zones))
	}
	noms := map[string]bool{}
	for i, z := range c.Zones {
		if noms[z.Nom] || z.Nom == "" {
			t.Errorf("nom de zone vide ou en double : %q", z.Nom)
		}
		noms[z.Nom] = true
		n := 0
		for _, cel := range c.Cellules {
			if cel.Zone == i {
				n++
			}
		}
		if n == 0 {
			t.Errorf("zone vide : %s", z.ID)
		}
	}
	types := map[string]int{}
	for _, l := range c.Lieux {
		types[l.Type]++
		cel := c.Case(l.X, l.Y)
		if cel == nil || CoutTerrain[cel.Terrain] == 0 {
			t.Errorf("lieu %s sur une case impraticable", l.ID)
		}
		if l.Type == "village" && (cel.Region != l.Region || c.Zones[cel.Zone].Niveau != 1) {
			t.Errorf("village %s mal placé (région %s, zone niv. %d)", l.Nom, cel.Region, c.Zones[cel.Zone].Niveau)
		}
	}
	if types["village"] != 21 || types["portail"] != 6 || types["mythique"] != len(lieuxMythiques) {
		t.Errorf("lieux : %v", types)
	}
	t.Logf("lieux par type : %v", types)
}

// Toutes les cases praticables sont reliées entre elles.
func TestCarteConnexe(t *testing.T) {
	c := Monde
	v := c.VillageDe("lagunes", "moderne")
	vu := map[[2]int]bool{{v.X, v.Y}: true}
	file := [][2]int{{v.X, v.Y}}
	for len(file) > 0 {
		p := file[0]
		file = file[1:]
		for _, n := range voisins(p[0], p[1]) {
			if cel := c.Case(n[0], n[1]); cel != nil && CoutTerrain[cel.Terrain] > 0 && !vu[n] {
				vu[n] = true
				file = append(file, n)
			}
		}
	}
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			if cel := c.Case(x, y); cel != nil && CoutTerrain[cel.Terrain] > 0 && !vu[[2]int{x, y}] {
				t.Errorf("case (%d,%d) inaccessible", x, y)
			}
		}
	}
}

// TestApercu dessine la carte en texte (go test -run Apercu -v).
func TestApercu(t *testing.T) {
	lettres := map[string]string{Savane: ".", SavaneBoisee: ",", Foret: "f", ForetDense: "F", Montagne: "M", Fleuve: "~", Lac: "O", Lagune: "=", Littoral: "_"}
	var b strings.Builder
	for y := 0; y < H; y++ {
		for x := 0; x < L; x++ {
			cel := Monde.Case(x, y)
			switch {
			case cel == nil:
				b.WriteString(" ")
			case cel.Lieu >= 0:
				b.WriteString(map[string]string{"village": "V", "ville": "o", "mythique": "*", "portail": "P"}[Monde.Lieux[cel.Lieu].Type])
			default:
				b.WriteString(lettres[cel.Terrain])
			}
		}
		b.WriteString("   ")
		for x := 0; x < L; x++ {
			cel := Monde.Case(x, y)
			if cel == nil {
				b.WriteString(" ")
			} else {
				b.WriteByte("LOMHNEC"[indexRegion(cel.Region)])
			}
		}
		b.WriteString("\n")
	}
	t.Log("\n" + b.String())
	for _, z := range Monde.Zones {
		t.Logf("%-16s rang %d niv %2d  %s", z.ID, z.Rang, z.Niveau, z.Nom)
	}
}

func indexRegion(id string) int {
	for i, r := range data.AllRegions() {
		if r.ID == id {
			return i
		}
	}
	return 0
}
