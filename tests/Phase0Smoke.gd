extends Node
## Headless-Smoke-Test fuer PHASE 0 (kein Addon, kein Testframework):
##   godot --headless --path . -- --phase0-smoke
## Prueft: Determinismus, 5 Chunks beim Start, Nachladen ueber >=5 Chunks,
## Boden-Schichten und fehlerfreien Chunk-Wechsel.

var chunk_manager: ChunkManager
var camera: CameraController


func setup(p_chunk_manager: ChunkManager, p_camera: CameraController) -> void:
	chunk_manager = p_chunk_manager
	camera = p_camera


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("[SMOKE] === PHASE 0 ===")

	# 1) Gleiche Seed => gleiche Welt
	var g1 := WorldGenerator.new(Global.world_seed)
	var g2 := WorldGenerator.new(Global.world_seed)
	var seed_ok := true
	for x in [0.0, 137.0, 2048.0, 12345.0, -8000.0]:
		if g1.height_at(x) != g2.height_at(x):
			seed_ok = false
		var tx := int(x / float(WorldGenerator.TILE_SIZE))
		var ty := g1.surface_tile_y_at(x) + 10
		if (g1.atlas_slot_at(tx, ty) != g2.atlas_slot_at(tx, ty)
				or g1.alternative_at(tx, ty) != g2.alternative_at(tx, ty)):
			seed_ok = false
	if str(g1.decorations_for_chunk(0)) != str(g2.decorations_for_chunk(0)):
		seed_ok = false
	print("[SMOKE] deterministische Hoehen/Materialien/Deko: %s" % ("OK" if seed_ok else "FEHLER"))

	# 1b) Projekt-Settings gemaess Master-Prompt
	var settings_ok := (
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0
		and String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus"
		and int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080
		and String(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items"
	)
	print("[SMOKE] Settings Nearest/Forward+/1920x1080/canvas_items: %s" % (
		"OK" if settings_ok else "FEHLER"))

	# 2) Infinite Chunks: Kamera ueber 5+ Chunks fahren
	var chunk_ok := true
	for x in [0.0, 2100.0, 4300.0, 8600.0, -2200.0, -6500.0, 0.0]:
		camera.teleport_to(Vector2(x, 300.0))
		chunk_manager._refresh()
		await get_tree().process_frame
		var count := chunk_manager.loaded_chunk_count()
		print("[SMOKE] x=%7.0f  chunks=%d  idx=%s" % [
			x, count, str(chunk_manager.loaded_chunk_indices())])
		if count != 5:
			chunk_ok = false

	# 3) Boden-Schichtung
	var top := g1.surface_tile_y_at(0.0)
	var layers: Array[String] = []
	for d in [0, 1, 5, 20, 60]:
		layers.append(String(WorldGenerator.SoilKind.keys()[g1.material_at(0, top + d)]))
	print("[SMOKE] Schichten (Tiefe 0/1/5/20/60 Tiles): %s" % ", ".join(layers))

	var ok := seed_ok and chunk_ok and settings_ok
	print("[SMOKE] Ergebnis: %s" % ("OK" if ok else "FEHLER"))
	get_tree().quit(0 if ok else 1)
