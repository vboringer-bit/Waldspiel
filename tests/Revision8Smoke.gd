extends Node
## Headless-Smoke-Test REVISION 8 (gemeinsamer Glucose-Pool, Eicheln unter
## Baeumen anklickbar, weltweite Abstandsregel auch off-screen):
##   godot --headless --path . -- --rev8-smoke

var interaction: InteractionController
var skill_tree: SkillTree
var skill_ui: SkillTreeUI
var wildlife: WildlifeSystem
var chunk_manager: ChunkManager
var hud: HUD
var save_manager: SaveManager
var growth: GrowthSystem
var water: WaterSystem
var time_manager: TimeManager
var season_system: SeasonSystem
var camera: CameraController

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_skill_tree: SkillTree,
		p_skill_ui: SkillTreeUI, p_wildlife: WildlifeSystem,
		p_chunks: ChunkManager, p_hud: HUD, p_save: SaveManager,
		p_growth: GrowthSystem, p_water: WaterSystem, p_time: TimeManager,
		p_season: SeasonSystem, p_camera: CameraController) -> void:
	interaction = p_interaction
	skill_tree = p_skill_tree
	skill_ui = p_skill_ui
	wildlife = p_wildlife
	chunk_manager = p_chunks
	hud = p_hud
	save_manager = p_save
	growth = p_growth
	water = p_water
	time_manager = p_time
	season_system = p_season
	camera = p_camera


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === REVISION 8: Glucose-Pool, Eichel-Vorrang, Abstand weltweit ===")
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
	interaction.set_seed_count(0)
	skill_tree.reset()
	season_system.debug_force_germination = false
	season_system.debug_no_germination = false
	hud.refresh()

	# --- 1) Gemeinsamer Glucose-Pool -----------------------------------------
	var a := interaction.spawn_tree_at(Vector2(-320.0, 0.0), {})
	var b := interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	var c := interaction.spawn_tree_at(Vector2(320.0, 0.0), {})
	_check(a != null and b != null and c != null, "Drei Baeume fuer den Pool angelegt")
	a.glucose = 0.0
	b.glucose = 0.0
	c.glucose = 40.0
	_check(skill_tree.debug_pool_size() == 3, "Pool enthaelt ALLE 3 Baeume dieser Art")
	_check(absf(skill_tree.pooled_glucose() - 40.0) < 0.01,
		"Pool = Summe aller Baeume (40.0)")
	_check(absf(skill_tree.pooled_glucose(a) - 40.0) < 0.01,
		"Pool auch mit einzelnem Ankerbaum die Gesamtsumme")
	_check(skill_tree.species_key(a) == skill_tree.species_key(c),
		"Alle drei Baeume gehoeren zur selben Art")
	_check(skill_tree.skilltree_species_key() == "oak",
		"Skilltree gehoert zur Art 'oak'")
	_check(skill_tree.can_unlock("root_efficiency", a),
		"Kauf moeglich obwohl Ankerbaum 0 Glucose hat")
	_check(skill_tree.can_unlock("root_efficiency", null),
		"Kauf OHNE ausgewaehlten Baum moeglich")
	_check(not skill_tree.can_unlock("root_efficiency", null) == false,
		"Pool-Pruefung aktiv (nicht deaktiviert)")
	var cost := skill_tree.cost_of("root_efficiency")
	_check(absf(cost - 10.0) < 0.01, "Kosten des Testknotens = 10 Glucose")
	skill_ui.refresh()
	_check(skill_ui.debug_glucose_text().contains("40.0"),
		"Skilltree-UI zeigt den GESAMTEN Pool statt Baumglucose")
	_check(skill_tree.unlock("root_efficiency", null),
		"Freischalten ohne Auswahl erfolgreich")
	_check(skill_tree.is_unlocked("root_efficiency"), "Knoten ist freigeschaltet")
	_check(absf(skill_tree.pooled_glucose() - (40.0 - cost)) < 0.01,
		"Kosten exakt aus dem Pool bezahlt")
	var sum_after := a.glucose + b.glucose + c.glucose
	_check(absf(sum_after - (40.0 - cost)) < 0.01,
		"Abbuchung auf die Baeume summiert sich exakt")
	_check(a.glucose >= 0.0 and b.glucose >= 0.0 and c.glucose >= 0.0,
		"Kein Baum wird durch den Pool-Kauf negativ")
	var want := skill_tree.modifier("root_water")
	_check(absf(want - 1.25) < 0.01, "Effekt root_water = 1.25")
	_check(absf(a.skill_root_water_mult - want) < 0.01,
		"Effekt gilt fuer Baum A")
	_check(absf(b.skill_root_water_mult - want) < 0.01,
		"Effekt gilt fuer Baum B")
	_check(absf(c.skill_root_water_mult - want) < 0.01,
		"Effekt gilt fuer Baum C")
	var d := interaction.spawn_tree_at(Vector2(640.0, 0.0), {})
	_check(d != null and absf(d.skill_root_water_mult - want) < 0.01,
		"NEU spawnender Baum bekommt denselben Effekt")
	_check(save_manager.save_game(), "Speichern mit Pool-Stand")
	_check(save_manager.load_game(), "Laden mit Pool-Stand")
	_check(skill_tree.is_unlocked("root_efficiency"),
		"Skilltree-Zustand nach Laden erhalten")
	var applied := 0
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree and absf((t as BaseTree).skill_root_water_mult - 1.25) < 0.01:
			applied += 1
	_check(applied >= 3, "Effekte nach Laden auf alle Baeume der Art angewandt")

	# --- 2) Eichel direkt unter einem Baum -----------------------------------
	interaction.clear_trees()
	interaction.set_seed_count(0)
	var under := interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	for _i in 6:
		under.add_trunk_tile()
	var gy := season_system.generator.height_smooth_at(0.0)
	var click_pos := Vector2(0.0, gy - 10.0)
	_check(interaction.find_tree_at(click_pos) == under,
		"Baum ueberdeckt die Klickposition (Ausgangslage)")
	var seed_id := season_system.debug_spawn_seed_at(0.0, false)
	_check(not seed_id.is_empty(), "Eichel direkt unter dem Baum angelegt")
	_check(season_system.has_collectible_at(click_pos),
		"Eichel wird an dieser Position erkannt")
	var seeds_before := interaction.get_seed_count()
	interaction.debug_click_world_full(click_pos)
	_check(interaction.get_seed_count() == seeds_before + 1,
		"Eichel unter dem Baum wurde Aufgesammelt")
	_check(not interaction.debug_drag_pending(),
		"KEIN Drag am Baum gestartet (Eichel hatte Vorrang)")
	_check(season_system.collected.has(seed_id),
		"Eichel als eingesammelt markiert")
	_check(not season_system.has_collectible_at(click_pos),
		"Eichel verschwindet nach dem Aufsammeln")
	var seed_id2 := season_system.debug_spawn_seed_at(0.0, false)
	interaction.debug_click_world_full(click_pos)
	_check(season_system.collected.has(seed_id2),
		"Zweite Eichel unter demselben Baum ebenfalls einsammelbar")

	# --- 3) Abstandsregel gilt WELTWEIT (auch off-screen) --------------------
	interaction.clear_trees()
	var far_x := 5000.0
	var snapped_far := roundf(far_x / 16.0) * 16.0
	_check(camera != null and absf(camera.global_position.x - snapped_far) > 1000.0,
		"Pruefpunkt liegt weit AUSSERHALB des sichtbaren Bereichs")
	var big := interaction.spawn_tree_at(Vector2(far_x, 0.0), {})
	_check(big != null, "Off-screen Baum angelegt")
	_check(absf(interaction.debug_nearest_tree_distance(snapped_far)) < 0.01,
		"Off-screen Baum wird von der Abstandspruefung gefunden")
	_check(not interaction.can_spawn_tree_at(Vector2(snapped_far, 0.0)),
		"GLEICHER Platz off-screen ist blockiert")
	_check(not interaction.can_spawn_tree_at(Vector2(snapped_far + 32.0, 0.0)),
		"Zu naher Platz (32 px) off-screen ist blockiert")
	_check(interaction.can_spawn_tree_at(Vector2(snapped_far + 48.0, 0.0)),
		"Mindestabstand 48 px off-screen wird akzeptiert")
	_check(interaction.can_spawn_tree_at(Vector2(snapped_far + 400.0, 0.0)),
		"Weit entfernter Platz off-screen wird akzeptiert")
	_check(absf(interaction.debug_min_tree_spacing() - 48.0) < 0.01,
		"Mindestabstand ist 48 px (3 Tiles)")
	for _i in 40:
		big.add_trunk_tile()
	_check(big.trunk_tiles >= 20, "Off-screen Baum ohne Nachbarn voll ausgewachsen")
	var twin := interaction.spawn_tree_at(Vector2(far_x, 0.0), {})
	_check(twin != null and twin.tree_id != big.tree_id,
		"Zweiter Baum am SELBEN Platz hat eigene tree_id")
	_check(twin.debug_neighbor_shade() > 0.90,
		"d==0 erzeugt MAXIMALEN Schatten (R7-Loch d<1 behoben)")
	_check(big.debug_neighbor_shade() > 0.0,
		"Beschattung wirkt in beide Richtungen")
	_check(twin.debug_light_factor() < 0.45,
		"Zweiter Baum hat stark reduziertes Licht")
	_check(twin.debug_crowd_cap("trunk") < 28,
		"Wuchsgrenze des zweiten Baums gestutzt")
	for _i in 40:
		twin.add_trunk_tile()
	_check(twin.trunk_tiles <= twin.debug_crowd_cap("trunk"),
		"Zweiter Baum waechst NICHT voll aus")

	# --- 4) Natuerliche Keimung respektiert die Regel ------------------------
	season_system.debug_force_germination = true
	var ground_far := season_system.generator.height_smooth_at(snapped_far)
	var grew_near := season_system.debug_land_at(snapped_far)
	_check(not grew_near, "Keimung am selben Platz off-screen BLOCKIERT")
	_check(season_system.has_collectible_at(Vector2(snapped_far, ground_far - 10.0)),
		"Blockierte Eichel bleibt einsammelbar liegen")
	var grew_far := season_system.debug_land_at(snapped_far + 400.0)
	_check(grew_far, "Keimung 400 px entfernt off-screen funktioniert")
	season_system.debug_force_germination = false

	# --- 5) Regression -------------------------------------------------------
	_check(skill_tree.all_nodes().size() == 24, "Weiterhin 24 Skilltree-Knoten")
	_check(skill_tree.connection_pairs().size() == 23,
		"Weiterhin 23 Skilltree-Verbindungen")
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus")
	_check(SaveManager.FORMAT_VERSION == 6, "Save-Format bleibt v6")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"REVISION-5-Glucosetempo unveraendert")
	_check(PixelArt.PATHS.size() == 21, "21 zentrale Pixelart-Slots erhalten")
	var rs: RootSegment = null
	big.add_root()
	if big.root_segments.size() > 0:
		rs = big.root_segments[0]
	_check(rs != null and rs.hit_rect().size == Vector2(16.0, 16.0),
		"Logisches 16x16-Raster fuer Wasser/Klick/Save erhalten")
	_finish()


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-70s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
