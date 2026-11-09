class_name Phase0Overlay
extends CanvasLayer
## Minimales Debug-/Info-Overlay fuer PHASE 0. Ausdruecklich NICHT das HUD aus
## Punkt 8 (Inventar, Glucose, Wasser, Zeit) - das folgt in PHASE 1/3.

var chunk_manager: ChunkManager
var camera: CameraController

var _panel: ColorRect
var _title: Label
var _info: Label
var _hint: Label
var _t := 0.0


func setup(p_chunk_manager: ChunkManager, p_camera: CameraController) -> void:
	chunk_manager = p_chunk_manager
	camera = p_camera


func _ready() -> void:
	var settings := LabelSettings.new()
	settings.font_size = 18
	settings.font_color = Color(0.94, 0.92, 0.85)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	settings.line_spacing = 5

	var title_settings := LabelSettings.new()
	title_settings.font_size = 22
	title_settings.font_color = Color(1.0, 0.95, 0.82)
	title_settings.shadow_size = 2
	title_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)

	_panel = ColorRect.new()
	_panel.name = "InfoPanel"
	_panel.color = Color(0.07, 0.08, 0.08, 0.58)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_title = _make_label(tr("PHASE0_TITLE"), title_settings)
	_info = _make_label("Initialisiere Welt …", settings)
	_hint = _make_label(tr("PHASE0_HINT"), settings)

	get_viewport().size_changed.connect(refresh_layout)
	refresh_layout()


func _make_label(text: String, settings: LabelSettings) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func refresh_layout() -> void:
	if _panel == null:
		return
	var size := Vector2(get_viewport().get_visible_rect().size)
	_panel.position = Vector2(24.0, 24.0)
	_panel.size = Vector2(620.0, 112.0)
	_title.position = Vector2(38.0, 34.0)
	_info.position = Vector2(38.0, 68.0)
	_hint.position = Vector2(24.0, size.y - 88.0)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.2 or chunk_manager == null or camera == null:
		return
	_t = 0.0
	_info.text = "Seed %d  ·  %d Chunks  ·  Kamera x=%d  ·  Zoom %.2fx\n%s" % [
		Global.world_seed,
		chunk_manager.loaded_chunk_count(),
		int(camera.global_position.x),
		camera.zoom.x,
		tr("PHASE0_LAYERS"),
	]
