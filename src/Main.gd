extends Node2D
## Einstiegsszene. Verdrahtet die modularen Systeme; enthaelt selbst keine
## Spiellogik. PHASE 0 (Welt/Kamera), PHASE 1 (Kern-Loop), PHASE 2
## (Wachstum & Boden), REVISION 1/2 und PHASE 3 (Zeit & Reproduktion)
## laufen hier zusammen.

@onready var _sky: SkyBackground = $SkyBackground
@onready var _mountains: MountainBackdrop = $World/MountainBackdrop
@onready var _chunk_manager: ChunkManager = $World/ChunkManager
@onready var _camera: CameraController = $World/WorldCamera
@onready var _trees: Node2D = $World/Trees
@onready var _bird_layer: BirdEvent = $World/BirdLayer
@onready var _ghost: GhostPreview = $World/GhostPreview
@onready var _growth: GrowthSystem = $Systems/GrowthSystem
@onready var _water: WaterSystem = $Systems/WaterSystem
@onready var _time: TimeManager = $Systems/TimeManager
@onready var _save: SaveManager = $Systems/SaveManager
@onready var _interaction: InteractionController = $Interaction
@onready var _hud: HUD = $HUD
@onready var _season: SeasonSystem = $Systems/SeasonSystem
@onready var _start_menu: StartMenu = $StartMenu
@onready var _rain: RainEffect = $RainLayer/RainEffect
@onready var _skill_tree: SkillTree = $Systems/SkillTree
@onready var _skill_ui: SkillTreeUI = $SkillTreeUI

var _last_fit: Vector2i = Vector2i.ZERO


func _ready() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	# Fuer Tests/Screenshots: trotz Vollbild-Default in den Fenstermodus.
	if args.has("--windowed"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_fit_display()
	get_tree().root.size_changed.connect(_fit_display)
	_chunk_manager.setup(_camera)
	# REVISION 3: Regen kennt Kamera + Gelände -> Aufprall auf der Oberfläche.
	# PHASE 4: Regen/Schnee kennt jetzt auch die Jahreszeit.
	_rain.setup(_camera, _chunk_manager.generator, _time)
	_mountains.setup(_camera)
	_sky.refresh_layout()
	var state := _chunk_manager.world_state
	_growth.setup(_chunk_manager.generator, _time)
	_water.setup(state, _chunk_manager.generator, _time)
	_interaction.setup(_camera, _chunk_manager, _trees, _bird_layer,
		_water, _growth, state, _ghost, _season)
	_season.setup(_chunk_manager, _trees, _camera, _time, _interaction)
	_save.setup(_interaction, _chunk_manager, state, _time, _season)
	_hud.setup(_interaction, _growth, _water, _time, _save, state)
	_skill_ui.setup(_interaction)
	_start_menu.setup(_should_show_start_menu(args))
	_apply_presets(args)

	# Headless-Tests (kein Addon):
	#   godot --headless --path . -- --phase0-smoke
	#   godot --headless --path . -- --phase1-smoke
	#   godot --headless --path . -- --phase2-smoke
	#   godot --headless --path . -- --rev3-smoke
	if args.has("--phase0-smoke"):
		var smoke0 = preload("res://tests/Phase0Smoke.gd").new()
		smoke0.setup(_chunk_manager, _camera)
		add_child(smoke0)
	elif args.has("--phase1-smoke"):
		var smoke1 = preload("res://tests/Phase1Smoke.gd").new()
		smoke1.setup(_interaction, _growth, _water, _save, _chunk_manager, _camera)
		add_child(smoke1)
	elif args.has("--phase2-smoke"):
		var smoke2 = preload("res://tests/Phase2Smoke.gd").new()
		smoke2.setup(_interaction, _growth, _water, _save,
			_chunk_manager, _camera, state, _ghost)
		add_child(smoke2)
	elif args.has("--rev1-smoke"):
		var smoke_r = preload("res://tests/Revision1Smoke.gd").new()
		smoke_r.setup(_interaction, _save, _chunk_manager, _camera)
		add_child(smoke_r)
	elif args.has("--rev2-smoke"):
		var smoke_r2 = preload("res://tests/Revision2Smoke.gd").new()
		smoke_r2.setup(_interaction, _growth, _water, _save,
			_chunk_manager, _camera, state)
		add_child(smoke_r2)
	elif args.has("--p3-smoke"):
		var smoke3 = preload("res://tests/Phase3Smoke.gd").new()
		smoke3.setup(_interaction, _growth, _water, _save,
			_chunk_manager, _camera, state, _time, _season,
			_bird_layer, _hud, _start_menu)
		add_child(smoke3)
	elif args.has("--rev3-smoke"):
		var smoke_r3 = preload("res://tests/Revision3Smoke.gd").new()
		smoke_r3.setup(_interaction, _water, _chunk_manager, _camera,
			state, _time, _rain)
		add_child(smoke_r3)
	elif args.has("--rev4-smoke"):
		var smoke_r4 = preload("res://tests/Revision4Smoke.gd").new()
		smoke_r4.setup(_interaction, _chunk_manager, _season, _hud, _camera)
		add_child(smoke_r4)
	elif args.has("--phase4-smoke"):
		var smoke4 = preload("res://tests/Phase4Smoke.gd").new()
		smoke4.setup(_interaction, _skill_tree, _skill_ui, _water, _growth,
			_chunk_manager, _camera, state, _time, _season, _save,
			_rain, _hud)
		add_child(smoke4)

	print("[Main] PHASE 3 + REVISION 3 bereit: %d Eicheln, Jahreszeiten x1/x3/x10, Herbst-Eichelfall, Samen finden/vergraben, Schwierigkeitsgrade." % [
		_interaction.get_seed_count()])


## Gleichmaessig auf die Fensterflaeche skalieren. Mit aspect="expand" wird
## der Viewport dadurch groesser als 1920x1080 statt von grauen Raendern
## umgeben zu sein; alle Canvas-Inhalte werden mit dem Faktor mitvergroessert.
func _fit_display() -> void:
	var ws := DisplayServer.window_get_size()
	if ws.x <= 0 or ws.y <= 0 or ws == _last_fit:
		return
	_last_fit = ws
	# PHASE 3: "canvas_items" + "expand" skaliert den 1920x1080-Viewport
	# bereits selbst auf die Fenstergroesse. Ein zusaetzlicher Faktor wuerde
	# DOPPELT skalieren (bei 2560x1440: sichtbar nur 1440x810 -> HUD rechts
	# abgeschnitten). Deshalb bewusst 1.0: kein grauer Rand, volle HUD-Breite.
	get_tree().root.content_scale_factor = 1.0


## F11 = Vollbild an/aus. "canvas_items"/"expand" skaliert den
## 1920x1080-Viewport dabei auf den Monitor (kein grauer Rand mehr).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# PHASE 3: Leertaste = Zeit anhalten / weiterlaufen lassen.
	if key.keycode == KEY_SPACE:
		_time.toggle_pause()
		EventBus.toast.emit(tr("MSG_PAUSED") if _time.paused
			else tr("MSG_RESUMED"))
		get_viewport().set_input_as_handled()
		return
	if key.keycode != KEY_F11:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()


## PHASE 3: Startmenue nur bei einem echten F5-Start ohne Test-/CLI-Flags.
func _should_show_start_menu(args: PackedStringArray) -> bool:
	if Global.difficulty_chosen:
		return false
	for a in args:
		if a.begins_with("--phase") or a.begins_with("--rev") \
				or a.begins_with("--p3-") or a == "--windowed" \
				or a.begins_with("--seed=") or a.begins_with("--difficulty=") \
				or a == "--headless":
			return false
	return true


## REVISION 2: Fuellstand des Starter-Beckens fuer Screenshots setzen.
func _set_reservoir_fill(fraction: float) -> void:
	var gen := _chunk_manager.generator
	var ty := gen.surface_tile_y_at(0.0) + 10
	_chunk_manager.world_state.debug_set_fill(0, ty, fraction)
	_chunk_manager.refresh_water_visuals()


## Reproduzierbare Zustaende fuer Screenshots / Tests.
## Ohne Argument: F5 startet OHNE Inventar-Eicheln; die 2 Start-Eicheln
## liegen auf dem Boden (REVISION 4).
func _apply_presets(args: PackedStringArray) -> void:
	if args.has("--p3-debug-sizes"):
		print("[DBG] window=", DisplayServer.window_get_size(),
			" root=", get_tree().root.size,
			" visible=", get_viewport().get_visible_rect().size,
			" scale=", get_tree().root.content_scale_factor,
			" mode=", get_tree().root.content_scale_mode,
			" aspect=", get_tree().root.content_scale_aspect)
	# --- PHASE 4: Skilltree + Winter-Schnee ----------------------------------
	if args.has("--phase4-shot-skilltree"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_growth.set_process(false)
		_water.set_process(false)
		_season.set_process(false)
		_interaction.debug_plant_twice()
		if _interaction.selected_tree != null:
			_interaction.selected_tree.glucose = 260.0
		for id in ["root_efficiency", "leaf_efficiency", "rain_absorption",
				"symbiosis", "spread"]:
			_skill_tree.debug_unlock(id)
		_skill_ui.open()
		_hud.refresh()
	elif args.has("--phase4-shot-snow"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 360.0))
		_time.debug_set_season(TimeManager.Season.WINTER, 3, 0.40)
		_water.force_rain(60.0)
		_rain.debug_populate(46)
		_growth.set_process(false)
		_water.set_process(false)
		_season.set_process(false)
		_hud.refresh()
	elif args.has("--phase4-shot-snow-detail"):
		_camera.set_zoom_immediate(1.9)
		_camera.teleport_to(Vector2(0.0, 345.0))
		_time.debug_set_season(TimeManager.Season.WINTER, 3, 0.40)
		_water.force_rain(60.0)
		_rain.debug_populate(52)
		_growth.set_process(false)
		_water.set_process(false)
		_season.set_process(false)
		_hud.refresh()
	elif args.has("--phase4-shot-skilltree-locked"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_growth.set_process(false)
		_water.set_process(false)
		_season.set_process(false)
		_interaction.debug_plant_twice()
		if _interaction.selected_tree != null:
			_interaction.selected_tree.glucose = 12.0
		_skill_ui.open()
		_hud.refresh()

	# --- REVISION 4: Start, Inventar-Klick und Wuchsstufen -------------------
	if args.has("--rev4-shot-start"):
		_camera.set_zoom_immediate(1.15)
		_camera.teleport_to(Vector2(0.0, 350.0))
		_growth.set_process(false)
		_water.set_process(false)
		_season.set_process(false)
		_hud.refresh()
	elif args.has("--rev4-shot-carry"):
		_camera.set_zoom_immediate(1.15)
		_camera.teleport_to(Vector2(0.0, 350.0))
		_growth.set_process(false)
		_season.set_process(false)
		_interaction.debug_carry_at(Vector2(960.0, 430.0), 320.0)
		_hud.refresh()
	elif args.has("--rev4-shot-stages"):
		_camera.set_zoom_immediate(1.35)
		_camera.teleport_to(Vector2(0.0, 430.0))
		_growth.set_process(false)
		_water.set_process(false)
		_season.set_process(false)
		var young: BaseTree = _interaction.spawn_tree_at(Vector2(-300.0, 0.0), {})
		var grown: BaseTree = _interaction.spawn_tree_at(Vector2(300.0, 0.0), {})
		for _i in 12:
			grown.add_trunk_tile()
			grown.add_leaf()
			grown.add_root()
		_interaction.select_tree(grown)
		_hud.refresh()
	elif args.has("--rev4-shot-water"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.53)
	elif args.has("--rev3-shot-rain-splash"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 340.0))
		_water.force_rain(60.0)
		_rain.debug_populate(38)
	elif args.has("--rev3-shot-water-a"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.50)
	elif args.has("--rev3-shot-water-b"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.53)
	elif args.has("--rev3-shot-water-smooth"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.53)
	elif args.has("--p3-shot-difficulty"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_start_menu.setup(true)
	elif args.has("--p3-shot-spring"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_interaction.debug_plant_twice()
		_growth.debug_advance(4.0)
		_time.debug_set_season(TimeManager.Season.SPRING, 1, 0.55)
		_hud.refresh()
	elif args.has("--p3-shot-autumn"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_interaction.debug_plant_twice()
		_growth.debug_advance(4.0)
		_time.debug_set_season(TimeManager.Season.AUTUMN, 3, 0.40)
		_season.debug_no_germination = true
		_season.debug_drop_acorns(7, true)
		_season.set_process(false)
		_hud.refresh()
	elif args.has("--p3-shot-winter"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_interaction.debug_plant_twice()
		_growth.debug_advance(4.0)
		_time.debug_set_season(TimeManager.Season.WINTER, 3, 0.35)
		_hud.refresh()
	elif args.has("--p3-shot-seeds"):
		_camera.set_zoom_immediate(1.8)
		_camera.teleport_to(Vector2(60.0, 340.0))
		_season.debug_spawn_seed_at(-180.0, false)
		_season.debug_spawn_seed_at(120.0, false)
		_season.debug_spawn_seed_at(280.0, true)
		_season.set_process(false)
	elif args.has("--p3-shot-rain-refill"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.18)
		_water.force_rain(60.0)
		_water.tick(30.0)
		_water.set_process(false)
		_rain.debug_populate(30)
		_hud.refresh()
	elif args.has("--p3-shot-bird-mid"):
		_camera.set_zoom_immediate(1.6)
		_camera.teleport_to(Vector2(0.0, 370.0))
		_interaction.debug_first_seed()
		_bird_layer.debug_bird_progress(0.35)
	elif args.has("--p3-shot-bird-exit"):
		_camera.set_zoom_immediate(1.6)
		_camera.teleport_to(Vector2(0.0, 370.0))
		_interaction.debug_first_seed()
		_bird_layer.debug_bird_progress(0.70)
	elif args.has("--rev2-shot-edges"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 620.0))
	elif args.has("--rev2-shot-water"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.45)
	elif args.has("--rev2-shot-water-low"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 500.0))
		_set_reservoir_fill(0.18)
	elif args.has("--rev1-shot-surface"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 300.0))
	elif args.has("--rev1-shot-carry"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_interaction.debug_carry_at(Vector2(960.0, 430.0), 320.0)
	elif args.has("--rev1-shot-placed"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 330.0))
		_interaction.debug_carry_at(Vector2(960.0, 430.0), 320.0)
		_interaction.debug_place_carried_at(320.0)
	elif args.has("--phase2-shot-caves"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 700.0))
	elif args.has("--phase2-shot-roots"):
		_camera.set_zoom_immediate(1.25)
		_camera.teleport_to(Vector2(0.0, 490.0))
		_interaction.debug_plant_twice()
		_interaction.debug_grow_roots(14)
		_water.set_process(false)
	elif args.has("--phase2-shot-manual"):
		_camera.set_zoom_immediate(1.6)
		_camera.teleport_to(Vector2(0.0, 390.0))
		_interaction.debug_plant_twice()
		Global.auto_mode = false
		_growth.set_process(false)
		_interaction.debug_grow_roots(3)
		_interaction.selected_tree.glucose = 42.0
		_interaction.debug_show_ghost()
		_hud.refresh_texts()
		_hud.refresh()
	elif args.has("--phase2-shot-dry"):
		_camera.set_zoom_immediate(1.0)
		_camera.teleport_to(Vector2(0.0, 700.0))
		_interaction.debug_drain_reservoirs()
	elif args.has("--phase1-shot-bird"):
		_camera.set_zoom_immediate(1.6)
		_camera.teleport_to(Vector2(0.0, 370.0))
		_interaction.debug_first_seed()
	elif args.has("--phase1-shot-planted"):
		_camera.set_zoom_immediate(1.6)
		_camera.teleport_to(Vector2(0.0, 370.0))
		_interaction.debug_plant_twice()
		_growth.debug_advance(5.0)
	elif args.has("--phase1-shot-rain"):
		_camera.set_zoom_immediate(1.6)
		_camera.teleport_to(Vector2(0.0, 370.0))
		_interaction.debug_plant_twice()
		_growth.debug_advance(2.0)
		_water.force_rain(30.0)
	elif args.has("--phase0-shot-soil"):
		_camera.set_zoom_immediate(0.85)
		_camera.teleport_to(Vector2(0.0, 790.0))
	elif args.has("--phase0-shot-pan"):
		_camera.set_zoom_immediate(0.75)
		_camera.teleport_to(Vector2(4300.0, 500.0))
