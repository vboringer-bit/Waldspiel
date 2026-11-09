extends Node
## Headless-Smoke-Test REVISION 5 (organisches Wachstum + Bodenleben):
##   godot --headless --path . -- --rev5-smoke
##
## 1) Regenwuermer graben UNTER der Erde, langsam, mit Gang-Spuren.
## 2) Wuermer und Ameisen sind deutlich kleiner, bleiben aber anklickbar.
## 3) Baeume: 28 freie Wuchsschritte, ~476 px Endhoehe, echte Verzweigung
##    und Blattpositionen abseits des 16px-Rasters bei erhaltener Wasserlogik.
## 4) Glucose: 5x langsameres Grundtempo + multiplikative Versorgungs-Bilanz
##    aus Wasser, Sonne, Naehrstoffen und Wurzelmasse.
## 5) AUTO-Wuchskraft, HUD, DE/EN, Speicherstand und P0-P5-Regression.

var interaction: InteractionController
var growth: GrowthSystem
var water: WaterSystem
var time_manager: TimeManager
var season_system: SeasonSystem
var wildlife: WildlifeSystem
var chunk_manager: ChunkManager
var hud: HUD
var save_manager: SaveManager

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_season: SeasonSystem,
		p_wildlife: WildlifeSystem, p_chunks: ChunkManager, p_hud: HUD,
		p_save: SaveManager) -> void:
	interaction = p_interaction
	growth = p_growth
	water = p_water
	time_manager = p_time
	season_system = p_season
	wildlife = p_wildlife
	chunk_manager = p_chunks
	hud = p_hud
	save_manager = p_save


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-66s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === REVISION 5: organisches Wachstum + Bodenleben ===")
	growth.set_process(false)
	water.set_process(false)
	season_system.set_process(false)
	wildlife.set_process(false)
	Global.set_difficulty(Global.Difficulty.NORMAL)
	Global.locale = "de"
	Global.auto_mode = false
	time_manager.set_paused(false)
	time_manager.set_time_scale(1.0)
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.20)
	interaction.clear_trees()
	wildlife.reset()
	hud.refresh()
	var gen := chunk_manager.generator

	# --- 1) Bodenleben: unter der Erde, langsam, mit Gang-Spuren ------------
	var positions := wildlife.debug_worm_positions()
	_check(positions.size() == 2, "2 Regenwuermer weiterhin IMMER vorhanden")
	var underground := true
	for p in positions:
		var v: Vector2 = p
		if v.y <= gen.height_smooth_at(v.x) + 10.0:
			underground = false
	_check(underground, "Beide Wuermer liegen unter der Erdoberflaeche")
	var under_count := 0
	for a in wildlife.animals:
		if is_instance_valid(a) and a.species == "worm" \
				and a.debug_is_underground():
			under_count += 1
	_check(under_count == 2, "Beide Wuermer melden 'unter der Erde'")
	var depths := wildlife.debug_worm_depths()
	_check(depths.size() == 2 and float(depths[0]) >= Animal.WORM_DEPTH_MIN
		and float(depths[0]) <= Animal.WORM_DEPTH_MAX,
		"Grabtiefe 20..120 px im Boden (%.0f px)" % float(depths[0]))
	var d0 := float(depths[0])
	wildlife.debug_step(8.0)
	var d1 := float(wildlife.debug_worm_depths()[0])
	_check(absf(d1 - d0) > 0.01,
		"Wurm gräbt sich langsam tiefer/hoeher (%.1f -> %.1f px)" % [d0, d1])
	var trails := wildlife.debug_trail_lengths()
	_check(trails.size() == 2 and int(trails[0]) >= 3,
		"Wurm hinterlaesst sichtbare Gang-Spuren (%d Punkte)" % int(trails[0]))
	_check(wildlife.debug_food() > 0,
		"Wurm/Ameise geben weiterhin automatisch Futter")

	# --- 2) Deutlich kleinere Bodenfauna ------------------------------------
	_check(wildlife.debug_body_span("worm") <= 12.0
		and wildlife.debug_body_span("ant") <= 9.0,
		"Wurm 12 px / Ameise 9 px statt 28/21 px")
	var small_hits := true
	for a in wildlife.animals:
		if is_instance_valid(a) and (a.species == "worm" or a.species == "ant"):
			if a.hit_rect().size.x > 16.0:
				small_hits = false
	_check(small_hits, "Kleine Klickflaechen passen zur neuen Tiergroesse")
	# Specht/Eichhoernchen erscheinen erst ab >50 % Gesundheit -> hier ueber
	# die Konstante pruefen, nicht ueber eine (noch nicht gespawnte) Instanz.
	_check(float(Animal.BODY_SPAN["woodpecker"]) >= 36.0
		and float(Animal.BODY_SPAN["squirrel"]) >= 36.0,
		"Specht/Eichhoernchen behalten ihre Groesse")

	# --- 3) Groesser, langsamer, frei verzweigt -----------------------------
	var mature: BaseTree = interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	_check(mature != null and mature.trunk_tiles == 2
		and mature.leaves_count == 2 and mature.root_count == 1,
		"Keimling unveraendert: 2 Stamm / 2 Blatt / 1 Wurzel")
	for _i in 26:
		mature.add_trunk_tile()
	for _i in 30:
		mature.add_root()
	while mature.leaves_count < 12 and mature.add_leaf():
		pass
	_check(BaseTree.MAX_TRUNK == 28 and mature.trunk_tiles == 28,
		"28 Wuchsschritte statt 12 (langsamer Aufbau)")
	_check(mature.debug_trunk_height() >= 470.0,
		"Ausgewachsener Stamm %.0f px (vorher 192 px)"
			% mature.debug_trunk_height())
	_check(mature.debug_branch_count() >= 5,
		"Stamm verzweigt sich in %d Aeste" % mature.debug_branch_count())
	_check(mature.debug_leaf_spread() >= 60.0,
		"Krone %.0f px breit, Blaetter an freien Astspitzen"
			% mature.debug_leaf_spread())
	var seg := mature.root_segments[0]
	_check(seg.debug_uses_organic_draw(),
		"Wurzel-Kachelsprite durch Freiform-Faser ersetzt")
	var jit: Vector2 = seg.debug_visual_jitter()
	_check(jit.length() > 0.5,
		"Wurzelendpunkte liegen abseits des 16px-Rasters (%.1f px)" % jit.length())
	_check(seg.hit_rect().size == Vector2(16.0, 16.0),
		"Logisches 16px-Raster fuer Wasser/Klick/Save erhalten")
	_check(mature.root_count >= 20,
		"Wurzelsystem waechst deutlich tiefer (%d Segmente)" % mature.root_count)

	# --- 4) Glucose: Grundtempo + echte Versorgungs-Bilanz -----------------
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"Glucose-Grundtempo 0.2 = ca. 5x langsamer")
	var young: BaseTree = interaction.spawn_tree_at(Vector2(420.0, 0.0), {})
	young.water = 100.0
	young.glucose = 0.0
	young.photosynthesize(1.0, 1.0, 1.0)
	var g_young := young.glucose
	var young_parts := young.environment_parts(1.0)
	_check(float(young_parts["roots"]) < 0.30,
		"Winzige Wurzel: Wurzel-Faktor nur %.2f" % float(young_parts["roots"]))
	mature.water = 100.0
	mature.glucose = 0.0
	mature.photosynthesize(1.0, 1.0, 1.0)
	var g_mature := mature.glucose
	_check(g_young > 0.0 and g_mature > g_young * 3.0,
		"Gut versorgter Baum: %.2f statt %.2f Glucose/s (>3x)"
			% [g_mature, g_young])
	var base_env := mature.environment_factor(1.0)
	mature.water = 20.0
	var dry_env := mature.environment_factor(1.0)
	_check(dry_env < base_env * 0.5,
		"Wenig Wasser senkt die Versorgung um >50 %")
	mature.water = 100.0
	_check(is_equal_approx(mature.environment_factor(0.0), 0.0),
		"Keine Sonne = keine Versorgung = keine Glucose")
	var n0 := mature.environment_factor(1.0)
	mature.nutrient_mult = 1.35
	var n1 := mature.environment_factor(1.0)
	_check(n1 > n0, "Mehr Naehrstoffe erhoehen die Versorgung (%.2f -> %.2f)"
		% [n0, n1])
	mature.nutrient_mult = 1.0
	mature.glucose = 0.0
	mature.photosynthesize(1.0, 1.0, 1.0)
	var expected := float(mature.leaves_count) \
		* mature.species.photosynthesis_efficiency \
		* Global.difficulty_factor("photosynthesis") \
		* mature.skill_glucose_mult * BaseTree.GLUCOSE_PACE \
		* mature.environment_factor(1.0)
	_check(is_equal_approx(mature.glucose, expected),
		"Glucose-Formel enthaelt Grundtempo + Versorgung (%.2f)" % expected)

	# --- 5) AUTO-Wuchskraft haengt an der Versorgung ------------------------
	mature.growth_vigor = 0.0
	mature.glucose = 0.0
	Global.auto_mode = true
	growth.tick(0.2)
	var vigor := mature.debug_growth_vigor()
	_check(vigor > 0.0 and vigor < BaseTree.AUTO_GROWTH_INTERVAL,
		"Wuchskraft sammelt sich langsam an (%.2f / %.2f)"
			% [vigor, BaseTree.AUTO_GROWTH_INTERVAL])
	Global.auto_mode = false

	# --- 6) HUD / DE+EN / Regression ---------------------------------------
	interaction.select_tree(mature)
	hud.refresh()
	_check(hud.debug_supply_text().contains("Versorgung"),
		"HUD zeigt Versorgungs-Bilanz: '%s'" % hud.debug_supply_text())
	var keys: Array[String] = [
		"HUD_SUPPLY", "SUPPLY_LIMIT_WATER", "SUPPLY_LIMIT_SUN",
		"SUPPLY_LIMIT_NUTRIENTS", "SUPPLY_LIMIT_ROOTS", "SUPPLY_LIMIT_OK",
		"MSG_BURROW", "MSG_SLOW_GROWTH", "MSG_ORGANIC_GROWTH",
	]
	var missing := 0
	for key in keys:
		Global.locale = "de"
		var de := tr(key)
		Global.locale = "en"
		var en := tr(key)
		if de == key or en == key or de == en:
			missing += 1
	Global.locale = "de"
	_check(missing == 0, "Alle %d REVISION-5-Schluessel in DE + EN" % keys.size())
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus (P4-Fix)")
	_check(SaveManager.FORMAT_VERSION == 6, "Speicherstand bleibt Format v6")
	_check(save_manager.save_game(), "Speichern mit Wurmtiefe funktioniert")
	_check(save_manager.load_game(), "Laden mit Wurmtiefe funktioniert")
	var loaded_depths := wildlife.debug_worm_depths()
	_check(loaded_depths.size() == 2 and float(loaded_depths[0]) >= Animal.WORM_DEPTH_MIN,
		"Wurmtiefe nach Save/Load wiederhergestellt")
	_finish()


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
