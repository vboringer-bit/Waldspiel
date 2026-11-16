extends Node
## Headless-Smoke-Test PHASE 8 (fünfte Tierart / Vogel-Progression, Master 7):
##   godot --headless --path . -- --p8-smoke
##
## Zentrale Invariante: ADVANCED bleibt ["woodpecker","squirrel"] und der
## Vogel erscheint NUR bei health > 50 % UND allen drei entdeckten Biomen.
## In keinem R0-R8-/P6-/P7-Smoke ist mehr als ein Biom entdeckt -> alle
## alten 783 Checks bleiben unveraendert gruen.

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
var gen: WorldGenerator

var _failures: Array[String] = []
var _bird_spawns := 0
var _carries := 0
var _left_carries := 0
var _planted := 0


func setup(p_interaction: InteractionController, p_chunks: ChunkManager,
		p_hud: HUD, p_save: SaveManager, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_season: SeasonSystem,
		p_wildlife: WildlifeSystem, p_health: ForestHealth,
		p_biomes: BiomeSystem, p_camera: CameraController) -> void:
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
	gen = p_chunks.generator


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === PHASE 8: fünf Tierarten, Vogel-Progression ===")
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
	interaction.clear_trees()
	interaction.set_seed_count(0)
	EventBus.animal_spawned.connect(func(sp): if sp == "bird": _bird_spawns += 1)
	EventBus.seed_carried.connect(func(from, to):
		_carries += 1
		if to.x < from.x: _left_carries += 1)
	EventBus.seed_planted_remote.connect(func(_p): _planted += 1)
	biomes.reset()
	wildlife.reset()
	forest_health.debug_set_biodiversity(10)
	hud.refresh()

	# --- 1) Basis / Regression: vier Arten wie in PHASE 5 -------------------
	_check(wildlife.debug_species_count() == 4,
		"P5-Regression: gesunder Wald hat weiterhin genau 4 Arten")
	_check(not wildlife.has_species("bird"),
		"Ohne alle drei Biome bleibt der Vogel abwesend")
	_check(wildlife.count_species("worm") == 2,
		"2 Regenwuermer wie bisher")
	_check(wildlife.count_species("ant") == 2,
		"2 Ameisen wie bisher")
	_check(wildlife.has_species("woodpecker")
		and wildlife.has_species("squirrel"),
		"Specht und Eichhoernchen bei > 50 % Gesundheit")
	_check(wildlife.debug_total_animal_count() == 6,
		"6 Einzeltiere vor der P8-Progression")
	_check(forest_health.debug_value() > ForestHealth.THRESHOLD,
		"Wald ist gesund (Voraussetzung geprueft)")
	_check(biomes.debug_discovered() == 1,
		"Zu Beginn ist nur das Start-Biom entdeckt")
	_check(wildlife.debug_species_target() == 5,
		"Ziel sind 5 Tierarten (Master 7)")
	_check(not wildlife.debug_progression_ready(),
		"Progression noch nicht freigeschaltet")
	_check(wildlife.debug_progression_biomes() == 1,
		"Progression sieht genau 1 entdecktes Biom")
	_check(is_equal_approx(wildlife.debug_progression_health(),
		forest_health.debug_value()),
		"Progression liest die echte Wald-Gesundheit")
	_check(hud.debug_species_text().contains("4/5")
		and hud.debug_species_text().contains("noch 1 offen"),
		"HUD zeigt 4/5 und den fehlenden Vogel")
	_check(hud.debug_phase6_title() == "PHASE 8 · Tierwelt & Progression",
		"Panel heisst jetzt PHASE 8 · Tierwelt & Progression")
	_check(not hud.debug_biome_text().is_empty()
		and not hud.debug_soil_text().is_empty()
		and not hud.debug_event_text().is_empty(),
		"P7-Biom-, P6-Boden- und Ereigniszeile bleiben erhalten")

	# --- 2) Progression: Biom-Entdeckung schaltet den Vogel frei -----------
	biomes.debug_force_at(-8192.0)
	_check(biomes.debug_discovered() == 2
		and not wildlife.debug_progression_ready()
		and not wildlife.has_species("bird"),
		"Zwei Biome reichen noch nicht (trocken entdeckt)")
	_check(wildlife.debug_species_count() == 4,
		"Weiterhin 4 Arten nach dem zweiten Biom")
	biomes.debug_force_at(8192.0)
	_check(biomes.debug_discovered() == 3,
		"Alle drei Biome entdeckt")
	_check(wildlife.debug_progression_ready(),
		"P8-Progression jetzt freigeschaltet")
	_check(wildlife.has_species("bird"),
		"Vogel siedelt sich als fünfte Art an")
	_check(wildlife.debug_species_count() == 5,
		"Genau 5 Tierarten vorhanden")
	_check(wildlife.debug_total_animal_count() == 7,
		"7 Einzeltiere inklusive Vogel")
	_check(_bird_spawns >= 1,
		"animal_spawned('bird') wurde emittiert")
	hud.refresh()
	_check(hud.debug_species_text().contains("5/5")
		and hud.debug_species_text().contains("alle da"),
		"HUD zeigt 5/5 · alle da")
	wildlife.debug_force_progression()
	_check(wildlife.count_species("bird") == 1,
		"Progression ist idempotent (kein Doppel-Vogel)")
	_check(_bird_spawns == 1,
		"Genau ein Vogel-Spawn-Signal")

	# Dauerhafte Freischaltung: sinkende Gesundheit entfernt den Vogel NICHT.
	forest_health.debug_set_biodiversity(0)
	_check(forest_health.debug_value() <= ForestHealth.THRESHOLD,
		"Wald-Gesundheit faellt unter 50 %")
	_check(wildlife.has_species("bird"),
		"Vogel bleibt als freigeschalteter Meilenstein")
	_check(not wildlife.debug_progression_ready(),
		"Progression meldet korrekt 'Bedingung nicht mehr erfuellt'")
	forest_health.debug_set_biodiversity(10)
	_check(wildlife.debug_species_count() == 5,
		"Nach Erholung wieder 5 Arten")

	# --- 3) Vogel-Eigenschaften --------------------------------------------
	var bird := wildlife.debug_animal("bird")
	_check(bird != null, "Vogel-Instanz vorhanden")
	if bird == null:
		_finish()
		return
	_check(bird.species == "bird", "Species-Key ist 'bird'")
	_check(is_equal_approx(bird.home_x, WildlifeSystem.PROGRESSION_BIRD_X),
		"Vogel startet an der eigenen Progression-Position")
	_check(bird.generator == gen and bird.wildlife == wildlife,
		"Vogel kennt Generator und WildlifeSystem")
	_check(is_equal_approx(Animal.BIRD_HEIGHT, 96.0),
		"Flughoehe 96px ueber der Gelaendekante")
	_check(bird.position.y < gen.ground_y_at(bird.position.x) - 50.0,
		"Vogel fliegt sichtbar ueber dem Boden")
	_check(is_equal_approx(bird.speed(), 190.0),
		"Vogel-Geschwindigkeit 190 px/s")
	_check(is_equal_approx(bird.debug_body_span(), 34.0),
		"Vogel-Koerperbreite 34px")
	_check(bird.hit_rect().size == Vector2(40.0, 36.0),
		"Eigene, gut klickbare Vogel-Hitbox")
	_check(bird.get_info_text().contains("Vogel"),
		"Info-Toast nennt den Vogel")
	_check(bird.get_info_text().contains("unterwegs"),
		"Info-Toast zeigt den aktuellen Zustand")
	_check(wildlife.click_at(bird.global_position),
		"Vogel ist per Linksklick anklickbar")
	var sprite := bird.get_node_or_null("PixelBody")
	_check(sprite != null and sprite is Sprite2D and sprite.visible,
		"Vogel nutzt den vorhandenen PixelArt.BIRD-Platzhalter")
	_check(sprite != null and sprite.texture != null
		and sprite.texture.resource_path == PixelArt.BIRD,
		"Genau der bestehende bird.png-Slot (kein neues Asset)")
	_check(Animal.SPEED.has("bird") and Animal.RANGE.has("bird")
		and Animal.BODY_SPAN.has("bird"),
		"Vogel in allen drei Tier-Tabellen eingetragen")
	_check(WildlifeSystem.PROGRESSION == ["bird"],
		"Eigene PROGRESSION-Liste fuer die fünfte Art")
	_check(WildlifeSystem.ADVANCED == ["woodpecker", "squirrel"],
		"ADVANCED bleibt unveraendert (P5-Regression)")
	_check(not WildlifeSystem.ADVANCED.has("bird"),
		"Vogel ist bewusst NICHT in ADVANCED")
	_check(is_equal_approx(WildlifeSystem.BIRD_CARRY_INTERVAL, 30.0),
		"Eigener Samen-Transport-Takt 30s")
	_check(is_equal_approx(WildlifeSystem.REMOTE_OFFSET, 2304.0),
		"REMOTE_OFFSET des Eichhoernchens bleibt 2304px")

	# --- 4) StateMachine / Flug ---------------------------------------------
	bird.debug_set_state(Animal.State.WANDER)
	_check(bird.state_key() == "STATE_WANDER", "Zustand WANDER")
	bird.debug_set_state(Animal.State.CARRY)
	_check(bird.state_key() == "STATE_CARRY", "Zustand CARRY")
	bird.debug_set_state(Animal.State.EAT)
	_check(bird.state_key() == "STATE_EAT", "Zustand EAT")
	bird.debug_set_state(Animal.State.IDLE)
	_check(bird.state_key() == "STATE_IDLE", "Zustand IDLE")
	bird.debug_set_state(Animal.State.WANDER)
	var x0 := bird.position.x
	bird.target_x = x0 + 120.0
	bird.tick(0.5)
	_check(bird.position.x > x0, "Vogel bewegt sich im WANDER-Zustand")
	_check(bird.facing == 1, "Blickrichtung folgt der Bewegung")
	_check(bird.position.y < gen.ground_y_at(bird.position.x) - 50.0,
		"Vogel bleibt auch waehrend des Flugs oben")
	_check(bird.phase > 0.0, "Flug-Phase zaehlt mit")
	for _i in range(8):
		bird.tick(0.4)
	_check(is_instance_valid(bird) and bird.species == "bird",
		"Mehrere Flug-Ticks ohne Fehler")
	bird.debug_set_state(Animal.State.EAT)
	var food0 := wildlife.food
	bird.tick(3.0)
	_check(wildlife.food > food0, "Vogel gibt beim Fressen echtes Futter")

	# --- 5) Samen-Transport nach links -------------------------------------
	var trees0 := get_tree().get_nodes_in_group("trees").size()
	var carry_target := bird.home_x - 2304.0
	bird.assign_carry(carry_target)
	_check(bird.carrying_seed and bird.target_x < bird.home_x,
		"Vogel traegt die Eichel nach LINKS")
	_check(bird.state_key() == "STATE_CARRY",
		"Transport nutzt den vorhandenen CARRY-Zustand")
	for _i in range(24):
		bird.tick(0.5)
	# Nach der Ankunft darf der Vogel bereits weitergeflogen sein (WANDER/EAT
	# je nach Seed); entscheidend ist nur, dass CARRY sauber beendet wurde.
	_check(not bird.carrying_seed and bird.state != Animal.State.CARRY,
		"Nach Ankunft ist der Transport sauber beendet")
	_check(get_tree().get_nodes_in_group("trees").size() > trees0,
		"Am Flugziel entsteht ein echter neuer Baum")
	_check(_planted >= 1, "seed_planted_remote wurde emittiert")
	var carries0 := _carries
	wildlife.debug_step(30.0)
	_check(_carries > carries0, "Automatischer Transport-Takt laeuft")
	_check(_left_carries >= 1,
		"Mindestens ein Transport geht nach links (Vogel)")
	_check(wildlife.debug_bird_carry_timer() < 30.0,
		"Vogel-Takt wurde zurueckgesetzt")

	# --- 6) DE/EN -----------------------------------------------------------
	Global.locale = "en"
	hud.refresh_texts()
	hud.refresh()
	_check(hud.debug_species_text().contains("Species")
		and hud.debug_species_text().contains("all present"),
		"EN: Artenzeile lokalisiert")
	_check(tr("ANIMAL_BIRD") == "Bird"
		and bird.get_info_text().contains("Bird"),
		"EN: Vogel-Name lokalisiert")
	_check(tr("HUD_PHASE8") == "PHASE 8 · Wildlife & Progression",
		"EN: Panel-Titel lokalisiert")
	_check(tr("MSG_BIRD_REQUIRES").contains("forest health"),
		"EN: Progressions-Hinweis lokalisiert")
	_check(hud.debug_phase6_title() == "PHASE 8 · Wildlife & Progression",
		"EN: Panel zeigt den lokalisierten Titel")
	Global.locale = "de"
	hud.refresh_texts()
	hud.refresh()
	_check(hud.debug_species_text().contains("5/5"),
		"DE: zurueck auf deutsche Artenzeile")

	# --- 7) Save v6: Tierliste stellt den Vogel wieder her -----------------
	var d0 := wildlife.to_dict()
	var has_bird_in_dict := false
	for e in d0.get("animals", []):
		if String(e.get("species", "")) == "bird":
			has_bird_in_dict = true
	_check(has_bird_in_dict,
		"wildlife.to_dict() speichert die fünfte Art generisch")
	_check(save_manager.save_game(), "Savegame mit P8-Zustand geschrieben")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary, "Savegame ist gueltiges JSON")
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_check(int(d.get("version", 0)) == 6, "Save-Format bleibt v6")
		_check(d.has("biomes") and d.has("soil")
			and d.has("disasters") and d.has("wildlife"),
			"Alle optionalen P6/P7-Schluessel bleiben erhalten")
	biomes.reset()
	wildlife.reset()
	_check(not wildlife.has_species("bird"),
		"Vor dem Laden ist der Vogel entfernt")
	_check(biomes.debug_discovered() == 1,
		"Vor dem Laden ist nur ein Biom entdeckt")
	_check(save_manager.load_game(), "Savegame mit P8-Zustand geladen")
	_check(wildlife.has_species("bird"),
		"Vogel nach Laden wiederhergestellt")
	_check(biomes.debug_discovered() == 3,
		"P7-Biom-Entdeckungen nach Laden erhalten")
	hud.refresh()
	_check(hud.debug_species_text().contains("/5"),
		"HUD-Artenzeile nach Laden gefuellt")

	# --- 8) Regression / Dateianker -----------------------------------------
	_check(SaveManager.FORMAT_VERSION == 6, "Save-Format weiterhin v6")
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"REVISION-5-Glucosetempo unveraendert")
	_check(PixelArt.PATHS.size() == 21, "21 zentrale Pixelart-Slots erhalten")
	_check(PixelArt.PATHS.has("bird"), "bird.png ist einer dieser 21 Slots")
	_check(SkillTree.instance.all_nodes().size() == 24,
		"Weiterhin 24 Skilltree-Knoten")
	_check(SkillTree.instance.connection_pairs().size() == 23,
		"Weiterhin 23 Skilltree-Verbindungen")
	_check(is_equal_approx(SoilChemistry.REGION_PX, 64.0),
		"P6-Regionen bleiben 64px")
	_check(is_equal_approx(Mycorrhiza.LINK_RADIUS, 280.0),
		"P6-Netzreichweite bleibt 280px")
	_check(is_equal_approx(DisasterSystem.GRACE_SECONDS, 300.0),
		"P6-Grace bleibt 300s")
	_check(is_equal_approx(WorldGenerator.BIOME_CORE_PX, 2048.0)
		and is_equal_approx(WorldGenerator.BIOME_BLEND_PX, 4096.0),
		"P7-Biom-Zonen bleiben unveraendert")
	_check(is_equal_approx(Global.difficulty_factor("soil_complexity"), 0.5),
		"Schwierigkeits-Faktoren unveraendert")
	_check(EventBus.has_signal("biome_discovered")
		and EventBus.has_signal("animal_spawned")
		and EventBus.has_signal("seed_planted_remote"),
		"Alle benoetigten EventBus-Signale vorhanden")
	var csv := FileAccess.get_file_as_string("res://data/localization.csv")
	_check(csv.split("\n").size() >= 248
		and csv.contains("HUD_PHASE8")
		and csv.contains("ANIMAL_BIRD")
		and csv.contains("HUD_PHASE7")
		and csv.contains("HUD_PHASE6")
		and csv.contains("MSG_BIRD_CARRIED"),
		"Lokalisierung enthaelt alle P8-Schluessel + P6/P7-Erbe")
	_check(FileAccess.file_exists("res://tests/Phase8Smoke.gd"),
		"Neuer P8-Smoke ist Teil des Projekts")
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

	_finish()


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-70s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
