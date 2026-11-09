extends Node
## Headless-Smoke-Test PHASE 4:
##   godot --headless --path . -- --phase4-smoke
##
## 1) Skilltree: 15 Knoten, 7 Pflicht-Mutationen, Vorbedingungen, Glucose-
##    Kosten, globale Synchronitaet, ECHTE Effekte auf Wasser/Glucose/Wachstum.
## 2) GraphEdit-UI: 15 Knoten, 14 Verbindungslinien, Zoom, oeffnen/schliessen.
## 3) Save v5: Skill-Fortschritt wird gespeichert und geladen.
## 4) Winter: SCHNEE statt Regen (keine Spritzer, keine Flocken unter dem
##    Boden), aber R3-Regeln (keine Entnahme, Auffuellen laeuft) bleiben.
## 5) Regression: Fruehling regnet weiter wie in REVISION 3.
## 6) PHASE-4-FIX: AUTO standardmaessig aus, ausgewachsener Baum verbraucht
##    keine Glucose, Kronenwuchs gibt +2 SICHTBARE Blaetter, Schnee bleibt
##    laenger liegen und taut beim Saisonwechsel sanft zu Regen.

var interaction: InteractionController
var skill_tree: SkillTree
var skill_ui: SkillTreeUI
var water: WaterSystem
var growth: GrowthSystem
var chunk_manager: ChunkManager
var camera: CameraController
var world_state: WorldState
var time_manager: TimeManager
var season_system: SeasonSystem
var save_manager: SaveManager
var rain: RainEffect
var hud: HUD

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_skill_tree: SkillTree,
		p_skill_ui: SkillTreeUI, p_water: WaterSystem,
		p_growth: GrowthSystem, p_chunks: ChunkManager,
		p_camera: CameraController, p_state: WorldState,
		p_time: TimeManager, p_season: SeasonSystem, p_save: SaveManager,
		p_rain: RainEffect, p_hud: HUD) -> void:
	interaction = p_interaction
	skill_tree = p_skill_tree
	skill_ui = p_skill_ui
	water = p_water
	growth = p_growth
	chunk_manager = p_chunks
	camera = p_camera
	world_state = p_state
	time_manager = p_time
	season_system = p_season
	save_manager = p_save
	rain = p_rain
	hud = p_hud


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-58s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === PHASE 4: Skilltree + Winter-Schnee ===")
	# Deterministisch: nur manuell ticken.
	growth.set_process(false)
	water.set_process(false)
	season_system.set_process(false)
	rain.set_process(false)
	skill_tree.reset()
	Global.locale = "de"
	_check(not Global.auto_mode, "AUTO standardmaessig aus (MANUELL)")

	# --- 1) Daten / Graph -----------------------------------------------------
	_check(skill_tree != null and skill_tree.data != null,
		"SkillTree + data/skilltrees/oak.tres geladen")
	_check(skill_tree.all_nodes().size() == 15, "Genau 15 MVP-Knoten")
	var mandatory := ["root_efficiency", "leaf_efficiency", "symbiosis",
		"parasite_res", "disease_res", "wood_hardness", "spread"]
	var all_present := true
	for id in mandatory:
		if skill_tree.node_data(id) == null:
			all_present = false
	_check(all_present, "Alle 7 Pflicht-Mutationen aus Master-Punkt 6")
	_check(skill_tree.connection_pairs().size() == 14,
		"14 Vorbedingungs-Verbindungen")
	_check(skill_tree.unlocked_count() == 0
		and is_equal_approx(skill_tree.modifier("root_water"), 1.0),
		"Start: nichts freigeschaltet, alle Modifikatoren = 1.0")

	# --- 2) Freischalten / echte Effekte -------------------------------------
	interaction.debug_plant_twice()
	var tree: BaseTree = interaction.selected_tree
	_check(tree != null, "Baum fuer Glucose-Bezahlung vorhanden")
	if tree == null:
		_finish()
		return
	tree.glucose = 500.0
	_check(skill_tree.can_unlock("root_efficiency", tree),
		"can_unlock(): Wurzel-Knoten bezahlbar")
	_check(not skill_tree.is_available("deep_roots")
		and not skill_tree.can_unlock("deep_roots", tree),
		"Vorbedingung sperrt Tiefwurzler")
	var before := tree.glucose
	_check(skill_tree.unlock("root_efficiency", tree),
		"Freischalten erfolgreich")
	_check(is_equal_approx(before - tree.glucose, 10.0),
		"Genau 10 Glucose abgezogen")
	_check(is_equal_approx(skill_tree.modifier("root_water"), 1.25),
		"+25 % Wasseraufnahme im Skilltree")
	_check(is_equal_approx(tree.skill_root_water_mult, 1.25),
		"apply_effect() wirkt auf die Baum-Instanz")
	tree.water = 0.0
	tree.absorb_water(1.0, 10.0)
	_check(is_equal_approx(tree.water, 12.5),
		"Echter Wert: 10 Wasser/s werden zu 12,5")

	# Globale Synchronitaet: ein NEUER Baum bekommt denselben Fortschritt.
	var tree2: BaseTree = interaction.spawn_tree_at(Vector2(400.0, 0.0), {})
	_check(tree2 != null and is_equal_approx(tree2.skill_root_water_mult, 1.25),
		"Skilltree pro Art synchron (neuer Baum uebernimmt Effekt)")

	tree.glucose = 500.0
	_check(skill_tree.unlock("leaf_efficiency", tree),
		"Effizientere Blaetter freigeschaltet")
	_check(is_equal_approx(tree.skill_glucose_mult, 1.20),
		"+20 % Glucose am Baum")
	tree.glucose = 0.0
	tree.water = 100.0
	tree.photosynthesize(1.0, 1.0, 1.0)
	var expected := float(tree.leaves_count) * tree.species.photosynthesis_efficiency \
		* Global.difficulty_factor("photosynthesis") * 1.20
	_check(tree.glucose > 0.0 and is_equal_approx(tree.glucose, expected),
		"Echter Wert: Fotosynthese erzeugt %.2f Glucose" % expected)

	tree.glucose = 500.0    # Fotosynthese-Test hat den Zaehler fast geleert
	_check(skill_tree.unlock("spread", tree),
		"Verbreitung freigeschaltet (Voraussetzung Blaetter)")
	_check(is_equal_approx(season_system.spread_bonus, 0.30),
		"P3-Anschluss set_spread_bonus() = +30 %")

	_check(skill_tree.unlock("photosynthesis_plus", tree)
		and skill_tree.unlock("crown_growth", tree),
		"Ketten-Freischaltung bis Kronenwuchs")
	_check(tree.skill_max_leaves_bonus == 2,
		"+2 Blaetter: can_grow('leaf') real erweitert")
	var crown := skill_tree.node_data("crown_growth")
	_check(crown != null and is_equal_approx(float(crown.effects.get("grant_leaves", 0.0)), 2.0),
		"Kronenwuchs enthaelt grant_leaves = 2")
	_check(tree.skill_leaf_grants == 2,
		"Kronenwuchs: +2 Blaetter SOFORT gutgeschrieben")
	_check(tree2 != null and tree2.skill_leaf_grants == 2,
		"+2 Blaetter auch auf allen anderen Eichen (global synchron)")

	_check(skill_tree.unlock("symbiosis", tree),
		"Symbiose mit ZWEI Vorbedingungen")
	_check(skill_tree.unlock("parasite_res", tree),
		"Parasiten-Resistenz freigeschaltet")
	_check(is_equal_approx(skill_tree.resistance("parasite_risk"), 0.5),
		"Resistenzwert -50 % gespeichert (PHASE-5-Anschluss)")
	_check(is_equal_approx(tree.skill_water_consumption_mult, 0.9),
		"Resistenz wirkt jetzt schon auf den Wasserverbrauch")
	var count_before := skill_tree.unlocked_count()
	_check(count_before >= 6, "%d Knoten freigeschaltet" % count_before)

	# --- 3) GraphEdit-UI ------------------------------------------------------
	_check(skill_ui.debug_node_count() == 15, "GraphEdit: 15 GraphNodes")
	_check(skill_ui.debug_connection_count() == 14, "GraphEdit: 14 Linien")
	EventBus.skilltree_open_requested.emit()   # derselbe Weg wie der HUD-Button
	_check(skill_ui.is_open(), "Skilltree-UI oeffnet ueber HUD-Signal / T")
	skill_ui.debug_set_zoom(1.2)
	_check(is_equal_approx(skill_ui.debug_zoom(), 1.2), "Zoom veraenderbar")
	skill_ui.refresh()
	skill_ui.close()
	_check(not skill_ui.is_open(), "Skilltree-UI schliesst wieder")

	# --- 4) Save v5 mit Skill-Fortschritt ------------------------------------
	_check(save_manager.save_game(), "Speichern (Format v6, v5-kompatibel)")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary and int((parsed as Dictionary).get("version", 0)) >= 5,
		"Savegame version >= 5 (PHASE 5 schreibt v6)")
	var saved_ids: Array = []
	if parsed is Dictionary:
		var skills_dict: Dictionary = (parsed as Dictionary).get("skills", {})
		saved_ids = skills_dict.get("unlocked", [])
	_check(saved_ids.size() == count_before,
		"Skill-Fortschritt im Savegame (%d IDs)" % saved_ids.size())
	skill_tree.reset()
	_check(skill_tree.unlocked_count() == 0, "Zurueckgesetzt vor dem Laden")
	_check(save_manager.load_game(), "Laden (Format v6, v5-kompatibel)")
	_check(skill_tree.unlocked_count() == count_before,
		"Skill-Fortschritt nach Laden wiederhergestellt")

	# --- 4b) PHASE-4-FIX: AUTO / Blatt-Cap / ausgewachsener Baum -------------
	var loaded_tree: BaseTree = interaction.selected_tree
	_check(loaded_tree != null and loaded_tree.skill_leaf_grants == 2,
		"Save v5 stellt Skill-Blaetter ohne Duplikate wieder her")
	if loaded_tree != null:
		var leaves_loaded := loaded_tree.leaves_count
		skill_tree._apply_to_all()
		_check(loaded_tree.leaves_count == leaves_loaded,
			"apply_effect() erzeugt keine doppelten Skill-Blaetter")

	# Cap-Test: mit Bonus muessen 13 + 14 entstehen, 15 muss scheitern.
	var cap_tree: BaseTree = interaction.spawn_tree_at(Vector2(800.0, 0.0), {})
	cap_tree.skill_max_leaves_bonus = 2
	cap_tree.leaves_count = 12
	var ok13 := cap_tree.grow_part("leaf")
	var ok14 := cap_tree.grow_part("leaf")
	var ok15 := cap_tree.grow_part("leaf")
	_check(ok13 and ok14 and not ok15 and cap_tree.leaves_count == 14,
		"add_leaf() respektiert Cap 14; grow_part() luegt nicht mehr")

	# Ausgewachsener Baum darf in AUTO keine Glucose mehr verbrauchen.
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.20)
	time_manager.set_paused(false)
	time_manager.set_time_scale(1.0)
	var full_tree: BaseTree = interaction.spawn_tree_at(Vector2(1000.0, 0.0), {})
	full_tree.debug_mark_full()
	full_tree.set_season(TimeManager.Season.SPRING)
	full_tree.water = 0.0          # Fotosynthese aus, damit nur AUTO-Kauf zaehlt
	full_tree.glucose = 50.0
	Global.auto_mode = true
	growth.tick(1.0)
	_check(is_equal_approx(full_tree.glucose, 50.0),
		"Ausgewachsener Baum: AUTO verbraucht KEINE Glucose")
	Global.auto_mode = false

	# --- 5) WINTER: Schnee statt Regen ---------------------------------------
	time_manager.debug_set_season(TimeManager.Season.WINTER, 3, 0.40)
	water.force_rain(30.0)
	_check(water.is_snowfall() and rain.debug_is_snow(),
		"Winter: Niederschlag ist SCHNEE")
	hud.refresh()
	_check(hud.debug_rain_label_text() == "Es schneit",
		"HUD zeigt „Es schneit“")
	var splashes_before := rain.debug_splash_count()
	for _i in 12:
		rain.debug_step(0.1)
	_check(rain.debug_splash_count() == splashes_before
		and rain.debug_active_splashes() == 0,
		"Schnee erzeugt KEINE Regen-Spritzer")
	_check(rain.debug_snow_settle_count() > 0,
		"Flocken bleiben auf der Oberflaeche liegen")
	var life_range := rain.debug_settle_life_range()
	_check(life_range.x >= 5.0 and life_range.y <= 9.0,
		"Schnee bleibt 5-9 s liegen (statt 1,6-3,2 s)")
	_check(rain.debug_drops_below_surface() == 0,
		"Keine Flocken unter der Geländelinie")

	# R3-Invarianten: Winter ruht, aber Niederschlag fuellt weiter auf.
	var gen := chunk_manager.generator
	var ty := gen.surface_tile_y_at(0.0) + 10
	world_state.debug_set_fill(0, ty, 0.20)
	var fill0 := world_state.fill_fraction(0, ty)
	water.tick(1.0)
	_check(world_state.fill_fraction(0, ty) > fill0,
		"Schnee fuellt Reservoirs weiter auf (R3 erhalten)")
	_check(is_equal_approx(water.last_reservoir_rate, 0.0),
		"Winter: weiterhin KEINE Reservoir-Entnahme (R3)")

	# --- 6) Sanfter Uebergang Schnee -> Regen --------------------------------
	time_manager.debug_set_season(TimeManager.Season.SPRING, 4, 0.20)
	_check(rain.debug_is_transitioning() and rain.debug_snow_blend() > 0.9,
		"Saisonwechsel startet WEICHEN Uebergang (kein harter Schnitt)")
	_check(rain.debug_snow_settle_count() > 0,
		"Liegender Schnee bleibt beim Uebergang erhalten")
	for _i in 3:
		rain.debug_step(0.1)
	hud.refresh()
	_check(hud.debug_rain_label_text() == "Der Schnee geht langsam in Regen ueber.",
		"HUD zeigt Tau-Meldung waehrend des Uebergangs")
	for _i in 37:
		rain.debug_step(0.1)
	_check(not rain.debug_is_transitioning() and rain.debug_snow_blend() < 0.01,
		"Uebergang endet nach 3,5 s bei reinem Regen")
	_check(not rain.debug_is_snow() and not water.is_snowfall(),
		"Fruehling: wieder Regen")
	# Auch Flocken, die noch WAEHREND des Uebergangs gelandet sind, schmelzen.
	for _i in 30:
		rain.debug_step(0.1)
	_check(rain.debug_snow_settle_count() == 0,
		"Schnee ist sanft geschmolzen (nicht hart geloescht)")
	_check(rain.debug_splash_count() > splashes_before,
		"Regen-Spritzer im Fruehling weiter aktiv (REV3)")

	# --- 7) Lokalisierung / Regression ---------------------------------------
	_check_localizations()
	_check(chunk_manager.loaded_chunk_count() == 5,
		"Weiterhin 5 geladene Chunks")
	_finish()


func _check_localizations() -> void:
	var keys: Array[String] = []
	for nd in skill_tree.all_nodes():
		keys.append(nd.title_key)
		keys.append(nd.desc_key)
	keys.append_array(["HUD_SKILLTREE", "HUD_HINT", "SKILL_UI_TITLE",
		"SKILL_UI_SUBTITLE", "SKILL_UI_CLOSE", "SKILL_UI_GLUCOSE",
		"SKILL_UI_HINT", "SKILL_UI_NO_TREE", "SKILL_UI_UNLOCK",
		"SKILL_UI_UNLOCKED", "SKILL_UI_LOCKED", "SKILL_UI_AVAILABLE",
		"SKILL_UI_COUNT", "MSG_SKILL_UNLOCKED", "MSG_SKILL_NO_GLUCOSE",
		"MSG_SKILL_PREREQ", "MSG_SKILL_NO_TREE", "MSG_SNOW",
		"MSG_SNOW_STOP", "MSG_SNOW_REFILL", "MSG_SNOW_MELT"])
	var missing := 0
	for key in keys:
		Global.locale = "de"
		var de := tr(key)
		Global.locale = "en"
		var en := tr(key)
		if de == key or en == key:
			missing += 1
		elif de == en and not ["+", "−", "1:1"].has(de):
			missing += 1
	Global.locale = "de"
	_check(missing == 0, "Alle %d P4-Schluessel in DE + EN uebersetzt" % keys.size())


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
