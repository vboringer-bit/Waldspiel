class_name WorldGenerator
extends RefCounted
## Reine, deterministische Weltberechnung - keine Nodes, keine Side-Effects.
## Gleiche Seed + gleiche X-Koordinate => identische Hoehe / identisches Material.
## Inspiriert von GDQuest godot-procedural-generation (make_seed_for / Sektoren)
## und der Idee einer oeffentlichen height_at()-Abfragefunktion.
##
## PHASE 2: Hoehlen (CAVE), endliche Wasserreservoirs (WATER), Bodenhärte.
## REVISION 1: fliessende Oberflaeche (height_smooth_at + TerrainSurface),
## unregelmaessig verteilte Untergrund-Strukturen (rotierte, mehrfache,
## groessenvariable Blasen mit Noise-Kanten statt eines gleichmaessigen Rasters).

enum SoilKind { AIR, ASH, HUMUS, TOPSOIL, CLAY, ROCK, STONE, WATER, CAVE }
enum BiomeKind { TROCKEN, TEMPERIERT, FEUCHT }

const TILE_SIZE := 16
const CHUNK_TILES_X := 128
const CHUNK_WIDTH_PX := 2048          # 128 * 16
const DEPTH_TILES := 68               # ~1088 px = ca. 1 Bildschirmtiefe
const BASE_SURFACE_Y := 320.0         # Horizont / mittlere Oberflaeche
const BOTTOM_TILE_Y := 88             # Fels-Basement: hier ist Schluss

# Atlas-Slots (siehe tools/generate_placeholders.py)
const SLOT_ASH := 0
const SLOT_HUMUS := 1
const SLOT_TOPSOIL_A := 2
const SLOT_TOPSOIL_B := 3
const SLOT_TOPSOIL_STONE := 4
const SLOT_CLAY_A := 5
const SLOT_CLAY_B := 6
const SLOT_CLAY_STONE := 7
const SLOT_ROCK_A := 8
const SLOT_ROCK_B := 9
const SLOT_ROCK_DEEP := 10
const SLOT_WATER := 11                # Reservoir (nass)
const SLOT_CAVE := 12                 # Hohlraum
const SLOT_ASH_ALT := 13
const SLOT_MOSS := 14                 # PHASE 5 reserviert
const SLOT_ROOTED := 15               # reserviert
const SLOT_DRY_WATER := 16            # ausgetrocknet (optisch heller)

# Starter-Reservoir: ein kleiner, GARANTIERTER Kern (damit Tutorial/Tests
# funktionieren) plus eine unregelmaessige, von Noise zerfranste Wasserlinse.
const STARTER_CORE_MIN_X := -1
const STARTER_CORE_MAX_X := 1
const STARTER_CORE_MIN_DEPTH := 10
const STARTER_CORE_MAX_DEPTH := 12

var world_seed: int = 0
## REVISION 2: 0.5 = ~50 % weniger Hoehlenflaeche als REVISION 1.
## Statt die Zell-Wahrscheinlichkeit zu halbieren (streut stark pro Seed)
## werden alle Blob-Radien mit sqrt(0.5) skaliert: Ellipsenflaeche ~ rx*ry,
## also fuer JEDEN Seed reproduzierbar halb so viel Hoehle.
var cave_area_scale: float = 0.5
var _cave_radius_scale: float = sqrt(0.5)

var _height_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _variation_noise := FastNoiseLite.new()
var _stone_noise := FastNoiseLite.new()
var _biome_noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _reservoir_noise := FastNoiseLite.new()
var _seed_noise := FastNoiseLite.new()
var _cave_cache: Dictionary = {}
var _res_cache: Dictionary = {}


func _init(p_seed: int = 20261105) -> void:
	set_world_seed(p_seed)


func set_world_seed(p_seed: int) -> void:
	world_seed = p_seed
	_cave_cache.clear()
	_res_cache.clear()
	_configure(_height_noise, p_seed, 1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3, 0.50)
	_configure(_detail_noise, p_seed, 2, FastNoiseLite.TYPE_SIMPLEX, 2, 0.45)
	_configure(_variation_noise, p_seed, 3, FastNoiseLite.TYPE_VALUE, 2, 0.50)
	_configure(_stone_noise, p_seed, 4, FastNoiseLite.TYPE_CELLULAR, 1, 0.50)
	_configure(_biome_noise, p_seed, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2, 0.50)
	_configure(_cave_noise, p_seed, 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2, 0.50)
	_configure(_reservoir_noise, p_seed, 7, FastNoiseLite.TYPE_SIMPLEX, 2, 0.45)
	_configure(_seed_noise, p_seed, 8, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2, 0.50)


func set_cave_area_scale(value: float) -> void:
	cave_area_scale = clampf(value, 0.05, 2.0)
	_cave_radius_scale = sqrt(cave_area_scale)
	_cave_cache.clear()
	_res_cache.clear()


func _configure(n: FastNoiseLite, s: int, salt: int, type: int, octaves: int, gain: float) -> void:
	n.seed = s + salt * 7919
	n.noise_type = type
	n.frequency = 1.0
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.fractal_lacunarity = 2.0


# --------------------------------------------------------------------------- #
# Hoehenlinie: height_smooth_at = fliessend, height_at = auf 16px gerastet
# --------------------------------------------------------------------------- #
## Kontinuierliche Huegellinie. TerrainSurface zeichnet daraus die sichtbare
## Oberkante in 4px-Schritten -> keine grossen 90-Grad-Ecken mehr.
func height_smooth_at(world_x: float) -> float:
	var broad := _height_noise.get_noise_1d(world_x / 1000.0)
	var fine := _detail_noise.get_noise_1d(world_x / 170.0)
	return BASE_SURFACE_Y + broad * 52.0 + fine * 10.0


## Spiel-/Tile-Logik bleibt auf dem 16px-Raster (pixel-perfekt).
func height_at(world_x: float) -> float:
	return roundf(height_smooth_at(world_x) / float(TILE_SIZE)) * float(TILE_SIZE)


func surface_tile_y_at(world_x: float) -> int:
	return int(height_at(world_x) / float(TILE_SIZE))


## REVISION 7: DIESE Kante zeichnet TerrainSurface (4px-Schritte). Alle
## Objekte, die "auf dem Boden abschliessen" muessen (Ameisenhuegel, Tiere),
## muessen sich an diesem Wert ausrichten - nicht am fliessenden Rohwert.
func ground_y_at(world_x: float) -> float:
	return roundf(height_smooth_at(world_x) / 4.0) * 4.0


func depth_tiles_at(global_tile_x: int, tile_y: int) -> int:
	return tile_y - surface_tile_y_at(float(global_tile_x * TILE_SIZE))


## Fliessende Tiefe in Pixeln fuer die Boden-Schichtgrenzen: dadurch wandern
## die Farbgrenzen pro Spalte sanft mit der Huegellinie statt zu springen.
func depth_px_at(global_tile_x: int, tile_y: int) -> float:
	return float(tile_y * TILE_SIZE + 8) - height_smooth_at(float(global_tile_x * TILE_SIZE))


# --------------------------------------------------------------------------- #
# Biome (PHASE 0-2: exakt 1 Biom, aber API + Noise fuer 3 Biome vorbereitet)
# --------------------------------------------------------------------------- #
func biome_at(_world_x: float) -> BiomeKind:
	return BiomeKind.TEMPERIERT


func biome_moisture_at(_world_x: float) -> float:
	return 0.5


func biome_noise_at(world_x: float) -> float:
	return _biome_noise.get_noise_1d(world_x / 6000.0)


# --------------------------------------------------------------------------- #
# REVISION 1: unregelmaessige Hoehlen + Wasserreservoirs
# --------------------------------------------------------------------------- #
func _hash2(a: int, b: int, salt: int) -> int:
	return ("%d_%d_%d_%d" % [world_seed, salt, a, b]).hash() & 0x7fffffff


## Mehrere ROTIERTE Ellipsen pro Zelle, mit stark variierenden Radien und
## Positions-Jitter ueber die Zellgrenzen hinaus. Eine Noise-Kante verformt
## den Rand zusaetzlich. Ergebnis: organisch, ohne sichtbares Raster.
func _blob_field(gx: int, ty: int, salt: int, cell_w: int, cell_h: int,
		density: int, r_min: float, r_max: float, wobble: float,
		elongated: bool, radius_scale: float = 1.0) -> bool:
	var cx := int(floor(float(gx) / float(cell_w)))
	var cy := int(floor(float(ty) / float(cell_h)))
	var edge := _cave_noise.get_noise_2d(
		float(gx) * 0.55 + float(salt), float(ty) * 0.55 - float(salt))
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var ccx := cx + ox
			var ccy := cy + oy
			var h := _hash2(ccx, ccy, salt)
			if (h % 100) >= density:
				continue
			var count := 1 + (h % 3)          # 1..3 Blasen pro Zelle
			for k in count:
				var h1 := _hash2(ccx * 7 + k, ccy * 11 - k, salt + 331)
				var h2 := _hash2(ccx * 13 - k, ccy * 5 + k, salt + 997)
				var h3 := _hash2(ccx * 3 + k, ccy * 17 + k, salt + 1543)
				# Jitter ueber 2 Zellbreiten -> Blasen ueberlappen Nachbarzellen.
				var bx := float(ccx * cell_w) + float(h1 % (cell_w * 2)) - float(cell_w) * 0.5
				var by := float(ccy * cell_h) + float(h2 % (cell_h * 2)) - float(cell_h) * 0.5
				var rr := float(h3 % 1000) / 1000.0
				var rx := lerpf(r_min, r_max, rr) * radius_scale
				var ry := lerpf(r_min * 0.55, r_max * 0.70,
					float(h1 % 100) / 100.0) * radius_scale
				if elongated:
					rx *= 1.85
					ry *= 0.55
				var angle := float(h2 % 628) / 100.0
				var ca := cos(angle)
				var sa := sin(angle)
				var ddx := float(gx) - bx
				var ddy := float(ty) - by
				var ux := (ddx * ca + ddy * sa) / maxf(rx, 0.5)
				var uy := (-ddx * sa + ddy * ca) / maxf(ry, 0.5)
				if ux * ux + uy * uy <= 1.0 + edge * wobble:
					return true
	return false


## Unregelmaessige Wasserlinse in Chunk 0 mit garantiertem Kern (3x3 Tiles).
func is_starter_reservoir(gx: int, ty: int) -> bool:
	var d := depth_tiles_at(gx, ty)
	if gx >= STARTER_CORE_MIN_X and gx <= STARTER_CORE_MAX_X \
			and d >= STARTER_CORE_MIN_DEPTH and d <= STARTER_CORE_MAX_DEPTH:
		return true
	if absi(gx) > 9 or d < 8 or d > 15:
		return false
	var nx := float(gx) / 9.0
	var ny := (float(d) - 11.5) / 3.6
	var wob := _reservoir_noise.get_noise_2d(float(gx) * 0.6 + 3.0, float(ty) * 0.6 - 7.0)
	return nx * nx + ny * ny <= 1.0 + wob * 0.50


func _compute_cave(gx: int, ty: int) -> bool:
	if is_starter_reservoir(gx, ty):
		return false
	var d := depth_tiles_at(gx, ty)
	if d < 5 or d > 44 or ty > BOTTOM_TILE_Y:
		return false
	# Drei ueberlagerte Familien: grosse Kammern, kleine Taschen, lange Gaenge.
	# REVISION 2: gleiche Zellverteilung wie REVISION 1, aber alle Radien
	# mit sqrt(0.5) -> ~50 % weniger Hoehlenflaeche, seed-stabil.
	var rs := _cave_radius_scale
	if _blob_field(gx, ty, 61, 24, 15, 48, 2.5, 7.0, 0.55, false, rs):
		return true
	if _blob_field(gx, ty, 83, 17, 11, 26, 1.4, 3.2, 0.45, false, rs):
		return true
	if _blob_field(gx, ty, 97, 31, 19, 14, 4.0, 9.0, 0.35, true, rs):
		return true
	return false


func cave_at(gx: int, ty: int) -> bool:
	var k := Vector2i(gx, ty)
	if _cave_cache.has(k):
		return _cave_cache[k]
	var v := _compute_cave(gx, ty)
	_cave_cache[k] = v
	return v


func _raw_reservoir(gx: int, ty: int) -> bool:
	if is_starter_reservoir(gx, ty):
		return true
	if cave_at(gx, ty):
		return false
	var d := depth_tiles_at(gx, ty)
	if d < 7 or d > 36 or ty > BOTTOM_TILE_Y:
		return false
	return _blob_field(gx, ty, 71, 19, 13, 34, 1.6, 3.6, 0.50, false)


## REVISION 2: 1-Tile-Dilatation. Ein Erd-Tile mit mindestens zwei nassen
## direkten Nachbarn wird mit Wasser gefuellt. Dadurch verbinden sich eng
## beieinander liegende Linsen zu EINEM Becken und Löcher verschwinden -
## genau das "Wasser haengt zusammen" aus der Anforderung.
const RES_NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)]


func reservoir_at(gx: int, ty: int) -> bool:
	var k := Vector2i(gx, ty)
	if _res_cache.has(k):
		return _res_cache[k]
	var v := _raw_reservoir(gx, ty)
	if not v and not cave_at(gx, ty):
		var wet_neighbors := 0
		for d in RES_NEIGHBORS:
			if _raw_reservoir(gx + d.x, ty + d.y):
				wet_neighbors += 1
		if wet_neighbors >= 2:
			v = true
	_res_cache[k] = v
	return v


# --------------------------------------------------------------------------- #
# REVISION 2: glatte Kanten fuer Erdschichten / Hoehlen / Wasser
# --------------------------------------------------------------------------- #
## Fliessende Schichtgrenze in Welt-Pixeln (4px-Raster wie die Oberflaeche).
## TerrainContours zeichnet daraus einen weichen Farbuebergang + Rim-Linie.
func layer_edge_y(world_x: float, depth_px: float, salt: float) -> float:
	var wob := _variation_noise.get_noise_1d(world_x / 340.0 + salt * 17.0) * 6.0
	var fine := _detail_noise.get_noise_1d(world_x / 95.0 - salt * 31.0) * 2.0
	return roundf((height_smooth_at(world_x) + depth_px + wob + fine) / 4.0) * 4.0


## Kleine organische Verformung der Blob-Isolinie in 4px-Aufloesung.
func edge_wobble_at(world_x: float, world_y: float, salt: float) -> float:
	return _cave_noise.get_noise_2d(world_x * 0.045 + salt * 13.0,
		world_y * 0.045 - salt * 7.0) * 0.22


## Start-Kapazitaet eines Reservoirs in Wasser-Einheiten (2.0/s Verbrauch).
func reservoir_capacity_at(gx: int, ty: int) -> float:
	var h := ("%d_res_%d_%d" % [world_seed, gx, ty]).hash() & 0x7fffffff
	return 60.0 + float(h % 61)   # 60 .. 120


# --------------------------------------------------------------------------- #
# Boden-Schichtung (Schichtgrenzen folgen der fliessenden Hoehe)
# --------------------------------------------------------------------------- #
func material_at(gx: int, ty: int) -> SoilKind:
	var surface_ty := surface_tile_y_at(float(gx * TILE_SIZE))
	if ty < surface_ty or ty > BOTTOM_TILE_Y:
		return SoilKind.AIR
	if cave_at(gx, ty):
		return SoilKind.CAVE
	if reservoir_at(gx, ty):
		return SoilKind.WATER
	var dp := depth_px_at(gx, ty)
	if dp < 16.0:
		return SoilKind.ASH
	if dp < 32.0:
		return SoilKind.HUMUS
	if dp <= 208.0:
		return SoilKind.TOPSOIL
	if dp <= 608.0:
		return SoilKind.CLAY
	return SoilKind.ROCK


## Liefert den Atlas-Slot fuer ein Tile oder -1 fuer Luft.
func atlas_slot_at(gx: int, ty: int) -> int:
	var surface_ty := surface_tile_y_at(float(gx * TILE_SIZE))
	if ty < surface_ty or ty > BOTTOM_TILE_Y:
		return -1
	if cave_at(gx, ty):
		return SLOT_CAVE
	if reservoir_at(gx, ty):
		return SLOT_WATER
	return soil_slot_at(gx, ty)


## REVISION 2: das REINE Erdreich unter einer Hoehle / einem Reservoir.
## TerrainContours uebermalt damit die harten 16px-Struktur-Tiles, bevor es
## die weiche Isolinie zeichnet (sonst scheinen die Blockecken durch).
func soil_slot_at(gx: int, ty: int) -> int:
	var surface_ty := surface_tile_y_at(float(gx * TILE_SIZE))
	if ty < surface_ty or ty > BOTTOM_TILE_Y:
		return -1
	var dp := depth_px_at(gx, ty)
	var variation := _variation_noise.get_noise_2d(float(gx) * 0.35, float(ty) * 0.35)
	var has_stone := _stone_noise.get_noise_2d(float(gx) * 1.3, float(ty) * 1.3) > 0.42

	if dp < 16.0:
		return SLOT_ASH_ALT if variation > 0.25 else SLOT_ASH
	if dp < 32.0:
		return SLOT_HUMUS
	if dp <= 208.0:
		if has_stone and dp > 56.0:
			return SLOT_TOPSOIL_STONE
		return SLOT_TOPSOIL_A if variation < 0.0 else SLOT_TOPSOIL_B
	if dp <= 608.0:
		if has_stone and dp > 240.0:
			return SLOT_CLAY_STONE
		return SLOT_CLAY_A if variation < 0.0 else SLOT_CLAY_B
	if dp > 880.0:
		return SLOT_ROCK_DEEP
	return SLOT_ROCK_A if variation < 0.0 else SLOT_ROCK_B


## Alternative Tile-ID. Spezial-Slots bleiben ungespiegelt.
func alternative_at(gx: int, ty: int) -> int:
	var slot := atlas_slot_at(gx, ty)
	if slot == SLOT_CAVE or slot == SLOT_WATER or slot == SLOT_DRY_WATER:
		return 0
	var n := _variation_noise.get_noise_2d(
		float(gx) * 0.71 + 31.0, float(ty) * 0.71 - 17.0)
	if n > 0.35:
		return 3
	if n > 0.0:
		return 1
	if n > -0.35:
		return 2
	return 0


# --------------------------------------------------------------------------- #
# Chunk-Dekoration (Start-Zustand: verkohlte Stuempfe / Aeste, keine Baeume)
# --------------------------------------------------------------------------- #
func chunk_seed(chunk_index: int) -> int:
	return ("%d_chunk_%d" % [world_seed, chunk_index]).hash() & 0x7fffffff


func decorations_for_chunk(chunk_index: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed(chunk_index)
	var out: Array[Dictionary] = []
	var used: Array[int] = []

	# Start-Chunk: 4 Stuempfe (Master-Prompt: 3-5), sonst 1-2 zur Deko.
	var stump_count := 4 if chunk_index == 0 else rng.randi_range(1, 2)
	for _i in stump_count:
		var tx := _spread_x(rng, used)
		used.append(tx)
		var wx := float(chunk_index * CHUNK_WIDTH_PX + tx * TILE_SIZE)
		# Fliessende Oberflaeche als Auflagehoehe (4px-Raster).
		var sy := roundf(height_smooth_at(wx) / 4.0) * 4.0
		out.append({
			"x": float(tx * TILE_SIZE),
			"y": sy - float(TILE_SIZE * 2),
			"kind": "stump_%s" % ["a", "b", "c"][rng.randi_range(0, 2)],
		})

	for _i in rng.randi_range(1, 3):
		var tx := _spread_x(rng, used)
		used.append(tx)
		var wx := float(chunk_index * CHUNK_WIDTH_PX + tx * TILE_SIZE)
		var sy := roundf(height_smooth_at(wx) / 4.0) * 4.0
		out.append({
			"x": float(tx * TILE_SIZE),
			"y": sy - float(TILE_SIZE),
			"kind": "branch",
		})
	return out


func _spread_x(rng: RandomNumberGenerator, used: Array[int]) -> int:
	var tx := rng.randi_range(4, CHUNK_TILES_X - 6)
	for _attempt in 12:
		if not _too_close(tx, used, 14):
			break
		tx = rng.randi_range(4, CHUNK_TILES_X - 6)
	return tx


func _too_close(x: int, used: Array[int], min_distance: int) -> bool:
	for other in used:
		if absi(x - other) < min_distance:
			return true
	return false


# --------------------------------------------------------------------------- #
# PHASE 3: Samen finden / flach vergraben (Master-Punkt 7, "Per Noise verteilt")
# --------------------------------------------------------------------------- #
## Reine, seed-deterministische Kandidatenliste fuer einen Chunk. `roll`
## entscheidet ueber die Dichte (Schwierigkeitsgrad) und `buried` ueber die
## Art: auf dem Boden liegend (Eichel-Sprite) oder flach vergraben (Huegel,
## nur mit einer Wurzel erreichbar). Es werden KEINE Nodes erzeugt.
func ground_seeds_for_chunk(chunk_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d_seeds_%d" % [world_seed, chunk_index]).hash() & 0x7fffffff
	var cluster := _seed_noise.get_noise_1d(float(chunk_index) * 9.0 + 17.0)
	var count := 3 + int(roundf(cluster * 2.0))        # 1..5 pro Chunk
	var used: Array[int] = []
	for i in count:
		var tx := _spread_x(rng, used)
		used.append(tx)
		var lx := float(tx * TILE_SIZE)
		var wx := float(chunk_index * CHUNK_WIDTH_PX) + lx
		var n := _seed_noise.get_noise_1d(wx / 260.0)
		var sy := roundf(height_smooth_at(wx) / 4.0) * 4.0
		var buried := n > 0.05 and rng.randf() < 0.55
		out.append({
			"id": "%d:%d:%d" % [chunk_index, tx, i],
			"chunk": chunk_index,
			"x": lx,
			"y": sy,
			"gx": chunk_index * CHUNK_TILES_X + tx,
			"ty": surface_tile_y_at(wx) + 2,
			"buried": buried,
			"roll": float(rng.randi_range(0, 1000)) / 1000.0,
		})
	return out
