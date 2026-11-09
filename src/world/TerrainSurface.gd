class_name TerrainSurface
extends Node2D
## REVISION 1: Fliessende Oberflaeche.
##
## Das Spiellogik-Raster bleibt 16x16 px (pixel-perfekt, Save/Load, Kollision).
## Die SICHTBARE Aschekante wird hier aber aus der kontinuierlichen Hoehenlinie
## WorldGenerator.height_smooth_at() in 4px-Schritten gezeichnet und auf ein
## 4px-Raster gerundet. Dadurch entstehen sanfte, treppenarme Uebergaenge statt
## der vorherigen 16px-Bloecke mit grossen 90-Grad-Ecken.
##
## Die oberste TileMapLayer-Zeile wird dafuer in Chunk._build_terrain()
## ausgelassen und durch dieses Profil ersetzt; alle tieferen Tiles bleiben
## unveraendert (inkl. Reservoir/Hoehlen-Slots).

const STEP := 4.0
const BODY := Color(0.212, 0.196, 0.184)       # Asche-Grundton des Atlas
const RIM_DARK := Color(0.105, 0.098, 0.092)    # verbrannte Oberkante
const RIM_LIGHT := Color(0.43, 0.40, 0.36)      # heller Aschestreifen
const SPECK_DARK := Color(0.13, 0.12, 0.11)
const SPECK_LIGHT := Color(0.37, 0.34, 0.31)

var index: int = 0
var generator: WorldGenerator


func setup(p_index: int, p_generator: WorldGenerator) -> void:
	index = p_index
	generator = p_generator
	name = "Surface"
	z_index = 1                 # ueber tile_layer (0), unter Baeumen (2)
	queue_redraw()


func _draw() -> void:
	if generator == null:
		return
	var steps := int(WorldGenerator.CHUNK_WIDTH_PX / STEP)   # 512
	var origin := float(index * WorldGenerator.CHUNK_WIDTH_PX)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for s in range(steps + 1):
		var wx := origin + float(s) * STEP
		var y := roundf(generator.height_smooth_at(wx) / STEP) * STEP
		var ty := generator.surface_tile_y_at(wx)
		top.append(Vector2(float(s) * STEP, y))
		bottom.append(Vector2(float(s) * STEP, float(ty * WorldGenerator.TILE_SIZE + 24)))

	var poly := PackedVector2Array()
	poly.append_array(top)
	for i in range(bottom.size() - 1, -1, -1):
		poly.append(bottom[i])
	draw_colored_polygon(poly, BODY)

	# Verbrannte Oberkante + heller Aschesaum.
	draw_polyline(top, RIM_DARK, 2.0)
	var lite := PackedVector2Array()
	for p in top:
		lite.append(p + Vector2(0.0, 3.0))
	draw_polyline(lite, RIM_LIGHT, 1.0)

	# Deterministische Asche-Sprenkel im Kap (keine neuen Assets noetig).
	for s in range(0, steps, 2):
		var h := ("%d_surface_%d" % [generator.world_seed, index * 2048 + int(s * STEP)]).hash()
		var yy := top[s].y + 6.0 + float(absi(h) % 14)
		draw_rect(Rect2(float(s) * STEP + 1.0, yy, 2.0, 2.0),
			SPECK_DARK if h % 2 == 0 else SPECK_LIGHT)
