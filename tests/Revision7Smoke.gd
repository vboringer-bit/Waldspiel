extends Node
## Headless-Smoke-Test REVISION 7 (ortsfester Wurm-Gang, dunklere Würmer,
## bodenfester Ameisenhuegel, 6 sinnvolle Skilltree-Knoten, Lichtkonkurrenz):
##   godot --headless --path . -- --rev7-smoke

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
var _last_toast: String = ""


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


func _on_toast(t: String) -> void:
	_last_toast = t


func run() -> void:
	print("[SMOKE] === REVISION 7: ruhiger Gang, Erdschluss, Licht & Skills ===")
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

	# --- 1) Wurm: Gang ist ein ortsfester, eigener Node ---------------------
	var worm := wildlife.debug_animal("worm")
	_check(worm != null, "Regenwurm vorhanden")
	if worm != null:
		wildlife.debug_step(6.0)
		var tn := worm.debug_trail_node()
		_check(tn != null, "BurrowTrail als eigener Tunnel-Node vorhanden")
		if tn != null:
			_check(tn.top_level and tn.global_position.distance_to(Vector2.ZERO) < 0.001,
				"Tunnel hat Identitaets-Transformation (top_level)")
			_check(tn.get_parent() != worm,
				"Tunnel ist NICHT Kind des animierten Wurmkoerpers")
			_check(tn.debug_point_count() >= 2,
				"Tunnel hat %d geglaettete Welt-Punkte" % tn.debug_point_count())
			var first0 := tn.debug_first_point()
			var p0 := worm.debug_trail_point(0)
			var sig0 := worm.debug_trail_signature()
			# Jetzt KEINERLEI Bewegung mehr: Tiefe festhalten, x-Ziel = aktuelle x.
			worm.debug_freeze_motion()
			wildlife.debug_step(2.0)
			_check(p0.distance_to(worm.debug_trail_point(0)) < 0.001,
				"Gang-Stuetzpunkt bleibt exakt ortsfest")
			_check(sig0.distance_to(worm.debug_trail_signature()) < 0.001,
				"Keine neuen Punkte ohne echte Bewegung (kein Wackeln)")
			_check(first0.distance_to(tn.debug_first_point()) < 0.001,
				"Gezeichneter Tunnel wandert nicht mit dem Koerper")
			_check(absf(worm.debug_body_offset()) < 0.01,
				"Wurmkoerper hat kein Sinus-Wackeln mehr (Offset %.4f)" %
					worm.debug_body_offset())
		_check(worm.debug_trail_size() >= 3,
			"Gang behaelt %d stabile Stuetzpunkte" % worm.debug_trail_size())
		# Dunklere Pixelart: echte PNG-Pixel lesen, nicht nur eine Konstante.
		var tex := load(PixelArt.WORM) as Texture2D
		var img: Image = null
		if tex != null:
			img = tex.get_image()
		_check(img != null, "Wurm-Textur lesbar")
		if img != null:
			var body := img.get_pixel(8, 8)
			var edge := img.get_pixel(0, 7)
			_check(body.a > 0.9 and body.r < 0.60 and body.g < 0.35,
				"Wurmkoerper gedeckt dunkel (%.2f/%.2f/%.2f)" %
					[body.r, body.g, body.b])
			_check(edge.r < 0.30, "Wurmkontur ebenfalls dunkel")
		_check(PixelArt.WORM_BODY.get_luminance() < 0.40,
			"Zentrale Wurm-Palette ist dunkler als in R6")

	# --- 2) Ameisenhuegel: Basis folgt der sichtbaren Gelaendekante ---------
	var ah := wildlife.debug_anthill(0)
	_check(ah != null, "Ameisenhuegel vorhanden")
	if ah != null:
		var gen := wildlife.generator
		var profile := ah.debug_base_profile()
		_check(profile.size() >= 9, "Huegelbasis aus %d Gelaendepunkten" % profile.size())
		var aligned := true
		for q in profile:
			if absf(q.y - gen.ground_y_at(q.x)) > 0.01:
				aligned = false
		_check(aligned, "Jeder Basispunkt liegt auf ground_y_at() (kein Schweben)")
		_check(ah.debug_base_gap() < 0.01,
			"Maximaler Erdschluss-Abstand %.3f px" % ah.debug_base_gap())
		_check(ah.debug_ground_gap() < 0.01,
			"Huegelposition auf der 4px-Oberkante (Abstand %.3f px)" %
				ah.debug_ground_gap())
		var hr := ah.hit_rect()
		var gy := gen.ground_y_at(ah.global_position.x)
		_check(hr.position.y <= gy and hr.position.y + hr.size.y >= gy,
			"Klickflaeche schliesst mit dem Boden ab")
	wildlife.debug_step(4.0)
	var ants := wildlife.debug_animals("ant")
	var grounded := ants.size() >= 2
	for a in ants:
		var an := a as Animal
		var gap := an.debug_ground_gap()
		if gap > 0.5 or gap < -6.0:
			grounded = false
	_check(grounded, "%d Ameisen weiter bodengebunden" % ants.size())

	# --- 3) Skilltree: 24 sinnvolle Knoten + echte Effekte ------------------
	_check(skill_tree.all_nodes().size() == 24
		and skill_tree.connection_pairs().size() == 23,
		"24 Knoten / 23 Verbindungen im Skilltree")
	_check(skill_ui.debug_node_count() == 24
		and skill_ui.debug_connection_count() == 23,
		"GraphEdit zeigt 24 Knoten / 23 Linien")
	var new_ids: Array[String] = ["light_seeker", "shade_leaf", "forest_edge",
		"spring_sap", "humus_net", "winter_store"]
	var all_new := true
	for id in new_ids:
		if skill_tree.node_data(id) == null:
			all_new = false
	_check(all_new, "6 neue Licht-/Jahreszeit-Mutationen vorhanden")
	var keys: Array[String] = [
		"SKILL_LIGHTSEEK_TITLE", "SKILL_LIGHTSEEK_DESC",
		"SKILL_SHADELEAF_TITLE", "SKILL_SHADELEAF_DESC",
		"SKILL_FORESTEDGE_TITLE", "SKILL_FORESTEDGE_DESC",
		"SKILL_SPRINGSAP_TITLE", "SKILL_SPRINGSAP_DESC",
		"SKILL_HUMUSNET_TITLE", "SKILL_HUMUSNET_DESC",
		"SKILL_WINTERSTORE_TITLE", "SKILL_WINTERSTORE_DESC",
		"HUD_LIGHT", "LIGHT_LIMIT_CROWD", "LIGHT_LIMIT_OK", "MSG_CROWD_BLOCKED",
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

	var chain: Array[String] = ["root_efficiency", "leaf_efficiency",
		"photosynthesis_plus", "crown_growth", "symbiosis", "mushroom_node",
		"winter_hardy", "light_seeker", "shade_leaf", "forest_edge",
		"spring_sap", "humus_net", "winter_store"]
	var unlocked := true
	for id in chain:
		if not skill_tree.debug_unlock(id):
			unlocked = false
	_check(unlocked, "Neue Knoten sind ueber Vorbedingungen freischaltbar")
	_check(skill_tree.modifier("germination") > 1.34,
		"Waldrand: +35 %% Keimung (%.2f)" % skill_tree.modifier("germination"))
	_check(skill_tree.modifier("spring_vigor") > 1.44,
		"Fruehlingssaft: +45 %% Wuchskraft (%.2f)" % skill_tree.modifier("spring_vigor"))
	_check(skill_tree.modifier("winter_water") > 1.50,
		"Wintervorrat: +25 %% Winterwasser (%.2f)" % skill_tree.modifier("winter_water"))
	_check(skill_tree.modifier("nutrients") > 1.29,
		"Humusnetz: +15 %% Naehrstoffe (%.2f)" % skill_tree.modifier("nutrients"))
	_check(season_system.germination_mult > 1.34,
		"Keimung liest den Skilltree-Wert (%.2f)" % season_system.germination_mult)

	# --- 4) Lichtkonkurrenz: dichter Stand bleibt klein ---------------------
	skill_tree.reset()
	interaction.clear_trees()
	var solo := interaction.spawn_tree_at(Vector2(0.0, 0.0), {})
	_check(solo != null and is_equal_approx(solo.debug_light_factor(), 1.0),
		"Alleinstehender Baum: 100 % Licht")
	if solo != null:
		for _i in 26:
			solo.add_trunk_tile()
		while solo.leaves_count < 12 and solo.add_leaf():
			pass
		_check(solo.trunk_tiles == 28 and solo.leaves_count == 12,
			"Freistehender Baum waechst voll aus (28/12)")
		var full_h := solo.debug_trunk_height()
		var close := interaction.spawn_tree_at(Vector2(64.0, 0.0), {})
		_check(close != null and close.debug_is_crowded(),
			"Nachbar in 64 px Abstand wird als Beschattung erkannt")
		if close != null:
			var lf := close.debug_light_factor()
			_check(lf < 0.75, "Nur %.0f %% Licht im dichten Stand" % (lf * 100.0))
			var cap_t := close.debug_crowd_cap("trunk")
			var cap_l := close.debug_crowd_cap("leaf")
			_check(cap_t < 22 and cap_l < 10,
				"Wuchs-Cap sinkt auf %d Stamm / %d Blatt" % [cap_t, cap_l])
			for _i in 40:
				if not close.add_trunk_tile():
					break
			for _i in 40:
				if not close.add_leaf():
					break
			_check(close.trunk_tiles <= cap_t and close.leaves_count <= cap_l,
				"Baum bleibt klein (%d/%d statt 28/12)" %
					[close.trunk_tiles, close.leaves_count])
			_check(close.debug_trunk_height() < full_h * 0.80,
				"Klein bleibender Stamm %.0f px statt %.0f px" %
					[close.debug_trunk_height(), full_h])
			interaction.select_tree(close)
			hud.refresh()
			_check(hud.debug_light_text().contains("Licht"),
				"HUD zeigt echtes Licht: '%s'" % hud.debug_light_text())
			_last_toast = ""
			if not EventBus.toast.is_connected(_on_toast):
				EventBus.toast.connect(_on_toast)
			close.glucose = 0.0
			interaction.manual_growth(close,
				Vector2(close.global_position.x, close.global_position.y - 100.0))
			if EventBus.toast.is_connected(_on_toast):
				EventBus.toast.disconnect(_on_toast)
			_check(_last_toast.begins_with("Zu wenig Licht"),
				"Klick am Cap meldet Lichtmangel statt stumm zu scheitern")
			# Skilltree gegensteuern: Lichtsucher + Waldrand hellen den Stand auf.
			var before := close.debug_light_factor()
			for id in ["root_efficiency", "leaf_efficiency", "photosynthesis_plus",
					"crown_growth", "light_seeker", "shade_leaf", "forest_edge"]:
				skill_tree.debug_unlock(id)
			var after := close.debug_light_factor()
			_check(after > before + 0.05,
				"Licht-Skills hellen auf: %.0f %% -> %.0f %%" %
					[before * 100.0, after * 100.0])
			_check(close.crowd_tolerance >= 0.54 and close.shade_gain >= 0.49,
				"crowd_tolerance %.2f / shade_gain %.2f am Baum wirksam" %
					[close.crowd_tolerance, close.shade_gain])

	# --- 5) Save/Load + Regression ------------------------------------------
	_check(SaveManager.FORMAT_VERSION == 6,
		"Save-Format bleibt v6 (neue Felder weiterhin optional)")
	_check(save_manager.save_game(), "Speichern mit REVISION-7-Stand")
	_check(save_manager.load_game(), "Laden mit REVISION-7-Stand")
	var still_small := false
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree:
			var bt := t as BaseTree
			if bt.debug_is_crowded() and bt.trunk_tiles <= 20:
				still_small = true
	_check(still_small, "Beschatteter Baum bleibt auch nach Laden klein")
	_check(not Global.auto_mode, "AUTO bleibt standardmaessig aus")
	_check(is_equal_approx(BaseTree.GLUCOSE_PACE, 0.2),
		"REVISION-5-Glucosetempo unveraendert")
	_check(PixelArt.PATHS.size() == 21, "21 zentrale Pixelart-Slots erhalten")
	var rs: RootSegment = null
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree and (t as BaseTree).root_segments.size() > 0:
			rs = (t as BaseTree).root_segments[0]
			break
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
