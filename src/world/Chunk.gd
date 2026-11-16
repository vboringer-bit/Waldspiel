class_name TerrainChunk
extends Node2D
## Ein horizontaler Chunk (2048 px). Besitzt genau eine TileMapLayer fuer den
## Bodenquerschnitt und einen Decor-Root fuer die Brand-Rueckstaende.
## PHASE 2: Hoehlen (CAVE) und Reservoirs (WATER) kommen aus dem Generator;
## ausgetrocknete Reservoirs werden ueber WorldState auf SLOT_DRY_WATER
## umgeschaltet und bleiben auch nach einem Chunk-Reload trocken.

const SPRITE_DIR := PixelArt.DIR

var index: int = 0
var generator: WorldGenerator
var world_state: WorldState
var tile_layer: TileMapLayer
var decor_root: Node2D
var surface: TerrainSurface
var contours: TerrainContours
## REVISION 3: nur die eigenen Reservoir-Kacheln merken. Frueher lief
## refresh_reservoirs() bei JEDEM Pegelschritt durch 128 x 88 Tiles und
## rief jeweils den Noise-Generator auf -> sichtbarer Ruckler.
var _water_cells: Array[Vector2i] = []

## KORREKTUR P8.1: zeitgescheitelter Chunk-Aufbau. Ein kompletter Chunk
## kostete frueher einen ganzen Frame (sichtbarer Ruckler beim Ueberfahren
## einer Chunkgrenze mit schnellem WASD). Jetzt werden 4 Spalten pro
## Scheibe gebaut; ChunkManager verteilt die Scheiben auf mehrere Frames.
## load_radius = 2 => der neu gebaute Chunk liegt zwei Chunks neben der
## Kamera und ist daher noch ausserhalb des sichtbaren Ausschnitts.
var _done_cols: int = 0
var _caves_partial: Dictionary = {}
var _water_partial: Dictionary = {}
var _built: bool = false


func setup(p_index: int, p_generator: WorldGenerator, p_tile_set: TileSet,
		p_world_state: WorldState, p_sliced: bool = false) -> void:
	index = p_index
	generator = p_generator
	world_state = p_world_state
	name = "Chunk_%d" % index
	position = Vector2(float(index * WorldGenerator.CHUNK_WIDTH_PX), 0.0)
	_done_cols = 0
	_built = false
	_caves_partial.clear()
	_water_partial.clear()
	_water_cells.clear()

	tile_layer = TileMapLayer.new()
	tile_layer.name = "Terrain"
	tile_layer.tile_set = p_tile_set
	tile_layer.rendering_quadrant_size = 16
	tile_layer.collision_enabled = true
	tile_layer.y_sort_enabled = true
	add_child(tile_layer)

	# REVISION 1: die sichtbare Oberkante wird als fliessendes 4px-Profil
	# gezeichnet, nicht mehr als 16px-Blockkante der TileMapLayer.
	surface = TerrainSurface.new()
	surface.setup(index, generator)
	add_child(surface)

	_build_decor()
	EventBus.reservoir_dried.connect(_on_reservoir_dried)
	EventBus.reservoir_level_changed.connect(_on_level_changed)

	if not p_sliced:
		build_slice(WorldGenerator.CHUNK_TILES_X)


## Baut `cols` weitere Spalten. Rueckgabe true, wenn der Chunk fertig ist.
## Strukturen werden mit +-2 Spalten Rand gescannt, damit Blobs an der
## Chunkgrenze nicht hart abgeschnitten werden.
func build_slice(cols: int) -> bool:
	if _built:
		return true
	var first_gx := index * WorldGenerator.CHUNK_TILES_X
	var end := mini(_done_cols + cols, WorldGenerator.CHUNK_TILES_X)

	for lx in range(_done_cols - 2, end + 2):
		var gx := first_gx + lx
		var top := generator.surface_tile_y_at(float(gx * WorldGenerator.TILE_SIZE))
		for ty in range(top + 1, WorldGenerator.BOTTOM_TILE_Y + 1):
			if generator.cave_at(gx, ty):
				_caves_partial[Vector2i(gx, ty)] = true
			elif generator.reservoir_at(gx, ty):
				_water_partial[Vector2i(gx, ty)] = true

	for lx in range(_done_cols, end):
		var gx := first_gx + lx
		var top := generator.surface_tile_y_at(float(gx * WorldGenerator.TILE_SIZE))
		# Top-Zeile auslassen: TerrainSurface deckt sie ab.
		for ty in range(top + 1, WorldGenerator.BOTTOM_TILE_Y + 1):
			var slot := _slot_for(gx, ty)
			if slot >= 0:
				var alt := generator.alternative_at(gx, ty)
				tile_layer.set_cell(Vector2i(lx, ty), 0, Vector2i(slot, 0), alt)

	_done_cols = end
	if _done_cols >= WorldGenerator.CHUNK_TILES_X:
		_finish_build()
		return true
	return false


func _finish_build() -> void:
	var first_gx := index * WorldGenerator.CHUNK_TILES_X
	for tv in _water_partial.keys():
		var g: Vector2i = tv as Vector2i
		var lx := g.x - first_gx
		if lx >= 0 and lx < WorldGenerator.CHUNK_TILES_X:
			_water_cells.append(Vector2i(lx, g.y))
	contours = TerrainContours.new()
	contours.setup(index, generator, world_state, _caves_partial, _water_partial)
	add_child(contours)
	_built = true


func is_build_complete() -> bool:
	return _built


func debug_built_columns() -> int:
	return _done_cols


func _slot_for(gx: int, ty: int) -> int:
	if generator.cave_at(gx, ty):
		return WorldGenerator.SLOT_CAVE
	if generator.reservoir_at(gx, ty):
		if world_state != null and world_state.is_dry(gx, ty):
			return WorldGenerator.SLOT_DRY_WATER
		return WorldGenerator.SLOT_WATER
	return generator.atlas_slot_at(gx, ty)


func _on_level_changed() -> void:
	refresh_reservoirs()
	if contours != null:
		# REVISION 4: nur die Wasser-Kontur neu zeichnen, nicht Erde/Hoehlen.
		contours.queue_water_redraw()


func _on_reservoir_dried(tile: Vector2i) -> void:
	var lx := tile.x - index * WorldGenerator.CHUNK_TILES_X
	if lx < 0 or lx >= WorldGenerator.CHUNK_TILES_X or tile_layer == null:
		return
	if not generator.reservoir_at(tile.x, tile.y):
		return
	tile_layer.set_cell(Vector2i(lx, tile.y), 0,
		Vector2i(WorldGenerator.SLOT_DRY_WATER, 0), 0)


## Nach Save/Load: alle sichtbaren Reservoirs passend neu einfaerben.
func refresh_reservoirs() -> void:
	if tile_layer == null or world_state == null:
		return
	for cell in _water_cells:
		var gx := index * WorldGenerator.CHUNK_TILES_X + cell.x
		var slot := (WorldGenerator.SLOT_DRY_WATER
			if world_state.is_dry(gx, cell.y)
			else WorldGenerator.SLOT_WATER)
		tile_layer.set_cell(cell, 0, Vector2i(slot, 0), 0)


func _build_decor() -> void:
	decor_root = Node2D.new()
	decor_root.name = "Decor"
	decor_root.y_sort_enabled = true
	add_child(decor_root)

	for d in generator.decorations_for_chunk(index):
		var tex: Texture2D = load(SPRITE_DIR + String(d["kind"]) + ".png")
		if tex == null:
			push_warning("[Chunk] Platzhalter fehlt: %s" % d["kind"])
			continue
		var sprite := Sprite2D.new()
		sprite.name = String(d["kind"])
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(float(d["x"]), float(d["y"]))
		decor_root.add_child(sprite)
