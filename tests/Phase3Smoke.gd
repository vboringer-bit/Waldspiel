extends Node
## Headless-Smoke-Test fuer PHASE 3 (Zeit & Reproduktion) inklusive der zwei
## Korrekturen, die der Nutzer VOR PHASE 3 gemeldet hat:
##   1) Wasserreservoirs muessen sich bei Regen SICHTBAR wieder auffuellen.
##   2) Der Vogel muss weiterfliegen, bis er AUS DEM BILD heraus ist.
##
##   godot --headless --path . -- --p3-smoke
##
## Zusaetzlich: Jahreszeiten (15 min/Jahr), x1/x3/x10 + Pause, Winterruhe,
## Schwierigkeitsgrade, Samen finden/flach vergraben, Herbst-Eichelfall,
## Savegame v4 und alle P0/P1/P2/REV1/REV2-Regressionen.

var interaction: InteractionController
var growth: GrowthSystem
var water: WaterSystem
var save_manager: SaveManager
var chunk_manager: ChunkManager
var camera: CameraController
var world_state: WorldState
var time_manager: TimeManager
var season_system: SeasonSystem
var bird_layer: BirdEvent
var hud: HUD
var start_menu: StartMenu

var _failures: Array[String] = []
var _drops := 0
var _collected_signals := 0


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_save: SaveManager, p_chunks: ChunkManager,
		p_camera: CameraController, p_state: WorldState,
		p_time: TimeManager, p_season: SeasonSystem, p_bird: BirdEvent,
		p_hud: HUD, p_menu: StartMenu) -> void:
	interaction = p_interaction
	growth = p_growth
	water = p_water
	save_manager = p_save
	chunk_manager = p_chunks
	camera = p_camera
	world_state = p_state
	time_manager = p_time
	season_system = p_season
	bird_layer = p_bird
	hud = p_hud
	start_menu = p_menu


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-58s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.acorn_dropped.connect(func(_p): _drops += 1)
	EventBus.seed_collected.connect(func(_s): _collected_signals += 1)
	run()


func run() -> void:
	print("[SMOKE] === PHASE 3 (Zeit & Reproduktion) ===")
	# Hintergrund-Prozesse anhalten, damit die Zahlen deterministisch sind.
	water.set_process(false)
	growth.set_process(false)
	time_manager.set_process(false)
	season_system.set_process(false)
	Global.auto_mode = false

	var gen := chunk_manager.generator
	var ty := gen.surface_tile_y_at(0.0) + 10

	# --- 1) BUGFIX: Regen fuellt Reservoirs sichtbar auf ---------------------
	world_state.debug_set_fill(0, ty, 0.20)
	var f0 := world_state.fill_fraction(0, ty)
	var line0 := world_state.waterline_px(0, ty)
	water.force_rain(60.0)
	water.tick(20.0)
	var f1 := world_state.fill_fraction(0, ty)
	var line1 := world_state.waterline_px(0, ty)
	_check(f1 > f0 + 0.05,
		"Regen fuellt Becken sichtbar auf (%.0f%% -> %.0f%%)" % [f0 * 100.0, f1 * 100.0])
	_check(line1 < line0, "Wasserspiegel steigt wieder (Pegelzeile %d -> %d)" % [int(line0 / 16), int(line1 / 16)])
	world_state.consume(0, ty, 200.0)
	var f2 := world_state.fill_fraction(0, ty)
	water.tick(5.0)
	var f3 := world_state.fill_fraction(0, ty)
	_check(f3 > f2, "Auffuellung ueberwiegt Wurzelentnahme (%.1f%% -> %.1f%%)" % [f2 * 100.0, f3 * 100.0])
	_check(tr("MSG_RAIN_REFILL").contains("fullen") or tr("MSG_RAIN_REFILL").contains("füllen"),
		"Regen-Feedback nennt das Auffuellen")
	water.raining = false

	# --- 2) BUGFIX: Vogel fliegt AUS DEM BILD heraus ------------------------
	bird_layer.spawn_bird(Vector2(320.0, 320.0), false)
	var left := bird_layer.screen_left_world_x()
	var exit_x := bird_layer.exit_world_x(Vector2(320.0, 320.0))
	_check(exit_x < left - 100.0,
		"Abflugziel liegt links ausserhalb (%.0f < %.0f)" % [exit_x, left])
	_check(bird_layer.last_flight_duration >= 1.3,
		"Flugdauer aus Distanz berechnet (%.2f s)" % bird_layer.last_flight_duration)
	bird_layer.debug_bird_progress(1.0)
	var sp := bird_layer.debug_active_sprite()
	_check(sp != null and sp.position.x < left,
		"Vogel am Ende tatsaechlich ausserhalb des Bildes")
	bird_layer.debug_cleanup()

	# --- 3) Jahreszeiten / Zeitspulen / Pause --------------------------------
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.0)
	interaction.debug_plant_twice()
	var trees := get_tree().get_nodes_in_group("trees")
	_check(trees.size() == 1, "Keimling vorhanden (Jahreszeiten-Test)")
	var tree: BaseTree = trees[0]
	time_manager.set_time_scale(10.0)
	_check(is_equal_approx(time_manager.time_scale, 10.0), "Zeitspule x10 aktiv")
	_check(is_equal_approx(time_manager.scaled_delta(1.0), 10.0),
		"scaled_delta(1s) = 10s bei x10")
	time_manager.toggle_pause()
	_check(is_equal_approx(time_manager.scaled_delta(1.0), 0.0), "Pause stoppt Simulation")
	time_manager.toggle_pause()
	time_manager.set_time_scale(1.0)
	_check(is_equal_approx(time_manager.year_length_seconds, 900.0),
		"1 Spiel-Jahr = 15 Echtzeit-Minuten")

	time_manager.debug_set_season(TimeManager.Season.WINTER, 3, 0.4)
	_check(tree.is_bare(), "Winter: Laubbaum ist kahl")
	_check(is_equal_approx(time_manager.growth_factor(), 0.0),
		"Winter: Wachstumsfaktor = 0")
	var g0 := tree.glucose
	growth.tick(5.0)
	_check(is_equal_approx(tree.glucose, g0), "Winter: keine Fotosynthese")
	_check(not interaction.manual_growth(tree, tree.global_position + Vector2(0.0, 10.0)),
		"Winter: manuelles Wachstum blockiert")
	time_manager.debug_set_season(TimeManager.Season.SPRING, 3, 0.1)
	_check(not tree.is_bare(), "Fruehling: Baum wieder belaubt")
	growth.tick(5.0)
	_check(tree.glucose > g0, "Fruehling: Wachstumsboost / Glucose steigt")
	var y0 := time_manager.year
	time_manager.debug_advance(time_manager.year_length_seconds + 1.0)
	_check(time_manager.year == y0 + 1, "Nach einem Jahr: Zaehler + 1")
	_check(time_manager.get_label().contains(tr("HUD_YEAR"))
		and time_manager.get_label().contains(time_manager.season_name()),
		"HUD-Zeitlabel: lokalisiertes Jahr + Jahreszeit")

	# --- 4) Schwierigkeitsgrade ----------------------------------------------
	var cost_normal := GrowthCost.for_tile(gen, 0, gen.surface_tile_y_at(0.0) + 2)
	Global.set_difficulty(0)
	var cost_easy := GrowthCost.for_tile(gen, 0, gen.surface_tile_y_at(0.0) + 2,
		Global.difficulty_factor("growth_cost"))
	var dens_easy := season_system.density_threshold()
	_check(cost_easy < cost_normal, "LEICHT: guenstigeres Wachstum")
	_check(Global.difficulty_factor("seed_density") > 1.0,
		"LEICHT: mehr Samen")
	Global.set_difficulty(2)
	_check(Global.difficulty_factor("growth_cost") > 1.0,
		"SCHWER: teureres Wachstum")
	_check(season_system.density_threshold() < dens_easy,
		"SCHWER: weniger Samen als LEICHT")
	_check(Global.difficulty_factor("rain_refill") < 1.0,
		"SCHWER: langsamere Regen-Auffuellung")
	_check(Global.difficulty_toggle("ph") and Global.difficulty_toggle("nutrients")
		and Global.difficulty_toggle("mycorrhiza"),
		"SCHWER: Schalter fuer pH / N-P-K / Mykorrhiza gesetzt")
	_check(is_equal_approx(Global.difficulty_factor("disaster_rate"), 2.0),
		"SCHWER: haeufige Katastrophen vorbereitet")
	Global.set_difficulty(0)
	_check(not Global.difficulty_toggle("disasters")
		and not Global.difficulty_toggle("ph")
		and is_equal_approx(Global.difficulty_factor("disaster_rate"), 0.0),
		"LEICHT: keine Katastrophen, kein pH")
	Global.set_difficulty(1)
	_check(Global.difficulty_toggle("disasters")
		and not Global.difficulty_toggle("nutrients"),
		"NORMAL: seltene Stuerme, noch keine N-P-K-Simulation")
	_check(is_equal_approx(SeasonSystem.MATURE_AGE_YEARS, 3.0),
		"Natuerliche Vermehrung ab ~3 Spiel-Jahren")
	_check(season_system.debug_maturity(1.0) < season_system.debug_maturity(3.0),
		"Junge Baeume werfen seltener Eicheln ab")
	start_menu.debug_choose(0)
	_check(int(Global.difficulty) == 0 and not start_menu.is_open(),
		"Startmenue waehlt Schwierigkeit vor Spielstart")
	Global.set_difficulty(1)

	# --- 5) Samen finden / flach vergraben -----------------------------------
	interaction.set_seed_count(2)
	var gid := season_system.debug_spawn_seed_at(220.0, false)
	var gp := season_system.debug_seed_position(gid)
	var inv0 := interaction.get_seed_count()
	var col0 := season_system.debug_collected_count()
	var hit := season_system.collect_at(gp + Vector2(0.0, -8.0))
	_check(hit and interaction.get_seed_count() == inv0 + 1,
		"Boden-Eichel anklicken -> +1 Inventar")
	_check(season_system.debug_collected_count() == col0 + 1
		and _collected_signals > 0, "seed_collected-Signal + eingesammelt gemerkt")

	var bid := season_system.debug_spawn_seed_at(0.0, true)
	var bp := season_system.debug_seed_position(bid)
	_check(season_system.has_buried_at(bp), "Vergrabener Huegel erkannt (Rechtsklick-Info)")
	var col1 := season_system.debug_collected_count()
	season_system.debug_force_buried_collection()
	_check(not season_system.debug_is_collected(bid),
		"Vergrabene Eichel ohne Wurzel NICHT erreichbar")
	interaction.debug_grow_roots(3)
	season_system.debug_force_buried_collection()
	_check(season_system.debug_is_collected(bid)
		and season_system.debug_collected_count() > col1,
		"Wurzel legt vergrabene Eichel frei")

	# --- 6) Herbst-Eichelfall -------------------------------------------------
	time_manager.debug_set_season(TimeManager.Season.AUTUMN, 4, 0.3)
	season_system.debug_no_germination = true
	var ground_before := season_system.debug_ground_seed_count()
	var drops_before := _drops
	season_system.debug_drop_acorns(5, true)
	_check(_drops - drops_before == 5, "Herbst: 5 Eicheln fallen unter der Krone")
	_check(season_system.debug_ground_seed_count() >= ground_before + 5,
		"Gefallene Eicheln bleiben einsammelbar liegen")
	_check(tree.leaves_count > 0, "Herbst: Blaetter vorhanden (Faerbung moeglich)")

	# --- 7) Savegame v4 ------------------------------------------------------
	Global.set_difficulty(2)
	time_manager.set_time_scale(10.0)
	time_manager.debug_set_season(TimeManager.Season.AUTUMN, 7, 0.4)
	var collected_before := season_system.debug_collected_count()
	_check(save_manager.save_game(), "Speichern (Format v4)")
	var f := FileAccess.open("user://savegame.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	# PHASE 4 hebt das Format auf v5 (Skill-Fortschritt); >= 4 bleibt gueltig.
	var ok_v4 := parsed is Dictionary and int((parsed as Dictionary).get("version", 0)) >= 4
	_check(ok_v4, "Savegame version >= 4 (PHASE 4: v5)")
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_check(d.has("difficulty") and d.has("time") and d.has("seeds"),
			"v4 speichert Schwierigkeit / Zeit / Samen")
	Global.set_difficulty(0)
	time_manager.set_time_scale(1.0)
	time_manager.debug_set_season(TimeManager.Season.WINTER, 1, 0.0)
	_check(save_manager.load_game(), "Laden (Format v4)")
	_check(int(Global.difficulty) == 2, "Schwierigkeit aus Savegame wiederhergestellt")
	_check(is_equal_approx(time_manager.time_scale, 10.0), "Zeitskala aus Savegame")
	_check(time_manager.season == TimeManager.Season.AUTUMN, "Jahreszeit aus Savegame")
	_check(season_system.debug_collected_count() == collected_before,
		"Eingesammelte Samen bleiben eingesammelt")

	# --- 8) Regressionen -----------------------------------------------------
	await get_tree().process_frame
	_check(chunk_manager.loaded_chunk_count() == 5, "Weiterhin 5 aktive Chunks")
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"Nearest-Pixel-Filter weiterhin aktiv")
	_check(is_equal_approx(get_tree().root.content_scale_factor, 1.0),
		"Keine Doppelskalierung: HUD bei Vollbild vollstaendig")
	_check(hud.find_child("DifficultyButton", true, false) != null
		and hud.find_child("PauseButton", true, false) != null,
		"HUD: Schwierigkeits- + Pause-Button vorhanden")
	Global.locale = "en"
	var en_ok := tr("SEASON_WINTER") == "Winter" and tr("MSG_RAIN_REFILL").contains("refilling")
	Global.locale = "de"
	_check(en_ok and tr("SEASON_SPRING") == "Frühling", "DE/EN weiterhin aktiv")
	_check(tr("MSG_WINTER_GROWTH").length() > 10, "Neue PHASE-3-Texte lokalisiert")
	_check(typeof(Global.auto_mode) == TYPE_BOOL, "AUTO/MANUELL Toggle weiterhin intakt")

	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty() else "FEHLER (%d)" % _failures.size()))
	for f_txt in _failures:
		print("[SMOKE]   -> %s" % f_txt)
	get_tree().quit(0 if _failures.is_empty() else 1)
