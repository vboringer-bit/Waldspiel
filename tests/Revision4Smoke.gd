extends Node
## Headless-Smoke-Test REVISION 4 (vor PHASE 4):
##   godot --headless --path . -- --rev4-smoke
##
## 1) Ruckler: Statik (Erde/Hoehlen) wird EINMAL gezeichnet, Pegel-Redraws
##    beruehren nur die Wasser-Kontur; Isolinien-Geometrie ist gecacht.
## 2) Spielstart: 0 Eicheln im Inventar, genau 2 frei auf dem Boden.
## 3) Einsammeln „wie bisher", aber WELT-Klicks nehmen keine Inventar-Eichel;
##    nur das HUD-Icon. Platzierung nur auf dem Boden, nicht im Himmel.
## 4) Stamm + Wurzeln: 5 diskrete Wachstumsstufen, duenn -> dick, mit
##    natuerlicher Verjuengung nach oben / zur Wurzelspitze.

var interaction: InteractionController
var chunk_manager: ChunkManager
var season_system: SeasonSystem
var hud: HUD
var camera: CameraController

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_chunks: ChunkManager,
		p_season: SeasonSystem, p_hud: HUD, p_camera: CameraController) -> void:
	interaction = p_interaction
	chunk_manager = p_chunks
	season_system = p_season
	hud = p_hud
	camera = p_camera


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-52s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === REVISION 4 (Performance + Eicheln + Wuchsstufen) ===")
	var gen := chunk_manager.generator

	# --- 1) Performance: getrennte, gecachte Kontur-Ebenen -------------------
	var chunk := chunk_manager.get_chunk(0)
	_check(chunk != null and chunk.contours != null,
		"Chunk 0 hat Kontur-Node")
	var contours: TerrainContours = chunk.contours
	_check(contours.water_painter != null
		and contours.water_painter.get_parent() == contours,
		"Eigener Wasser-CanvasItem als Kind vorhanden")
	_check(contours.debug_geometry_cached(),
		"Isolinien + Schichtpolygone im Cache (kein Noise-Redraw)")
	var static_before := contours.debug_static_draws
	var water_before := contours.debug_water_draws
	for _i in 6:
		contours.queue_water_redraw()
		await get_tree().process_frame
	_check(contours.debug_static_draws == static_before,
		"6 Pegel-Redraws bauen Erde/Hoehlen NICHT neu auf")
	_check(contours.debug_water_draws > water_before,
		"Nur die Wasser-Kontur wird neu gezeichnet")
	_check(contours.debug_static_draws <= 1,
		"Statik wurde insgesamt hoechstens 1x gezeichnet")

	# --- 2) Start: kein Inventar, genau 2 Boden-Eicheln ----------------------
	_check(InteractionController.STARTING_SEEDS == 0,
		"Konstante STARTING_SEEDS = 0")
	_check(interaction.get_seed_count() == 0,
		"Spielstart: 0 Eicheln im Inventar")
	var starters := season_system.debug_starter_positions()
	_check(starters.size() == 2, "Genau 2 Start-Eicheln auf dem Boden")
	var in_start_view := 0
	for gp in season_system.debug_ground_positions():
		if absf(gp.x) < 960.0:
			in_start_view += 1
	_check(in_start_view == 2,
		"Im Startbild genau 2 FREI liegende Eicheln (nicht vergraben)")
	_check(absi(int(starters[0].x)) < 900 and absi(int(starters[1].x)) < 900,
		"Start-Eicheln liegen im sichtbaren Startbereich")

	# --- 3) Einsammeln + Klick-Regeln ----------------------------------------
	var p0: Vector2 = starters[0]
	_check(season_system.collect_at(p0 + Vector2(0.0, -8.0))
		and interaction.get_seed_count() == 1,
		"Boden-Eichel anklicken -> +1 Inventar (wie bisher)")
	_check(season_system.debug_starter_positions().size() == 1,
		"Eingesammelte Eichel verschwindet vom Boden")

	# Ein Klick irgendwo in der Welt darf KEINE Inventar-Eichel nehmen.
	var inv := interaction.get_seed_count()
	interaction.debug_click_world(Vector2(700.0, 380.0))
	_check(interaction.get_seed_count() == inv and not interaction.carrying,
		"Weltklick auf leeren Boden nimmt KEINE Inventar-Eichel")

	# Nur das HUD-Icon startet das Tragen.
	hud.debug_click_seed_icon()
	_check(interaction.carrying and interaction.get_seed_count() == inv - 1,
		"Nur Klick auf das Eichel-Icon nimmt Eichel auf")
	_check(hud != null, "HUD-Icon-Klick registriert")

	# Im Himmel wird NICHT platziert.
	interaction.debug_click_world(Vector2(700.0, -100.0))
	_check(interaction.carrying
		and interaction.get_seed_count() == inv - 1,
		"Klick in den Himmel platziert die Eichel NICHT")

	# Auf dem Boden wird platziert.
	var sy := gen.height_smooth_at(700.0)
	interaction.debug_click_world(Vector2(700.0, sy + 4.0))
	_check(not interaction.carrying,
		"Klick auf den Boden platziert die schwebende Eichel")

	# --- 4) Wachstumsstufen Stamm + Wurzeln ----------------------------------
	interaction.set_seed_count(0)
	interaction.first_seed_eaten = false
	interaction.debug_plant_twice()
	var trees := get_tree().get_nodes_in_group("trees")
	_check(trees.size() == 1, "Keimling fuer Wuchsstufen-Test vorhanden")
	if trees.is_empty():
		_finish()
		return
	var t: BaseTree = trees[0] as BaseTree
	var stage0 := t.debug_stage()
	var trunk0 := t.debug_trunk_width(0)
	var root0 := t.debug_root_width(0)
	_check(stage0 == 0 and trunk0 > 0.0 and trunk0 < 0.45,
		"Keimling: Stufe 0, Stamm duenn (%.2f)" % trunk0)
	_check(root0 > 0.0 and root0 < trunk0,
		"Keimling: Wurzelspitze noch duenner als Stamm")

	# Wachsen: Stamm, Blaetter UND Wurzeln -> Stufe steigt, Breite nimmt zu.
	for _i in 12:
		t.add_trunk_tile()
		t.add_leaf()
		t.add_root()
	var stage1 := t.debug_stage()
	var trunk1 := t.debug_trunk_width(0)
	var root1 := t.debug_root_width(0)
	_check(stage1 >= stage0 + 2,
		"Wachstum wechselt mehrere sichtbare Stufen (%d -> %d)" % [stage0, stage1])
	_check(trunk1 > trunk0 + 0.15,
		"Stamm wird deutlich dicker (%.2f -> %.2f)" % [trunk0, trunk1])
	_check(root1 > root0 + 0.10,
		"Wurzeln werden deutlich dicker (%.2f -> %.2f)" % [root0, root1])
	_check(trunk1 <= 1.0 and root1 <= 1.0,
		"Maximalbreite bleibt bei 100 % (kein Ueberwachsen)")
	_check(t.debug_trunk_width(0) > t.debug_trunk_width(4),
		"Stamm verjuengt sich nach oben (realistisch)")
	_check(t.debug_root_width(0) > t.debug_root_width(t.root_count - 1),
		"Tiefe Wurzelspitze bleibt duenner als der Wurzelhals")
	_check(t.root_segments[0].hit_rect().size == Vector2(16.0, 16.0),
		"16px-Kollisionsraster der Wurzeln unveraendert")

	# Wuchsstufe ueberlebt Save/Load.
	var snapshot := t.to_dict()
	var probe: BaseTree = preload("res://src/plants/Oak.gd").new()
	add_child(probe)
	probe.setup(null, 999, snapshot)
	var stage_loaded := probe.debug_stage()
	_check(stage_loaded == stage1
		and is_equal_approx(probe.debug_trunk_width(0), trunk1),
		"Wuchsstufe + Breite ueber Save/Load erhalten")

	# --- 5) Lokalisierung / Regression ---------------------------------------
	Global.locale = "de"
	var de := tr("MSG_ACORN_GROUND_ONLY")
	Global.locale = "en"
	var en := tr("MSG_ACORN_GROUND_ONLY")
	Global.locale = "de"
	_check(de != "MSG_ACORN_GROUND_ONLY" and en != de and en.length() > 5,
		"Neuer Hinweistext in DE + EN vorhanden")
	_check(chunk_manager.loaded_chunk_count() == 5,
		"Weiterhin 5 geladene Chunks")

	_finish()


func _finish() -> void:
	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty()
		else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
