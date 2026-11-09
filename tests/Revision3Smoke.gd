extends Node
## REVISION 3 (vor PHASE 4): drei gemeldete Punkte als headless Smoke-Test.
##   1) Wasserpegel sinkt/steigt STUFENLOS (kein 16px-Ruckler mehr).
##   2) Im Winter ziehen Bäume KEIN Wasser aus den Reservoirs.
##   3) Regen fällt bis zur Geländeoberfläche und spritzt dort auf.
##
##   godot --headless --path . -- --rev3-smoke

var interaction: InteractionController
var water: WaterSystem
var chunk_manager: ChunkManager
var camera: CameraController
var world_state: WorldState
var time_manager: TimeManager
var rain: RainEffect

var _failures: Array[String] = []
var _volume_signals := 0
var _level_signals := 0


func setup(p_interaction: InteractionController, p_water: WaterSystem,
		p_chunks: ChunkManager, p_camera: CameraController,
		p_state: WorldState, p_time: TimeManager,
		p_rain: RainEffect) -> void:
	interaction = p_interaction
	water = p_water
	chunk_manager = p_chunks
	camera = p_camera
	world_state = p_state
	time_manager = p_time
	rain = p_rain


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-62s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.reservoir_volume_changed.connect(func(): _volume_signals += 1)
	EventBus.reservoir_level_changed.connect(func(): _level_signals += 1)
	run()


func run() -> void:
	print("[SMOKE] === REVISION 3 (vor PHASE 4) ===")
	water.set_process(false)
	time_manager.set_process(false)
	rain.set_process(false)
	Global.auto_mode = false

	var gen := chunk_manager.generator
	var ty := gen.surface_tile_y_at(0.0) + 10
	var gid := world_state.group_id_for(0, ty)
	_check(not gid.is_empty(), "Starter-Becken gefunden")

	# --- 1) Stufenloser Pegel ------------------------------------------------
	var tiles: Array = world_state.group_tiles(gid)
	var top_y := (tiles[0] as Vector2i).y
	world_state.debug_set_fill(0, ty, 1.0)
	var line_full := world_state.waterline_px(0, ty)
	_check(is_equal_approx(line_full, float(top_y * 16)),
		"Voll: Pegel exakt an der Becken-Oberkante (REV2-Regression)")

	# 0.5 %-Schritte: im echten Spiel sind es ~0.017 %/Frame (1 %/s bei 60
	# FPS), die Abtastung hier ist also bereits ~30x groeber als die Realitaet.
	var lines: Array[float] = []
	var fractional := 0
	for i in 200:
		world_state.debug_set_fill(0, ty, 1.0 - float(i + 1) * 0.005)
		var l := world_state.waterline_px(0, ty)
		lines.append(l)
		if absf(l / 16.0 - roundf(l / 16.0)) > 0.001:
			fractional += 1
	var max_step := 0.0
	var monotonic := true
	for i in range(1, lines.size()):
		var step := lines[i] - lines[i - 1]
		max_step = maxf(max_step, absf(step))
		if step < -0.0001:
			monotonic = false
	_check(monotonic and lines[lines.size() - 1] > line_full,
		"Pegel wandert beim Entleeren gleichmaessig nach unten")
	_check(max_step < 16.0,
		"KEIN 16px-Sprung: groesster Schritt %.2f px" % max_step)
	_check(fractional >= 150,
		"Zwischenwerte INNERHALB einer Tile-Zeile (%d/200 fraktional)" % fractional)

	# Steigender Pegel (Regen) ist genauso stufenlos.
	var up: Array[float] = []
	for i in 200:
		world_state.debug_set_fill(0, ty, float(i + 1) * 0.005)
		up.append(world_state.waterline_px(0, ty))
	var max_up := 0.0
	var mono_up := true
	for i in range(1, up.size()):
		var step := up[i] - up[i - 1]
		max_up = maxf(max_up, absf(step))
		if step > 0.0001:
			mono_up = false
	_check(mono_up and max_up < 16.0,
		"Auffuellen ebenfalls stufenlos (max. %.2f px/Schritt)" % max_up)

	# Feines Redraw vs. teure Tile-Umschaltung: eine kleine Aenderung darf
	# NUR das Konturen-Signal ausloesen, nicht den 16px-Zeilenwechsel.
	world_state.debug_set_fill(0, ty, 0.5)
	_volume_signals = 0
	_level_signals = 0
	world_state.consume(0, ty, 1.0)
	_check(_volume_signals > 0 and _level_signals == 0,
		"Kleine Aenderung: Kontur-Redraw, KEIN Tile-Slot-Ruckler")

	# --- 2) Winter: keine Reservoir-Entnahme ---------------------------------
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.0)
	interaction.debug_plant_twice()
	interaction.debug_grow_roots(16)
	var tree: BaseTree = interaction.selected_tree
	var contact := Vector2i(-9999, -9999)
	if tree != null:
		for seg in tree.root_segments:
			var gt: Vector2i = seg.global_tile()
			if gen.reservoir_at(gt.x, gt.y):
				contact = gt
				break
	_check(contact.x > -9000, "Pfahlwurzel beruehrt ein Reservoir")
	var winter_gid := world_state.group_id_for(contact.x, contact.y)
	if winter_gid.is_empty():
		winter_gid = gid
	world_state.debug_set_fill(contact.x, contact.y, 0.80)

	time_manager.debug_set_season(TimeManager.Season.WINTER, 2, 0.3)
	var v0 := world_state.group_volume(winter_gid)
	water.tick(5.0)
	var v1 := world_state.group_volume(winter_gid)
	_check(is_equal_approx(v0, v1) and is_equal_approx(water.last_reservoir_rate, 0.0),
		"WINTER: Baum entnimmt KEIN Reservoir-Wasser (%.1f -> %.1f)" % [v0, v1])

	time_manager.debug_set_season(TimeManager.Season.SPRING, 2, 0.3)
	var v2 := world_state.group_volume(winter_gid)
	water.tick(5.0)
	var v3 := world_state.group_volume(winter_gid)
	_check(v3 < v2 and water.last_reservoir_rate > 0.0,
		"FRUEHLING: Entnahme wieder aktiv (%.1f -> %.1f)" % [v2, v3])

	# --- 3) Regen trifft die Oberflaeche + Spritzer --------------------------
	var expected_surface := gen.height_smooth_at(0.0)
	_check(is_equal_approx(rain.debug_surface_y(0.0), expected_surface),
		"Regen-Aufprallhoehe = echte Gelaendelinie (%.1f px)" % expected_surface)
	water.force_rain(60.0)
	_check(rain.raining, "rain_started aktiviert den Regen-Effekt")
	var before := rain.debug_splash_count()
	for _i in 8:
		rain.debug_step(0.25)
	var splashes := rain.debug_splash_count() - before
	_check(splashes > 20, "Aufprall erzeugt viele Spritzer (%d)" % splashes)
	_check(rain.debug_drops_below_surface() == 0,
		"Kein Tropfen faellt durch den Boden hindurch")
	_check(rain.debug_active_splashes() > 0,
		"Spritzer / Rippen sind sichtbar aktiv")

	# --- 4) Regression -------------------------------------------------------
	_check(chunk_manager.loaded_chunk_count() == 5, "Weiterhin 5 aktive Chunks")
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"Nearest-Pixel-Filter weiterhin aktiv")
	world_state.debug_set_fill(0, ty, 0.5)
	var level_row := int(world_state.waterline_px(0, ty) / 16.0)
	var ordered := true
	for tv in tiles:
		var t: Vector2i = tv as Vector2i
		if world_state.is_dry(t.x, t.y) and t.y >= level_row:
			ordered = false
		if not world_state.is_dry(t.x, t.y) and t.y < level_row:
			ordered = false
	_check(ordered, "Trocken weiterhin ausschliesslich OBEN (REV2-Regression)")
	Global.locale = "en"
	var en_ok := tr("SEASON_WINTER") == "Winter" \
		and tr("MSG_WINTER_WATER").contains("no water")
	Global.locale = "de"
	_check(en_ok and tr("SEASON_SPRING") == "Frühling"
		and tr("MSG_WINTER_WATER").contains("kein Wasser"),
		"DE/EN + neuer Winter-/Regen-Hinweis aktiv")

	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty() else "FEHLER (%d)" % _failures.size()))
	for f in _failures:
		print("[SMOKE]   -> %s" % f)
	get_tree().quit(0 if _failures.is_empty() else 1)
