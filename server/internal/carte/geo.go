// Package carte construit la carte du monde : la vraie Côte d'Ivoire
// découpée en cases, avec ses terrains, ses sept régions, huit zones par
// région, ses villages, ses villes, ses lieux mythiques et ses portails.
package carte

// Point géographique (longitude, latitude).
type Point struct{ Lon, Lat float64 }

// contour simplifié du pays, dans le sens des aiguilles d'une montre depuis
// l'embouchure du Cavally. Les indices 30 à 39 suivent la côte.
var contour = []Point{
	{-7.53, 4.37}, {-7.45, 5.10}, {-7.55, 5.90}, {-8.10, 6.30},
	{-8.45, 6.60}, {-8.55, 7.10}, {-8.40, 7.60}, {-8.10, 7.80},
	{-8.15, 8.25}, {-8.20, 9.10}, {-7.95, 9.60}, {-8.05, 10.10},
	{-7.50, 10.30}, {-6.95, 10.20}, {-6.20, 10.50}, {-5.90, 10.35},
	{-5.50, 10.45}, {-5.20, 10.35}, {-4.90, 10.00}, {-4.60, 9.80},
	{-4.30, 9.65}, {-3.90, 9.90}, {-3.30, 9.90}, {-2.70, 9.50},
	{-2.75, 9.00}, {-2.55, 8.00}, {-2.95, 7.30}, {-3.10, 6.70},
	{-3.20, 6.20}, {-2.95, 5.60}, {-3.05, 5.10}, {-3.28, 5.13},
	{-3.74, 5.20}, {-4.02, 5.30}, {-4.42, 5.20}, {-5.00, 5.13},
	{-5.57, 5.08}, {-6.08, 4.95}, {-6.64, 4.75}, {-7.36, 4.42},
}

// Les trois grands fleuves (Comoé, Bandama, Sassandra).
var fleuves = [][]Point{
	{{-4.6, 10.2}, {-3.9, 9.0}, {-3.65, 7.6}, {-3.5, 6.4}, {-3.75, 5.2}},
	{{-5.6, 9.9}, {-5.5, 8.4}, {-5.5, 7.5}, {-5.2, 6.5}, {-5.0, 5.15}},
	{{-7.4, 9.3}, {-6.9, 7.7}, {-6.6, 6.6}, {-6.3, 5.8}, {-6.1, 4.97}},
}

// Le lac de Kossou, sur le Bandama.
var lacKossou = []Point{{-5.55, 7.45}, {-5.45, 6.95}}

// Ville réelle, qui donne son nom à une zone.
type Ville struct {
	Nom string
	Point
}

var villes = []Ville{
	{"Abidjan", Point{-4.02, 5.35}}, {"Grand-Bassam", Point{-3.74, 5.21}}, {"Assinie", Point{-3.28, 5.13}},
	{"Aboisso", Point{-3.21, 5.47}}, {"Adzopé", Point{-3.86, 6.11}}, {"Agboville", Point{-4.21, 5.93}},
	{"Dabou", Point{-4.38, 5.33}}, {"Jacqueville", Point{-4.42, 5.20}}, {"Grand-Lahou", Point{-5.00, 5.13}},
	{"Tiassalé", Point{-4.83, 5.90}}, {"Divo", Point{-5.36, 5.84}}, {"Lakota", Point{-5.68, 5.85}},
	{"Fresco", Point{-5.57, 5.08}}, {"Sassandra", Point{-6.08, 4.95}}, {"San-Pédro", Point{-6.64, 4.75}},
	{"Tabou", Point{-7.36, 4.42}}, {"Soubré", Point{-6.60, 5.78}}, {"Gagnoa", Point{-5.95, 6.13}},
	{"Issia", Point{-6.59, 6.49}}, {"Daloa", Point{-6.45, 6.88}}, {"Taï", Point{-7.45, 5.87}},
	{"Guiglo", Point{-7.49, 6.54}}, {"Duékoué", Point{-7.35, 6.74}}, {"Bangolo", Point{-7.49, 7.01}},
	{"Toulépleu", Point{-8.41, 6.58}}, {"Man", Point{-7.55, 7.41}}, {"Danané", Point{-8.15, 7.26}},
	{"Biankouma", Point{-7.61, 7.74}}, {"Touba", Point{-7.68, 8.28}}, {"Séguéla", Point{-6.67, 7.96}},
	{"Mankono", Point{-6.19, 8.06}}, {"Vavoua", Point{-6.47, 7.38}}, {"Odienné", Point{-7.56, 9.51}},
	{"Madinani", Point{-6.94, 9.61}}, {"Minignan", Point{-7.83, 9.99}}, {"Boundiali", Point{-6.48, 9.52}},
	{"Tengréla", Point{-6.41, 10.48}}, {"Korhogo", Point{-5.63, 9.46}}, {"Ferkessédougou", Point{-5.19, 9.59}},
	{"Ouangolodougou", Point{-5.15, 9.97}}, {"Kong", Point{-4.61, 9.15}}, {"Dabakala", Point{-4.43, 8.36}},
	{"Katiola", Point{-5.10, 8.14}}, {"Bouaké", Point{-5.03, 7.69}}, {"Béoumi", Point{-5.58, 7.67}},
	{"Sakassou", Point{-5.29, 7.45}}, {"Yamoussoukro", Point{-5.28, 6.82}}, {"Toumodi", Point{-5.02, 6.55}},
	{"Bouaflé", Point{-5.74, 6.99}}, {"Sinfra", Point{-5.91, 6.62}}, {"Dimbokro", Point{-4.71, 6.65}},
	{"Bongouanou", Point{-4.20, 6.65}}, {"Daoukro", Point{-3.96, 7.06}}, {"M'Bahiakro", Point{-4.34, 7.46}},
	{"Bondoukou", Point{-2.80, 8.04}}, {"Tanda", Point{-3.17, 7.80}}, {"Bouna", Point{-3.00, 9.27}},
	{"Nassian", Point{-3.47, 8.45}}, {"Abengourou", Point{-3.49, 6.73}}, {"Agnibilékrou", Point{-3.20, 7.13}},
	{"Kani", Point{-6.60, 8.48}}, {"Samatiguila", Point{-7.35, 9.83}}, {"Doropo", Point{-3.35, 9.80}},
	{"Téhini", Point{-3.66, 9.60}}, {"Guéyo", Point{-6.07, 5.69}}, {"Méagui", Point{-6.56, 5.40}},
	{"Kouibly", Point{-7.25, 7.26}}, {"Zouan-Hounien", Point{-8.24, 6.92}},
}

// Emplacement des villages, dans l'ordre traditionnel, moderne, futuriste.
var emplacementsVillages = map[string][3]Point{
	"lagunes":        {{-3.40, 5.25}, {-3.74, 5.21}, {-4.02, 5.35}},
	"cote_ouest":     {{-7.30, 5.90}, {-6.08, 4.95}, {-6.64, 4.75}},
	"montagnes":      {{-7.61, 7.74}, {-7.55, 7.41}, {-8.15, 7.45}},
	"hautes_savanes": {{-7.56, 9.51}, {-6.67, 7.96}, {-7.10, 9.05}},
	"savanes_nord":   {{-6.48, 9.52}, {-4.61, 9.15}, {-5.63, 9.46}},
	"levant":         {{-2.80, 8.04}, {-3.49, 6.73}, {-3.00, 9.27}},
	"coeur":          {{-5.35, 7.20}, {-5.03, 7.69}, {-5.28, 6.82}},
}

// Centre de gravité indicatif de chaque région (graine supplémentaire).
var centresRegions = map[string]Point{
	"lagunes": {-3.9, 5.9}, "cote_ouest": {-6.6, 5.5}, "montagnes": {-7.7, 7.3},
	"hautes_savanes": {-7.1, 9.1}, "savanes_nord": {-5.3, 9.5}, "levant": {-3.3, 8.0},
	"coeur": {-5.2, 7.3},
}

// Lieu mythique ou remarquable, avec éventuellement une rencontre fixe.
type lieuMythique struct {
	ID, Nom, Description string
	Point
	Niveau    int
	Rencontre string
}

var lieuxMythiques = []lieuMythique{
	{"coeur_tai", "Cœur de la forêt de Taï", "Là où les arbres sont plus vieux que les villages. Un esprit veille.", Point{-7.25, 5.65}, 5, "esprit_tai"},
	{"cascades_man", "Cascades de Man", "L'eau tombe de la montagne. Un apprenti renégat s'y cache.", Point{-7.70, 7.30}, 3, "renegat"},
	{"profondeurs_lagune", "Profondeurs de la lagune Ébrié", "Des pirogues sans rameurs glissent la nuit.", Point{-4.45, 5.30}, 4, "brigand"},
	{"faubourgs_neo_ebrie", "Faubourgs de Néo-Ébrié", "Des drones patrouillent : le Cercle d'Acier est ici.", Point{-4.15, 5.55}, 7, "cercle_acier"},
	{"rives_kossou", "Rives du lac de Kossou", "Des tambours résonnent sous l'eau. Les Sans-Visage préparent un rituel.", Point{-5.30, 7.30}, 10, "sans_visage"},
	{"parc_comoe", "Parc de la Comoé", "La plus grande réserve sauvage du pays. On y entend rugir des bêtes oubliées.", Point{-3.75, 8.90}, 8, ""},
	{"sommet_nimba", "Sommet du mont Nimba", "Le toit du pays. Quelque chose de très ancien y dort.", Point{-8.35, 7.60}, 25, ""},
}
