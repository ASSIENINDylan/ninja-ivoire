extends Node
## Client HTTP du serveur local. Toute la logique du jeu vit sur le
## serveur : le client ne fait qu'envoyer des intentions et afficher.

var port := 7777
var base := "http://127.0.0.1:7777"


func utiliser_port(p: int) -> void:
	port = p
	base = "http://127.0.0.1:%d" % p


func appel(methode: int, chemin: String, corps = null) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 8.0 if chemin != "/api/sante" else 1.5
	add_child(req)
	var entetes := PackedStringArray(["Content-Type: application/json"])
	var texte := "" if corps == null else JSON.stringify(corps)
	var err := req.request(base + chemin, entetes, methode, texte)
	if err != OK:
		req.queue_free()
		return {"ok": false, "erreur": "Requête impossible (%d)." % err, "reseau": true}
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "erreur": "Le serveur ne répond pas.", "reseau": true}
	var code: int = res[1]
	var body: PackedByteArray = res[3]
	var donnees = JSON.parse_string(body.get_string_from_utf8())
	if code >= 400:
		var msg := "Erreur %d." % code
		if donnees is Dictionary and donnees.has("erreur"):
			msg = str(donnees["erreur"])
		return {"ok": false, "erreur": msg}
	return {"ok": true, "data": donnees}


func lire(chemin: String) -> Dictionary:
	return await appel(HTTPClient.METHOD_GET, chemin)


func envoyer(chemin: String, corps: Dictionary = {}) -> Dictionary:
	return await appel(HTTPClient.METHOD_POST, chemin, corps)


func supprimer(chemin: String) -> Dictionary:
	return await appel(HTTPClient.METHOD_DELETE, chemin)
