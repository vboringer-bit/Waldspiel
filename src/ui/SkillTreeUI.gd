class_name SkillTreeUI
extends CanvasLayer
## PHASE 4 (Master-Punkt 6 + 8): Zoom- & pannable Skilltree-UI auf Basis von
## Godot `GraphEdit` / `GraphNode`. 24 Knoten aus `data/skilltrees/oak.tres`,
## Vorbedingungen als echte Verbindungslinien, Freischalten kostet Glucose.
##
## * Oben rechts im HUD: Button "Skilltree (T)". Taste T / Esc schliesst.
## * Mittlere Maustaste = Graph verschieben (GraphEdit Standard),
##   Mausrad/Ctrl oder die +/-/1:1-Buttons = Zoom (zoom_min..zoom_max).
## * Die Knoten sind absichtlich NICHT verschiebbar (draggable = false):
##   verschoben wird der Graph, nicht das Layout.
## * Kein Tag/Nacht-Zyklus, keine neuen Assets, alle Texte DE/EN.

func _branch_color(branch: String) -> Color:
	match branch:
		"water": return Color(0.45, 0.72, 0.92)
		"leaf": return Color(0.60, 0.84, 0.55)
		"resist": return Color(0.88, 0.75, 0.48)
		"symbiosis": return Color(0.78, 0.65, 0.92)
		# REVISION 7: eigene Farben fuer Licht- und Jahreszeit-Ast.
		"light": return Color(0.96, 0.84, 0.48)
		"season": return Color(0.52, 0.82, 0.78)
	return Color.WHITE

var interaction: InteractionController

var _bg: ColorRect
var _title: Label
var _subtitle: Label
var _glucose: Label
var _count: Label
var _hint: Label
var _close: Button
var _zoom_in: Button
var _zoom_out: Button
var _zoom_reset: Button
var _graph: GraphEdit
var _widgets: Dictionary = {}     # node_id -> {node, desc, state, button}
var _acc := 0.0


func _ready() -> void:
	layer = 30
	visible = false
	_build()
	_connect()
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh_texts()
	refresh()


func setup(p_interaction: InteractionController) -> void:
	interaction = p_interaction


func _build() -> void:
	_bg = ColorRect.new()
	_bg.name = "Dimmer"
	_bg.color = Color(0.04, 0.06, 0.06, 0.88)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_title = _label(28, Color(0.92, 0.95, 0.86))
	_subtitle = _label(15, Color(0.68, 0.78, 0.72))
	_glucose = _label(19, Color(0.63, 0.85, 0.62))
	_count = _label(15, Color(0.88, 0.78, 0.50))
	_hint = _label(14, Color(0.62, 0.72, 0.68))
	add_child(_title)
	add_child(_subtitle)
	add_child(_glucose)
	add_child(_count)
	add_child(_hint)

	_close = _button("SKILL_UI_CLOSE")
	_zoom_in = _button("SKILL_UI_ZOOM_IN")
	_zoom_out = _button("SKILL_UI_ZOOM_OUT")
	_zoom_reset = _button("SKILL_UI_ZOOM_RESET")
	add_child(_close)
	add_child(_zoom_in)
	add_child(_zoom_out)
	add_child(_zoom_reset)

	_graph = GraphEdit.new()
	_graph.name = "SkillGraph"
	_graph.minimap_enabled = true
	_graph.right_disconnects = false
	_graph.zoom_min = 0.35
	_graph.zoom_max = 1.8
	_graph.zoom_step = 1.15
	_graph.zoom = 1.0
	# Die eingebaute GraphEdit-Leiste liegt sonst ueber Titel/Zeile 1.
	# Stattdessen die eigenen +/-/1:1-Buttons unten links verwenden.
	_graph.show_menu = false
	_graph.show_zoom_buttons = false
	_graph.show_grid_buttons = false
	_graph.show_minimap_button = false
	_graph.show_arrange_button = false
	_graph.show_zoom_label = false
	_graph.scroll_offset = Vector2(40.0, 20.0)
	add_child(_graph)
	_build_nodes()


func _settings(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	return ls


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.label_settings = _settings(size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(key: String) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size = Vector2(44.0, 34.0)
	return b


func _build_nodes() -> void:
	var st := SkillTree.instance
	if st == null:
		return
	for nd in st.all_nodes():
		var gn := GraphNode.new()
		gn.name = nd.id
		gn.title = tr(nd.title_key)
		gn.position_offset = nd.graph_position
		gn.draggable = false
		gn.resizable = false
		gn.selectable = false
		gn.custom_minimum_size = Vector2(268.0, 132.0)
		var col := _branch_color(nd.branch)
		gn.set_slot(0, true, 0, col, true, 0, col)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		var desc := Label.new()
		desc.text = tr(nd.desc_key)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(246.0, 42.0)
		desc.label_settings = _settings(13, Color(0.82, 0.86, 0.82))
		var state := _label(13, Color(0.70, 0.78, 0.70))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(246.0, 34.0)
		btn.pressed.connect(_on_unlock_pressed.bind(nd.id))
		box.add_child(desc)
		box.add_child(state)
		box.add_child(btn)
		gn.add_child(box)
		_graph.add_child(gn)
		_widgets[nd.id] = {"node": gn, "desc": desc, "state": state,
			"button": btn, "data": nd}

	# Verbindungslinien erst NACHDEM alle GraphNodes im Baum sind.
	for pair in st.connection_pairs():
		var from := String(pair[0])
		var to := String(pair[1])
		if _graph.has_node(from) and _graph.has_node(to):
			_graph.connect_node(from, 0, to, 0)


func _connect() -> void:
	_close.pressed.connect(close)
	_zoom_in.pressed.connect(_on_zoom.bind(1.15))
	_zoom_out.pressed.connect(_on_zoom.bind(1.0 / 1.15))
	_zoom_reset.pressed.connect(_on_zoom_reset)
	EventBus.skilltree_open_requested.connect(open)
	EventBus.skill_unlocked.connect(func(_id): refresh())
	EventBus.skilltree_changed.connect(func(): refresh())
	EventBus.tree_selected.connect(func(_t): refresh())
	EventBus.game_loaded.connect(func(): refresh())
	EventBus.locale_changed.connect(func(_l): refresh_texts())
	# Vom Spieler gezogene Verbindungen ignorieren: das Layout ist fest.
	_graph.connection_request.connect(func(_a, _b, _c, _d): pass)
	_graph.disconnection_request.connect(func(_a, _b, _c, _d): pass)


func _layout() -> void:
	var vp := Vector2(get_viewport().get_visible_rect().size)
	_bg.position = Vector2.ZERO
	_bg.size = vp
	_title.position = Vector2(32.0, 22.0)
	_title.size = Vector2(700.0, 40.0)
	_subtitle.position = Vector2(32.0, 64.0)
	_subtitle.size = Vector2(1100.0, 26.0)
	_glucose.position = Vector2(vp.x - 560.0, 26.0)
	_glucose.size = Vector2(340.0, 30.0)
	_count.position = Vector2(vp.x - 560.0, 58.0)
	_count.size = Vector2(340.0, 26.0)
	_close.position = Vector2(vp.x - 190.0, 24.0)
	_close.size = Vector2(158.0, 40.0)
	_hint.position = Vector2(32.0, vp.y - 42.0)
	_hint.size = Vector2(vp.x - 64.0, 28.0)
	_graph.position = Vector2(28.0, 104.0)
	_graph.size = Vector2(vp.x - 56.0, vp.y - 158.0)
	_zoom_reset.position = Vector2(40.0, vp.y - 86.0)
	_zoom_reset.size = Vector2(58.0, 34.0)
	_zoom_out.position = Vector2(104.0, vp.y - 86.0)
	_zoom_out.size = Vector2(48.0, 34.0)
	_zoom_in.position = Vector2(158.0, vp.y - 86.0)
	_zoom_in.size = Vector2(48.0, 34.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc >= 0.2:
		_acc = 0.0
		refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_T:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------- #
# Oeffnen / Zoomen / Freischalten
# --------------------------------------------------------------------------- #
func open() -> void:
	visible = true
	refresh()
	_layout()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func is_open() -> bool:
	return visible


func _on_zoom(factor: float) -> void:
	_graph.zoom = clampf(_graph.zoom * factor,
		_graph.zoom_min, _graph.zoom_max)
	refresh()


func _on_zoom_reset() -> void:
	_graph.zoom = 1.0
	_graph.scroll_offset = Vector2(40.0, 20.0)
	refresh()


func _on_unlock_pressed(id: String) -> void:
	var st := SkillTree.instance
	if st == null or interaction == null:
		return
	if st.unlock(id, interaction.selected_tree):
		refresh()


# --------------------------------------------------------------------------- #
# Anzeige
# --------------------------------------------------------------------------- #
func refresh_texts() -> void:
	var st := SkillTree.instance
	_title.text = tr("SKILL_UI_TITLE")
	_subtitle.text = tr("SKILL_UI_SUBTITLE")
	_hint.text = tr("SKILL_UI_HINT")
	_close.text = tr("SKILL_UI_CLOSE")
	_zoom_in.text = tr("SKILL_UI_ZOOM_IN")
	_zoom_out.text = tr("SKILL_UI_ZOOM_OUT")
	_zoom_reset.text = tr("SKILL_UI_ZOOM_RESET")
	for id in _widgets.keys():
		var w: Dictionary = _widgets[id]
		var nd: SkillNodeData = w["data"]
		(w["node"] as GraphNode).title = tr(nd.title_key)
		(w["desc"] as Label).text = tr(nd.desc_key)
	if st == null:
		return


func refresh() -> void:
	var st := SkillTree.instance
	if st == null:
		return
	var tree: BaseTree = interaction.selected_tree if interaction != null else null
	if tree != null:
		_glucose.text = "%s  %.1f" % [tr("SKILL_UI_GLUCOSE"), tree.glucose]
	else:
		_glucose.text = tr("SKILL_UI_NO_TREE")
	_count.text = tr("SKILL_UI_COUNT") % st.unlocked_count()

	for id in _widgets.keys():
		var w: Dictionary = _widgets[id]
		var nd: SkillNodeData = w["data"]
		var gn: GraphNode = w["node"]
		var state: Label = w["state"]
		var btn: Button = w["button"]
		if st.is_unlocked(nd.id):
			state.text = tr("SKILL_UI_UNLOCKED")
			state.label_settings.font_color = Color(0.60, 0.88, 0.62)
			btn.text = tr("SKILL_UI_UNLOCKED")
			btn.disabled = true
			gn.modulate = Color(0.78, 1.0, 0.80)
		elif not st.is_available(nd.id):
			state.text = tr("SKILL_UI_LOCKED")
			state.label_settings.font_color = Color(0.72, 0.62, 0.58)
			btn.text = tr("SKILL_UI_UNLOCK") % int(nd.cost)
			btn.disabled = true
			gn.modulate = Color(0.62, 0.64, 0.64)
		else:
			var enough := tree != null and tree.glucose >= nd.cost
			state.text = tr("SKILL_UI_AVAILABLE")
			state.label_settings.font_color = Color(0.90, 0.86, 0.62)
			btn.text = tr("SKILL_UI_UNLOCK") % int(nd.cost)
			btn.disabled = not enough
			gn.modulate = Color(1.0, 1.0, 1.0)


# --------------------------------------------------------------------------- #
# Debug-Hooks (Smoke-Test / Screenshots)
# --------------------------------------------------------------------------- #
func debug_node_count() -> int:
	var n := 0
	for c in _graph.get_children():
		if c is GraphNode:
			n += 1
	return n


func debug_connection_count() -> int:
	return _graph.get_connection_list().size()


func debug_zoom() -> float:
	return _graph.zoom


func debug_set_zoom(value: float) -> void:
	_graph.zoom = clampf(value, _graph.zoom_min, _graph.zoom_max)
