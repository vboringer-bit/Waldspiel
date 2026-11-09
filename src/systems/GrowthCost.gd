class_name GrowthCost
extends RefCounted
## PHASE 2: Wurzelwachstum kostet Glucose ABHAENGIG VON DER BODENHÄRTE
## (Master-Punkt 4.3: "Fels teurer"). Basis = 10 Glucose fuer Mutterboden,
## entsprechend dem Akzeptanzkriterium "Klick auf Wurzel -> kostet 10 Glucose".
## Zentrale, modulare Tabelle statt verteilter Magic Numbers.

const BASE := 10.0


static func multiplier(kind: int) -> float:
	match kind:
		WorldGenerator.SoilKind.ASH:     return 0.8   # lockere Brandasche
		WorldGenerator.SoilKind.HUMUS:   return 0.9
		WorldGenerator.SoilKind.TOPSOIL: return 1.0   # Referenz = 10 Glucose
		WorldGenerator.SoilKind.CLAY:    return 1.3   # Lehm ist zaeh
		WorldGenerator.SoilKind.ROCK:    return 2.5   # Fels deutlich teurer
		WorldGenerator.SoilKind.STONE:   return 3.0   # Steinklumpen am teuersten
		WorldGenerator.SoilKind.WATER:   return 1.5   # nasses Reservoir
		WorldGenerator.SoilKind.CAVE:    return 0.4   # Hohlraum: fast frei
		WorldGenerator.SoilKind.AIR:     return 0.5
	return 1.0


## `scale` = Global.difficulty_factor("growth_cost"). Default 1.0 haelt
## alle P0/P1/P2-Smokes bei NORMAL unveraendert.
static func for_tile(generator: WorldGenerator, global_tile_x: int, tile_y: int,
		scale: float = 1.0) -> float:
	return BASE * multiplier(generator.material_at(global_tile_x, tile_y)) * scale


## Kosten des naechsten Wurzelschritts (Ghost-Preview + Kauf identisch).
## Liefert -1.0, wenn kein Ziel-Tile mehr frei ist.
static func for_root(tree: BaseTree, generator: WorldGenerator,
		scale: float = 1.0) -> float:
	if tree == null or generator == null:
		return -1.0
	var tip := tree.deepest_tip()
	var target := tree.propose_next_tile(tip)
	if target == BaseTree.INVALID_TILE:
		return -1.0
	var gt := tree.global_tile_for(target)
	return for_tile(generator, gt.x, gt.y, scale)


static func material_key(kind: int) -> String:
	match kind:
		WorldGenerator.SoilKind.ASH:     return "SOIL_ASH"
		WorldGenerator.SoilKind.HUMUS:   return "SOIL_HUMUS"
		WorldGenerator.SoilKind.TOPSOIL: return "SOIL_TOPSOIL"
		WorldGenerator.SoilKind.CLAY:    return "SOIL_CLAY"
		WorldGenerator.SoilKind.ROCK:    return "SOIL_ROCK"
		WorldGenerator.SoilKind.STONE:   return "SOIL_STONE"
		WorldGenerator.SoilKind.WATER:   return "SOIL_WATER"
		WorldGenerator.SoilKind.CAVE:    return "SOIL_CAVE"
		WorldGenerator.SoilKind.AIR:     return "SOIL_AIR"
	return "SOIL_AIR"


static func material_name(kind: int) -> String:
	## TranslationServer.translate() ist statisch; tr() waere an einen Node gebunden.
	return TranslationServer.translate(material_key(kind))
