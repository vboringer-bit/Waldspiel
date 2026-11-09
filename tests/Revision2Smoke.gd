extends Node
## Headless-Smoke-Test fuer REVISION 2 (vor PHASE 3):
##   godot --headless --path . -- --rev2-smoke
## 1) Alle Strukturen haben weiche 4px-Kanten (Schichten, Hoehlen, Wasser).
## 2) Hoehlen sind ~50 % seltener als in REVISION 1.
## 3) Wasser = EIN zusammenhaengendes Becken mit gemeinsamem Volumen;
##    der Pegel sinkt von oben nach unten, nicht nur am Wurzel-Tile.

var interaction: InteractionController
var growth: GrowthSystem
var water: WaterSystem
var save_manager: SaveManager
var chunk_manager: ChunkManager
var camera: CameraController
var world_state: WorldState

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_save: SaveManager, p_chunks: ChunkManager,
		p_camera: CameraController, p_state: WorldState) -> void:
	interaction = p_interaction
	growth = p_growth
	water = p_water
	save_manager = p_save
	chunk_manager = p_chunks
	camera = p_camera
	world_state = p_state


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-58s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	growth.set_process(false)
	water.set_process(false)
	print("[SMOKE] === REVISION 2 (vor PHASE 3) ===")
	var gen := chunk_manager.generator
	var top := gen.surface_tile_y_at(0.0)

	# --- 1) ~50 % weniger Hoehlen ------------------------------------------
	_check(is_equal_approx(gen.cave_area_scale, 0.5),
		"Hoehlenflaeche auf 50 % gesetzt")
	var legacy := WorldGenerator.new(Global.world_seed)
	legacy.set_cave_area_scale(1.0)
	var now_count := 0
	var old_count := 0
	for gx in range(-80, 81):
		for ty in range(top + 5, top + 45):
			if gen.cave_at(gx, ty):
				now_count += 1
			if legacy.cave_at(gx, ty):
				old_count += 1
	var ratio := float(now_count) / float(maxi(old_count, 1))
	_check(old_count > 30 and ratio >= 0.35 and ratio <= 0.65,
		"Hoehlen ~50 %% seltener (%d statt %d, %.0f%%)" % [
			now_count, old_count, ratio * 100.0])

	# --- 2) Weiche Kanten fuer ALLE Strukturen -------------------------------
	var chunk0 := chunk_manager.get_chunk(0)
	_check(chunk0 != null and chunk0.surface != null and chunk0.contours != null,
		"TerrainSurface + TerrainContours pro Chunk vorhanden")
	var max_step := 0.0
	var big_corners := 0
	var prev := gen.layer_edge_y(-2048.0, 208.0, 3.0)
	for x in range(-2048, 2049, 4):
		var y := gen.layer_edge_y(float(x), 208.0, 3.0)
		var d := absf(y - prev)
		max_step = maxf(max_step, d)
		if d >= 16.0:
			big_corners += 1
		prev = y
	_check(big_corners == 0 and max_step <= 8.0,
		"Schichtgrenze fliessend: max. %.0f px / %d Ecken" % [max_step, big_corners])
	var wobbles := {}
	for x in range(0, 512, 16):
		wobbles[int(gen.edge_wobble_at(float(x) * 4.0, 700.0, 11.0) * 1000.0)] = true
	_check(wobbles.size() >= 8,
		"Blob-Kanten organisch verwackelt (%d verschiedene Werte)" % wobbles.size())
	_check(int(ProjectSettings.get_setting("display/window/size/mode")) == 3,
		"Vollbild-Skalierung aus REVISION 1 bleibt")

	# --- 3) Zusammenhaengendes Becken ---------------------------------------
	world_state.reset()
	var res := Vector2i(0, top + 10)
	_check(gen.reservoir_at(res.x, res.y),
		"Starter-Reservoir weiterhin garantiert")
	var gid := world_state.group_id_for(res.x, res.y)
	_check(not gid.is_empty(), "Reservoir wurde als zusammenhängendes Becken erkannt")
	var tiles: Array = world_state.group_tiles(gid)
	_check(tiles.size() >= 4, "Becken hat %d verbundene Tiles" % tiles.size())
	var top_tile: Vector2i = tiles[0]
	var bottom_tile: Vector2i = tiles[tiles.size() - 1]
	_check(world_state.group_id_for(bottom_tile.x, bottom_tile.y) == gid,
		"Oberes und unteres Tile gehoeren zum SELBEN Becken")
	_check(is_equal_approx(world_state.fill_fraction(res.x, res.y), 1.0),
		"Frisches Becken ist voll (100 %)")
	var line_full := world_state.waterline_px(res.x, res.y)
	_check(is_equal_approx(line_full, float(top_tile.y * 16)),
		"Wasserspiegel startet an der Oberkante des Beckens")

	# --- 4) Pegel sinkt VON OBEN NACH UNTEN ---------------------------------
	world_state.debug_set_fill(res.x, res.y, 0.5)
	var line_half := world_state.waterline_px(res.x, res.y)
	_check(is_equal_approx(world_state.fill_fraction(res.x, res.y), 0.5)
		and line_half > line_full,
		"Halbes Volumen -> Pegel wandert nach unten")
	var level_row := int(line_half / 16.0)
	var dry_n := 0
	var wet_n := 0
	var ordered := true
	for tv in tiles:
		var t: Vector2i = tv as Vector2i
		var dry := world_state.is_dry(t.x, t.y)
		if dry:
			dry_n += 1
			if t.y >= level_row:
				ordered = false
		else:
			wet_n += 1
			if t.y < level_row:
				ordered = false
	_check(dry_n > 0 and wet_n > 0 and ordered,
		"Trocken ausschliesslich OBEN (%d trocken / %d nass)" % [dry_n, wet_n])
	var cap := gen.reservoir_capacity_at(res.x, res.y)
	_check(world_state.remaining_at(bottom_tile.x, bottom_tile.y) < cap,
		"Alle Tiles teilen sich EIN Volumen (auch das unterste)")

	# Verbrauch an EINEM Tile trocknet ANDERE Tiles mit aus.
	var dry_before := world_state.dry_count()
	# Genug entnehmen, damit der Pegel mindestens eine ganze Tile-Zeile faellt.
	var needed := float(tiles.size()) * WorldState.PER_TILE_VOLUME * 0.30
	var taken := world_state.consume(bottom_tile.x, bottom_tile.y, needed)
	_check(taken > 0.0
		and world_state.fill_fraction(res.x, res.y) < 0.5
		and world_state.dry_count() > dry_before,
		"Entnahme am unteren Tile laesst OBEN weitere Tiles trocknen")

	# Langsame Versickerung + Regen-Auffuellung.
	var v0 := world_state.group_volume(gid)
	world_state.tick_passive(2.0)
	var v1 := world_state.group_volume(gid)
	_check(v1 < v0, "Langsame natuerliche Versickerung (%.1f -> %.1f)" % [v0, v1])
	world_state.refill(2.0)
	_check(world_state.group_volume(gid) > v1, "Regen fuellt das Becken wieder auf")

	# --- 5) Sichtbare Umschaltung + Save/Load v3 -----------------------------
	world_state.debug_set_fill(res.x, res.y, 0.35)
	chunk_manager.refresh_water_visuals()
	await get_tree().process_frame
	var dry_atlas := -1
	var wet_atlas := -1
	for tv in tiles:
		var t: Vector2i = tv as Vector2i
		var ci := int(floor(float(t.x) / float(WorldGenerator.CHUNK_TILES_X)))
		var c := chunk_manager.get_chunk(ci)
		if c == null:
			continue
		var lx := t.x - ci * WorldGenerator.CHUNK_TILES_X
		var coords := c.tile_layer.get_cell_atlas_coords(Vector2i(lx, t.y))
		if world_state.is_dry(t.x, t.y) and dry_atlas < 0:
			dry_atlas = coords.x
		if not world_state.is_dry(t.x, t.y) and wet_atlas < 0:
			wet_atlas = coords.x
	_check(dry_atlas == WorldGenerator.SLOT_DRY_WATER
		and wet_atlas == WorldGenerator.SLOT_WATER,
		"Trocken = helles Tile 16, nass = blaues Tile 11")
	_check(chunk0.contours != null, "Weiche Konturen werden nach Pegel-Wechsel neu gezeichnet")

	var f_before := world_state.fill_fraction(res.x, res.y)
	_check(save_manager.save_game(), "Speichern (Format v3 mit Becken-Volumen)")
	world_state.reset()
	_check(save_manager.load_game(), "Laden (Format v3)")
	var f_after := world_state.fill_fraction(res.x, res.y)
	_check(absf(f_before - f_after) < 0.02,
		"Pegel aus Savegame wiederhergestellt (%.0f%% -> %.0f%%)" % [
			f_before * 100.0, f_after * 100.0])

	# --- 6) Regression -------------------------------------------------------
	camera.teleport_to(Vector2(4300.0, 300.0))
	chunk_manager._refresh()
	await get_tree().process_frame
	_check(chunk_manager.loaded_chunk_count() == 5, "Weiterhin 5 aktive Chunks")
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0
		and String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus",
		"Nearest + Forward+ weiterhin aktiv")
	Global.locale = "en"
	var en_ok := tr("SOIL_CAVE") == "Cave" and tr("HUD_ACORN_TIP").begins_with("Pick up")
	Global.locale = "de"
	_check(en_ok, "DE/EN weiterhin aktiv")

	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty() else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
