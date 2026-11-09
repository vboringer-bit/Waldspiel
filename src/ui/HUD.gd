class_name HUD
extends CanvasLayer
## PHASE 1 HUD (Punkt 8): Glucose mit Icon, Wasser-Balken des ausgewaehlten
## Baums, Inventar, Zeit-Platzhalter, AUTO/MANUELL, Skilltree-Platzhalter,
## Speichern/Laden, DE/EN-Umschaltung, Toast + Regen-Anzeige.
## PHASE 2: Anzeige der Wurzel-Kosten (Ghost-Preview) + Reservoir-Fuellstand.
## PHASE 3: Jahreszeiten-Fortschritt, Zeitspulen x1/x3/x10, Pause und
## Schwierigkeits-Umschalter. Skilltree-UI bleibt PHASE 4.

const BAR_HEIGHT := 148.0
const ICON_DIR := "res://assets/placeholders/"

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


func setup(p_interaction: InteractionController, p_growth: GrowthSystem,
		p_water: WaterSystem, p_time: TimeManager, p_save: SaveManager,
		p_world_state: WorldState = null) -> void:
	interaction = p_interaction
	growth_system = p_growth
	water_system = p_water
	time_manager = p_time
	save_manager = p_save
	world_state = p_world_state
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
	EventBus.time_scale_changed.connect(func(_s, _p): refresh())
	EventBus.difficulty_changed.connect(func(_d): refresh_texts())


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

	_skill_button.position = Vector2(vp.x - 250.0, 24.0)
	_skill_button.size = Vector2(226.0, 40.0)
	_hint.position = Vector2(24.0, y - 30.0)
	_toast_label.position = Vector2(0.0, 128.0)
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
	_save_button.text = tr("UI_SAVE")
	_load_button.text = tr("UI_LOAD")
	_water_caption.text = tr("HUD_WATER")
	_rain_label.text = tr("MSG_SNOW") if _is_winter() else tr("MSG_RAIN")
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
	_rain_label.text = tr("MSG_SNOW") if _is_winter() else tr("MSG_RAIN")
	_mode_button.text = tr("MODE_AUTO") if Global.auto_mode else tr("MODE_MANUAL")
	_lang_button.text = Global.locale.to_upper()
	_refresh_reservoir_label(tree)


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
