package grammar

import (
	"strings"

	"github.com/ASSIENINDylan/ninja-ivoire/server/internal/data"
)

// Nom d'un jutsu : « <Voie> : <Image> », à la manière des arts ninjas.
//
//	Braise : Croc de la hyène
//	Lagune : Grande Toile d'Ananzè, qui dévore — sans fin
//
// La voie vient de l'élément, l'image de la forme et de l'effet, puis
// viennent l'effet secondaire et les modificateurs. Le nom descriptif
// (« Lame de Feu dévorante ») reste disponible dans Jutsu.Nature.

// Voies : le nom poétique de chaque élément.
var voies = map[string]string{
	"feu": "Braise", "eau": "Lagune", "vent": "Alizé", "terre": "Latérite",
	"foudre": "Orage", "vegetal": "Fromager", "metal": "Forge", "son": "Djembé",
	"sable": "Dune", "venin": "Vipère", "brume": "Brume", "sel": "Sel",
	"essaim": "Nuée", "soleil": "Zénith", "lune": "Croissant", "gravite": "Abîme",
	"lave": "Coulée", "glace": "Givre", "vapeur": "Geyser", "magnetisme": "Aimant",
	"tempete": "Tornade", "cristal": "Cristal", "acide": "Acide", "bois_sacre": "Bois sacré",
	"onde": "Onde", "cendre": "Cendre", "crepuscule": "Crépuscule", "songe": "Songe",
	"fleau": "Fléau", "seisme": "Faille", "maree": "Grande Marée", "harmattan": "Harmattan",
	"ivoire": "Ivoire", "esprit": "Ancêtres", "lumiere": "Aurore", "ombre": "Nuit sans lune",
	"vie": "Source", "temps": "Temps", "vide": "Néant", "astre": "Étoiles",
}

type image struct {
	texte   string
	feminin bool
}

// images : une image pour chaque couple forme × effet, puisée dans la
// faune, les métiers, les contes et la vie des villages.
var images = map[string]map[string]image{
	data.FTrait: {
		data.XConsumer: {"Dard du frelon", false}, data.XLier: {"Flèche du piégeur", true},
		data.XSoigner: {"Flèche du guérisseur", true}, data.XAveugler: {"Éclat du miroir", false},
		data.XRepousser: {"Trait du bélier", false}, data.XDrainer: {"Aiguillon de la sangsue", false},
		data.XBriser: {"Javelot brise-bouclier", false}, data.XDissimuler: {"Plume du hibou", true},
		data.XRenforcer: {"Appel du griot", false}, data.XMarquer: {"Marque du kaolin", true},
	},
	data.FLame: {
		data.XConsumer: {"Croc de la hyène", false}, data.XLier: {"Serre de l'aigle pêcheur", true},
		data.XSoigner: {"Main de la sage-femme", true}, data.XAveugler: {"Revers du caméléon", false},
		data.XRepousser: {"Charge du buffle", true}, data.XDrainer: {"Morsure de la chauve-souris", true},
		data.XBriser: {"Hache du forgeron", true}, data.XDissimuler: {"Lame de minuit", true},
		data.XRenforcer: {"Sabre du champion", false}, data.XMarquer: {"Entaille du lignage", true},
	},
	data.FMur: {
		data.XConsumer: {"Palissade d'épines", true}, data.XLier: {"Enclos du bouvier", false},
		data.XSoigner: {"Case de la guérisseuse", true}, data.XAveugler: {"Mur des miroirs", false},
		data.XRepousser: {"Digue furieuse", true}, data.XDrainer: {"Muraille affamée", true},
		data.XBriser: {"Rempart hérissé", false}, data.XDissimuler: {"Voile du village", false},
		data.XRenforcer: {"Rempart des ancêtres", false}, data.XMarquer: {"Mur aux signes", false},
	},
	data.FCercle: {
		data.XConsumer: {"Ronde dévorante", true}, data.XLier: {"Ronde des chaînes", true},
		data.XSoigner: {"Chant de la veillée", false}, data.XAveugler: {"Danse des lucioles", true},
		data.XRepousser: {"Onde du grand tambour", true}, data.XDrainer: {"Cercle des assoiffés", false},
		data.XBriser: {"Ronde des masques brisés", true}, data.XDissimuler: {"Cercle du secret", false},
		data.XRenforcer: {"Danse des guerriers", true}, data.XMarquer: {"Ronde des présages", true},
	},
	data.FDouble: {
		data.XConsumer: {"Reflet vorace", false}, data.XLier: {"Jumeau piégeur", false},
		data.XSoigner: {"Double bienveillant", false}, data.XAveugler: {"Reflet trompeur", false},
		data.XRepousser: {"Double furieux", false}, data.XDrainer: {"Ombre qui boit", true},
		data.XBriser: {"Jumeau fracassant", false}, data.XDissimuler: {"Ombre du caméléon", true},
		data.XRenforcer: {"Jumeau du champion", false}, data.XMarquer: {"Reflet accusateur", false},
	},
	data.FLien: {
		data.XConsumer: {"Étreinte du python", true}, data.XLier: {"Toile d'Ananzè", true},
		data.XSoigner: {"Fil de vie", false}, data.XAveugler: {"Bandeau du conteur", false},
		data.XRepousser: {"Fouet du bouvier", false}, data.XDrainer: {"Liane assoiffée", true},
		data.XBriser: {"Chaîne brise-os", true}, data.XDissimuler: {"Pagne du secret", false},
		data.XRenforcer: {"Lien du sang", false}, data.XMarquer: {"Cordelette du devin", true},
	},
	data.FArmure: {
		data.XConsumer: {"Cuirasse vorace", true}, data.XLier: {"Écorce collante", true},
		data.XSoigner: {"Peau du baobab", true}, data.XAveugler: {"Carapace miroitante", true},
		data.XRepousser: {"Cuirasse du rhinocéros", true}, data.XDrainer: {"Peau de sangsue", true},
		data.XBriser: {"Écailles du pangolin", false}, data.XDissimuler: {"Manteau du caméléon", false},
		data.XRenforcer: {"Cuirasse des anciens", true}, data.XMarquer: {"Peau peinte au kaolin", true},
	},
	data.FPiege: {
		data.XConsumer: {"Gueule du crocodile", true}, data.XLier: {"Collet du chasseur", false},
		data.XSoigner: {"Source cachée", true}, data.XAveugler: {"Piège aux lucioles", false},
		data.XRepousser: {"Trappe du bélier", true}, data.XDrainer: {"Nasse du marigot", true},
		data.XBriser: {"Mâchoire broyeuse", true}, data.XDissimuler: {"Terrier secret", false},
		data.XRenforcer: {"Embuscade des braves", true}, data.XMarquer: {"Appât du devin", false},
	},
	data.FInvocation: {
		data.XConsumer: {"Esprit dévoreur", false}, data.XLier: {"Masque du geôlier", false},
		data.XSoigner: {"Esprit de la source", false}, data.XAveugler: {"Masque éblouissant", false},
		data.XRepousser: {"Génie du tourbillon", false}, data.XDrainer: {"Esprit affamé", false},
		data.XBriser: {"Masque du destructeur", false}, data.XDissimuler: {"Esprit de la brousse", false},
		data.XRenforcer: {"Masque du champion", false}, data.XMarquer: {"Totem accusateur", false},
	},
	data.FPas: {
		data.XConsumer: {"Bond de la panthère", false}, data.XLier: {"Pas de l'araignée", false},
		data.XSoigner: {"Pas de la guérisseuse", false}, data.XAveugler: {"Envol du calao", false},
		data.XRepousser: {"Ruée du buffle", true}, data.XDrainer: {"Glissade de la sangsue", true},
		data.XBriser: {"Saut de l'éléphant", false}, data.XDissimuler: {"Pas du caméléon", false},
		data.XRenforcer: {"Pas de la danse guerrière", false}, data.XMarquer: {"Pas du chasseur", false},
	},
}

// suitesEffet : l'effet secondaire, en proposition invariable.
var suitesEffet = map[string]string{
	data.XConsumer: "qui dévore", data.XLier: "qui enserre", data.XSoigner: "qui apaise",
	data.XAveugler: "qui éblouit", data.XRepousser: "qui balaie", data.XDrainer: "qui boit la vie",
	data.XBriser: "qui fend les défenses", data.XDissimuler: "qui efface", data.XRenforcer: "qui exalte",
	data.XMarquer: "qui condamne",
}

// epithetesModEffet : les modificateurs d'effet, invariables.
var epithetesModEffet = map[string]string{
	data.MAmplifier: "au paroxysme", data.MEtendre: "sans fin", data.MMultiplier: "en essaim",
	data.MRetarder: "à retardement", data.MSilence: "sans bruit", data.MPersistance: "tenace",
}

// nommer donne le nom poétique d'un jutsu.
func nommer(j *Jutsu) string {
	img := images[j.Forme][j.Effet]
	g := genre(img.feminin)
	var tete []string
	for _, m := range j.ModsForme {
		tete = append(tete, prefixeModForme[m][g])
	}
	tete = append(tete, img.texte)
	nom := voies[j.Element] + " : " + strings.Join(tete, " ")
	if j.Effet2 != "" {
		nom += ", " + suitesEffet[j.Effet2]
	}
	if len(j.ModsEffet) > 0 {
		var ep []string
		for _, m := range j.ModsEffet {
			ep = append(ep, epithetesModEffet[m])
		}
		nom += " — " + strings.Join(ep, ", ")
	}
	return nom
}

// tablesNoms exporte les tables des noms poétiques.
func tablesNoms() map[string]any {
	imgs := map[string]any{}
	for f, m := range images {
		row := map[string]any{}
		for e, im := range m {
			row[e] = map[string]any{"texte": im.texte, "feminin": im.feminin}
		}
		imgs[f] = row
	}
	return map[string]any{"voies": voies, "images": imgs, "suites_effet": suitesEffet, "epithetes_mod_effet": epithetesModEffet}
}
