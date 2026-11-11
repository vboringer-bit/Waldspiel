extends Node
## Headless-Smoke-Test PHASE 6 (Schwierigkeitsgrade / Bodenchemie /
## Mykorrhiza / Katastrophen):
##   godot --headless --path . -- --p6-smoke

var interaction: InteractionController
var chunk_manager: ChunkManager
var hud: HUD
var save_manager: SaveManager
var growth: GrowthSystem
var water: WaterSystem
var time_manager: TimeManager
var season: SeasonSystem
var wildlife: WildlifeSystem
var skill_tree: SkillTree
var soil: SoilChemistry
var myco: Mycorrhiza
var disasters: DisasterSystem
var camera: CameraController

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_chunks: ChunkManager,
		p_hud: HUD, p_save: SaveManager, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_season: SeasonSystem,
		p_wildlife: WildlifeSystem, p_skill_tree: SkillTree,
		p_soil: SoilChemistry, p_myco: Mycorrhiza,
		p_disasters: DisasterSystem, p_camera: CameraController) -> void:
	interaction = p_interaction
	chunk_manager = p_chunks
	hud = p_hud
	save_manager = p_save
	growth = p_growth
	water = p_water
	time_manager = p_time
	season = p_season
	wildlife = p_wildlife
	skill_tree = p_skill_tree
	soil = p_soil
	myco = p_myco
	disasters = p_disasters
	camera = p_camera


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === PHASE 6: pH/N-P-K, Mykorrhiza, Katastrophen ===")
	growth.set_process(false)
	water.set_process(false)
	season.set_process(false)
	wildlife.set_process(false)
	soil.set_process(false)
	myco.set_process(false)
	disasters.set_process(false)
	Global.locale = "de"
	Global.auto_mode = false
	Global.set_difficulty(Global.Difficulty.NORMAL)
	time_manager.set_paused(false)
	time_manager.set_time_scale(1.0)
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.20)
	interaction.clear_trees()
	interaction.set_seed_count(0)
	skill_tree.reset()
	soil.reset(Global.world_seed)
	disasters.from_dict({})
	myco.debug_force_rebuild()
	hud.refresh()

	# --- 1) deterministische Testbaeume --------------------------------------
	var t1 := interaction.spawn_tree_at(Vector2(-192.0, 0.0), {})
	var t2 := interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	var t3 := interaction.spawn_tree_at(Vector2(192.0, 0.0), {})
	_check(t1 != null and t2 != null and t3 != null,
		"Drei Eichen fuer P6 angelegt")
	_check(get_tree().get_nodes_in_group("trees").size() == 3,
		"Genau drei Baeume im SceneTree")
	_reset_tree_values()
	soil.debug_set_all(t1.global_position.x, 6.0, 100.0, 100.0, 100.0)
	soil.debug_set_all(t2.global_position.x, 6.0, 100.0, 100.0, 100.0)
	soil.debug_set_all(t3.global_position.x, 6.0, 100.0, 100.0, 100.0)

	# --- 2) Schalter / Referenzverhalten -------------------------------------
	Global.set_difficulty(Global.Difficulty.LEICHT)
	_check(not soil.debug_is_active(), "LEICHT: keine aktive Bodenchemie")
	_check(not myco.debug_active(), "LEICHT: kein Mykorrhiza-Malus")
	_check(not disasters.enabled(), "LEICHT: Katastrophen aus")
	_check(disasters.debug_allowed_kinds().is_empty(),
		"LEICHT: keine erlaubten Ereignisse")
	_check(not disasters.debug_force(DisasterSystem.Kind.DROUGHT),
		"LEICHT: Duerre laesst sich nicht erzwingen")
	_check(is_equal_approx(soil.debug_soil_factor(0.0), 1.0),
		"LEICHT: Bodenfaktor exakt 1.0")
	_check(is_equal_approx(myco.debug_bonus(t2), 1.0),
		"LEICHT: Netz-Faktor exakt 1.0")
	_check(is_equal_approx(Global.difficulty_factor("soil_complexity"), 0.0),
		"LEICHT: soil_complexity = 0.0")
	_check(is_equal_approx(Global.difficulty_factor("disaster_rate"), 0.0),
		"LEICHT: disaster_rate = 0.0")

	Global.set_difficulty(Global.Difficulty.NORMAL)
	_check(not soil.debug_is_active(), "NORMAL: weiterhin keine N-P-K-Wirkung")
	_check(not Global.difficulty_toggle("nutrients"),
		"NORMAL: nutrients-Schalter bleibt aus (P3-Regression)")
	_check(disasters.enabled(), "NORMAL: seltene Katastrophen erlaubt")
	_check(is_equal_approx(disasters.debug_rate(), 0.35),
		"NORMAL: disaster_rate = 0.35")
	var normal_kinds := disasters.debug_allowed_kinds()
	_check(normal_kinds.size() == 2
		and normal_kinds.has(DisasterSystem.Kind.STORM)
		and normal_kinds.has(DisasterSystem.Kind.BEETLE)
		and not normal_kinds.has(DisasterSystem.Kind.DROUGHT),
		"NORMAL: nur Sturm und Borkenkaefer, keine Duerre")
	_check(not disasters.debug_force(DisasterSystem.Kind.DROUGHT),
		"NORMAL: Duerre bleibt SCHWER vorbehalten")
	_check(disasters.debug_force(DisasterSystem.Kind.STORM),
		"NORMAL: seltener Sturm kann starten")
	_check(disasters.debug_last_event() == "STORM", "NORMAL: Ereignis = STORM")
	disasters.debug_end()
	_check(is_equal_approx(soil.debug_soil_factor(0.0), 1.0),
		"NORMAL: Bodenfaktor exakt 1.0")
	_check(is_equal_approx(myco.debug_bonus(t2), 1.0),
		"NORMAL: Netz-Faktor exakt 1.0")
	_check(is_equal_approx(Global.difficulty_factor("soil_complexity"), 0.5),
		"NORMAL: soil_complexity = 0.5 (Referenzwert)")
	hud.refresh()
	_check(hud.debug_soil_text().contains("Boden einfach"),
		"HUD NORMAL zeigt vereinfachten Boden")

	Global.set_difficulty(Global.Difficulty.SCHWER)
	_check(Global.difficulty_toggle("ph")
		and Global.difficulty_toggle("nutrients")
		and Global.difficulty_toggle("mycorrhiza"),
		"SCHWER: pH / N-P-K / Mykorrhiza-Schalter aktiv (P3-Regression)")
	_check(soil.debug_is_active(), "SCHWER: Bodenchemie wirkt")
	_check(not myco.debug_active(), "SCHWER: ohne Skill kein aktives Netz")
	_check(is_equal_approx(myco.debug_penalty(), 0.55),
		"SCHWER: Mykorrhiza-Malus ohne Netz = 0.55")
	_check(is_equal_approx(myco.debug_bonus(t2), 0.55),
		"SCHWER: naehrstoff-Faktor ohne Netz gedrosselt")
	_check(is_equal_approx(t2.debug_mycorrhiza_factor(), 0.55),
		"SCHWER: Malus steckt in environment_parts()")
	_check(is_equal_approx(Global.difficulty_factor("soil_complexity"), 1.0),
		"SCHWER: soil_complexity = 1.0")
	_check(is_equal_approx(disasters.debug_rate(), 2.0),
		"SCHWER: disaster_rate = 2.0")
	_check(disasters.debug_allowed_kinds().size() == 3,
		"SCHWER: alle drei Katastrophen erlaubt")
	_check(absf(soil.debug_soil_factor(0.0)
		- soil.debug_availability(0.0)) < 0.001,
		"SCHWER: Bodenfaktor = echte Verfuegbarkeit")

	# --- 3) pH-Glocke, Liebigs Minimum, Regionen ----------------------------
	soil.reset(Global.world_seed)
	var ph0 := soil.debug_ph(256.0)
	var npk0 := soil.debug_npk(256.0)
	soil.reset(Global.world_seed)
	var npk1 := soil.debug_npk(256.0)
	_check(is_equal_approx(soil.debug_ph(256.0), ph0),
		"Gleicher Seed + gleiche Region = gleicher pH")
	_check(absf(npk1.x - npk0.x) < 0.001
		and absf(npk1.y - npk0.y) < 0.001
		and absf(npk1.z - npk0.z) < 0.001,
		"Gleicher Seed + gleiche Region = gleiche N/P/K")
	_check(soil.region_at(0.0) == 0 and soil.region_at(63.9) == 0
		and soil.region_at(64.0) == 1 and soil.region_at(-1.0) == -1,
		"64px-Regionen sind stabil und grenzen korrekt ab")
	soil.debug_set_all(0.0, 6.0, 100.0, 100.0, 100.0)
	var good := soil.debug_availability(0.0)
	_check(is_equal_approx(soil.debug_ph_fit(0.0), 1.0),
		"pH 6.0 = Eichen-Optimum (Fit 1.0)")
	_check(is_equal_approx(soil.debug_limiting(0.0), 1.0),
		"Volle N/P/K = kein Liebig-Minimum")
	_check(is_equal_approx(good, 1.20),
		"Optimale Region: Verfuegbarkeit 1.20")
	_check(is_equal_approx(soil.debug_soil_factor(0.0), 1.20),
		"Optimale Region: Bodenfaktor 1.20")
	soil.debug_set_ph(0.0, 4.2)
	var bad_ph := soil.debug_availability(0.0)
	_check(soil.debug_ph_fit(0.0) <= 0.21 and bad_ph < good,
		"Schlechter pH senkt Verfuegbarkeit deutlich")
	soil.debug_set_all(0.0, 6.0, 20.0, 100.0, 100.0)
	var low_n := soil.debug_availability(0.0)
	_check(soil.debug_limiting(0.0) <= 0.26 and low_n < good,
		"Liebig: knappes N limitiert trotz vollem P/K")
	_check(low_n > bad_ph - 0.001,
		"Liebig-Minimum und pH-Glocke sind zwei getrennte Regeln")

	# --- 4) Verbrauch und Regeneration ---------------------------------------
	soil.reset(Global.world_seed)
	soil.debug_set_all(t1.global_position.x, 6.0, 90.0, 90.0, 90.0)
	var n_before_grow := soil.debug_npk(t1.global_position.x).x
	var consumed_before := soil.debug_consumed()
	_check(t1.grow_part("leaf"), "Echter Blattzuwachs via grow_part()")
	_check(soil.debug_consumed() > consumed_before,
		"Wachstum verbraucht N/P/K bei SCHWER")
	_check(soil.debug_npk(t1.global_position.x).x < n_before_grow,
		"N in der Wurzelregion sinkt messbar")
	Global.set_difficulty(Global.Difficulty.NORMAL)
	var consumed_normal := soil.debug_consumed()
	var n_normal := soil.debug_npk(t1.global_position.x).x
	_check(t1.grow_part("leaf"), "Zweiter Zuwachs bei NORMAL moeglich")
	_check(is_equal_approx(soil.debug_consumed(), consumed_normal),
		"NORMAL verbraucht KEINE N/P/K (R0-R8 unveraendert)")
	_check(is_equal_approx(soil.debug_npk(t1.global_position.x).x, n_normal),
		"NORMAL laesst den Boden unveraendert")
	Global.set_difficulty(Global.Difficulty.SCHWER)
	soil.debug_set_all(1024.0, 6.0, 10.0, 10.0, 10.0)
	soil.debug_set_raining(false)
	soil.debug_regenerate(10.0)
	var dry_gain := soil.debug_npk(1024.0).x - 10.0
	soil.debug_set_all(1024.0, 6.0, 10.0, 10.0, 10.0)
	soil.debug_set_raining(true)
	soil.debug_regenerate(10.0)
	var wet_gain := soil.debug_npk(1024.0).x - 10.0
	soil.debug_set_raining(false)
	_check(dry_gain > 0.0, "Humus regeneriert N/P/K ohne Regen")
	_check(wet_gain > dry_gain, "Regen beschleunigt die Regeneration")
	var info := interaction.debug_soil_info_at(Vector2(0.0, 500.0))
	_check(info.contains("pH") and info.contains("Verfuegbarkeit"),
		"Rechtsklick zeigt pH / N-P-K / Verfuegbarkeit")
	Global.set_difficulty(Global.Difficulty.NORMAL)
	_check(interaction.debug_soil_info_at(Vector2(0.0, 500.0))
		.contains("nur bei SCHWER"),
		"Rechtsklick NORMAL zeigt vereinfachten Boden")
	Global.set_difficulty(Global.Difficulty.SCHWER)

	# --- 5) Mykorrhiza -------------------------------------------------------
	skill_tree.reset()
	myco.debug_force_rebuild()
	_check(not myco.debug_skill_active(), "Ohne Symbiose-Skill kein Pilznetz")
	_check(myco.debug_link_count() == 0, "Ohne Skill keine Verbindungen")
	_check(skill_tree.debug_unlock("root_efficiency"),
		"Vorbedingung root_efficiency freigeschaltet")
	_check(skill_tree.debug_unlock("leaf_efficiency"),
		"Vorbedingung leaf_efficiency freigeschaltet")
	_check(skill_tree.debug_unlock("symbiosis"),
		"Symbiose-Knoten freigeschaltet")
	_check(skill_tree.debug_unlock("mushroom_node"),
		"Pilz-Knoten freigeschaltet")
	_check(skill_tree.debug_unlock("humus_net"),
		"Humusnetz-Knoten freigeschaltet")
	_check(myco.debug_skill_active(), "Symbiose-Skill aktiv")
	_check(myco.debug_active(), "SCHWER + Skill = aktives Mykorrhiza-Netz")
	myco.debug_force_rebuild()
	_check(myco.debug_link_count() == 2,
		"Drei Baeume innerhalb von 280px -> genau zwei Netzverbindungen")
	_check(myco.debug_bonus(t2) > 1.0,
		"Vernetzter Baum erhaelt Naehrstoff-Bonus")
	soil.debug_set_all(t2.global_position.x, 6.0, 100.0, 100.0, 100.0)
	_check(t2.debug_soil_factor() > 1.0,
		"pH/N-P-K-Faktor bleibt bei SCHWER wirksam")
	_check(t2.debug_mycorrhiza_factor() > 1.0,
		"Netz-Bonus steckt in environment_parts()")
	_check(float(t2.environment_parts(1.0)["nutrients"]) > 0.15,
		"Versorgungsbilanz bleibt positiv und messbar")
	hud.refresh()
	_check(hud.debug_soil_text().contains("Netz an"),
		"HUD zeigt aktives Pilznetz")
	var far_a := interaction.spawn_tree_at(Vector2(5008.0, 0.0), {})
	var far_b := interaction.spawn_tree_at(Vector2(5200.0, 0.0), {})
	_check(far_a != null and far_b != null,
		"Zwei weitere Baeume ausserhalb der Kamera angelegt")
	_check(camera != null
		and absf(far_a.global_position.x - camera.global_position.x) > 1000.0,
		"Testpunkt liegt mehr als 1000px ausserhalb der Kamera")
	myco.debug_force_rebuild()
	_check(myco.debug_link_count() == 3,
		"Pilznetz verbindet auch OFF-SCREEN Baeume weltweit")
	Global.set_difficulty(Global.Difficulty.NORMAL)
	_check(not myco.debug_active()
		and is_equal_approx(myco.debug_bonus(t2), 1.0),
		"NORMAL: sichtbares Netz ohne Simulationswirkung")
	Global.set_difficulty(Global.Difficulty.SCHWER)

	# --- 6) Katastrophen mit echten Werten ----------------------------------
	disasters.from_dict({})
	_reset_tree_values()
	_check(disasters.debug_force(DisasterSystem.Kind.STORM),
		"SCHWER: Sturm startet")
	disasters.debug_tick(2.0)
	var storm_no_res := disasters.debug_damage()
	_check(storm_no_res > 0.0, "Sturm verursacht Gesamtschaden")
	_check(t2.health < 100.0, "Sturm senkt Gesundheit des Baums")
	_check(disasters.debug_active_kind() == DisasterSystem.Kind.STORM,
		"Sturm bleibt waehrend des Ticks aktiv")
	disasters.debug_end()
	_check(disasters.debug_active_kind() == DisasterSystem.Kind.NONE,
		"Ereignis endet sauber")
	_check(skill_tree.debug_unlock("spread"), "Resistenzkette: Verbreitung")
	_check(skill_tree.debug_unlock("parasite_res"),
		"Resistenzkette: Parasiten-Resistenz")
	_check(skill_tree.debug_unlock("disease_res"),
		"Resistenzkette: Krankheits-Resistenz")
	_check(skill_tree.debug_unlock("wood_hardness"),
		"Resistenzkette: Holz-Haerte")
	_check(is_equal_approx(skill_tree.resistance("storm_risk"), 0.5),
		"Holz-Haerte halbiert Sturmrisiko")
	_check(is_equal_approx(skill_tree.resistance("parasite_risk"), 0.5),
		"Parasiten-Resistenz halbiert Borkenkaefer-Risiko")
	disasters.from_dict({})
	_reset_tree_values()
	_check(disasters.debug_force(DisasterSystem.Kind.STORM),
		"Zweiter Sturm mit Resistenz startet")
	disasters.debug_tick(2.0)
	var storm_res := disasters.debug_damage()
	_check(storm_res > 0.0 and storm_res < storm_no_res * 0.60,
		"Resistenz halbiert den Sturmschaden")
	disasters.debug_end()

	disasters.from_dict({})
	_reset_tree_values()
	soil.debug_set_raining(true)
	_check(disasters.debug_force(DisasterSystem.Kind.DROUGHT),
		"SCHWER: Duerre startet")
	disasters.debug_tick(2.0)
	_check(t2.water < 100.0, "Duerre entzieht allen Baeumen Wasser")
	_check(not soil.raining, "Duerre stoppt die Boden-Regeneration")
	_check(disasters.debug_last_event() == "DROUGHT",
		"Ereignistyp DROUGHT protokolliert")
	disasters.debug_end()

	disasters.from_dict({})
	_reset_tree_values()
	_check(disasters.debug_force(DisasterSystem.Kind.BEETLE),
		"SCHWER: Borkenkaefer startet")
	disasters.debug_tick(2.0)
	_check(t2.glucose < 50.0, "Borkenkaefer entzieht Glucose")
	_check(disasters.debug_last_event() == "BEETLE",
		"Ereignistyp BEETLE protokolliert")
	disasters.debug_end()

	# --- 7) Grace, Pause, HUD, DE/EN -----------------------------------------
	disasters.from_dict({})
	disasters.debug_tick(299.0)
	_check(disasters.debug_active_kind() == DisasterSystem.Kind.NONE,
		"Vor 300s Grace startet kein Zufallsereignis")
	disasters.debug_tick(200.0)
	_check(disasters.debug_active_kind() != DisasterSystem.Kind.NONE,
		"Nach Grace + disaster_rate startet ein echtes Ereignis")
	_check(disasters.debug_event_count() == 1,
		"Ein natuerliches Ereignis gezaehlt")
	disasters.debug_end()
	disasters.from_dict({})
	time_manager.set_paused(true)
	disasters.debug_tick(10.0)
	_check(disasters.debug_active_kind() == DisasterSystem.Kind.NONE
		and is_equal_approx(disasters.debug_damage(), 0.0),
		"Pause stoppt Katastrophen-Ticks")
	time_manager.set_paused(false)
	disasters.from_dict({})
	_check(disasters.debug_force(DisasterSystem.Kind.STORM),
		"Sturm fuer HUD-/Sprachtest aktiv")
	hud.refresh()
	_check(hud.debug_event_text().contains("Ereignis")
		and hud.debug_event_text().contains("Sturm"),
		"HUD zeigt aktives Ereignis mit Restzeit")
	Global.locale = "en"
	hud.refresh_texts()
	hud.refresh()
	_check(hud.debug_event_text().contains("Event"),
		"EN: HUD-Ereigniszeile lokalisiert")
	_check(tr("DISASTER_STORM") == "Storm",
		"EN: Katastrophenname lokalisiert")
	Global.locale = "de"
	hud.refresh_texts()
	hud.refresh()
	_check(tr("MSG_SOIL_CHEM_OFF").contains("nur bei SCHWER"),
		"DE: Boden-Hinweis lokalisiert")
	disasters.debug_end()
	hud.refresh()
	_check(hud.debug_event_text().contains("keines"),
		"HUD zeigt nach Ereignisende 'keines'")

	# --- 8) Save/Load v6 mit optionalen P6-Schluesseln ----------------------
	Global.set_difficulty(Global.Difficulty.SCHWER)
	soil.debug_set_all(0.0, 6.2, 71.0, 72.0, 73.0)
	soil.debug_set_all(1024.0, 5.1, 31.0, 32.0, 33.0)
	soil.consume(1024.0, 1.3)
	disasters.from_dict({})
	disasters.debug_force(DisasterSystem.Kind.STORM)
	disasters.debug_tick(1.0)
	disasters.debug_end()
	var saved_damage := disasters.debug_damage()
	_check(saved_damage > 0.0, "Save-Test: Ereignisschaden vorhanden")
	_check(save_manager.save_game(), "Savegame mit P6-Zustand geschrieben")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary, "Savegame ist gueltiges JSON")
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_check(int(d.get("version", 0)) == 6,
			"Save-Format bleibt v6")
		_check(d.has("soil") and d.has("disasters") and d.has("mycorrhiza"),
			"Optionale P6-Schluessel im Savegame")
	soil.debug_set_all(0.0, 4.2, 1.0, 1.0, 1.0)
	soil.debug_set_all(1024.0, 7.8, 1.0, 1.0, 1.0)
	disasters.from_dict({})
	_check(save_manager.load_game(), "Savegame mit P6-Zustand geladen")
	myco.debug_force_rebuild()
	hud.refresh()
	_check(is_equal_approx(soil.debug_ph(0.0), 6.2),
		"pH nach Laden wiederhergestellt")
	_check(absf(soil.debug_npk(0.0).x - 71.0) < 0.001
		and absf(soil.debug_npk(0.0).y - 72.0) < 0.001
		and absf(soil.debug_npk(0.0).z - 73.0) < 0.001,
		"N/P/K nach Laden wiederhergestellt")
	_check(is_equal_approx(soil.debug_ph(1024.0), 5.1),
		"Zweite Bodenregion nach Laden wiederhergestellt")
	_check(soil.debug_consumed() > 0.0,
		"Gesamtverbrauch nach Laden erhalten")
	_check(disasters.debug_event_count() == 1
		and disasters.debug_damage() > 0.0,
		"Ereigniszaehler + Schaden nach Laden erhalten")
	_check(disasters.debug_active_kind() == DisasterSystem.Kind.NONE,
		"Laufendes Ereignis wird NICHT fortgesetzt")
	_check(skill_tree.is_unlocked("symbiosis")
		and skill_tree.is_unlocked("wood_hardness"),
		"Skilltree inkl. Symbiose/Resistenz nach Laden erhalten")
	_check(myco.debug_link_count() >= 2,
		"Pilznetz nach Laden neu verbunden")
	_check(hud.debug_soil_text().contains("pH"),
		"HUD zeigt nach Laden wieder Bodenchemie")

	# --- 9) Regression / Dateianker ------------------------------------------
	_check(SaveManager.FORMAT_VERSION == 6, "Save-Format weiterhin v6")
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"REVISION-5-Glucosetempo unveraendert")
	_check(PixelArt.PATHS.size() == 21, "21 zentrale Pixelart-Slots erhalten")
	_check(skill_tree.all_nodes().size() == 24,
		"Weiterhin 24 Skilltree-Knoten")
	_check(skill_tree.connection_pairs().size() == 23,
		"Weiterhin 23 Skilltree-Verbindungen")
	_check(is_equal_approx(SoilChemistry.REGION_PX, 64.0),
		"P6-Regionen bleiben 64px")
	_check(is_equal_approx(Mycorrhiza.LINK_RADIUS, 280.0),
		"P6-Netzreichweite bleibt 280px")
	_check(is_equal_approx(DisasterSystem.GRACE_SECONDS, 300.0),
		"P6-Grace bleibt 300s")
	_check(is_equal_approx(DisasterSystem.EVENT_DURATION, 24.0),
		"P6-Ereignisdauer bleibt 24s")
	_check(FileAccess.file_exists("res://src/systems/SoilChemistry.gd")
		and FileAccess.file_exists("res://src/systems/Mycorrhiza.gd")
		and FileAccess.file_exists("res://src/systems/DisasterSystem.gd"),
		"Drei modulare P6-Systeme vorhanden")
	var csv := FileAccess.get_file_as_string("res://data/localization.csv")
	_check(csv.split("\n").size() >= 225
		and csv.contains("HUD_PHASE6")
		and csv.contains("HUD_SOIL_FULL")
		and csv.contains("MSG_DISASTER_DROUGHT")
		and csv.contains("MSG_MYCORRHIZA_ACTIVE"),
		"Lokalisierung enthaelt alle P6-Schluessel")
	var any_tree: BaseTree = null
	for n in get_tree().get_nodes_in_group("trees"):
		if n is BaseTree:
			any_tree = n as BaseTree
			break
	_check(any_tree != null, "Nach Laden existiert mindestens ein Baum")
	if any_tree != null:
		any_tree.add_root()
		var seg = any_tree.root_segments[0] if any_tree.root_segments.size() > 0 else null
		_check(seg != null and seg.hit_rect().size == Vector2(16.0, 16.0),
			"Logisches 16x16-Raster fuer Wasser/Klick/Save erhalten")

	_finish()


func _reset_tree_values() -> void:
	for n in get_tree().get_nodes_in_group("trees"):
		if n is BaseTree:
			var t := n as BaseTree
			t.water = 100.0
			t.health = 100.0
			t.glucose = 50.0


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-70s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
