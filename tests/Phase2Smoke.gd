extends Node
## Headless-Smoke-Test fuer PHASE 2:
##   godot --headless --path . -- --phase2-smoke
## Prueft Hoehlen, endliche Reservoirs, Bodenhärte/Kosten, echte Wurzel-Segmente
## mit RootTip-Hierarchie, Ghost-Preview, Austrocknen (optisch heller),
## Save/Load v2, 5 Chunks und DE/EN. PHASE 0/1 Regression separat.

var interaction: InteractionController
var growth: GrowthSystem
var water: WaterSystem
var save_manager: SaveManager
var chunk_manager: ChunkManager
var camera: CameraController
var world_state: WorldState
var ghost: GhostPreview

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_save: SaveManager, p_chunks: ChunkManager,
		p_camera: CameraController, p_state: WorldState,
		p_ghost: GhostPreview) -> void:
	interaction = p_interaction
	growth = p_growth
	water = p_water
	save_manager = p_save
	chunk_manager = p_chunks
	camera = p_camera
	world_state = p_state
	ghost = p_ghost


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-52s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	growth.set_process(false)
	water.set_process(false)
	print("[SMOKE] === PHASE 2 ===")
	var gen := chunk_manager.generator
	var top := gen.surface_tile_y_at(0.0)

	# 1) Determinismus der neuen Welt-Features
	var twin := WorldGenerator.new(Global.world_seed)
	var deterministic := true
	for gx in [-12, 0, 20, 77, 130]:
		for ty in [top + 6, top + 14, top + 25]:
			if (gen.cave_at(gx, ty) != twin.cave_at(gx, ty)
					or gen.reservoir_at(gx, ty) != twin.reservoir_at(gx, ty)
					or gen.atlas_slot_at(gx, ty) != twin.atlas_slot_at(gx, ty)):
				deterministic = false
	_check(deterministic, "Hoehlen/Reservoirs deterministisch pro Seed")

	# 2) Hoehlen + garantiertes Starter-Reservoir
	var caves := 0
	# REVISION 2: Hoehlen sind ~50 % seltener -> groesseres Fenster noetig.
	for gx in range(-48, 49):
		for ty in range(top + 5, top + 45):
			if gen.cave_at(gx, ty):
				caves += 1
	_check(caves > 0, "Hoehlen-Tiles in Chunk 0 vorhanden (%d)" % caves)
	_check(gen.reservoir_at(0, top + 10)
		and gen.material_at(0, top + 10) == WorldGenerator.SoilKind.WATER,
		"Starter-Reservoir unter dem Keimling (Tiefe 10)")

	# 3) Hoehlen sind Hohlraeume (keine Kollision)
	var source := chunk_manager.tile_set.get_source(0) as TileSetAtlasSource
	var cave_data := source.get_tile_data(Vector2i(WorldGenerator.SLOT_CAVE, 0), 0)
	_check(cave_data.get_collision_polygons_count(0) == 0,
		"Hoehlen-Tile ohne Kollision (Hohlraum)")

	# 4) Kosten nach Bodenhärte
	_check(is_equal_approx(GrowthCost.for_tile(gen, 0, top + 2), 10.0),
		"Mutterboden = 10 Glucose (Akzeptanzkriterium)")
	_check(GrowthCost.multiplier(WorldGenerator.SoilKind.ROCK)
			> GrowthCost.multiplier(WorldGenerator.SoilKind.CLAY)
		and GrowthCost.multiplier(WorldGenerator.SoilKind.CLAY)
			> GrowthCost.multiplier(WorldGenerator.SoilKind.TOPSOIL)
		and GrowthCost.multiplier(WorldGenerator.SoilKind.TOPSOIL)
			> GrowthCost.multiplier(WorldGenerator.SoilKind.CAVE),
		"Fels > Lehm > Mutterboden > Hoehle (Kosten)")

	# 5) Keimling mit echten Wurzel-Segmenten + RootTip-Knoten
	interaction.debug_plant_twice()
	var t: BaseTree = interaction.selected_tree
	_check(t != null and t.root_segments.size() == 1
		and t.root_segments[0].grid == Vector2i.ZERO,
		"Keimling: 1 RootSegment auf (0,0)")
	_check(t.root_segments[0].get_node_or_null("RootTip") != null,
		"Hierarchie Tree -> Roots -> RootSegment -> RootTip")

	# 6) Klick auf Wurzel -> laenger, kostet bodenabhaengige Glucose
	t.glucose = 100.0
	var before := t.root_count
	var cost := GrowthCost.for_root(t, gen)
	var ok_click := interaction.manual_root_growth(t, t.root_segments[0])
	_check(ok_click and t.root_count > before
		and is_equal_approx(t.glucose, 100.0 - cost),
		"Wurzelklick: laenger, −%.0f Glucose (Boden)" % cost)
	_check(t.deepest_tip() != null
		and t.deepest_tip().grid.y > t.root_segments[0].grid.y,
		"Wurzel waechst in Erd-Richtung (+y)")

	# 7) Ghost-Preview
	Global.auto_mode = false
	interaction.debug_show_ghost()
	_check(ghost != null and ghost.visible, "Ghost-Preview sichtbar (MANUELL)")
	var ghost_target := t.propose_next_tile(t.deepest_tip())
	_check(ghost_target != BaseTree.INVALID_TILE,
		"Ghost zeigt naechstes freies Erd-Tile")

	# 8) Pfahlwurzel erreicht das Reservoir
	interaction.debug_grow_roots(16)
	var contact := false
	for s in t.root_segments:
		var gt: Vector2i = s.global_tile()
		if gen.reservoir_at(gt.x, gt.y):
			contact = true
	_check(contact, "Pfahlwurzel beruehrt Reservoir (%d Segmente)" % t.root_segments.size())

	# 9) Schnelles Wasser + endliche Kapazitaet
	var res := Vector2i(int(floor(t.global_position.x / 16.0)),
		int(floor(t.global_position.y / 16.0)) + 10)
	var cap := gen.reservoir_capacity_at(res.x, res.y)
	var rem0 := world_state.remaining_at(res.x, res.y)
	t.water = 20.0
	water.tick(2.0)
	var gain := t.water - 20.0
	var normal := t.species.base_water_gain * float(t.root_count) * 2.0
	_check(gain > normal + 1.0,
		"Reservoir schneller als Boden (%.1f > %.1f / 2s)" % [gain, normal])
	_check(world_state.remaining_at(res.x, res.y) < rem0,
		"Kapazitaet nimmt ab (%.0f -> %.0f von %.0f)" % [
			rem0, world_state.remaining_at(res.x, res.y), cap])

	# 10) Austrocknen + optisch helleres Tile
	world_state.debug_drain(res.x, res.y)
	_check(world_state.is_dry(res.x, res.y), "Reservoir ausgetrocknet")
	var chunk := chunk_manager.get_chunk(0)
	var atlas := chunk.tile_layer.get_cell_atlas_coords(Vector2i(res.x, res.y))
	_check(atlas.x == WorldGenerator.SLOT_DRY_WATER,
		"Ausgetrocknet = heller Atlas-Slot 16")

	# 11) Save/Load v2: Wurzel-Segmente + Trockenzustand
	var roots_before := t.root_segments.size()
	_check(save_manager.save_game(), "Speichern (Format v2)")
	interaction.clear_trees()
	world_state.reset()
	_check(save_manager.load_game(), "Laden (Format v2)")
	_check(world_state.is_dry(res.x, res.y),
		"Trockenzustand aus Savegame wiederhergestellt")
	var restored := get_tree().get_nodes_in_group("trees")
	_check(restored.size() == 1
		and restored[0].root_segments.size() == roots_before
		and restored[0].deepest_tip() != null,
		"Wurzel-Segmente + Tips aus Savegame")

	# 12) Regression: 5 Chunks, Settings, DE/EN
	camera.teleport_to(Vector2(4300.0, 300.0))
	chunk_manager._refresh()
	await get_tree().process_frame
	_check(chunk_manager.loaded_chunk_count() == 5, "5 Chunks nach Pan auf x=4300")
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0
		and String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus",
		"Nearest + Forward+ weiterhin aktiv")
	Global.locale = "en"
	var en_ok := tr("SOIL_CAVE") == "Cave" and tr("MSG_RESERVOIR_DRY").begins_with("A water")
	Global.locale = "de"
	_check(en_ok and tr("SOIL_TOPSOIL") == "Mutterboden",
		"DE/EN: neue PHASE-2-Texte")

	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty() else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
