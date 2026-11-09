class_name TerrainAtlas
extends RefCounted
## Baut das TileSet zur Laufzeit aus dem 16-Slot-Atlas.
## Vorteil: keine fragile .tres-Datei mit Sub-Resources; Aenderungen am Atlas
## wirken sofort. Kollision ist bereits vorbereitet (Physics Layer 0).
##
## Pro Slot gibt es 3 Alternative Tiles (gespiegelt / leicht abgedunkelt), damit
## die gekachelte Erde nicht als sichtbares Rastermuster repetiert.

const ATLAS_PATH := PixelArt.SOIL_ATLAS
const SLOT_COUNT := 17             # Slot 16 = ausgetrocknetes Reservoir (PHASE 2)
const TILE_SIZE := 16
const ALTERNATIVES := [1, 2, 3]


static func create_tile_set() -> TileSet:
	var tex: Texture2D = load(ATLAS_PATH)
	if tex == null:
		push_error("[TerrainAtlas] %s fehlt - tools/generate_placeholders.py ausfuehren." % ATLAS_PATH)
		return TileSet.new()

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Zuerst Tiles anlegen, dann die Source ans TileSet haengen: erst danach
	# kennt TileData die Physics-Layer des TileSets (sonst p_layer_id = 0
	# out of bounds). Kollision und Alternativen im Anschluss setzen.
	for i in SLOT_COUNT:
		source.create_tile(Vector2i(i, 0))
	tile_set.add_source(source, 0)

	var half := float(TILE_SIZE) * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	for i in SLOT_COUNT:
		var coords := Vector2i(i, 0)
		# Hoehlen sind Hohlraeume: kein Kollisions-Polygon darauf.
		if i != WorldGenerator.SLOT_CAVE:
			_set_collision(source.get_tile_data(coords, 0), square)
		for alt in ALTERNATIVES:
			source.create_alternative_tile(coords, alt)
			var data: TileData = source.get_tile_data(coords, alt)
			data.flip_h = (alt == 1 or alt == 3)
			data.flip_v = (alt == 2 or alt == 3)
			data.modulate = Color(0.95, 0.95, 0.95, 1.0) if alt == 2 else Color.WHITE
			if i != WorldGenerator.SLOT_CAVE:
				_set_collision(data, square)

	return tile_set


static func _set_collision(data: TileData, polygon: PackedVector2Array) -> void:
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, polygon)
