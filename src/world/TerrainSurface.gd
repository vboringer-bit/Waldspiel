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
var origin: float = 0.0
var generator: WorldGenerator


func setup(p_index: int, p_generator: WorldGenerator) -> void:
	index = p_index
	origin = float(p_index * WorldGenerator.CHUNK_WIDTH_PX)
	generator = p_generator
	name = "Surface"
	z_index = 1                 # ueber tile_layer (0), unter Baeumen (2)
	queue_redraw()


func _draw() -> void:
	if generator == null:
		return
	var steps := int(WorldGenerator.CHUNK_WIDTH_PX / STEP)   # 512
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
	# KORREKTUR P8.1: Der Biom-Ton wurde frueher EINMAL in der Chunk-Mitte
	# berechnet und auf den ganzen Chunk angewandt -> harter Farbsprung an
	# jeder 2048px-Grenze. Jetzt wird streifenweise in WELTKOORDINATEN
	# abgetastet (identisch zu TerrainContours._draw_biome_tint), damit
	# linker und rechter Nachbarchunk an der Naht exakt dieselbe Farbe haben.
	# Im temperierten Kern bleibt der bisherige EINE draw_colored_polygon-
	# Aufruf mit BODY bitgenau erhalten.
	draw_colored_polygon(poly, BODY)
	var any_tint := false
	for i in 32:
		var wx := origin + (float(i) + 0.5) * 64.0
		if generator.biome_tint_at(wx).a > 0.002:
			any_tint = true
			break
	if any_tint:
		for i in 32:
			var wx := origin + (float(i) + 0.5) * 64.0
			var tint := generator.biome_tint_at(wx)
			if tint.a <= 0.002:
				continue
			var i0 := i * 16
			var i1 := mini((i + 1) * 16, top.size() - 1)
			var quad := PackedVector2Array()
			for k in range(i0, i1 + 1):
				quad.append(top[k])
			for k in range(i1, i0 - 1, -1):
				quad.append(bottom[k])
			draw_colored_polygon(quad, BODY.lerp(
				Color(tint.r, tint.g, tint.b), clampf(tint.a * 2.2, 0.0, 0.65)))

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


## KORREKTUR P8.1: Debug-Hook. Liefert die 32 Streifen-Alphas in
## WELTKOORDINATEN. Der letzte Streifen von Chunk n und der erste von
## Chunk n+1 muessen praktisch identisch sein (keine Naht).
func debug_stripe_tints() -> Array:
	var out: Array[float] = []
	if generator == null:
		return out
	for i in 32:
		out.append(generator.biome_tint_at(
			origin + (float(i) + 0.5) * 64.0).a)
	return out
