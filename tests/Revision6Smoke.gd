extends Node
## Headless-Smoke-Test REVISION 6 (stabile Gänge, Rotation, Bodenbindung,
## gezielt ziehbares Wachstum, Verdickung, Pixelart-Slots, dichte Krone):
##   godot --headless --path . -- --rev6-smoke

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

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_skill_tree: SkillTree,
		p_skill_ui: SkillTreeUI, p_wildlife: WildlifeSystem,
		p_chunks: ChunkManager, p_hud: HUD, p_save: SaveManager,
		p_growth: GrowthSystem, p_water: WaterSystem, p_time: TimeManager,
		p_season: SeasonSystem) -> void:
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


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === REVISION 6: Ziehen, Verdickung, stabile Bodenfauna ===")
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
	skill_tree.reset()
	interaction.clear_trees()
	interaction.set_seed_count(0)
	wildlife.reset()
	hud.refresh()

	# --- 1) Wurm: stabiler Gang + Rotation nach Grabrichtung ---------------
	var worm := wildlife.debug_animal("worm")
	_check(worm != null, "Regenwurm vorhanden")
	if worm != null:
		var p0 := worm.debug_trail_point(0)
		wildlife.debug_step(1.2)
		var p1 := worm.debug_trail_point(0)
		_check(p0.distance_to(p1) < 0.001,
			"Gang-Mittellinie bleibt ortsfest (kein Wackeln)")
		_check(worm.debug_trail_size() >= 3,
			"Gang hat %d stabile Stuetzpunkte" % worm.debug_trail_size())
		worm.debug_hold_vertical(worm.burrow_depth + 70.0)
		wildlife.debug_step(3.0)
		var av := worm.debug_body_angle()
		_check(absf(sin(av)) > 0.75,
			"Wurm gräbt senkrecht -> Sprite senkrecht (%.2f rad)" % av)
		worm.debug_nudge_horizontal(20.0)
		var ah := worm.debug_body_angle()
		_check(absf(sin(ah)) < 0.35,
			"Wurm gräbt waagerecht -> Sprite waagerecht (%.2f rad)" % ah)
		_check(worm.debug_is_underground(), "Wurm bleibt unter der Erde")

	# --- 2) Ameisen: bodengebunden ------------------------------------------
	wildlife.debug_step(4.0)
	var ants := wildlife.debug_animals("ant")
	var grounded := ants.size() >= 2
	for a in ants:
		var an := a as Animal
		var gap := an.debug_ground_gap()
		if gap > 0.5 or gap < -6.0:
			grounded = false
	_check(grounded, "%d Ameisen laufen auf der Geländekante (kein Schweben)"
		% ants.size())

	# --- 3) Pixelart: alle Texturen an EINER zentralen Stelle --------------
	var slots := ["trunk", "branch", "root", "root_tip", "leaf", "worm",
		"ant", "acorn", "soil_atlas", "sky"]
	var slots_ok := PixelArt.PATHS.size() >= 21
	for key in slots:
		if not PixelArt.PATHS.has(key) \
			or not ResourceLoader.exists(PixelArt.path(key)):
			slots_ok = false
	_check(slots_ok, "%d zentrale Pixelart-Slots inkl. Wurm/Ameise"
		% PixelArt.PATHS.size())
	var tree_src := FileAccess.get_file_as_string("res://src/plants/Tree.gd")
	var animal_src := FileAccess.get_file_as_string("res://src/animals/Animal.gd")
	_check(not tree_src.contains("assets/placeholders/")
		and not animal_src.contains("assets/placeholders/"),
		"Baum + Tiere nutzen ausschliesslich PixelArt-Pfade")

	# --- 4) Gezieltes Ziehen: Wurzel + Verdickung ---------------------------
	var tree: BaseTree = interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	tree.glucose = 800.0
	tree.set_season(TimeManager.Season.SPRING)
	interaction.select_tree(tree)
	var base := tree.global_position
	var roots_before := tree.root_count
	var root_widths_before: Array = []
	for seg in tree.root_segments:
		root_widths_before.append(seg.debug_draw_width())
	var root_path: Array = [
		base + Vector2(6.0, 6.0),
		base + Vector2(12.0, 24.0),
		base + Vector2(28.0, 48.0),
		base + Vector2(48.0, 76.0),
		base + Vector2(72.0, 104.0),
	]
	var ok_root := interaction.debug_drag_sequence(root_path, 800.0)
	_check(ok_root and tree.root_count > roots_before,
		"Wurzel per Drag gezogen (%d -> %d Segmente)"
			% [roots_before, tree.root_count])
	var thickened := 0
	for i in range(mini(root_widths_before.size(), tree.root_segments.size())):
		if tree.root_segments[i].debug_draw_width() \
			> float(root_widths_before[i]) + 0.01:
			thickened += 1
	_check(thickened == root_widths_before.size(),
		"Alle %d zuvor verbundenen Wurzeln wurden dicker"
			% root_widths_before.size())
	var ft := tree.debug_root_free_target(tree.root_segments.size() - 1)
	_check(ft.length() > 10.0, "Gezogene Wurzel behält ihren freien Zielpunkt")

	# --- 5) Gezieltes Ziehen: Stamm + Verdickung ----------------------------
	var trunk_before := tree.trunk_tiles
	var trunk_widths_before := tree.debug_trunk_segment_widths()
	var top := base + Vector2(0.0,
		-float(tree.trunk_tiles) * BaseTree.TRUNK_STEP)
	var wood_path: Array = [
		top,
		top + Vector2(10.0, -30.0),
		top + Vector2(30.0, -60.0),
		top + Vector2(55.0, -95.0),
	]
	var ok_wood := interaction.debug_drag_sequence(wood_path, 800.0)
	_check(ok_wood and tree.trunk_tiles > trunk_before
		and tree.trunk_guide.size() >= 2,
		"Stamm per Drag geformt (%d -> %d Schritte, %d Guide-Punkte)"
			% [trunk_before, tree.trunk_tiles, tree.trunk_guide.size()])
	var trunk_widths_after := tree.debug_trunk_segment_widths()
	var all_trunk_thicker := true
	for i in trunk_widths_before.size():
		if float(trunk_widths_after[i]) \
			<= float(trunk_widths_before[i]) + 0.001:
			all_trunk_thicker = false
	_check(all_trunk_thicker,
		"Alle %d vorhandenen Stammsegmente wurden dicker"
			% trunk_widths_before.size())

	# --- 6) Gezieltes Ziehen: freier Ast ------------------------------------
	var branches_before := tree.debug_custom_branch_count()
	var crown := base + Vector2(10.0,
		-float(tree.trunk_tiles) * BaseTree.TRUNK_STEP + 20.0)
	var branch_path: Array = [
		crown,
		crown + Vector2(40.0, -8.0),
		crown + Vector2(90.0, 2.0),
		crown + Vector2(140.0, 20.0),
	]
	var ok_branch := interaction.debug_drag_sequence(branch_path, 800.0)
	_check(ok_branch and tree.debug_custom_branch_count() > branches_before,
		"Freier Ast per Drag gezogen (%d -> %d)"
			% [branches_before, tree.debug_custom_branch_count()])
	_check(tree.debug_anchor_count() >= 32,
		"%d Blatt-Anker inkl. gezogener Aeste" % tree.debug_anchor_count())

	# --- 7) Skilltree: genug Blaetter fuer eine dichte Krone ----------------
	var unlock_ids := ["leaf_efficiency", "photosynthesis_plus",
		"crown_growth", "canopy_i", "canopy_ii", "canopy_iii"]
	var unlocked := true
	for id in unlock_ids:
		if not skill_tree.debug_unlock(id):
			unlocked = false
	_check(unlocked, "Dichte-Krone-Kette im Skilltree freischaltbar")
	_check(skill_tree.all_nodes().size() == 24
		and skill_tree.connection_pairs().size() == 23,
		"24 Knoten / 23 Verbindungen im Skilltree")
	_check(skill_ui.debug_node_count() == 24
		and skill_ui.debug_connection_count() == 23,
		"GraphEdit zeigt 24 Knoten / 23 Linien")
	_check(tree.skill_max_leaves_bonus >= 38,
		"Blatt-Obergrenze +%d (Kronenwuchs + 3 Stufen)"
			% tree.skill_max_leaves_bonus)
	_check(tree.skill_leaf_density >= 2,
		"Kronendichte %d (zusaetzliche Deko-Blaetter)"
			% tree.skill_leaf_density)
	_check(tree.leaves_count >= 40,
		"Skilltree schenkt sofort %d Blaetter" % tree.leaves_count)
	var added := 0
	while tree.leaves_count < 50 and tree.grow_part("leaf"):
		added += 1
	_check(tree.leaves_count == 50 and not tree.grow_part("leaf"),
		"Genug Blaetter: %d zusaetzlich, 50 erreichbar, danach echtes Cap"
			% added)
	var indices := tree.debug_leaf_anchor_indices()
	var uniq: Dictionary = {}
	for v in indices:
		uniq[int(v)] = true
	_check(uniq.size() >= 20,
		"%d Blaetter auf %d verschiedene Ast-Anker verteilt (keine kahlen Aeste)"
			% [indices.size(), uniq.size()])

	# --- 8) Save/Load + Regression ------------------------------------------
	var snapshot := tree.to_dict()
	var probe := preload("res://src/plants/Oak.gd").new()
	add_child(probe)
	probe.setup(null, 999, snapshot)
	_check(probe.debug_custom_branch_count() == tree.debug_custom_branch_count()
		and probe.trunk_guide.size() >= 2,
		"Gezogene Aeste + Stammform ueber Baum-Snapshot erhalten")
	var li := tree.root_segments.size() - 1
	_check(probe.debug_root_free_target(li).distance_to(
		tree.debug_root_free_target(li)) < 0.01,
		"Freie Wurzel-Zielpunkte ueber Snapshot erhalten")
	probe.queue_free()
	_check(save_manager.save_game(), "Speichern mit REVISION-6-Geometrie")
	_check(save_manager.load_game(), "Laden mit REVISION-6-Geometrie")
	var restored := false
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree and (t as BaseTree).debug_custom_branch_count() >= 1:
			restored = true
	_check(restored, "Gezogener Ast nach Spielstand-Laden wiederhergestellt")
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus")
	_check(SaveManager.FORMAT_VERSION == 6,
		"Speicherstand bleibt Format v6 (optionale neue Felder)")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"REVISION-5-Glucosetempo unveraendert")

	# --- 9) Lokalisierung DE/EN ---------------------------------------------
	var keys: Array[String] = [
		"SKILL_CANOPY1_TITLE", "SKILL_CANOPY2_DESC", "SKILL_CANOPY3_TITLE",
		"MSG_DRAG_HINT", "MSG_DRAG_GROWN", "MSG_DRAG_BLOCKED",
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
	_check(missing == 0, "Alle %d neuen Schluessel in DE + EN" % keys.size())
	_finish()


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-70s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
