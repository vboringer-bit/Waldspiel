extends Node
## Headless-Smoke-Test PHASE 7 (drei Biome / Weltzonen nach Master 3.1):
##   godot --headless --path . -- --p7-smoke
##
## Zentrale Invariante: im temperierten Kern |x| <= 2048 px sind ALLE neuen
## Faktoren exakt 1.0 und die Blende exakt 0.0. Damit bleiben die
## R0-R8-/P6-Smokes (Arbeitsbereich |x| <= 1024 px) bitgenau unveraendert.

var interaction: InteractionController
var chunk_manager: ChunkManager
var hud: HUD
var save_manager: SaveManager
var growth: GrowthSystem
var water: WaterSystem
var time_manager: TimeManager
var season: SeasonSystem
var soil: SoilChemistry
var biomes: BiomeSystem
var camera: CameraController
var gen: WorldGenerator

var _failures: Array[String] = []
## PHASE 7: Integrationszaehler fuer die neuen EventBus-Signale.
var _biome_signals := 0
var _discover_signals := 0


func setup(p_interaction: InteractionController, p_chunks: ChunkManager,
		p_hud: HUD, p_save: SaveManager, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_season: SeasonSystem,
		p_soil: SoilChemistry, p_biomes: BiomeSystem,
		p_camera: CameraController) -> void:
	interaction = p_interaction
	chunk_manager = p_chunks
	hud = p_hud
	save_manager = p_save
	growth = p_growth
	water = p_water
	time_manager = p_time
	season = p_season
	soil = p_soil
	biomes = p_biomes
	camera = p_camera
	gen = p_chunks.generator


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === PHASE 7: drei Biome, Weltzonen, Biom-Faktoren ===")
	growth.set_process(false)
	water.set_process(false)
	season.set_process(false)
	soil.set_process(false)
	biomes.set_process(false)
	Global.locale = "de"
	Global.auto_mode = false
	Global.set_difficulty(Global.Difficulty.NORMAL)
	time_manager.set_paused(false)
	time_manager.set_time_scale(1.0)
	time_manager.debug_set_season(TimeManager.Season.SPRING, 1, 0.20)
	interaction.clear_trees()
	interaction.set_seed_count(0)
	biomes.reset()
	soil.reset(Global.world_seed)
	hud.refresh()
	EventBus.biome_changed.connect(func(_k, _b): _biome_signals += 1)
	EventBus.biome_discovered.connect(func(_k): _discover_signals += 1)

	# --- 1) Zonen, Grenzen, weiche Blende -----------------------------------
	_check(gen.world_seed == Global.world_seed, "Generator nutzt den Welt-Seed")
	_check(is_equal_approx(WorldGenerator.BIOME_CORE_PX, 2048.0),
		"1 Chunk temperierter Kern (2048px)")
	_check(is_equal_approx(WorldGenerator.BIOME_BLEND_PX, 4096.0),
		"2 Chunks weiche Blende (4096px)")
	_check(is_equal_approx(WorldGenerator.BIOME_FULL_PX, 6144.0),
		"3 Chunks bis zur vollen Auspraegung (6144px)")
	_check(gen.biome_at(0.0) == WorldGenerator.BiomeKind.TEMPERIERT,
		"Start x=0 ist temperiert")
	_check(gen.biome_at(-1024.0) == WorldGenerator.BiomeKind.TEMPERIERT
		and gen.biome_at(1024.0) == WorldGenerator.BiomeKind.TEMPERIERT,
		"Ganzes Smoke-Fenster -1024..1024 bleibt temperiert")
	_check(gen.biome_at(1000.0) == WorldGenerator.BiomeKind.TEMPERIERT,
		"Phase4Smoke-Baum bei x=1000 bleibt im Kern")
	_check(gen.biome_target_at(-8192.0) == WorldGenerator.BiomeKind.TROCKEN,
		"Links liegt das trockene Ziel-Biom")
	_check(gen.biome_target_at(8192.0) == WorldGenerator.BiomeKind.FEUCHT,
		"Rechts liegt das feuchte Ziel-Biom")
	_check(gen.biome_target_at(0.0) == WorldGenerator.BiomeKind.TEMPERIERT,
		"Kern hat kein Ziel-Biom")
	_check(gen.biome_at(-6144.0) == WorldGenerator.BiomeKind.TROCKEN,
		"Ab -6144px ist TROCKEN dominant")
	_check(gen.biome_at(6144.0) == WorldGenerator.BiomeKind.FEUCHT,
		"Ab +6144px ist FEUCHT dominant")
	_check(gen.biome_at(-8192.0) == WorldGenerator.BiomeKind.TROCKEN
		and gen.biome_at(8192.0) == WorldGenerator.BiomeKind.FEUCHT,
		"Beide aeusseren Zonen sind voll ausgepraegt")
	_check(is_equal_approx(gen.biome_blend_at(0.0), 0.0),
		"Blende im Start exakt 0.0")
	_check(is_equal_approx(gen.biome_blend_at(-2048.0), 0.0)
		and is_equal_approx(gen.biome_blend_at(2048.0), 0.0),
		"Blende bleibt bis zur Kerngrenze exakt 0.0")
	_check(is_equal_approx(gen.biome_blend_at(-1024.0), 0.0)
		and is_equal_approx(gen.biome_blend_at(1024.0), 0.0),
		"Blende bleibt im gesamten Testfenster exakt 0.0")
	_check(is_equal_approx(gen.biome_blend_at(6144.0), 1.0)
		and is_equal_approx(gen.biome_blend_at(-6144.0), 1.0),
		"Blende erreicht nach 3 Chunks exakt 1.0")
	_check(is_equal_approx(gen.biome_blend_at(20000.0), 1.0)
		and is_equal_approx(gen.biome_blend_at(-20000.0), 1.0),
		"Blende bleibt auch weit draussen bei 1.0")
	var b30 := gen.biome_blend_at(3000.0)
	var b40 := gen.biome_blend_at(4096.0)
	var b55 := gen.biome_blend_at(5500.0)
	_check(b30 > 0.0 and b30 < b40 and b40 < b55 and b55 < 1.0,
		"Blende steigt monoton und sanft (Smoothstep)")
	_check(absf(gen.biome_blend_at(-3000.0) - b30) < 0.20,
		"Linke und rechte Blende sind nahezu symmetrisch")
	var twin := WorldGenerator.new(Global.world_seed)
	_check(is_equal_approx(gen.biome_blend_at(-5000.0),
		twin.biome_blend_at(-5000.0))
		and is_equal_approx(gen.biome_blend_at(5000.0),
			twin.biome_blend_at(5000.0)),
		"Gleicher Seed = identische Biom-Blende")
	_check(is_equal_approx(gen.biome_noise_at(3000.0),
		twin.biome_noise_at(3000.0)),
		"Biom-Noise ist seed-deterministisch")
	var other := WorldGenerator.new(Global.world_seed + 17)
	_check(not is_equal_approx(gen.biome_noise_at(3000.0),
		other.biome_noise_at(3000.0)),
		"Anderer Seed verformt die Biom-Grenze anders")
	_check(is_equal_approx(other.biome_blend_at(0.0), 0.0),
		"Auch ein anderer Seed haelt den Kern exakt bei 0.0")

	# --- 2) Feuchte und die fuenf messbaren Faktoren ------------------------
	_check(is_equal_approx(gen.biome_moisture_at(0.0), 0.50),
		"Feuchte im Kern = 0.50 (P0-P6-Referenz)")
	_check(is_equal_approx(gen.biome_moisture_at(-8192.0), 0.15),
		"Feuchte TROCKEN = 0.15")
	_check(is_equal_approx(gen.biome_moisture_at(8192.0), 0.85),
		"Feuchte FEUCHT = 0.85")
	_check(gen.biome_moisture_at(-8192.0) < gen.biome_moisture_at(0.0)
		and gen.biome_moisture_at(0.0) < gen.biome_moisture_at(8192.0),
		"Feuchte-Reihenfolge trocken < temperiert < feucht")
	_check(is_equal_approx(gen.biome_moisture_factor_at(0.0), 1.0)
		and is_equal_approx(gen.biome_moisture_factor_at(-1024.0), 1.0)
		and is_equal_approx(gen.biome_moisture_factor_at(1024.0), 1.0),
		"Bodenwasser-Faktor im Kern exakt 1.0")
	_check(is_equal_approx(gen.biome_moisture_factor_at(-8192.0), 0.65)
		and is_equal_approx(gen.biome_moisture_factor_at(8192.0), 1.35),
		"Bodenwasser: 0.65 trocken / 1.35 feucht")
	_check(is_equal_approx(water.debug_biome_factor_at(0.0), 1.0),
		"WaterSystem liest Kern-Faktor 1.0")
	_check(water.debug_biome_factor_at(-8192.0) < 1.0
		and water.debug_biome_factor_at(8192.0) > 1.0,
		"WaterSystem uebernimmt die Biom-Feuchte echt")
	_check(is_equal_approx(gen.biome_cost_factor_at(0.0), 1.0),
		"Wurzel-Kosten im Kern exakt 1.0")
	_check(is_equal_approx(gen.biome_cost_factor_at(-8192.0), 1.30)
		and is_equal_approx(gen.biome_cost_factor_at(8192.0), 0.85),
		"Wurzel-Kosten: 1.30 trocken / 0.85 feucht")
	_check(gen.biome_reservoir_density_at(0.0) == 34,
		"Reservoir-Dichte im Kern bleibt 34 (Referenz)")
	_check(gen.biome_reservoir_density_at(-8192.0) == 18,
		"Reservoir-Dichte TROCKEN = 18")
	_check(gen.biome_reservoir_density_at(8192.0) == 52,
		"Reservoir-Dichte FEUCHT = 52")
	_check(gen.biome_reservoir_density_at(-8192.0)
		< gen.biome_reservoir_density_at(0.0)
		and gen.biome_reservoir_density_at(0.0)
		< gen.biome_reservoir_density_at(8192.0),
		"Weniger Reservoirs links, mehr rechts")
	_check(is_equal_approx(gen.biome_capacity_factor_at(0.0), 1.0),
		"Reservoir-Kapazitaet im Kern exakt 1.0")
	_check(is_equal_approx(gen.biome_capacity_factor_at(-8192.0), 0.70)
		and is_equal_approx(gen.biome_capacity_factor_at(8192.0), 1.40),
		"Reservoir-Kapazitaet: 0.70 / 1.40")
	_check(is_equal_approx(gen.biome_regen_factor_at(0.0), 1.0),
		"N/P/K-Regeneration im Kern exakt 1.0")
	_check(is_equal_approx(gen.biome_regen_factor_at(-8192.0), 0.70)
		and is_equal_approx(gen.biome_regen_factor_at(8192.0), 1.40),
		"N/P/K-Regeneration: 0.70 / 1.40")
	_check(is_equal_approx(gen.biome_tint_at(0.0).a, 0.0),
		"Kein Boden-Tint im Kern (Alpha 0)")
	_check(gen.biome_tint_at(-8192.0).a > 0.0
		and gen.biome_tint_at(8192.0).a > 0.0,
		"Beide aeusseren Biome werden eingefaerbt")
	_check(gen.biome_tint_at(-8192.0).r > gen.biome_tint_at(8192.0).r,
		"Trocken ist sandig-hell, feucht moosig-dunkel")
	_check(gen.biome_name_key(0.0) == "BIOME_TEMPERIERT"
		and gen.biome_name_key(-8192.0) == "BIOME_TROCKEN"
		and gen.biome_name_key(8192.0) == "BIOME_FEUCHT",
		"Lokalisierungs-Keys der drei Biome")
	_check(gen.biome_target_name_key(3000.0) == "BIOME_FEUCHT"
		and gen.biome_target_name_key(-3000.0) == "BIOME_TROCKEN",
		"Uebergangszonen nennen ihr Ziel-Biom")
	_check(gen.biome_label(-8192.0) == "Trocken"
		and gen.biome_label(8192.0) == "Feucht",
		"DE: Biom-Namen lokalisiert")

	# --- 3) Geometrie bitgenau unveraendert ---------------------------------
	var geom_ok := true
	var atlas_ok := true
	var mat_ok := true
	for gx in range(-64, 65):
		var wx := float(gx * WorldGenerator.TILE_SIZE)
		if not is_equal_approx(gen.height_smooth_at(wx),
				twin.height_smooth_at(wx)):
			geom_ok = false
		if gen.height_at(wx) != twin.height_at(wx):
			geom_ok = false
		if not is_equal_approx(gen.ground_y_at(wx), twin.ground_y_at(wx)):
			geom_ok = false
		var top := gen.surface_tile_y_at(wx)
		for ty in range(top, top + 40):
			if gen.cave_at(gx, ty) != twin.cave_at(gx, ty):
				geom_ok = false
			if gen.reservoir_at(gx, ty) != twin.reservoir_at(gx, ty):
				geom_ok = false
			if gen.atlas_slot_at(gx, ty) != twin.atlas_slot_at(gx, ty):
				atlas_ok = false
			if gen.material_at(gx, ty) != twin.material_at(gx, ty):
				mat_ok = false
	_check(geom_ok, "Hoehen/Hoehlen/Reservoirs im Kern bitgenau unveraendert")
	_check(atlas_ok, "Alle Atlas-Slots im Kern unveraendert")
	_check(mat_ok, "Alle Boden-Materialien im Kern unveraendert")
	var ty0 := gen.surface_tile_y_at(0.0) + 2
	_check(is_equal_approx(GrowthCost.for_tile(gen, 0, ty0), 10.0),
		"Akzeptanzkriterium: Wurzel kostet im Kern weiter 10 Glucose")
	_check(is_equal_approx(GrowthCost.for_tile(gen, 0, ty0, 1.35), 13.5),
		"Schwierigkeits-Scale wirkt unveraendert weiter")
	var ty_wet := gen.surface_tile_y_at(8192.0) + 2
	var expect_wet := GrowthCost.BASE \
		* GrowthCost.multiplier(gen.material_at(512, ty_wet)) \
		* gen.biome_cost_factor_at(8192.0)
	_check(is_equal_approx(GrowthCost.for_tile(gen, 512, ty_wet), expect_wet),
		"Feucht-Biom verbilligt den Wurzelkauf messbar")
	var ty_dry := gen.surface_tile_y_at(-8192.0) + 2
	var expect_dry := GrowthCost.BASE \
		* GrowthCost.multiplier(gen.material_at(-512, ty_dry)) \
		* gen.biome_cost_factor_at(-8192.0)
	_check(is_equal_approx(GrowthCost.for_tile(gen, -512, ty_dry), expect_dry),
		"Trocken-Biom verteuert den Wurzelkauf messbar")
	var h0 := ("%d_res_%d_%d" % [gen.world_seed, 0, ty0]).hash() & 0x7fffffff
	_check(is_equal_approx(gen.reservoir_capacity_at(0, ty0),
		60.0 + float(h0 % 61)),
		"Reservoir-Kapazitaet im Kern exakt wie vor P7")
	var hw := ("%d_res_%d_%d" % [gen.world_seed, 512, ty_wet]).hash() & 0x7fffffff
	_check(is_equal_approx(gen.reservoir_capacity_at(512, ty_wet),
		(60.0 + float(hw % 61)) * 1.40),
		"Feucht-Biom erhoeht die Startkapazitaet um 40 Prozent")
	var hd := ("%d_res_%d_%d" % [gen.world_seed, -512, ty_dry]).hash() & 0x7fffffff
	_check(is_equal_approx(gen.reservoir_capacity_at(-512, ty_dry),
		(60.0 + float(hd % 61)) * 0.70),
		"Trocken-Biom senkt die Startkapazitaet um 30 Prozent")

	# --- 4) Boden-Regeneration pro Region (echter P6-Anschluss) -------------
	soil.reset(Global.world_seed)
	soil.debug_set_raining(false)
	soil.debug_set_all(0.0, 6.0, 10.0, 10.0, 10.0)
	soil.debug_set_all(-8192.0, 6.0, 10.0, 10.0, 10.0)
	soil.debug_set_all(8192.0, 6.0, 10.0, 10.0, 10.0)
	_check(soil.debug_region_count() == 3, "Drei Bodenregionen angelegt")
	soil.debug_regenerate(10.0)
	var gain_core := soil.debug_npk(0.0).x - 10.0
	var gain_dry := soil.debug_npk(-8192.0).x - 10.0
	var gain_wet := soil.debug_npk(8192.0).x - 10.0
	_check(gain_core > 0.0 and gain_dry > 0.0 and gain_wet > 0.0,
		"Alle drei Regionen regenerieren N/P/K")
	_check(is_equal_approx(gain_core, SoilChemistry.REGEN_BASE * 10.0),
		"Kern regeneriert exakt wie vor P7")
	_check(gain_wet > gain_core and gain_core > gain_dry,
		"Feucht regeneriert schneller, trocken langsamer")
	_check(is_equal_approx(gain_wet, gain_core * 1.40)
		and is_equal_approx(gain_dry, gain_core * 0.70),
		"Regenerations-Faktoren 1.40 / 0.70 sind exakt")

	# --- 5) Rechtsklick / HUD / BiomeSystem ----------------------------------
	# R5/R7 zeigen ihre Bilanz nur fuer einen AUSGEWAEHLTEN Baum.
	var probe := interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	interaction.select_tree(probe)
	hud.refresh()
	var info0 := interaction.debug_soil_info_at(Vector2(0.0, 500.0))
	var info_dry := interaction.debug_soil_info_at(Vector2(-8192.0, 500.0))
	var info_wet := interaction.debug_soil_info_at(Vector2(8192.0, 500.0))
	_check(info0.contains("Temperiert") and info0.contains("Kosten x1.00"),
		"Rechtsklick im Kern: temperiert, Kosten x1.00")
	_check(info_dry.contains("Trocken") and info_dry.contains("Feuchte 15%")
		and info_dry.contains("Kosten x1.30"),
		"Rechtsklick links: Trocken, 15%, Kosten x1.30")
	_check(info_wet.contains("Feucht") and info_wet.contains("Feuchte 85%")
		and info_wet.contains("Kosten x0.85"),
		"Rechtsklick rechts: Feucht, 85%, Kosten x0.85")
	biomes.reset()
	_check(biomes.debug_kind() == WorldGenerator.BiomeKind.TEMPERIERT
		and is_equal_approx(biomes.debug_blend(), 0.0),
		"BiomeSystem startet im temperierten Kern")
	_check(biomes.debug_discovered() == 1
		and biomes.debug_has_discovered(WorldGenerator.BiomeKind.TEMPERIERT)
		and biomes.debug_visits() == 0,
		"Start-Biom ist entdeckt, noch keine Wechsel")
	biomes.debug_force_at(3000.0)
	_check(biomes.debug_kind() == WorldGenerator.BiomeKind.TEMPERIERT
		and biomes.debug_blend() > 0.0 and biomes.debug_blend() < 0.5,
		"Uebergangszone bleibt temperiert mit Teilblende")
	_check(biomes.debug_display().contains("Feucht")
		and biomes.debug_display().contains("->"),
		"HUD benennt das Ziel-Biom im Uebergang")
	biomes.debug_force_at(-8192.0)
	_check(biomes.debug_kind() == WorldGenerator.BiomeKind.TROCKEN
		and is_equal_approx(biomes.debug_blend(), 1.0),
		"Kamera-Sprung links => TROCKEN, Blende 1.0")
	_check(biomes.debug_discovered() == 2
		and biomes.debug_has_discovered(WorldGenerator.BiomeKind.TROCKEN)
		and biomes.debug_visits() == 1,
		"Trocken-Biom entdeckt und ein Wechsel gezaehlt")
	hud.refresh()
	_check(hud.debug_biome_text().contains("Trocken")
		and hud.debug_biome_text().contains("15%"),
		"HUD zeigt Trocken mit 15% Feuchte")
	biomes.debug_force_at(8192.0)
	_check(biomes.debug_kind() == WorldGenerator.BiomeKind.FEUCHT
		and biomes.debug_discovered() == 3
		and biomes.debug_visits() == 2,
		"Alle drei Biome entdeckt, zwei Wechsel")
	hud.refresh()
	_check(hud.debug_biome_text().contains("Feucht")
		and hud.debug_biome_text().contains("85%"),
		"HUD zeigt Feucht mit 85% Feuchte")
	_check(hud.debug_phase6_title() == "PHASE 7 · Welt & Biome",
		"Oekologie-Panel heisst jetzt PHASE 7 · Welt & Biome")
	_check(hud.debug_supply_text().contains("Versorgung")
		and hud.debug_light_text().contains("Licht"),
		"R5-Versorgung und R7-Licht bleiben erhalten")
	_check(not hud.debug_soil_text().is_empty()
		and not hud.debug_event_text().is_empty(),
		"P6-Boden- und Ereigniszeile bleiben erhalten")

	# --- 6) DE/EN ------------------------------------------------------------
	Global.locale = "en"
	hud.refresh_texts()
	biomes.debug_force_at(-8192.0)
	hud.refresh()
	_check(hud.debug_biome_text().contains("Dry")
		and hud.debug_biome_text().contains("moisture"),
		"EN: Biom-Zeile lokalisiert")
	_check(tr("BIOME_TROCKEN") == "Dry" and tr("BIOME_FEUCHT") == "Wet"
		and tr("BIOME_TEMPERIERT") == "Temperate",
		"EN: alle drei Biom-Namen lokalisiert")
	_check(biomes.debug_label_at(-8192.0) == "Dry"
		and biomes.debug_label_at(8192.0) == "Wet",
		"EN: Generator-Labels folgen der Sprache")
	_check(tr("MSG_SOIL_BIOME").contains("cost"),
		"EN: Bodeninfo-Schluessel lokalisiert")
	Global.locale = "de"
	hud.refresh_texts()
	biomes.debug_force_at(0.0)
	hud.refresh()
	_check(hud.debug_biome_text().contains("Temperiert"),
		"DE: zurueck auf Temperiert")

	# --- 7) Save v6 mit optionalem biomes-Key -------------------------------
	var t0 := probe
	var t1 := interaction.spawn_tree_at(Vector2(8192.0, 0.0), {})
	_check(t0 != null and t1 != null,
		"Zwei Baeume in unterschiedlichen Biomen angelegt")
	biomes.reset()
	biomes.debug_force_at(-8192.0)
	biomes.debug_force_at(8192.0)
	var saved := biomes.to_dict()
	_check(saved.has("discovered") and saved.has("visits")
		and saved.has("last") and saved.has("x"),
		"BiomeSystem.to_dict() liefert vollstaendigen Zustand")
	_check(save_manager.save_game(), "Savegame mit P7-Zustand geschrieben")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary, "Savegame ist gueltiges JSON")
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_check(int(d.get("version", 0)) == 6, "Save-Format bleibt v6")
		_check(d.has("biomes"), "Optionaler P7-Key 'biomes' im Savegame")
		_check(d.has("soil") and d.has("disasters")
			and d.has("mycorrhiza"),
			"Alle P6-Schluessel bleiben im Savegame erhalten")
	biomes.reset()
	_check(biomes.debug_discovered() == 1,
		"Zustand vor dem Laden absichtlich zurueckgesetzt")
	_check(save_manager.load_game(), "Savegame mit P7-Zustand geladen")
	_check(biomes.debug_discovered() == 3
		and biomes.debug_visits() == 2,
		"Entdeckungen und Wechsel nach Laden erhalten")
	_check(biomes.debug_kind() == WorldGenerator.BiomeKind.FEUCHT,
		"Letztes Biom nach Laden wiederhergestellt")
	biomes.from_dict({})
	_check(biomes.debug_discovered() == 0 and biomes.debug_visits() == 0,
		"Altes Save ohne 'biomes' liefert saubere Defaults")
	hud.refresh()

	# --- 8) Regression / Dateianker -----------------------------------------
	_check(SaveManager.FORMAT_VERSION == 6, "Save-Format weiterhin v6")
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"REVISION-5-Glucosetempo unveraendert")
	_check(PixelArt.PATHS.size() == 21, "21 zentrale Pixelart-Slots erhalten")
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
	_check(is_equal_approx(Global.difficulty_factor("soil_complexity"), 0.5),
		"NORMAL-Schwierigkeit unveraendert (P6-Referenz)")
	_check(WorldGenerator.TILE_SIZE == 16
		and WorldGenerator.CHUNK_WIDTH_PX == 2048,
		"16px-Raster und 2048px-Chunks unveraendert")
	_check(gen.biome_moisture_factor_at(5008.0) > 1.0,
		"P6-Offscreen-Testpunkt x=5008 liegt im Feucht-Biom")
	_check(FileAccess.file_exists("res://src/systems/BiomeSystem.gd")
		and FileAccess.file_exists("res://tests/Phase7Smoke.gd"),
		"Neue modulare P7-Dateien vorhanden")
	var csv := FileAccess.get_file_as_string("res://data/localization.csv")
	_check(csv.split("\n").size() >= 239
		and csv.contains("HUD_PHASE7")
		and csv.contains("HUD_PHASE6")
		and csv.contains("BIOME_TROCKEN")
		and csv.contains("MSG_SOIL_BIOME"),
		"Lokalisierung enthaelt alle P7-Schluessel + P6-Erbe")
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

	# --- 9) Signal-Integration, Uebergangs-Faktoren, Erbe -------------------
	_check(EventBus.has_signal("biome_changed")
		and EventBus.has_signal("biome_discovered"),
		"Zwei neue P7-Signale am EventBus registriert")
	_check(_biome_signals >= 4 and _discover_signals >= 3,
		"Biom-Wechsel und Entdeckungen werden wirklich emittiert")
	var mid_left := gen.biome_moisture_factor_at(-3000.0)
	var mid_right := gen.biome_moisture_factor_at(3000.0)
	_check(mid_left > 0.65 and mid_left < 1.0
		and mid_right > 1.0 and mid_right < 1.35,
		"Uebergangszonen interpolieren die Bodenfeuchte stetig")
	_check(gen.biome_cost_factor_at(-3000.0) > 1.0
		and gen.biome_cost_factor_at(-3000.0) < 1.30
		and gen.biome_cost_factor_at(3000.0) < 1.0
		and gen.biome_cost_factor_at(3000.0) > 0.85,
		"Wurzel-Kosten interpolieren im Uebergang stetig")
	_check(gen.biome_reservoir_density_at(-3000.0) < 34
		and gen.biome_reservoir_density_at(3000.0) > 34,
		"Reservoir-Dichte interpoliert im Uebergang stetig")
	_check(gen.biome_capacity_factor_at(-3000.0) < 1.0
		and gen.biome_capacity_factor_at(3000.0) > 1.0,
		"Reservoir-Kapazitaet interpoliert im Uebergang stetig")
	_check(gen.biome_regen_factor_at(-3000.0) < 1.0
		and gen.biome_regen_factor_at(3000.0) > 1.0,
		"N/P/K-Regeneration interpoliert im Uebergang stetig")
	_check(gen.biome_tint_at(3000.0).a > 0.0
		and gen.biome_tint_at(3000.0).a < gen.biome_tint_at(8192.0).a,
		"Boden-Tint blendet im Uebergang sanft ein")
	var info_mid := interaction.debug_soil_info_at(Vector2(3000.0, 500.0))
	_check(info_mid.contains("Feucht") and info_mid.contains("x0."),
		"Rechtsklick im Uebergang zeigt gemischte Kosten")
	_check(gen.biome_at(4096.0) == WorldGenerator.BiomeKind.TEMPERIERT
		or gen.biome_at(4096.0) == WorldGenerator.BiomeKind.FEUCHT,
		"Blend-Mitte gehoert zu einem der beiden angrenzenden Biome")
	_check(GrowthCost.multiplier(WorldGenerator.SoilKind.ROCK)
		> GrowthCost.multiplier(WorldGenerator.SoilKind.CLAY)
		and GrowthCost.multiplier(WorldGenerator.SoilKind.CLAY)
		> GrowthCost.multiplier(WorldGenerator.SoilKind.TOPSOIL),
		"P2-Bodenhaerte-Tabelle bleibt unveraendert")
	_check(WorldGenerator.SLOT_ASH == 0 and WorldGenerator.SLOT_MOSS == 14
		and WorldGenerator.SLOT_DRY_WATER == 16,
		"Atlas-Slot-Nummern bleiben unveraendert")
	_check(is_equal_approx(Global.difficulty_factor("disaster_rate"), 0.35)
		and Global.difficulty_toggle("disasters"),
		"P6-Katastrophen-Schalter bei NORMAL unveraendert")
	_check(is_equal_approx(gen.biome_moisture_factor_at(0.0),
		gen.biome_moisture_factor_at(-2048.0)),
		"Kerngrenze ist stetig (kein Sprung bei -2048px)")
	_check(biomes.kind_label(WorldGenerator.BiomeKind.TROCKEN) == "Trocken"
		and biomes.kind_label(WorldGenerator.BiomeKind.FEUCHT) == "Feucht",
		"BiomeSystem.kind_label() lokalisiert die Enum-Werte")
	_check(tr("MSG_BIOME_EDGES").contains("drei") or tr("MSG_BIOME_EDGES").contains("Drei"),
		"DE: Biom-Hinweistext lokalisiert")
	_check(not hud.debug_biome_text().is_empty(),
		"HUD-Biomzeile ist auch nach Save/Load gefuellt")
	var rt := biomes.to_dict()
	biomes.from_dict(rt)
	_check(biomes.debug_kind() == int(rt.get("last", -1))
		and biomes.debug_visits() == int(rt.get("visits", -1)),
		"BiomeSystem.to_dict/from_dict Roundtrip verlustfrei")

	_finish()


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-70s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
