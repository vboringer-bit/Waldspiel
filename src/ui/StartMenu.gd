class_name StartMenu
extends CanvasLayer
## PHASE 3: Schwierigkeitsgrad VOR Spielstart waehlbar (Master-Punkt 4.2).
##
## Kleines, nicht-blockierendes Panel in der Bildmitte: die Welt laeuft und
## bleibt sichtbar, es gibt KEINEN get_tree().paused (sonst kaeme die Leertaste
## zum Entpausen nicht mehr an). Wer --difficulty=... oder ein Test-/Shot-Flag
## uebergibt, sieht das Panel nicht. Danach ist der Grad jederzeit im HUD
## umschaltbar und wird im Savegame (v4) mitgeschrieben.

var _root: Control
var _bg: ColorRect
var _title: Label
var _subtitle: Label
var _hint: Label
var _buttons: Array[Button] = []
var _show: bool = false


func _ready() -> void:
	_build()
	_connect()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_root.visible = _show


func setup(p_show: bool) -> void:
	_show = p_show
	if _root != null:
		_root.visible = p_show
		refresh_texts()


func _build() -> void:
	_root = Control.new()
	_root.name = "StartMenuRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.09, 0.08, 0.92)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bg)

	var title_settings := LabelSettings.new()
	title_settings.font_size = 30
	title_settings.font_color = Color(0.94, 0.94, 0.84)
	var sub_settings := LabelSettings.new()
	sub_settings.font_size = 16
	sub_settings.font_color = Color(0.72, 0.82, 0.73)
	var hint_settings := LabelSettings.new()
	hint_settings.font_size = 13
	hint_settings.font_color = Color(0.60, 0.68, 0.62)

	_title = _label("", title_settings)
	_subtitle = _label("", sub_settings)
	_hint = _label("", hint_settings)

	for key in ["START_EASY", "START_NORMAL", "START_HARD"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0.0, 46.0)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", Color(0.93, 0.92, 0.84))
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.16, 0.23, 0.20, 0.98)
		normal.border_color = Color(0.40, 0.56, 0.43, 1.0)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(6)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.24, 0.36, 0.28, 1.0)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.set_meta("key", key)
		_root.add_child(b)
		_buttons.append(b)


func _label(text: String, settings: LabelSettings) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = settings
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _connect() -> void:
	# Difficulty-Enum: 0 = LEICHT, 1 = NORMAL, 2 = SCHWER
	_buttons[0].pressed.connect(_choose.bind(0))
	_buttons[1].pressed.connect(_choose.bind(1))
	_buttons[2].pressed.connect(_choose.bind(2))
	EventBus.locale_changed.connect(func(_l): refresh_texts())


func _choose(value: int) -> void:
	Global.set_difficulty(value)
	EventBus.toast.emit(tr("MSG_DIFFICULTY_SET") % tr(Global.difficulty_name_key()))
	_root.visible = false
	_show = false


func refresh_texts() -> void:
	if _title == null:
		return
	_title.text = tr("START_TITLE")
	_subtitle.text = tr("START_SUBTITLE")
	_hint.text = tr("START_HINT")
	for b in _buttons:
		b.text = tr(String(b.get_meta("key")))


func _layout() -> void:
	if _root == null:
		return
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var w := minf(660.0, vp.x - 80.0)
	var h := 300.0
	var origin := (vp - Vector2(w, h)) * 0.5
	_root.position = Vector2.ZERO
	_root.size = vp
	_bg.position = origin
	_bg.size = Vector2(w, h)
	_title.position = origin + Vector2(28.0, 20.0)
	_title.size = Vector2(w - 56.0, 44.0)
	_subtitle.position = origin + Vector2(28.0, 66.0)
	_subtitle.size = Vector2(w - 56.0, 30.0)
	for i in _buttons.size():
		_buttons[i].position = origin + Vector2(28.0, 104.0 + float(i) * 52.0)
		_buttons[i].size = Vector2(w - 56.0, 46.0)
	_hint.position = origin + Vector2(28.0, h - 34.0)
	_hint.size = Vector2(w - 56.0, 26.0)


func is_open() -> bool:
	return _show


func debug_choose(value: int) -> void:
	_choose(value)
