extends Node
## Headless-Smoke-Test PHASE 5:
##   godot --headless --path . -- --phase5-smoke
##
## 1) Wald-Gesundheit: echte Metrik aus Blaettern + Baeumen + Biodiversitaet,
##    Basis-Tiere immer, Specht/Eichhoernchen erst ab > 50 %.
## 2) StateMachine, Futter, Ameisenhuegel/Kolonie, Kollision mit Baeumen.
## 3) Eichhoernchen traegt Samen in einen ANDEREN Chunk.
## 4) Mistel + Wurmbefall ziehen echte Glucose; Specht und Resistenz entfernen.
## 5) Pilz-Symbiose: sichtbarer Patch + +15 % Naehrstoffe.
## 6) Schwierigkeit, HUD, DE/EN, Save/Load v6 und P0-P4-Regression.

var interaction: InteractionController
var skill_tree: SkillTree
var forest_health: ForestHealth
var wildlife: WildlifeSystem
var parasites: ParasiteSystem
var save_manager: SaveManager
var time_manager: TimeManager
var season_system: SeasonSystem
var growth: GrowthSystem
var water: WaterSystem
var chunk_manager: ChunkManager
var camera: CameraController
var world_state: WorldState
var hud: HUD

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_skill_tree: SkillTree,
		p_health: ForestHealth, p_wildlife: WildlifeSystem,
		p_parasites: ParasiteSystem, p_save: SaveManager,
		p_time: TimeManager, p_season: SeasonSystem,
		p_growth: GrowthSystem, p_water: WaterSystem,
		p_chunks: ChunkManager, p_camera: CameraController,
		p_state: WorldState, p_hud: HUD) -> void:
	interaction = p_interaction
	skill_tree = p_skill_tree
	forest_health = p_health
	wildlife = p_wildlife
	parasites = p_parasites
	save_manager = p_save
	time_manager = p_time
	season_system = p_season
	growth = p_growth
	water = p_water
	chunk_manager = p_chunks
	camera = p_camera
	world_state = p_state
	hud = p_hud


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-62s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === PHASE 5: Tiere, Symbiose, Parasiten ===")
	# Deterministisch: nur explizit ticken.
	growth.set_process(false)
	water.set_process(false)
	season_system.set_process(false)
	wildlife.set_process(false)
	parasites.set_process(false)
	parasites.debug_set_spawns_frozen(true)
	Global.set_difficulty(Global.Difficulty.NORMAL)
	Global.locale = "de"
	Global.auto_mode = false
	time_manager.set_paused(false)
	time_manager.set_time_scale(1.0)
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.20)
	skill_tree.reset()
	interaction.clear_trees()
	wildlife.reset()
	parasites.debug_clear()
	parasites.debug_sync_fungi()
	forest_health.debug_clear_override()
	forest_health.recompute()

	# --- 1) Basis-Tiere + Gesundheit ----------------------------------------
	_check(forest_health.debug_value() < ForestHealth.THRESHOLD,
		"Start: Wald-Gesundheit unter 50 %")
	_check(wildlife.debug_animal_count("worm") == 2,
		"2 Regenwuermer sind IMMER vorhanden")
	_check(wildlife.debug_animal_count("ant") == 2,
		"2 Ameisen sind IMMER vorhanden")
	_check(wildlife.debug_anthill_count() == 1,
		"Ameisenhuegel als Erd-Pixelhaufen vorhanden")
	_check(not wildlife.has_species("woodpecker")
		and not wildlife.has_species("squirrel"),
		"Specht/Eichhoernchen bei schwachem Wald noch abwesend")
	_check(wildlife.debug_species_count() == 2,
		"Basis-Biodiversitaet = 2 Tierarten")

	# --- 2) Gesundheit > 50 % lockt weitere Tiere an ------------------------
	interaction.debug_plant_twice()
	var tree: BaseTree = interaction.selected_tree
	_check(tree != null, "Keimling fuer PHASE-5-Tests vorhanden")
	if tree == null:
		_finish()
		return
	while tree.leaves_count < 6 and tree.add_leaf():
		pass
	var tree2: BaseTree = interaction.spawn_tree_at(Vector2(400.0, 0.0), {})
	while tree2.leaves_count < 6 and tree2.add_leaf():
		pass
	var healthy := forest_health.debug_value()
	_check(healthy > ForestHealth.THRESHOLD,
		"Wald-Gesundheit %.2f > 0.50 durch Blaetter + Baeume" % healthy)
	wildlife.debug_sync_advanced()
	_check(wildlife.has_species("woodpecker"),
		"Specht siedelt sich ab > 50 % Gesundheit an")
	_check(wildlife.has_species("squirrel"),
		"Eichhoernchen siedelt sich ab > 50 % Gesundheit an")
	_check(wildlife.debug_species_count() == 4,
		"Jetzt 4 Tierarten (Biodiversitaet steigt)")
	_check(forest_health.debug_biodiversity() >= 4,
		"Gesundheits-Metrik zaehlt Biodiversitaet mit")

	# --- 3) StateMachine / Futter / Ameisenkolonie ---------------------------
	# Erst OHNE Klick und OHNE debug_force_state(): die StateMachine muss
	# selbststaendig von WANDER/IDLE nach EAT wechseln und Futter erzeugen.
	wildlife.debug_step(12.0)
	var food_auto := wildlife.debug_food()
	_check(wildlife.debug_force_state("worm", Animal.State.EAT),
		"StateMachine: Zustand EAT gesetzt")
	_check(wildlife.debug_state_count("worm", Animal.State.EAT) > 0,
		"StateMachine: EAT ist am Tier gespeichert")
	wildlife.debug_step(3.0)
	_check(food_auto > 0 and wildlife.debug_food() > food_auto,
		"Automatischer Zyklus UND EAT geben Futter (+%d)" % wildlife.debug_food())
	var ants_before := wildlife.debug_animal_count("ant")
	wildlife.debug_step(11.0)
	_check(wildlife.debug_colony_size() > ants_before,
		"Ameisenkolonie vermehrt sich langsam")
	_check(wildlife.debug_animal_count("ant") > ants_before,
		"Neue Ameise wurde gespawnt")
	_check(wildlife.debug_anthill_count() >= 1,
		"Ameisenhuegel bleibt bestehen")
	_check(hud.debug_food_text().contains("Futter"),
		"HUD zeigt Futter-Zaehler")

	# --- 4) Ferntransport in einen anderen Chunk -----------------------------
	var trees_before := get_tree().get_nodes_in_group("trees").size()
	var remote: BaseTree = wildlife.debug_force_remote_seed()
	var trees_after := get_tree().get_nodes_in_group("trees").size()
	_check(remote != null and trees_after == trees_before + 1,
		"Eichhoernchen pflanzt einen neuen Baum")
	if remote != null:
		var chunk_idx := int(floor(remote.global_position.x
			/ float(WorldGenerator.CHUNK_WIDTH_PX)))
		_check(chunk_idx != 0,
			"Neuer Baum liegt in Chunk %d (nicht Start-Chunk)" % chunk_idx)

	# --- 5) Parasiten: Glucose-Entzug + Specht -------------------------------
	parasites.debug_infest(tree, Parasite.Kind.MISTLETOE)
	parasites.debug_infest(tree, Parasite.Kind.WORM)
	_check(parasites.debug_parasite_count() == 2,
		"Mistel UND Wurmbefall am Baum sichtbar")
	tree.glucose = 50.0
	parasites.debug_step(2.0)
	_check(tree.glucose < 50.0 and tree.glucose >= 0.0,
		"Parasiten ziehen echte Glucose ab (%.2f)" % tree.glucose)
	_check(wildlife.debug_force_help(tree),
		"parasite_spawned schickt den Specht zum Baum")
	wildlife.debug_step(1.2)
	_check(parasites.debug_parasite_count() < 2,
		"Specht pickt einen Parasiten weg")
	_check(parasites.debug_last_removed_by() == "woodpecker",
		"Entfernung ist als 'woodpecker' protokolliert")

	# --- 6) Resistenz-Skill entfernt die Mistel ------------------------------
	parasites.debug_infest(tree, Parasite.Kind.MISTLETOE)
	tree.glucose = 500.0
	_check(skill_tree.unlock("leaf_efficiency", tree),
		"Voraussetzung: Effizientere Blaetter")
	_check(skill_tree.unlock("spread", tree),
		"Voraussetzung: Verbreitung")
	_check(skill_tree.unlock("parasite_res", tree),
		"Parasiten-Resistenz freigeschaltet")
	_check(is_equal_approx(skill_tree.resistance("parasite_risk"), 0.5),
		"Resistenz -50 % wirkt auf Spawn-/Entzugs-Risiko")
	_check(parasites.debug_parasite_count(Parasite.Kind.MISTLETOE) == 0,
		"Resistenz befreit den Baum von der Mistel")
	_check(parasites.debug_last_removed_by() == "resistance",
		"Entfernung ist als 'resistance' protokolliert")

	# --- 7) Schwierigkeit ----------------------------------------------------
	Global.set_difficulty(Global.Difficulty.LEICHT)
	_check(not Global.difficulty_toggle("parasites")
		and not parasites.debug_force_spawn(),
		"LEICHT: ueberhaupt keine Parasiten-Spawns")
	Global.set_difficulty(Global.Difficulty.NORMAL)

	# --- 8) Pilz-Symbiose / Naehrstoffe -------------------------------------
	var health_before_fungi := forest_health.debug_value()
	tree.glucose = 500.0
	_check(skill_tree.unlock("root_efficiency", tree),
		"Voraussetzung fuer Symbiose: Wurzel-Knoten")
	_check(skill_tree.unlock("symbiosis", tree),
		"Symbiose-Knoten mit zwei Vorbedingungen")
	_check(skill_tree.unlock("mushroom_node", tree),
		"Pilz-Knoten freigeschaltet")
	_check(parasites.debug_fungus_count() >= 1,
		"Pilz-Symbiose erzeugt sichtbare Fungus-Patches")
	_check(is_equal_approx(tree.nutrient_mult, 1.15),
		"Pilze geben +15 % Naehrstoffe (echter Multiplikator)")
	_check(forest_health.debug_value() > health_before_fungi,
		"Pilz-Patches erhoehen die Wald-Gesundheit")
	tree.glucose = 0.0
	tree.water = 100.0
	tree.photosynthesize(1.0, 1.0, 1.0)
	# REVISION 5: nutrient_mult wirkt jetzt INNERHALB der Versorgungs-Bilanz.
	var expected := float(tree.leaves_count) \
		* tree.species.photosynthesis_efficiency \
		* Global.difficulty_factor("photosynthesis") \
		* tree.skill_glucose_mult * BaseTree.GLUCOSE_PACE \
		* tree.environment_factor(1.0)
	_check(is_equal_approx(tree.glucose, expected),
		"Fotosynthese nutzt Versorgungs-Bilanz (%.2f)" % expected)
	var env_with := tree.environment_factor(1.0)
	tree.nutrient_mult = 1.0
	var env_without := tree.environment_factor(1.0)
	tree.nutrient_mult = 1.15
	_check(env_with > env_without,
		"Pilz-Naehrstoffe erhoehen die Versorgungs-Bilanz")
	hud.refresh()
	_check(hud.debug_health_text().contains("%"),
		"HUD zeigt Wald-Gesundheit in Prozent")
	_check(hud.debug_parasites_text().contains("Pilze"),
		"HUD zeigt Parasiten- und Pilz-Zaehler")

	# --- 9) Lokalisierung ----------------------------------------------------
	_check_localizations()

	# --- 10) Save / Load v6 --------------------------------------------------
	parasites.debug_infest(tree, Parasite.Kind.WORM)
	var animals_before := wildlife.debug_total_animal_count()
	var parasite_before := parasites.debug_parasite_count()
	var fungi_before := parasites.debug_fungus_count()
	var food_before := wildlife.debug_food()
	_check(save_manager.save_game(), "Speichern (Format v6)")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary
		and int((parsed as Dictionary).get("version", 0)) == 6,
		"Savegame version = 6")
	var has_p5 := parsed is Dictionary \
		and (parsed as Dictionary).has("wildlife") \
		and (parsed as Dictionary).has("parasites")
	_check(has_p5, "Tiere/Futter und Parasiten liegen im Savegame")
	skill_tree.reset()
	wildlife.reset()
	parasites.debug_clear()
	parasites.debug_sync_fungi()
	interaction.clear_trees()
	_check(save_manager.load_game(), "Laden (Format v6)")
	_check(wildlife.debug_total_animal_count() == animals_before,
		"Tiere/Futter nach Laden wiederhergestellt")
	_check(wildlife.debug_food() == food_before,
		"Futter-Zaehler nach Laden identisch")
	_check(parasites.debug_parasite_count() == parasite_before,
		"Parasiten nach Laden wiederhergestellt")
	_check(parasites.debug_fungus_count() == fungi_before,
		"Pilz-Patches nach Laden wiederhergestellt")
	var loaded := get_tree().get_nodes_in_group("trees")
	_check(loaded.size() >= 1, "Baeume nach Laden wiederhergestellt")
	if loaded.size() >= 1:
		var lt := loaded[0] as BaseTree
		_check(is_equal_approx(lt.nutrient_mult, 1.15),
			"Naehrstoff-Multiplikator nach Laden erhalten")

	# --- 11) Regression ------------------------------------------------------
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus (P4-Fix)")
	_check(skill_tree.all_nodes().size() == 24,
		"Skilltree bleibt bei 24 Knoten")
	_check(chunk_manager.loaded_chunk_count() == 5,
		"Weiterhin 5 geladene Chunks")
	_finish()


func _check_localizations() -> void:
	var keys: Array[String] = [
		"HUD_PHASE5", "HUD_FOREST_HEALTH", "HUD_FOOD", "HUD_WILDLIFE",
		"HUD_PARASITES", "HUD_FUNGI", "ANIMAL_WORM", "ANIMAL_ANT",
		"ANIMAL_WOODPECKER", "ANIMAL_SQUIRREL", "STATE_IDLE",
		"STATE_WANDER", "STATE_EAT", "STATE_HELP_TREE", "STATE_CARRY",
		"MSG_ANIMAL_INFO", "MSG_ANTHILL_INFO", "MSG_FOOD_GAINED",
		"MSG_ANTHILL_GROWN", "MSG_WILDLIFE_ARRIVED", "MSG_WILDLIFE_LEFT",
		"MSG_WOODPECKER_HELP", "MSG_SEED_CARRIED",
		"MSG_TREE_PLANTED_REMOTE", "MSG_PARASITE_SPAWN",
		"MSG_PARASITE_MISTLETOE", "MSG_PARASITE_WORM",
		"MSG_PARASITE_INFO", "MSG_PARASITE_REMOVED", "BY_WOODPECKER",
		"BY_RESISTANCE", "MSG_RESISTANCE_CLEAN", "MSG_FUNGUS_SPAWN",
		"MSG_FUNGUS_INFO", "SKILL_MUSHROOM_DESC",
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
	_check(missing == 0, "Alle %d PHASE-5-Schluessel in DE + EN uebersetzt" % keys.size())


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
