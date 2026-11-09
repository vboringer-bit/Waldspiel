extends Node
## Headless-Smoke-Test fuer PHASE 1:
##   godot --headless --path . -- --phase1-smoke
## REVISION 4: Startinventar = 0 (die 2 Eicheln liegen auf dem Boden).
## Prueft Zufallsseed, Vogel-Event, Keimling, Fotosynthese,
## Wasser (normal / 5x Regen), AUTO/MANUELL, Save/Load und 5 Chunks.

var interaction: InteractionController
var growth: GrowthSystem
var water: WaterSystem
var save_manager: SaveManager
var chunk_manager: ChunkManager
var camera: CameraController

var _failures: Array[String] = []


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_save: SaveManager, p_chunks: ChunkManager,
		p_camera: CameraController) -> void:
	interaction = p_interaction
	growth = p_growth
	water = p_water
	save_manager = p_save
	chunk_manager = p_chunks
	camera = p_camera


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-46s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	# Systeme manuell ticken, damit die Messwerte deterministisch sind.
	growth.set_process(false)
	water.set_process(false)
	print("[SMOKE] === PHASE 1 ===")

	# 1) Seed wird pro Start gewuerfelt
	_check(Global.seed_is_random and Global.world_seed > 0,
		"Zufalls-Seed pro Neustart (seed=%d)" % Global.world_seed)
	_check(interaction.get_seed_count() == 0,
		"REV4: Start OHNE Eicheln im Inventar")
	# Der Test simuliert das eingesammelte Inventar (2 Boden-Eicheln), damit
	# die PHASE-1-Tutorial-Logik unveraendert geprueft werden kann.
	interaction.set_seed_count(2)
	_check(interaction.get_seed_count() == 2, "Testinventar: 2 Eicheln")

	# 2) Tutorial: 1. Eichel wird gefressen
	var x := 0.0
	var pos := Vector2(x, chunk_manager.generator.height_at(x) + 8.0)
	interaction.plant_seed_at(pos, true)
	_check(interaction.first_seed_eaten, "Vogel-Event ausgeloest")
	_check(interaction.get_seed_count() == 1, "Inventar nach Vogel: 1")
	_check(get_tree().get_nodes_in_group("trees").size() == 0, "Noch kein Baum")

	# 3) 2. Eichel keimt zum Mini-Baum
	interaction.plant_seed_at(pos, true)
	var trees := get_tree().get_nodes_in_group("trees")
	_check(trees.size() == 1, "1 Baum nach 2. Eichel")
	var t: BaseTree = trees[0]
	_check(t.leaves_count == 2 and t.root_count == 1 and t.trunk_tiles == 2,
		"Keimling: 2 Stamm-Tiles / 2 Blaetter / 1 Wurzel")
	_check(interaction.selected_tree == t, "Baum ausgewaehlt (HUD)")

	# 4) Fotosynthese
	Global.auto_mode = false
	var g0 := t.glucose
	var w0 := t.water
	growth.tick(5.0)
	_check(t.glucose > g0 and t.water < w0, "Glucose steigt / Wasser sinkt")
	print("[SMOKE] Glucose %.2f -> %.2f | Wasser %.2f -> %.2f" % [
		g0, t.glucose, w0, t.water])

	# 5) Wasser: normaler Boden vs. Regen (5x)
	t.water = 50.0
	water.tick(2.0)
	var normal_gain := t.water - 50.0
	t.water = 50.0
	water.force_rain(30.0)
	water.tick(2.0)
	var rain_gain := t.water - 50.0
	_check(water.raining, "Regen aktiv")
	var rain_effect := get_tree().get_first_node_in_group("rain_effect")
	_check(rain_effect != null and rain_effect.raining and rain_effect.visible,
		"Regen-Partikel (blaue Linien) sichtbar")
	_check(normal_gain > 0.0 and rain_gain > normal_gain * 4.5,
		"Regen-Boost ~5x (normal %.2f / Regen %.2f)" % [normal_gain, rain_gain])

	# 6) AUTO verteilt Glucose selbst
	Global.auto_mode = true
	t.water = 80.0
	t.glucose = 25.0
	var leaves_before := t.leaves_count
	growth.tick(0.1)
	_check(t.leaves_count == leaves_before + 1 and t.glucose < 20.0,
		"AUTO: Blatt-Wachstum, -10 Glucose")

	# 7) MANUELL: Klick auf Wurzelbereich kostet 10 Glucose
	Global.auto_mode = false
	t.glucose = 25.0
	var roots_before := t.root_count
	var ok_manual := interaction.manual_growth(t,
		Vector2(t.global_position.x, t.global_position.y + 10.0))
	_check(ok_manual and t.root_count == roots_before + 1 and t.glucose < 20.0,
		"MANUELL: Wurzel-Wachstum (Kosten nach Boden)")

	# 8) Save / Load (Seed + Baumwerte + Inventar)
	var seed_before := Global.world_seed
	var glucose_before := t.glucose
	var inv_before := interaction.get_seed_count()
	_check(save_manager.save_game(), "Speichern nach user://savegame.json")
	interaction.clear_trees()
	_check(get_tree().get_nodes_in_group("trees").size() == 0, "Baeume vor Load entfernt")
	_check(save_manager.load_game(), "Laden erfolgreich")
	var restored := get_tree().get_nodes_in_group("trees")
	_check(restored.size() == 1, "1 Baum wiederhergestellt")
	_check(Global.world_seed == seed_before, "Seed aus Spielstand wiederhergestellt")
	_check(interaction.get_seed_count() == inv_before, "Inventar aus Spielstand")
	if restored.size() > 0:
		_check(absf(restored[0].glucose - glucose_before) < 0.01,
			"Glucose aus Spielstand")

	# 9) Infinite Chunks weiterhin intakt
	camera.teleport_to(Vector2(4300.0, 300.0))
	chunk_manager._refresh()
	await get_tree().process_frame
	_check(chunk_manager.loaded_chunk_count() == 5, "5 Chunks nach Pan auf x=4300")

	# 10) DE/EN Umschaltung ueber den TranslationServer
	Global.locale = "en"
	var en_ok := tr("MSG_BIRD_EVENT").begins_with("A bird took the first placed acorn")
	Global.locale = "de"
	_check(en_ok and tr("MSG_BIRD_EVENT").begins_with("Der Vogel hat die erste platzierte"),
		"DE/EN-Umschaltung (TranslationServer)")

	# 11) Projekt-Settings unveraendert
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0
		and String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus",
		"Nearest + Forward+ weiterhin aktiv")

	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty() else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
