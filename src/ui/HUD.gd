class_name HUD
extends CanvasLayer
## PHASE 1 HUD (Punkt 8): Glucose mit Icon, Wasser-Balken des ausgewaehlten
## Baums, Inventar, Zeit-Platzhalter, AUTO/MANUELL, Skilltree-Platzhalter,
## Speichern/Laden, DE/EN-Umschaltung, Toast + Regen-Anzeige.
## PHASE 2: Anzeige der Wurzel-Kosten (Ghost-Preview) + Reservoir-Fuellstand.
## PHASE 3: Jahreszeiten-Fortschritt, Zeitspulen x1/x3/x10, Pause und
## Schwierigkeits-Umschalter. Skilltree-UI bleibt PHASE 4.

const BAR_HEIGHT := 148.0
const ICON_DIR := PixelArt.DIR

var interaction: InteractionController
var growth_system: GrowthSystem
var water_system: WaterSystem
var time_manager: TimeManager
var save_manager: SaveManager
var world_state: WorldState

var _bar: ColorRect
var _glucose_icon: TextureRect
var _glucose_label: Label
var _seed_icon: TextureRect
var _inventory_label: Label
var _water_caption: Label
var _water_bar: ProgressBar
var _water_label: Label
var _selected_label: Label
var _time_label: Label
var _mode_button: Button
var _lang_button: Button
var _save_button: Button
var _load_button: Button
var _skill_button: Button
var _rain_label: Label
var _growth_label: Label
var _reservoir_label: Label
var _difficulty_button: Button
var _scale_buttons: Array[Button] = []
var _pause_button: Button
var _season_bar: ProgressBar
var _season_label: Label
var _hint: Label
var _toast_label: Label

var _settings: LabelSettings
var _small: LabelSettings
var _cost_settings: LabelSettings
var _warn_settings: LabelSettings
var _toast_timer: float = 0.0
var _acc: float = 0.0
var _ghost_cost: float = -1.0
var _ghost_material: String = ""
var _ghost_affordable: bool = true
## PHASE-4-FIX: 0 = Regen, 1 = Schnee, dazwischen sanfter Uebergang.
var _precipitation_blend: float = -1.0

## PHASE 5: eigenes, kollisionsfreies Oekologie-Panel oben links.
var wildlife = null
var forest_health = null
var parasite_system = null
var _p5_panel: ColorRect
var _p5_title: Label
var _p5_health: Label
var _p5_health_bar: ProgressBar
var _p5_food: Label
var _p5_wildlife: Label
var _p5_parasites: Label
## REVISION 5: Versorgungs-Bilanz des ausgewaehlten Baums.
var _p5_supply: Label
## REVISION 7: echtes Licht aus der Nachbarschaft (Lichtkonkurrenz).
var _p7_light: Label
## PHASE 6: Bodenzeile (pH/N-P-K/Netz) + aktives Katastrophen-Ereignis.
## Bewusst als EIGENE Zeilen: "Versorgung" (R5) und "Licht" (R7) bleiben
## unveraendert erhalten und werden nicht verdrängt.
var _p6_soil: Label
var _p6_event: Label


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_save: SaveManager,
		p_world_state: WorldState = null, p_wildlife = null,
		p_health = null, p_parasites = null) -> void:
	interaction = p_interaction
	growth_system = p_growth
	water_system = p_water
	time_manager = p_time
	save_manager = p_save
	world_state = p_world_state
	wildlife = p_wildlife
	forest_health = p_health
	parasite_system = p_parasites
	refresh_texts()
	refresh()


func _ready() -> void:
	_build_settings()
	_build_widgets()
	_connect()
	refresh_texts()
	_layout()
	get_viewport().size_changed.connect(_layout)


func _build_settings() -> void:
	_settings = LabelSettings.new()
	_settings.font_size = 18
	_settings.font_color = Color(0.94, 0.92, 0.85)
	_settings.shadow_size = 1
	_settings.shadow_color = Color(0, 0, 0, 0.7)

	_small = LabelSettings.new()
	_small.font_size = 14
	_small.font_color = Color(0.72, 0.78, 0.74)
	_small.shadow_size = 1
	_small.shadow_color = Color(0, 0, 0, 0.7)

	_cost_settings = LabelSettings.new()
	_cost_settings.font_size = 13
	_cost_settings.font_color = Color(0.78, 0.90, 0.68)
	_cost_settings.shadow_size = 1
	_cost_settings.shadow_color = Color(0, 0, 0, 0.8)

	_warn_settings = LabelSettings.new()
	_warn_settings.font_size = 13
	_warn_settings.font_color = Color(0.94, 0.62, 0.55)
	_warn_settings.shadow_size = 1
	_warn_settings.shadow_color = Color(0, 0, 0, 0.8)


func _build_widgets() -> void:
	_bar = ColorRect.new()
	_bar.name = "HUDBar"
	_bar.color = Color(0.07, 0.09, 0.09, 0.82)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

	_glucose_icon = _icon("glucose.png")
	_glucose_label = _label("Glucose  0.0", _settings)
	_seed_icon = _icon("acorn.png")
	# REVISION 1: Eichel-Icon ist jetzt anklickbar -> aufnehmen & schweben lassen.
	_seed_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_seed_icon.size = Vector2(28.0, 28.0)
	_seed_icon.tooltip_text = tr("HUD_ACORN_TIP")
	_seed_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_seed_icon.gui_input.connect(_on_seed_icon_input)
	_inventory_label = _label("× 0", _settings)

	_water_caption = _label("Wasser", _small)
	_water_bar = ProgressBar.new()
	_water_bar.min_value = 0.0
	_water_bar.max_value = 100.0
	_water_bar.value = 0.0
	_water_bar.show_percentage = false
	_water_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.13, 0.13, 0.95)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.34, 0.61, 0.78, 1.0)
	fill.set_corner_radius_all(3)
	_water_bar.add_theme_stylebox_override("background", bg)
	_water_bar.add_theme_stylebox_override("fill", fill)
	add_child(_water_bar)
	_water_label = _label("0%", _small)

	_selected_label = _label("Kein Baum ausgewählt", _small)
	_time_label = _label("Jahr 1 · Frühling", _small)

	_mode_button = _button("AUTO")
	_lang_button = _button("DE")
	_save_button = _button("Speichern")
	_load_button = _button("Laden")
	_rain_label = _label("Es regnet", _settings)
	_rain_label.visible = false

	_growth_label = _label("", _cost_settings)
	_reservoir_label = _label("", _cost_settings)

	_skill_button = _button("Skilltree (T)")
	_skill_button.disabled = false          # PHASE 4: UI ist da

	# --- PHASE 3: Schwierigkeit + Zeitspulen + Pause + Jahreszeitenbalken ---
	_difficulty_button = _button("Schwierigkeit: Normal")
	_difficulty_button.name = "DifficultyButton"
	for i in 3:
		var sb := _button(["x1", "x3", "x10"][i])
		sb.name = "TimeScaleButton%d" % i
		_scale_buttons.append(sb)
	_pause_button = _button("Pause")
	_pause_button.name = "PauseButton"
	_season_label = _label("", _small)
	_season_bar = ProgressBar.new()
	_season_bar.min_value = 0.0
	_season_bar.max_value = 100.0
	_season_bar.value = 0.0
	_season_bar.show_percentage = false
	_season_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0.10, 0.13, 0.13, 0.95)
	sbg.set_corner_radius_all(3)
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = Color(0.62, 0.79, 0.55, 1.0)
	sfill.set_corner_radius_all(3)
	_season_bar.add_theme_stylebox_override("background", sbg)
	_season_bar.add_theme_stylebox_override("fill", sfill)
	add_child(_season_bar)

	# --- PHASE 5: Wald-Gesundheit, Futter, Tiere, Parasiten, Pilze -----------
	_p5_panel = ColorRect.new()
	_p5_panel.name = "Phase5Panel"
	_p5_panel.color = Color(0.07, 0.10, 0.09, 0.82)
	_p5_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_p5_panel)
	_p5_title = _label("PHASE 5", _settings)
	_p5_health = _label("", _small)
	_p5_health_bar = ProgressBar.new()
	_p5_health_bar.min_value = 0.0
	_p5_health_bar.max_value = 100.0
	_p5_health_bar.value = 0.0
	_p5_health_bar.show_percentage = false
	_p5_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p5bg := StyleBoxFlat.new()
	p5bg.bg_color = Color(0.10, 0.13, 0.13, 0.95)
	p5bg.set_corner_radius_all(3)
	var p5fill := StyleBoxFlat.new()
	p5fill.bg_color = Color(0.55, 0.80, 0.48, 1.0)
	p5fill.set_corner_radius_all(3)
	_p5_health_bar.add_theme_stylebox_override("background", p5bg)
	_p5_health_bar.add_theme_stylebox_override("fill", p5fill)
	add_child(_p5_health_bar)
	_p5_food = _label("", _small)
	_p5_wildlife = _label("", _small)
	_p5_parasites = _label("", _small)
	_p5_supply = _label("", _small)
	_p5_supply.modulate = Color(0.74, 0.88, 0.70, 1.0)
	_p7_light = _label("", _small)
	_p7_light.modulate = Color(0.90, 0.84, 0.58, 1.0)
	_p6_soil = _label("", _small)
	_p6_soil.name = "Phase6Soil"
	_p6_soil.modulate = Color(0.76, 0.88, 0.68, 1.0)
	_p6_event = _label("", _small)
	_p6_event.name = "Phase6Event"
	_p6_event.modulate = Color(0.92, 0.78, 0.62, 1.0)

	_hint = _label("", _small)
	_toast_label = _label("", _settings)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0


func _icon(filename: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ICON_DIR + filename)
	t.size = Vector2(16.0, 16.0)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _label(text: String, settings: LabelSettings) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = settings
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 42.0)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.93, 0.92, 0.84))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.21, 0.20, 0.96)
	normal.border_color = Color(0.34, 0.44, 0.39, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.31, 0.28, 0.98)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.30, 0.40, 0.31, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.12, 0.14, 0.14, 0.7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	add_child(b)
	return b


func _on_seed_icon_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if interaction != null:
				interaction.hud_acorn_clicked()
			_seed_icon.accept_event()


## REVISION 4: Nur ein echter Klick auf das Icon nimmt eine Eichel aus dem
## Inventar. Das Icon wird waehrend des Tragens markiert, damit sichtbar ist,
## welche Eichel „angeklickt" wurde.
func debug_click_seed_icon() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_on_seed_icon_input(ev)


## PHASE 4: Skilltree-Button oben rechts oeffnet die GraphEdit-UI.
func _on_skill_pressed() -> void:
	EventBus.skilltree_open_requested.emit()


func _is_winter() -> bool:
	return time_manager != null and time_manager.is_winter()


func _on_precipitation_blend_changed(blend: float) -> void:
	_precipitation_blend = clampf(blend, 0.0, 1.0)
	refresh()


func _precipitation_text() -> String:
	var blend := _precipitation_blend
	if blend < 0.0:
		blend = 1.0 if _is_winter() else 0.0
	if blend > 0.05 and blend < 0.95:
		return tr("MSG_SNOW_MELT")
	return tr("MSG_SNOW") if blend >= 0.5 else tr("MSG_RAIN")


func debug_rain_label_text() -> String:
	return _rain_label.text


func _connect() -> void:
	_skill_button.pressed.connect(_on_skill_pressed)
	_mode_button.pressed.connect(_on_mode_pressed)
	_lang_button.pressed.connect(_on_lang_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	EventBus.toast.connect(_on_toast)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.inventory_changed.connect(func(_count): refresh())
	EventBus.tree_selected.connect(func(_tree): refresh())
	EventBus.tree_grew.connect(func(_tree, _part): refresh())
	EventBus.rain_started.connect(func(_duration): refresh())
	EventBus.rain_stopped.connect(func(): refresh())
	EventBus.ghost_preview.connect(_on_ghost_preview)
	EventBus.root_grown.connect(func(_tree, _tile, _cost): refresh())
	EventBus.reservoir_dried.connect(func(_tile): refresh())
	EventBus.mode_changed.connect(func(_auto): _hide_ghost_info())
	# PHASE 3
	_difficulty_button.pressed.connect(_on_difficulty_pressed)
	for i in _scale_buttons.size():
		_scale_buttons[i].pressed.connect(_on_scale_pressed.bind(TimeManager.SCALES[i]))
	_pause_button.pressed.connect(_on_pause_pressed)
	EventBus.season_changed.connect(func(_y, _s): refresh())
	EventBus.precipitation_mode_changed.connect(func(_snow): refresh())
	EventBus.precipitation_blend_changed.connect(_on_precipitation_blend_changed)
	EventBus.time_scale_changed.connect(func(_s, _p): refresh())
	EventBus.difficulty_changed.connect(func(_d): refresh_texts())
	# PHASE 5: Oekologie-Panel reagiert auf alle neuen Signale.
	EventBus.forest_health_changed.connect(func(_v): refresh())
	EventBus.food_changed.connect(func(_v): refresh())
	EventBus.wildlife_changed.connect(func(): refresh())
	EventBus.animal_spawned.connect(func(_v): refresh())
	EventBus.animal_state_changed.connect(func(_a, _b): refresh())
	EventBus.colony_grown.connect(func(_v): refresh())
	EventBus.parasite_spawned.connect(func(_a, _b): refresh())
	EventBus.parasite_removed.connect(func(_a, _b, _c): refresh())
	EventBus.fungus_patch_spawned.connect(func(_v): refresh())
	EventBus.seed_planted_remote.connect(func(_v): refresh())
	EventBus.game_loaded.connect(func(): refresh())
	# PHASE 6: Boden / Netz / Ereignisse aktualisieren die zwei neuen Zeilen.
	EventBus.soil_changed.connect(func(_r): refresh())
	EventBus.mycorrhiza_changed.connect(func(_n): refresh())
	EventBus.disaster_started.connect(func(_k, _d): refresh())
	EventBus.disaster_ended.connect(func(_k): refresh())


# --------------------------------------------------------------------------- #
# Layout
# --------------------------------------------------------------------------- #
func _layout() -> void:
	if _bar == null:
		return
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var y := vp.y - BAR_HEIGHT
	_bar.position = Vector2(0.0, y)
	_bar.size = Vector2(vp.x, BAR_HEIGHT)

	_glucose_icon.position = Vector2(24.0, y + 26.0)
	_glucose_label.position = Vector2(48.0, y + 20.0)
	_seed_icon.position = Vector2(240.0, y + 22.0)
	_inventory_label.position = Vector2(276.0, y + 20.0)
	_water_caption.position = Vector2(370.0, y + 18.0)
	_water_bar.position = Vector2(370.0, y + 48.0)
	_water_bar.size = Vector2(220.0, 18.0)
	_water_label.position = Vector2(600.0, y + 45.0)
	_selected_label.position = Vector2(700.0, y + 20.0)
	_time_label.position = Vector2(700.0, y + 52.0)

	_mode_button.position = Vector2(990.0, y + 30.0)
	_mode_button.size = Vector2(150.0, 42.0)
	_lang_button.position = Vector2(1150.0, y + 30.0)
	_lang_button.size = Vector2(66.0, 42.0)
	_save_button.position = Vector2(1226.0, y + 30.0)
	_save_button.size = Vector2(120.0, 42.0)
	_load_button.position = Vector2(1356.0, y + 30.0)
	_load_button.size = Vector2(110.0, 42.0)
	_rain_label.position = Vector2(1490.0, y + 34.0)

	_growth_label.position = Vector2(1620.0, y + 18.0)
	_reservoir_label.position = Vector2(1620.0, y + 52.0)

	# Dritte HUD-Reihe (PHASE 3): Schwierigkeit / Zeit / Jahreszeit.
	_difficulty_button.position = Vector2(990.0, y + 96.0)
	_difficulty_button.size = Vector2(190.0, 40.0)
	var sx := 1190.0
	var widths := [52.0, 52.0, 60.0]
	for i in _scale_buttons.size():
		_scale_buttons[i].position = Vector2(sx, y + 96.0)
		_scale_buttons[i].size = Vector2(widths[i], 40.0)
		sx += widths[i] + 6.0
	_pause_button.position = Vector2(sx + 6.0, y + 96.0)
	_pause_button.size = Vector2(110.0, 40.0)
	_season_label.position = Vector2(1500.0, y + 74.0)
	_season_label.size = Vector2(300.0, 24.0)
	_season_bar.position = Vector2(1500.0, y + 104.0)
	_season_bar.size = Vector2(300.0, 16.0)

	_p5_panel.position = Vector2(20.0, 24.0)
	_p5_panel.size = Vector2(360.0, 250.0)
	_p5_title.position = Vector2(36.0, 30.0)
	_p5_health.position = Vector2(36.0, 58.0)
	_p5_health_bar.position = Vector2(36.0, 82.0)
	_p5_health_bar.size = Vector2(328.0, 10.0)
	_p5_food.position = Vector2(36.0, 100.0)
	_p5_wildlife.position = Vector2(200.0, 100.0)
	_p5_parasites.position = Vector2(36.0, 122.0)
	_p5_supply.position = Vector2(36.0, 146.0)
	_p7_light.position = Vector2(36.0, 168.0)
	# PHASE 6: zwei neue Zeilen, ohne die R5/R7-Zeilen zu verschieben.
	_p6_soil.position = Vector2(36.0, 192.0)
	_p6_soil.size = Vector2(330.0, 22.0)
	_p6_event.position = Vector2(36.0, 216.0)
	_p6_event.size = Vector2(330.0, 22.0)

	_skill_button.position = Vector2(vp.x - 250.0, 24.0)
	_skill_button.size = Vector2(226.0, 40.0)
	_hint.position = Vector2(24.0, y - 30.0)
	# PHASE 6: Toast unter das erweiterte Oekologie-Panel legen.
	_toast_label.position = Vector2(0.0, 282.0)
	_toast_label.size = Vector2(vp.x, 44.0)


# --------------------------------------------------------------------------- #
# Texte / Werte
# --------------------------------------------------------------------------- #
func refresh_texts() -> void:
	if _mode_button == null:
		return
	_hint.text = tr("HUD_HINT")
	if _seed_icon != null:
		_seed_icon.tooltip_text = tr("HUD_ACORN_TIP")
	_skill_button.text = tr("HUD_SKILLTREE")
	if _p5_title != null:
		_p5_title.text = tr("HUD_PHASE6")
	_save_button.text = tr("UI_SAVE")
	_load_button.text = tr("UI_LOAD")
	_water_caption.text = tr("HUD_WATER")
	_rain_label.text = _precipitation_text()
	_mode_button.text = tr("MODE_AUTO") if Global.auto_mode else tr("MODE_MANUAL")
	_lang_button.text = Global.locale.to_upper()
	_refresh_difficulty()
	_refresh_growth_label()


func refresh() -> void:
	if _glucose_label == null or interaction == null:
		return
	var tree := interaction.selected_tree
	var glucose := 0.0
	var water := 0.0
	if tree != null:
		glucose = tree.glucose
		water = tree.water
	_glucose_label.text = "%s  %.1f" % [tr("HUD_GLUCOSE"), glucose]
	_inventory_label.text = "× %d" % interaction.get_seed_count()
	_seed_icon.modulate = Color(1.0, 0.82, 0.46) if interaction.carrying \
		else Color(1.0, 1.0, 1.0)
	_water_bar.value = water
	_water_label.text = "%d%%" % int(water)
	if tree != null:
		_selected_label.text = "%s: %s" % [tr("HUD_SELECTED"), tree.species.species_name]
	else:
		_selected_label.text = tr("HUD_NO_TREE")
	_time_label.text = time_manager.get_label() if time_manager != null else ""
	_refresh_difficulty()
	_refresh_time_controls()
	_rain_label.visible = water_system != null and water_system.raining
	_rain_label.text = _precipitation_text()
	_mode_button.text = tr("MODE_AUTO") if Global.auto_mode else tr("MODE_MANUAL")
	_lang_button.text = Global.locale.to_upper()
	_refresh_reservoir_label(tree)
	_refresh_p5_panel()
	_refresh_p6_panel()


func _refresh_p5_panel() -> void:
	if _p5_health == null:
		return
	var health_pct := 0.0
	var food_count := 0
	var animal_count := 0
	var parasite_count := 0
	var fungus_count := 0
	if forest_health != null:
		health_pct = forest_health.value * 100.0
	if wildlife != null:
		food_count = wildlife.debug_food()
		animal_count = wildlife.debug_total_animal_count()
	if parasite_system != null:
		parasite_count = parasite_system.debug_parasite_count()
		fungus_count = parasite_system.debug_fungus_count()
	_p5_health.text = "%s: %d%%" % [tr("HUD_FOREST_HEALTH"), int(roundf(health_pct))]
	_p5_health_bar.value = health_pct
	_p5_food.text = "%s: %d" % [tr("HUD_FOOD"), food_count]
	_p5_wildlife.text = "%s: %d" % [tr("HUD_WILDLIFE"), animal_count]
	_p5_parasites.text = "%s: %d · %s: %d" % [
		tr("HUD_PARASITES"), parasite_count, tr("HUD_FUNGI"), fungus_count]


	# REVISION 5: echte Versorgungs-Bilanz (Wasser/Sonne/Naehrstoffe/Wurzeln)
	# plus der jeweils knappste Faktor. Kein erfundener Wert: alles kommt aus
	# BaseTree.environment_parts().
	var tree: BaseTree = null
	if interaction != null:
		tree = interaction.selected_tree
	if tree == null:
		_p5_supply.text = ""
		_p7_light.text = ""
	else:
		var parts := tree.environment_parts()
		var total := int(roundf(clampf(float(parts["total"]), 0.0, 1.0) * 100.0))
		var worst := 2.0
		var limit := "SUPPLY_LIMIT_OK"
		var pairs := [["water", "SUPPLY_LIMIT_WATER"],
			["sun", "SUPPLY_LIMIT_SUN"],
			["nutrients", "SUPPLY_LIMIT_NUTRIENTS"],
			["roots", "SUPPLY_LIMIT_ROOTS"]]
		for pair in pairs:
			var v := float(parts[String(pair[0])])
			if v < worst:
				worst = v
				limit = String(pair[1])
		if worst >= 0.85:
			limit = "SUPPLY_LIMIT_OK"
		_p5_supply.text = tr("HUD_SUPPLY") % [total, tr(limit)]
		# REVISION 7: zeigt an, warum ein dichter Stand klein bleibt.
		var light_pct := int(roundf(tree.debug_light_factor() * 100.0))
		var light_state := "LIGHT_LIMIT_OK" if light_pct >= 99 \
			else "LIGHT_LIMIT_CROWD"
		_p7_light.text = tr("HUD_LIGHT") % [light_pct, tr(light_state)]


## PHASE 6: Welche Welt-X-Position zeigt die Bodenzeile? Bevorzugt der
## ausgewaehlte Baum, sonst die Kameramitte. Reine Abfrage, kein Seiteneffekt.
func _p6_probe_x() -> float:
	if interaction != null and interaction.selected_tree != null:
		return interaction.selected_tree.global_position.x
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		return cam.global_position.x
	return 0.0


func _refresh_p6_panel() -> void:
	if _p6_soil == null:
		return
	var chem := SoilChemistry.instance
	var net := Mycorrhiza.instance
	var dis := DisasterSystem.instance
	var net_key := "MYCORRHIZA_OFF"
	if net != null and net.symbiosis_active():
		net_key = "MYCORRHIZA_ON"
	if chem != null and chem.is_active():
		var wx := _p6_probe_x()
		var npk := chem.npk_at(wx)
		_p6_soil.text = tr("HUD_SOIL_FULL") % [
			chem.ph_at(wx), int(roundf(npk.x)), int(roundf(npk.y)),
			int(roundf(npk.z)), tr(net_key)]
	else:
		# LEICHT/NORMAL: bewusst KEINE erfundenen pH-Werte (Master 4.2).
		_p6_soil.text = tr("HUD_SOIL_SIMPLE") % [
			tr("MSG_SOIL_CHEM_OFF"), tr(net_key)]
	var ev := tr("HUD_EVENT_QUIET")
	if dis != null and dis.active_kind != DisasterSystem.Kind.NONE:
		var name_key := "DISASTER_DROUGHT"
		match dis.active_kind:
			DisasterSystem.Kind.STORM: name_key = "DISASTER_STORM"
			DisasterSystem.Kind.BEETLE: name_key = "DISASTER_BEETLE"
		ev = tr("HUD_EVENT_ACTIVE") % [tr(name_key),
			int(ceilf(dis.time_left))]
	_p6_event.text = tr("HUD_EVENT") % [ev]


func debug_soil_text() -> String:
	return _p6_soil.text if _p6_soil != null else ""


func debug_event_text() -> String:
	return _p6_event.text if _p6_event != null else ""


func debug_phase6_title() -> String:
	return _p5_title.text if _p5_title != null else ""


func debug_supply_text() -> String:
	return _p5_supply.text if _p5_supply != null else ""


func debug_light_text() -> String:
	return _p7_light.text if _p7_light != null else ""


func debug_health_text() -> String:
	return _p5_health.text if _p5_health != null else ""


func debug_food_text() -> String:
	return _p5_food.text if _p5_food != null else ""


func debug_parasites_text() -> String:
	return _p5_parasites.text if _p5_parasites != null else ""


func _refresh_growth_label() -> void:
	if _growth_label == null:
		return
	if _ghost_cost < 0.0 or Global.auto_mode:
		_growth_label.text = tr("HUD_GROWTH_IDLE")
		_growth_label.label_settings = _small
	else:
		_growth_label.text = tr("HUD_GROWTH_COST") % [_ghost_material, _ghost_cost]
		_growth_label.label_settings = _cost_settings if _ghost_affordable else _warn_settings


func _refresh_reservoir_label(tree: BaseTree) -> void:
	if _reservoir_label == null:
		return
	if water_system == null:
		_reservoir_label.text = ""
		return
	# REVISION 3: im Winter zieht der Baum KEIN Reservoir-Wasser.
	if time_manager != null and time_manager.is_winter():
		_reservoir_label.text = tr("MSG_WINTER_WATER")
		_reservoir_label.label_settings = _cost_settings
		return
	var f := water_system.reservoir_fraction(tree)
	if f < 0.0:
		_reservoir_label.text = tr("HUD_NO_RESERVOIR")
		_reservoir_label.label_settings = _small
	else:
		_reservoir_label.text = tr("HUD_RESERVOIR") % (f * 100.0)
		_reservoir_label.label_settings = _cost_settings if f > 0.25 else _warn_settings


func _on_ghost_preview(tile: Vector2i, cost: float, affordable: bool, material: String) -> void:
	if tile.x < 0:
		_hide_ghost_info()
		return
	_ghost_cost = cost
	_ghost_material = material
	_ghost_affordable = affordable
	_refresh_growth_label()


func _hide_ghost_info() -> void:
	_ghost_cost = -1.0
	_refresh_growth_label()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		refresh()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast_label.modulate.a = clampf(_toast_timer, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_toast_label.text = ""


func _on_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_timer = 3.5


func _on_locale_changed(_locale: String) -> void:
	refresh_texts()
	refresh()


func _on_mode_pressed() -> void:
	Global.auto_mode = not Global.auto_mode
	EventBus.mode_changed.emit(Global.auto_mode)
	refresh_texts()
	refresh()


func _on_lang_pressed() -> void:
	Global.locale = "en" if Global.locale == "de" else "de"
	refresh_texts()
	refresh()


# --------------------------------------------------------------------------- #
# PHASE 3: Schwierigkeit / Zeitspulen / Pause
# --------------------------------------------------------------------------- #
func _refresh_difficulty() -> void:
	if _difficulty_button == null:
		return
	_difficulty_button.text = tr("HUD_DIFFICULTY") % tr(Global.difficulty_name_key())


func _refresh_time_controls() -> void:
	if _season_bar == null or time_manager == null:
		return
	_season_bar.value = time_manager.season_progress() * 100.0
	_season_label.text = "%s · %.0f%%" % [
		time_manager.season_name(), time_manager.season_progress() * 100.0]
	for i in _scale_buttons.size():
		var active := (not time_manager.paused
			and is_equal_approx(time_manager.time_scale, float(TimeManager.SCALES[i])))
		_scale_buttons[i].modulate = (Color(0.62, 1.0, 0.68) if active
			else Color.WHITE)
	_pause_button.text = tr("UI_PAUSE")
	_pause_button.modulate = (Color(1.0, 0.72, 0.62) if time_manager.paused
		else Color.WHITE)


func _on_scale_pressed(value: float) -> void:
	if time_manager != null:
		time_manager.set_time_scale(value)
	refresh()


func _on_pause_pressed() -> void:
	if time_manager != null:
		time_manager.toggle_pause()
		EventBus.toast.emit(tr("MSG_PAUSED") if time_manager.paused
			else tr("MSG_RESUMED"))
	refresh()


func _on_difficulty_pressed() -> void:
	Global.set_difficulty((int(Global.difficulty) + 1) % 3)
	EventBus.toast.emit(tr("MSG_DIFFICULTY_SET") % tr(Global.difficulty_name_key()))
	refresh_texts()
	refresh()


func _on_save_pressed() -> void:
	if save_manager != null:
		save_manager.save_game()


func _on_load_pressed() -> void:
	if save_manager != null:
		save_manager.load_game()
	refresh()
