extends "res://src/plants/Tree.gd"
## Eiche (Startart) - extends Tree.gd, wie in Master-Punkt 9 gefordert.
## PHASE 2: Pfahlwurzel + Herzwurzelsystem (recherchiert, Punkt 4.3).
##   * Pfahlwurzel: Hauptachse waechst strikt nach unten (0,1).
##   * Herzwurzelsystem: alle `root_side_every` Tiles entsteht eine zusaetzliche
##     Seitenwurzel als weiterer anklickbarer Tip (siehe grow_root_from()).
##   * Buche (Flachwurzler) / Kiefer (sehr tiefe Pfahlwurzel) = PHASE 3.


func default_species() -> TreeSpeciesData:
	return load("res://data/species/oak.tres")


func build_mini() -> void:
	# 2 Stamm-Tiles, 2 Blätter, 1 kleine Wurzel
	super.build_mini()


## Erdsuche: Hauptachse bevorzugt senkrecht, Seitenwurzeln biegen nach unten.
func root_candidates(tip: RootSegment) -> Array[Vector2i]:
	if tip.direction.x != 0:
		var sx := tip.direction.x
		return [Vector2i(sx, 1), Vector2i(0, 1), Vector2i(sx, 0),
			Vector2i(-sx, 1)]
	# Pfahlwurzel: nur diagonale Ausweichziele, wenn (0,1) belegt ist.
	return [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1),
		Vector2i(-1, 0), Vector2i(1, 0)]
