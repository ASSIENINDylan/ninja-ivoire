package grammar

import (
	"fmt"
	"math"
	"strings"
)

// Description d'un jutsu, générée à partir de son profil : elle dit
// exactement ce que fait le jutsu en combat.

// NomsTypes : le nom affiché de chaque type.
var NomsTypes = map[string]string{
	TDegats: "Dégâts", TDefense: "Défense", TEntrave: "Entrave", TIllusion: "Illusion", TSoin: "Soin",
}

var textesCible = map[string]string{
	CSoi: "le lanceur", CAllies: "tout son camp", CEnnemi: "une cible",
	CEnnemiEtendu: "une cible et sa voisine", CContact: "une cible au contact",
	CContactEtendu: "une cible au contact et sa voisine", CEnnemis: "tous les adversaires",
	CFront: "l'adversaire du premier rang", CAleatoire: "un adversaire au hasard",
	CAttaquant: "l'attaquant", CDeclencheur: "la victime",
}

// TextesStatut : {v} est remplacé par la valeur en pourcentage.
var TextesStatut = map[string]string{
	"def_phys":        "défense physique +{v} %",
	"def_mag":         "défense magique +{v} %",
	"renvoi":          "renvoie {v} % des dégâts reçus",
	"parade":          "pare entièrement le prochain coup",
	"esquive":         "esquive +{v} %",
	"reflet":          "renvoie le prochain jutsu à son lanceur",
	"deviation":       "détourne la prochaine attaque sur un allié de l'attaquant",
	"intangible_phys": "insensible aux dégâts physiques",
	"intangible_mag":  "insensible aux dégâts magiques",
	"invisible":       "impossible à cibler",
	"disparu":         "disparaît : ni ciblé ni touché",
	"leurre":          "{n} leurre(s) encaissent les attaques",
	"regen":           "régénère {v} % de la puissance par tour",
	"baume":           "à la fin du combat, soigne {v} % de la puissance",
	"second_souffle":  "survit une fois à un coup fatal et récupère {v} % de la puissance",
	"immobilise":      "ne peut plus changer de rang",
	"retenu":          "ne peut plus fuir",
	"desarme":         "ne peut plus frapper",
	"scelle":          "ne peut plus former de mudras",
	"sans_garde":      "ne peut plus se mettre en garde",
	"confus":          "{v} % de chances de frapper son propre camp",
	"endormi":         "endormi (un coup le réveille)",
	"aveugle":         "{v} % de chances de rater",
	"egare":           "ses attaques partent au hasard",
	"marque":          "subit {v} % de dégâts en plus",
	"sangsue":         "perd {v} % de la puissance par tour au profit du lanceur",
	"hasard":          "une entrave au hasard",
}

func pct(x float64) int { return int(math.Round(x * 100)) }

func tours(d int) string {
	if d > 1 {
		return fmt.Sprintf("%d tours", d)
	}
	return "1 tour"
}

func majuscule(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	return strings.ToUpper(string(r[0])) + string(r[1:])
}

// Decimale écrit un nombre à deux décimales, à la française.
func Decimale(x float64) string {
	return strings.Replace(fmt.Sprintf("%.2f", x), ".", ",", 1)
}

func texteStatut(e Effet) string {
	t := TextesStatut[e.Statut]
	if StatutsControle[e.Statut] && e.Valeur > 0 && !strings.Contains(t, "{v}") {
		t += " (réussite +{v} %)"
	}
	t = strings.ReplaceAll(t, "{v}", fmt.Sprint(pct(e.Valeur)))
	t = strings.ReplaceAll(t, "{n}", fmt.Sprint(int(math.Round(e.Valeur))))
	return t
}

// DecrireEffet : une phrase par effet.
func DecrireEffet(e Effet) string {
	c := textesCible[e.Cible]
	var s string
	switch e.Op {
	case OpDegats:
		s = fmt.Sprintf("Dégâts %ss à %s : %d %% de la puissance", e.Nature, c, pct(e.Mult))
		if e.Frappes > 1 {
			s += fmt.Sprintf(", en %d frappes", e.Frappes)
		}
		s += "."
	case OpDot:
		s = fmt.Sprintf("%s se consume : %d %% de la puissance par tour, %s.", majuscule(c), pct(e.Mult), tours(e.Duree))
	case OpStatut:
		if e.Duree > 0 {
			s = fmt.Sprintf("%s : %s, %s.", majuscule(c), texteStatut(e), tours(e.Duree))
		} else {
			s = fmt.Sprintf("%s : %s.", majuscule(c), texteStatut(e))
		}
	case OpBouclier:
		s = fmt.Sprintf("Bouclier de Souffle sur %s : %d %% de la puissance en PV temporaires.", c, pct(e.Mult))
	case OpSoin:
		s = fmt.Sprintf("Soigne le lanceur : %d %% de la puissance.", pct(e.Mult))
	case OpDrain:
		s = fmt.Sprintf("Draine %s (dégâts %ss, %d %% de la puissance", c, e.Nature, pct(e.Mult))
		if e.Frappes > 1 {
			s += fmt.Sprintf(", en %d frappes", e.Frappes)
		}
		s += fmt.Sprintf(") : le lanceur récupère %d %% des dégâts.", pct(e.Valeur))
	case OpDeplacer:
		if e.Vers == "avant" {
			s = fmt.Sprintf("Attire %s au premier rang", c)
		} else {
			s = fmt.Sprintf("Repousse %s au dernier rang", c)
		}
		if e.Valeur > 0 {
			s += fmt.Sprintf(" (réussite +%d %%)", pct(e.Valeur))
		}
		s += "."
	case OpBond:
		if e.Vers == "avant" {
			s = "Le lanceur bondit au premier rang."
		} else {
			s = "Le lanceur bondit au dernier rang."
		}
	case OpClone:
		if e.Nombre > 1 {
			s = fmt.Sprintf("Crée %d clones du lanceur, indiscernables pour l'adversaire, %s ; ils frappent à %d %% de sa force.", e.Nombre, tours(e.Duree), pct(e.Valeur))
		} else {
			s = fmt.Sprintf("Crée un clone du lanceur, indiscernable pour l'adversaire, %s ; il frappe à %d %% de sa force.", tours(e.Duree), pct(e.Valeur))
		}
	case OpDissiper:
		s = fmt.Sprintf("Dissipe les protections et illusions de %s.", c)
	case OpPurifier:
		s = "Purifie le lanceur de ses entraves et de ses maux."
	case OpInterrompre:
		s = fmt.Sprintf("Brise l'incantation de %s.", c)
	case OpAnnuler:
		s = "Son action est annulée."
	case OpRiposte:
		s = fmt.Sprintf("Pendant %s, qui attaque %s subit : %s", tours(e.Duree), c, decrireCharge(e.Effets))
	case OpPiege:
		s = fmt.Sprintf("Piège sous %s, %s ; dès qu'elle agit : %s", c, tours(e.Duree), decrireCharge(e.Effets))
	case OpInvocation:
		s = fmt.Sprintf("Une créature de Souffle agit pendant %s ; à chaque tour : %s", tours(e.Duree), decrireCharge(e.Effets))
	case OpDeclencheur:
		s = fmt.Sprintf("Si le lanceur passe sous %d %% de ses PV dans les %s : %s", pct(e.Valeur), tours(e.Duree), decrireCharge(e.Effets))
	case OpDiffere:
		if e.Duree > 1 {
			s = fmt.Sprintf("Au bout de %s : %s", tours(e.Duree), decrireCharge(e.Effets))
		} else {
			s = "Au tour suivant : " + decrireCharge(e.Effets)
		}
	}
	if e.Part > 0 {
		s += fmt.Sprintf(" (Cibles secondaires : %d %%.)", pct(e.Part))
	}
	if e.Propage > 0 {
		s += fmt.Sprintf(" L'effet se propage à un second adversaire (%d %%).", pct(e.Propage))
	}
	return s
}

func decrireCharge(l []Effet) string {
	parts := make([]string, len(l))
	for i, e := range l {
		d := DecrireEffet(e)
		parts[i] = strings.ToLower(d[:1]) + d[1:]
	}
	return strings.Join(parts, " ")
}

// LibelleType : « Dégâts magiques », « Entrave »…
func LibelleType(j *Jutsu) string {
	if j.Type == TDegats {
		return NomsTypes[TDegats] + " " + j.DegatsNature + "s"
	}
	return NomsTypes[j.Type]
}

// Decimale3 : jusqu'à trois décimales, au moins deux.
func Decimale3(x float64) string {
	t := fmt.Sprintf("%.3f", x)
	if strings.HasSuffix(t, "0") {
		t = t[:len(t)-1]
	}
	return strings.Replace(t, ".", ",", 1)
}

// Formule de la puissance, lisible.
func Formule(k Coefs) string {
	return fmt.Sprintf("Puissance = (8 + %s × Fangan + %s × Gnanga + %s × Manhis) × %s",
		Decimale3(k.F), Decimale3(k.G), Decimale3(k.M), Decimale3(k.N))
}

func decrire(j *Jutsu) string {
	lignes := []string{LibelleType(j) + ". " + Formule(j.Coefs) + "."}
	for _, e := range j.Effets {
		lignes = append(lignes, DecrireEffet(e))
	}
	if j.Delai {
		lignes = append(lignes, "Le Souffle s'accumule : le jutsu part au tour suivant.")
	}
	if j.Echo > 0 {
		lignes = append(lignes, fmt.Sprintf("Un écho rejoue le jutsu au tour suivant, à %d %%.", pct(j.Echo)))
	}
	if j.Incassable {
		lignes = append(lignes, "Incantation impossible à interrompre.")
	}
	if j.Indissipable {
		lignes = append(lignes, "Ses effets ne peuvent être ni dissipés ni purifiés.")
	}
	return strings.Join(lignes, "\n")
}
