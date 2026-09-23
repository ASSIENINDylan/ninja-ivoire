package data

// Categorie d'un mudra dans la grammaire.
type Categorie string

const (
	CatElement      Categorie = "element"
	CatForme        Categorie = "forme"
	CatEffet        Categorie = "effet"
	CatModificateur Categorie = "modificateur"
)

// Mudra est un signe de la main. Son sens (Ref) dépend de sa catégorie :
// un élément, une forme, un effet ou un modificateur.
type Mudra struct {
	ID        string    `json:"id"`
	Nom       string    `json:"nom"`
	Categorie Categorie `json:"categorie"`
	Ref       string    `json:"ref"`
	// Niveau requis pour débloquer le mudra. 0 : le mudra dépend d'un
	// élément connu (mudras d'élément) ; -1 : obtenu uniquement par quête.
	Niveau int `json:"niveau"`
}

// Formes (ce que devient le Souffle).
const (
	FTrait      = "trait"
	FLame       = "lame"
	FMur        = "mur"
	FCercle     = "cercle"
	FDouble     = "double"
	FLien       = "lien"
	FArmure     = "armure"
	FPiege      = "piege"
	FInvocation = "invocation"
	FPas        = "pas"
)

// Effets (ce que fait le Souffle).
const (
	XConsumer   = "consumer"
	XLier       = "lier"
	XSoigner    = "soigner"
	XAveugler   = "aveugler"
	XRepousser  = "repousser"
	XDrainer    = "drainer"
	XBriser     = "briser"
	XDissimuler = "dissimuler"
	XRenforcer  = "renforcer"
	XMarquer    = "marquer"
)

// Modificateurs (comment le Souffle agit).
const (
	MAmplifier   = "amplifier"
	MEtendre     = "etendre"
	MMultiplier  = "multiplier"
	MRetarder    = "retarder"
	MSilence     = "silence"
	MPersistance = "persistance"
)

var mudraList = []Mudra{
	// 16 mudras d'élément de base
	{ID: "panthere", Nom: "Panthère", Categorie: CatElement, Ref: "feu"},
	{ID: "lamantin", Nom: "Lamantin", Categorie: CatElement, Ref: "eau"},
	{ID: "calao", Nom: "Calao", Categorie: CatElement, Ref: "vent"},
	{ID: "buffle", Nom: "Buffle", Categorie: CatElement, Ref: "terre"},
	{ID: "aigle", Nom: "Aigle", Categorie: CatElement, Ref: "foudre"},
	{ID: "chimpanze", Nom: "Chimpanzé", Categorie: CatElement, Ref: "vegetal"},
	{ID: "enclume", Nom: "Enclume", Categorie: CatElement, Ref: "metal"},
	{ID: "tambour", Nom: "Tambour", Categorie: CatElement, Ref: "son"},
	{ID: "scorpion", Nom: "Scorpion", Categorie: CatElement, Ref: "sable"},
	{ID: "mamba", Nom: "Mamba", Categorie: CatElement, Ref: "venin"},
	{ID: "cameleon", Nom: "Caméléon", Categorie: CatElement, Ref: "brume"},
	{ID: "crabe", Nom: "Crabe", Categorie: CatElement, Ref: "sel"},
	{ID: "termite", Nom: "Termite", Categorie: CatElement, Ref: "essaim"},
	{ID: "coq", Nom: "Coq", Categorie: CatElement, Ref: "soleil"},
	{ID: "hibou", Nom: "Hibou", Categorie: CatElement, Ref: "lune"},
	{ID: "hippopotame", Nom: "Hippopotame", Categorie: CatElement, Ref: "gravite"},

	// 10 mudras de forme
	{ID: "martin_pecheur", Nom: "Martin-pêcheur", Categorie: CatForme, Ref: FTrait, Niveau: 1},
	{ID: "mante", Nom: "Mante", Categorie: CatForme, Ref: FLame, Niveau: 1},
	{ID: "tortue", Nom: "Tortue", Categorie: CatForme, Ref: FMur, Niveau: 1},
	{ID: "case", Nom: "Case ronde", Categorie: CatForme, Ref: FCercle, Niveau: 5},
	{ID: "araignee", Nom: "Araignée", Categorie: CatForme, Ref: FLien, Niveau: 10},
	{ID: "pangolin", Nom: "Pangolin", Categorie: CatForme, Ref: FArmure, Niveau: 15},
	{ID: "perroquet", Nom: "Perroquet", Categorie: CatForme, Ref: FDouble, Niveau: 20},
	{ID: "crocodile", Nom: "Crocodile", Categorie: CatForme, Ref: FPiege, Niveau: 30},
	{ID: "antilope", Nom: "Antilope", Categorie: CatForme, Ref: FPas, Niveau: 40},
	{ID: "masque", Nom: "Masque", Categorie: CatForme, Ref: FInvocation, Niveau: 50},

	// 10 mudras d'effet
	{ID: "braise", Nom: "Braise", Categorie: CatEffet, Ref: XConsumer, Niveau: 1},
	{ID: "liane", Nom: "Liane", Categorie: CatEffet, Ref: XLier, Niveau: 1},
	{ID: "kola", Nom: "Kola", Categorie: CatEffet, Ref: XSoigner, Niveau: 1},
	{ID: "belier", Nom: "Bélier", Categorie: CatEffet, Ref: XRepousser, Niveau: 5},
	{ID: "voile", Nom: "Voile", Categorie: CatEffet, Ref: XAveugler, Niveau: 10},
	{ID: "hache", Nom: "Hache", Categorie: CatEffet, Ref: XBriser, Niveau: 15},
	{ID: "moustique", Nom: "Moustique", Categorie: CatEffet, Ref: XDrainer, Niveau: 25},
	{ID: "racine", Nom: "Racine", Categorie: CatEffet, Ref: XRenforcer, Niveau: 35},
	{ID: "feuille", Nom: "Feuille", Categorie: CatEffet, Ref: XDissimuler, Niveau: 45},
	{ID: "kaolin", Nom: "Kaolin", Categorie: CatEffet, Ref: XMarquer, Niveau: 55},

	// 6 mudras modificateurs
	{ID: "lion", Nom: "Lion", Categorie: CatModificateur, Ref: MAmplifier, Niveau: 3},
	{ID: "fleuve", Nom: "Fleuve", Categorie: CatModificateur, Ref: MEtendre, Niveau: 8},
	{ID: "fourmi", Nom: "Fourmi", Categorie: CatModificateur, Ref: MMultiplier, Niveau: 12},
	{ID: "escargot", Nom: "Escargot", Categorie: CatModificateur, Ref: MRetarder, Niveau: 18},
	{ID: "silure", Nom: "Silure", Categorie: CatModificateur, Ref: MSilence, Niveau: 25},
	{ID: "baobab", Nom: "Baobab", Categorie: CatModificateur, Ref: MPersistance, Niveau: 35},

	// 8 mudras mythiques (quêtes uniquement)
	{ID: "elephant", Nom: "Éléphant", Categorie: CatElement, Ref: "ivoire", Niveau: -1},
	{ID: "ancetre", Nom: "Ancêtre", Categorie: CatElement, Ref: "esprit", Niveau: -1},
	{ID: "etoile", Nom: "Étoile du matin", Categorie: CatElement, Ref: "lumiere", Niveau: -1},
	{ID: "nuit", Nom: "Nuit", Categorie: CatElement, Ref: "ombre", Niveau: -1},
	{ID: "oeuf", Nom: "Œuf", Categorie: CatElement, Ref: "vie", Niveau: -1},
	{ID: "griot", Nom: "Griot", Categorie: CatElement, Ref: "temps", Niveau: -1},
	{ID: "gouffre", Nom: "Gouffre", Categorie: CatElement, Ref: "vide", Niveau: -1},
	{ID: "comete", Nom: "Comète", Categorie: CatElement, Ref: "astre", Niveau: -1},
}

// Mudras indexe les mudras par identifiant.
var Mudras = map[string]*Mudra{}

// MudraOfElement associe un élément de base ou mythique à son mudra.
var MudraOfElement = map[string]string{}

func init() {
	for i := range mudraList {
		m := &mudraList[i]
		Mudras[m.ID] = m
		if m.Categorie == CatElement {
			MudraOfElement[m.Ref] = m.ID
		}
	}
}

// AllMudras renvoie les mudras dans l'ordre du catalogue.
func AllMudras() []Mudra { return mudraList }

// NiveauFusion est le niveau à partir duquel on peut fusionner deux éléments.
const NiveauFusion = 60

// Unlocked indique si un ninja de ce niveau, connaissant ces éléments,
// peut former ce mudra.
func Unlocked(m *Mudra, niveau int, elements []string) bool {
	if m.Categorie == CatElement {
		return contains(elements, m.Ref)
	}
	return m.Niveau >= 1 && niveau >= m.Niveau
}
