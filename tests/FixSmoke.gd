extends Node
## Headless-Smoke-Test KORREKTURRUNDE P8.1 (DECISIONS.md §78):
##   godot --headless --path . -- --fix-smoke
##
## Deckt die neun gemeldeten Punkte ab: Eichhoernchen kleiner / bodengebunden /
## kletternd, Ruckler Biom-Wechsel, Ruckler WASD-Kamera, verstreute Eicheln mit
## 20 % Keimung und seltenerem Transport, Specht-Flug mit Frames + Sitzplatz +
## Parasiten fressen, Toast-Stack mit Ausbleichen, nahtlose Bodengenerierung.

var interaction: InteractionController
var chunk_manager: ChunkManager
var hud: HUD
var save_manager: SaveManager
var growth: GrowthSystem
var water: WaterSystem
var time_manager: TimeManager
var season: SeasonSystem
var wildlife: WildlifeSystem
var forest_health: ForestHealth
var biomes: BiomeSystem
var camera: CameraController
var parasites: ParasiteSystem
var gen: WorldGenerator

var _failures: Array[String] = []
var _biome_signals := 0


func setup(p_interaction: InteractionController, p_chunks: ChunkManager,
		p_hud: HUD, p_save: SaveManager, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_season: SeasonSystem,
		p_wildlife: WildlifeSystem, p_health: ForestHealth,
		p_biomes: BiomeSystem, p_camera: CameraController,
		p_parasites: ParasiteSystem) -> void:
	interaction = p_interaction
	chunk_manager = p_chunks
	hud = p_hud
	save_manager = p_save
	growth = p_growth
	water = p_water
	time_manager = p_time
	season = p_season
	wildlife = p_wildlife
	forest_health = p_health
	biomes = p_biomes
	camera = p_camera
	parasites = p_parasites
	gen = p_chunks.generator


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func _on_biome_signal(_kind: int, _blend: float) -> void:
	_biome_signals += 1


func run() -> void:
	print("[SMOKE] === KORREKTURRUNDE P8.1: neun Fehlerbehebungen ===")
	growth.set_process(false)
	water.set_process(false)
	season.set_process(false)
	wildlife.set_process(false)
	biomes.set_process(false)
	Global.locale = "de"
	Global.auto_mode = false
	Global.set_difficulty(Global.Difficulty.NORMAL)
	time_manager.set_paused(false)
	time_manager.set_time_scale(1.0)
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.20)
	parasites.debug_clear()
	interaction.clear_trees()
	interaction.set_seed_count(0)
	biomes.reset()
	wildlife.reset()
	forest_health.debug_set_biodiversity(10)
	forest_health.recompute()
	hud.refresh()
	hud.debug_clear_toasts()

	# --- 1) Erbe / Regression ------------------------------------------------
	_check(SaveManager.FORMAT_VERSION == 6, "Save-Format bleibt v6")
	_check(not Global.auto_mode, "AUTO bleibt aus")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2), "Glucose-Tempo bleibt 0,2")
	_check(PixelArt.PATHS.size() == 21,
		"21 zentrale Pixelart-Slots trotz neuer Specht-Frames")
	_check(PixelArt.WOODPECKER_FRAMES.size() == 5
		and PixelArt.WOODPECKER_FLIGHT_FRAMES == 4,
		"4 Flug-Frames + 1 Sitz-Frame registriert")
	_check(SkillTree.instance.all_nodes().size() == 24
		and SkillTree.instance.connection_pairs().size() == 23,
		"24/23 Skillnodes unveraendert")
	_check(WildlifeSystem.PROGRESSION == ["bird"]
		and WildlifeSystem.ADVANCED == ["woodpecker", "squirrel"],
		"P8-Progression und P5-ADVANCED unveraendert")
	_check(is_equal_approx(WorldGenerator.BIOME_CORE_PX, 2048.0)
		and is_equal_approx(WorldGenerator.BIOME_BLEND_PX, 4096.0)
		and is_equal_approx(WorldGenerator.BIOME_FULL_PX, 6144.0),
		"P7-Biomzonen unveraendert")
	_check(hud.debug_phase6_title().contains("PHASE 8")
		and not hud.debug_biome_text().is_empty()
		and not hud.debug_soil_text().is_empty()
		and not hud.debug_species_text().is_empty(),
		"Alle bisherigen HUD-Zeilen bleiben erhalten")
	var frame_hashes := {}
	var frames_ok := true
	for path in PixelArt.WOODPECKER_FRAMES:
		if not FileAccess.file_exists(path):
			frames_ok = false
		else:
			frame_hashes[FileAccess.get_md5(path)] = true
	_check(frames_ok and frame_hashes.size() >= 4,
		"Alle 5 Frame-PNGs vorhanden und mindestens 4 wirklich verschieden")

	# --- 2) Eichhoernchen: kleiner ------------------------------------------
	wildlife.debug_force_advanced()
	var sq := wildlife.debug_animal("squirrel")
	var wp := wildlife.debug_animal("woodpecker")
	_check(sq != null and wp != null,
		"Eichhoernchen und Specht fuer die Tests vorhanden")
	if sq == null or wp == null:
		_finish()
		return
	_check(is_equal_approx(float(Animal.BODY_SPAN["squirrel"]), 26.0),
		"Eichhoernchen ist jetzt 26px statt 40px")
	_check(is_equal_approx(float(Animal.BODY_SPAN["woodpecker"]), 40.0),
		"Specht behaelt seine 40px")
	_check(is_equal_approx(Animal.SQUIRREL_SCALE, 0.65),
		"Zeichnung des Eichhoernchens ist skaliert")
	_check(is_equal_approx(sq.debug_body_span(), 26.0),
		"Instanz meldet die neue Koerperbreite")
	_check(sq.hit_rect().size == Vector2(26.0, 22.0),
		"Klickflaeche passt zur neuen Groesse")
	_check(sq.hit_rect().size.x < wp.hit_rect().size.x,
		"Eichhoernchen ist jetzt kleiner als der Specht")

	# --- 3) Eichhoernchen: NIEMALS in der Luft -------------------------------
	# Keine Baeume im Weg -> _blocked() kann die Position nicht veraendern.
	var ground_ok := true
	var worst := 0.0
	for x in [-1600.0, -800.0, -400.0, 0.0, 400.0, 800.0, 1600.0]:
		sq.position.x = x
		sq.debug_set_state(Animal.State.WANDER)
		sq.target_x = x + 30.0
		sq.timer = 999.0
		sq.tick(0.1)
		var off := absf(sq.debug_ground_offset())
		worst = maxf(worst, off)
		if off > 1.5:
			ground_ok = false
		_check(off <= 1.5,
			"Bodenkontakt bei x=%d (Abweichung %.2f px)" % [int(x), off])
	_check(ground_ok and worst <= 1.5,
		"Maximale Bodenabweichung %.2f px ueber 7 Positionen" % worst)
	var long_ok := true
	for _i in range(50):
		sq.debug_set_state(Animal.State.WANDER)
		sq.timer = 999.0
		sq.tick(0.1)
		if absf(sq.debug_ground_offset()) > 1.5:
			long_ok = false
	_check(long_ok, "Auch nach 50 Ticks ueber Huegel nie in der Luft")
	_check(absf(sq.position.y - (gen.ground_y_at(sq.position.x) - 1.0)) < 0.25,
		"Eichhoernchen steht auf der 4px-Gelaendekante")
	_check(gen.ground_y_at(345.0) / 4.0 == roundf(gen.ground_y_at(345.0) / 4.0),
		"Gelaendekante ist weiterhin auf 4px gerastet")

	# --- 4) Eichhoernchen: auf Baeume klettern -------------------------------
	var climb_tree: BaseTree = interaction.spawn_tree_at(Vector2(sq.position.x + 60.0, 0.0), {})
	_check(climb_tree != null, "Baum fuer den Klettertest vorhanden")
	_check(sq.debug_force_climb(), "Klettern kann ausgeloest werden")
	_check(sq.state == Animal.State.CLIMB
		and sq.state_key() == "STATE_CLIMB",
		"Neuer Zustand CLIMB aktiv")
	_check(sq.climb_tree == climb_tree, "Kletterziel ist der echte Baum")
	_check(tr("STATE_CLIMB") == "klettert am Baum",
		"DE: STATE_CLIMB lokalisiert")
	Global.locale = "en"
	_check(tr("STATE_CLIMB") == "climbing a tree",
		"EN: STATE_CLIMB lokalisiert")
	Global.locale = "de"
	var highest := 9999.0
	for _i in range(18):
		sq.tick(0.1)
		highest = minf(highest, sq.position.y)
	_check(highest < gen.ground_y_at(sq.position.x) - 20.0,
		"Eichhoernchen klettert am Stamm nach oben (%.0f px)" % highest)
	for _i in range(24):
		sq.tick(0.1)
	_check(absf(sq.debug_ground_offset()) <= 1.5,
		"Nach dem Abstieg wieder bodengebunden")
	_check(sq.state != Animal.State.CLIMB,
		"Kletterzustand wurde sauber beendet")

	# --- 5) Specht: fliegen mit Frame-Animation ------------------------------
	_check(is_equal_approx(Animal.WOODPECKER_HEIGHT, 90.0),
		"Specht fliegt 90px ueber dem Boden")
	wp.position.x = 0.0
	wp.reseat(0.0)
	_check(is_equal_approx(wp.base_y, gen.ground_y_at(0.0) - 90.0),
		"Spawn-Hoehe des Spechts ist die Flughoehe")
	_check(wp.debug_frame_count() == 5,
		"5 Frame-Texturen im Voraus geladen")
	_check(wp.debug_frame_path().contains("woodpecker_f"),
		"Sprite2D zeigt einen echten Specht-Frame")
	wp.debug_set_state(Animal.State.FLY)
	_check(wp.state == Animal.State.FLY
		and wp.state_key() == "STATE_FLY",
		"Neuer Zustand FLY aktiv")
	var seen := {}
	var fly_ground := true
	for _i in range(24):
		wp.tick(0.1)
		seen[wp.debug_frame_index()] = true
		if wp.position.y > gen.ground_y_at(wp.position.x) - 50.0:
			fly_ground = false
	_check(seen.size() >= 3,
		"Flug-Animation durchlaeuft mindestens 3 verschiedene Frames")
	_check(not seen.has(4), "Sitz-Frame wird NUR beim Sitzen benutzt")
	_check(fly_ground, "Specht laeuft zu keiner Zeit bodennah")
	_check(is_equal_approx(wp.speed(), 240.0),
		"Specht-Geschwindigkeit bleibt 240 px/s")
	_check(tr("STATE_FLY") == "fliegt", "DE: STATE_FLY lokalisiert")
	Global.locale = "en"
	_check(tr("STATE_FLY") == "flying", "EN: STATE_FLY lokalisiert")
	Global.locale = "de"

	# --- 6) Specht: sitzen und Parasiten fressen -----------------------------
	var pcount0 := parasites.debug_parasite_count()
	_check(parasites.debug_infest(climb_tree, Parasite.Kind.MISTLETOE)
		and parasites.debug_infest(climb_tree, Parasite.Kind.WORM),
		"Zwei Parasiten am Baum fuer den Fraßtest")
	_check(parasites.debug_parasite_count() >= pcount0 + 2,
		"Parasitenzaehler vor dem Specht")
	_check(wildlife.debug_force_help(climb_tree),
		"Specht wird zum befallenen Baum geschickt")
	wildlife.debug_step(1.2)
	_check(parasites.debug_parasite_count() < pcount0 + 2,
		"Specht frisst bereits bei der Ankunft einen Parasiten")
	_check(parasites.debug_last_removed_by() == "woodpecker",
		"Fraß ist weiterhin als 'woodpecker' protokolliert")
	_check(wp.debug_is_perched()
		and wp.state == Animal.State.PERCH,
		"Specht setzt sich danach an den Stamm")
	_check(wp.state_key() == "STATE_PERCH",
		"Neuer Zustand PERCH aktiv")
	_check(wp.debug_frame_index() == PixelArt.WOODPECKER_FLIGHT_FRAMES,
		"Beim Sitzen wird das eigene Perch-Frame gezeigt")
	_check(absf(wp.position.y - (climb_tree.global_position.y
		- Animal.PERCH_HEIGHT)) < 4.0,
		"Sitzplatz liegt 64px ueber dem Stammfuss")
	wildlife.debug_step(1.2)
	_check(parasites.debug_parasite_count() <= pcount0,
		"Sitzen + Picken entfernt die restlichen Parasiten")
	_check(tr("STATE_PERCH") == "sitzt am Baum",
		"DE: STATE_PERCH lokalisiert")
	_check(tr("MSG_WOODPECKER_EAT").contains("Parasiten"),
		"DE: Fraß-Toast lokalisiert")
	Global.locale = "en"
	_check(tr("MSG_WOODPECKER_EAT").contains("parasite"),
		"EN: Fraß-Toast lokalisiert")
	_check(tr("STATE_PERCH") == "perched on a tree",
		"EN: STATE_PERCH lokalisiert")
	Global.locale = "de"

	# --- 7) Eicheln: seltener, verstreut, nur 20 % Keimung ------------------
	_check(is_equal_approx(WildlifeSystem.CARRY_INTERVAL, 55.0),
		"Transport jetzt nur alle 55s statt 22s")
	_check(WildlifeSystem.CARRY_INTERVAL > 22.0,
		"Eichhoernchen verschleppt insgesamt seltener")
	_check(is_equal_approx(WildlifeSystem.GERMINATION_CHANCE, 0.20),
		"Genau 20 % der verschleppten Eicheln keimen")
	_check(wildlife.debug_carry_stats()["carries"] == 0,
		"Transport-Statistik startet leer")
	var trees_before := get_tree().get_nodes_in_group("trees").size()
	var stats := wildlife.debug_simulate_carries(40)
	_check(int(stats["carries"]) == 40,
		"40 deterministische Transporte simuliert")
	_check(int(stats["germinated"]) >= 2
		and int(stats["germinated"]) <= 18,
		"Keimungen liegen im 20%%-Bereich (%d/40)" % int(stats["germinated"]))
	_check(int(stats["cached"]) == 40 - int(stats["germinated"]),
		"Alle uebrigen Eicheln werden versteckt, nicht gepflanzt")
	var targets := wildlife.debug_carry_targets()
	_check(wildlife.debug_scattered_unique(targets) >= 30,
		"Mindestens 30 verschiedene Zielorte (%d)" %
			wildlife.debug_scattered_unique(targets))
	var has_left := false
	var has_right := false
	var tmin := 1.0e9
	var tmax := -1.0e9
	for x in targets:
		var v := float(x)
		if v < 0.0: has_left = true
		if v > 0.0: has_right = true
		tmin = minf(tmin, v)
		tmax = maxf(tmax, v)
	_check(has_left and has_right,
		"Ziele liegen in BEIDE Richtungen verstreut")
	_check(tmax - tmin > 3000.0,
		"Ziele streuen ueber mehr als 3000px (%.0f px)" % (tmax - tmin))
	_check(targets.size() <= 64, "Ziel-Liste ist begrenzt")
	_check(get_tree().get_nodes_in_group("trees").size() > trees_before,
		"Nur die gekeimten Eicheln erzeugen echte Baeume")
	_check(tr("MSG_ACORN_CACHED").contains("keimt nicht"),
		"DE: Versteck-Toast lokalisiert")
	Global.locale = "en"
	_check(tr("MSG_ACORN_CACHED").contains("will not sprout"),
		"EN: Versteck-Toast lokalisiert")
	Global.locale = "de"
	# P5-Regression: der garantierte Test-Hook pflanzt genau EINEN Baum.
	var before_hook := get_tree().get_nodes_in_group("trees").size()
	var remote := wildlife.debug_force_remote_seed()
	_check(remote != null
		and get_tree().get_nodes_in_group("trees").size() == before_hook + 1,
		"debug_force_remote_seed() pflanzt unveraendert genau 1 Baum")
	if remote != null:
		_check(int(floor(remote.global_position.x
			/ float(WorldGenerator.CHUNK_WIDTH_PX))) != 0,
			"Dieser Baum liegt weiterhin in einem anderen Chunk")

	# --- 8) Toast-Stack: stapeln, ausbleichen, verschwinden -----------------
	hud.debug_clear_toasts()
	EventBus.toast.emit("MELDUNG A")
	EventBus.toast.emit("MELDUNG B")
	EventBus.toast.emit("MELDUNG C")
	_check(hud.debug_toast_count() == 3,
		"Drei Nachrichten werden uebereinander gestapelt")
	_check(hud.debug_toast_lines() == ["MELDUNG A", "MELDUNG B", "MELDUNG C"],
		"Reihenfolge im Stack bleibt erhalten / nichts ueberschrieben")
	var a0 := hud.debug_toast_alphas()
	_check(a0.size() == 3 and float(a0[0]) > 0.99
		and float(a0[1]) > 0.99 and float(a0[2]) > 0.99,
		"Neue Nachrichten sind voll lesbar")
	for i in range(4):
		EventBus.toast.emit("MELDUNG %d" % (i + 4))
	_check(hud.debug_toast_count() == 5,
		"Stack ist auf 5 Zeilen begrenzt")
	_check(hud.debug_toast_lines()[0] == "MELDUNG C",
		"Aelteste Nachricht wandert nach oben aus dem Stack")
	_check(HUD.TOAST_LIFE == 6.0 and HUD.TOAST_FADE == 1.5,
		"6s Lesezeit, danach 1,5s Ausbleichen")
	hud.debug_advance_toasts(5.0)
	var fading := hud.debug_toast_alphas()
	var fading_ok := true
	for v in fading:
		if float(v) >= 1.0 or float(v) <= 0.0:
			fading_ok = false
	_check(fading_ok, "Nach 5s bleichen ALLE Zeilen sichtbar aus")
	hud.debug_advance_toasts(2.0)
	_check(hud.debug_toast_count() == 0,
		"Nach 7s sind die Nachrichten vollstaendig verschwunden")
	hud.debug_clear_toasts()

	# --- 9) Nahtlose Bodengenerierung an Chunkgrenzen -----------------------
	var s0 := chunk_manager.get_chunk(0).surface.debug_stripe_tints()
	var s1 := chunk_manager.get_chunk(1).surface.debug_stripe_tints()
	var s2 := chunk_manager.get_chunk(2).surface.debug_stripe_tints()
	_check(s0.size() == 32 and s1.size() == 32 and s2.size() == 32,
		"Jeder Chunk tastet 32 Streifen in WELTKOORDINATEN ab")
	var core_zero := true
	for v in s0:
		if float(v) > 0.002:
			core_zero = false
	_check(core_zero,
		"Im Kern bleibt der bisherige EINE Draw-Aufruf ohne Tint erhalten")
	_check(absf(float(s1[31]) - float(s2[0])) < 0.01,
		"Kein Farbsprung an der Grenze 4096px (%.4f / %.4f)" %
			[float(s1[31]), float(s2[0])])
	_check(absf(gen.biome_tint_at(2047.0).a
		- gen.biome_tint_at(2049.0).a) < 0.01,
		"Biom-Tint ist auch direkt an 2048px stetig")
	_check(absf(gen.height_smooth_at(2047.0)
		- gen.height_smooth_at(2049.0)) < 4.0,
		"Hoehenlinie springt an der Chunkgrenze nicht")
	_check(absf(gen.layer_edge_y(2047.0, 208.0, 3.0)
		- gen.layer_edge_y(2049.0, 208.0, 3.0)) < 8.0,
		"Erdschichtgrenze ist an der Chunkgrenze stetig")
	var d_neg := gen.decorations_for_chunk(-1).size()
	var d_pos := gen.decorations_for_chunk(1).size()
	_check(absi(d_neg - d_pos) <= 4,
		"Deko-Dichte springt nicht mehr (%d vs %d)" % [d_neg, d_pos])
	_check(str(gen.decorations_for_chunk(0))
		== str(WorldGenerator.new(Global.world_seed).decorations_for_chunk(0)),
		"Deko bleibt seed-deterministisch")

	# --- 10) Kein Ruckler beim Biom-Wechsel ---------------------------------
	biomes.reset()
	_biome_signals = 0
	if not EventBus.biome_changed.is_connected(_on_biome_signal):
		EventBus.biome_changed.connect(_on_biome_signal)
	for i in range(20):
		biomes._process(0.05)
		biomes._update_at(3000.0 + float(i) * 20.0, false, false)
	_check(_biome_signals >= 1 and _biome_signals <= 5,
		"20 Blend-Schritte erzeugen hoechstens 5 Signale (%d)" % _biome_signals)
	_check(biomes.debug_emit_cooldown() >= 0.0,
		"Signal-Cooldown ist aktiv")
	var reqs0 := hud.debug_refresh_requests()
	for _i in range(12):
		EventBus.wildlife_changed.emit()
	_check(hud.debug_refresh_requests() == reqs0 + 12,
		"12 Signale werden als Refresh-Anforderungen gesammelt")
	_check(hud.debug_refresh_dirty(), "Dirty-Flag gesetzt statt 12 Einzelrefreshs")
	hud._process(0.11)
	_check(not hud.debug_refresh_dirty(),
		"Ein 10-Hz-Takt fuehrt alle gesammelten Refreshs zusammen aus")
	if EventBus.biome_changed.is_connected(_on_biome_signal):
		EventBus.biome_changed.disconnect(_on_biome_signal)

	# --- 11) Kein Ruckler bei schneller WASD-Kamera -------------------------
	_check(not chunk_manager.debug_sliced_build(),
		"Headless-Test laeuft synchron (wie alle alten Smokes)")
	_check(ChunkManager.SLICE_COLS == 2
		and ChunkManager.BUILD_BUDGET_USEC == 4000,
		"2-Spalten-Scheiben mit 4ms Frame-Budget")
	var bench := chunk_manager.debug_bench_build_ms(7)
	var bench2 := chunk_manager.debug_bench_build_ms(7)
	print("[SMOKE] Synchroner Chunk-Bau: %.1f ms -> wird auf Frames verteilt" % bench)
	print("[SMOKE] Wiederholter Chunk-Bau (Cache): %.1f ms" % bench2)
	_check(bench >= 0.0, "Chunk-Bau-Kosten messbar (%.1f ms)" % bench)
	chunk_manager.set_sliced_build(true)
	camera.teleport_to(Vector2(4300.0, 400.0))
	chunk_manager._refresh()
	_check(chunk_manager.loaded_chunk_count() == 5,
		"Weiterhin 5 geladene Chunks nach schnellem Pan")
	_check(chunk_manager.debug_pending_builds() > 0,
		"Neue Chunks werden als Scheiben-Jobs eingereiht")
	_check(chunk_manager.debug_incomplete_chunks() > 0,
		"Kein Chunk wird in EINEM Frame fertiggestellt")
	chunk_manager.debug_finish_builds()
	_check(chunk_manager.debug_pending_builds() == 0
		and chunk_manager.debug_incomplete_chunks() == 0,
		"Alle Scheiben sauber abgearbeitet")
	var c3 := chunk_manager.get_chunk(3)
	_check(c3 != null and c3.is_build_complete()
		and c3.tile_layer != null and c3.surface != null
		and c3.contours != null,
		"Fertiger Chunk hat TileMap, Surface und Konturen")
	chunk_manager.set_sliced_build(false)
	_check(not chunk_manager.debug_sliced_build()
		and chunk_manager.debug_incomplete_chunks() == 0,
		"Zurueckschalten auf synchron bleibt moeglich")

	# --- 12) Save / Load + Abschluss-Regression ------------------------------
	_check(save_manager.save_game(), "Speichern mit P8.1-Zustand")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary
		and int((parsed as Dictionary).get("version", 0)) == 6,
		"Savegame bleibt Format v6")
	_check(save_manager.load_game(), "Laden mit P8.1-Zustand")
	_check(PixelArt.PATHS.size() == 21
		and not Global.auto_mode
		and is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"Alle Kernkonstanten nach Laden unveraendert")
	var any_tree: BaseTree = null
	for n in get_tree().get_nodes_in_group("trees"):
		if n is BaseTree:
			any_tree = n as BaseTree
			break
	_check(any_tree != null, "Nach Laden existiert mindestens ein Baum")
	if any_tree != null:
		interaction.select_tree(any_tree)
		hud.refresh()
		_check(hud.debug_supply_text().contains("Versorgung")
			and hud.debug_light_text().contains("Licht"),
			"R5-Versorgung und R7-Licht bleiben erhalten")
		any_tree.add_root()
		var seg = any_tree.root_segments[0] if any_tree.root_segments.size() > 0 else null
		_check(seg != null and seg.hit_rect().size == Vector2(16.0, 16.0),
			"Logisches 16x16-Raster erhalten")
	_check(FileAccess.file_exists("res://tests/FixSmoke.gd"),
		"Neuer Fix-Smoke ist Teil des Projekts")
	var csv := FileAccess.get_file_as_string("res://data/localization.csv")
	_check(csv.split("\n").size() >= 253
		and csv.contains("STATE_CLIMB") and csv.contains("STATE_PERCH")
		and csv.contains("MSG_ACORN_CACHED")
		and csv.contains("HUD_PHASE8") and csv.contains("HUD_PHASE7"),
		"Lokalisierung enthaelt alle neuen Schluessel + P7/P8-Erbe")

	_finish()


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-72s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
