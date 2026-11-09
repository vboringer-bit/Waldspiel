class_name InteractionController
extends Node
## PHASE 1: Linksklick = Interaktion (Eichel pflanzen / Baum auswählen),
## Rechtsklick = Info. Mausrad + WASD bleiben PHASE 0.
## PHASE 2: Klick auf ein Wurzel-Segment laesst es in Erd-Richtung wachsen;
## die Kosten haengen vom Boden des Ziel-Tiles ab (GrowthCost). Eine
## Ghost-Preview zeigt bei Mausbewegung im MANUELL-Modus Ziel + Preis.

## REVISION 4: Der Spieler startet OHNE Eicheln im Inventar. Die zwei
## Start-Eicheln liegen stattdessen auf dem Boden (SeasonSystem) und werden
## ganz normal per Linksklick eingesammelt.
const STARTING_SEEDS := 0
const MAX_TREES := 100
const ACORN_PATH := "res://assets/placeholders/acorn.png"

var seed_count: int = STARTING_SEEDS
var first_seed_eaten: bool = false
var selected_tree: BaseTree = null

## REVISION 1: Eichel wird beim Anklicken AUFGENOMMEN und schwebt dann an der
## Maus. Erst der naechste Linksklick platziert sie auf der Oberflaeche.
## Der Vogel klaut die erste Eichel erst NACH diesem Platzierungsversuch.
var carrying: bool = false
var _carried_sprite: Sprite2D
var _carry_marker: Sprite2D
var _carry_layer: CanvasLayer
var debug_carry_screen: Vector2 = Vector2(-9999.0, -9999.0)
var debug_carry_world_x: float = 0.0

var camera: Camera2D
var generator: WorldGenerator
var trees_root: Node2D
var bird_layer: BirdEvent
var water_system: WaterSystem
var growth_system: GrowthSystem
var world_state: WorldState
var ghost: GhostPreview
## PHASE 3: Samen auf dem Boden / vergraben (bewusst untyped, damit die
## Reihenfolge der Klassen-Registrierung beim Import egal ist).
var season_system = null

var _next_id: int = 1


func setup(p_camera: Camera2D, p_chunk_manager: ChunkManager, p_trees_root: Node2D,
		p_bird_layer: BirdEvent, p_water: WaterSystem, p_growth: GrowthSystem,
		p_world_state: WorldState = null, p_ghost: GhostPreview = null,
		p_season_system = null) -> void:
	camera = p_camera
	generator = p_chunk_manager.generator
	trees_root = p_trees_root
	bird_layer = p_bird_layer
	water_system = p_water
	growth_system = p_growth
	world_state = p_world_state
	ghost = p_ghost
	season_system = p_season_system


func _process(_delta: float) -> void:
	if carrying:
		_update_carry_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE and carrying:
			clear_carrying(true)
			get_viewport().set_input_as_handled()
			return
		if key.pressed and not key.echo and key.keycode == KEY_R:
			water_system.force_rain(30.0)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if carrying:
			_update_carry_visuals()
		elif not Global.auto_mode and camera != null:
			update_ghost(camera.get_global_mouse_position())
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or camera == null:
		return
	var world_pos := camera.get_global_mouse_position()
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_left_click(world_pos)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if carrying:
			clear_carrying(true)
			get_viewport().set_input_as_handled()
		else:
			_right_click(world_pos)


func _left_click(pos: Vector2) -> void:
	# REVISION 4: Eine schwebende Eichel wird NUR noch auf dem Boden platziert.
	# Ein Klick in den Himmel / ins HUD verbraucht sie nicht mehr.
	if carrying:
		var surface := generator.height_smooth_at(pos.x)
		if pos.y < surface - 8.0:
			EventBus.toast.emit(tr("MSG_ACORN_GROUND_ONLY"))
			get_viewport().set_input_as_handled()
			return
		_place_carried(pos)
		get_viewport().set_input_as_handled()
		return
	# PHASE 3: eine herumliegende Eichel aufsammeln (Samen finden).
	if season_system != null and season_system.collect_at(pos):
		get_viewport().set_input_as_handled()
		return
	# PHASE 2: im MANUELL-Modus hat ein Wurzelklick Vorrang vor der Baum-Auswahl.
	if not Global.auto_mode:
		var hit := find_root_hit(pos)
		if not hit.is_empty():
			manual_root_growth(hit["tree"], hit["segment"])
			return
	var tree := find_tree_at(pos)
	if tree != null:
		if Global.auto_mode:
			select_tree(tree)
		else:
			manual_growth(tree, pos)
		return
	# REVISION 4: Ein Klick IRGENDWO im Bild darf keine Eichel aus dem
	# Inventar nehmen. Einziger Einstieg ist das Eichel-Icon im HUD
	# (HUD._on_seed_icon_input -> hud_acorn_clicked()). Leerer Boden,
	# Himmel und Baeume tun hier bewusst gar nichts mehr.


func _right_click(pos: Vector2) -> void:
	# PHASE 3: vergrabene Eicheln geben einen Hinweis statt Boden-Info.
	if season_system != null and season_system.has_buried_at(pos):
		EventBus.toast.emit(tr("MSG_SEED_BURIED"))
		return
	var tree := find_tree_at(pos)
	if tree != null:
		select_tree(tree)
		EventBus.toast.emit(tree.get_info_text())
		return
	var gx := int(floor(pos.x / float(WorldGenerator.TILE_SIZE)))
	var ty := int(floor(pos.y / float(WorldGenerator.TILE_SIZE)))
	var kind := generator.material_at(gx, ty)
	var depth := int(maxf(pos.y - generator.height_at(pos.x), 0.0))
	var cost := GrowthCost.for_tile(generator, gx, ty,
		Global.difficulty_factor("growth_cost"))
	EventBus.toast.emit(tr("MSG_SOIL_INFO") % [
		GrowthCost.material_name(kind), depth, cost, Global.world_seed])


# --------------------------------------------------------------------------- #
# Eicheln & Keimung
# --------------------------------------------------------------------------- #
func plant_seed_at(pos: Vector2, instant: bool = false,
		already_paid: bool = false) -> bool:
	if not already_paid:
		if seed_count <= 0:
			return false
		seed_count -= 1
		EventBus.inventory_changed.emit(seed_count)
	EventBus.seed_placed.emit(pos)
	if not instant:
		_spawn_acorn_sprite(pos)

	# 1. Eichel: scripted Vogel-Event
	if not first_seed_eaten:
		first_seed_eaten = true
		EventBus.seed_eaten.emit(pos)
		if not instant:
			bird_layer.spawn_bird(pos, false)
		EventBus.toast.emit(tr("MSG_BIRD_EVENT"))
		return true

	# 2. Eichel: Keimung
	if trees_root.get_child_count() >= MAX_TREES:
		return false
	var tree := spawn_tree_at(pos, {})
	select_tree(tree)
	EventBus.toast.emit(tr("MSG_GERMINATED"))
	return true


func spawn_tree_at(pos: Vector2, data: Dictionary) -> BaseTree:
	# REVISION 1: Baum steht auf der fliessenden Oberkante (4px-Raster),
	# nicht mehr auf der groben 16px-Rasterstufe.
	var sx := roundf(pos.x / float(WorldGenerator.TILE_SIZE)) * float(WorldGenerator.TILE_SIZE)
	var snapped := Vector2(sx,
		roundf(generator.height_smooth_at(sx) / 4.0) * 4.0)
	return _create_tree(snapped, data)


func spawn_tree_from_dict(d: Dictionary) -> BaseTree:
	var pos := Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	var tree := _create_tree(pos, d)
	tree.tree_id = int(d.get("id", tree.tree_id))
	_next_id = maxi(_next_id, tree.tree_id + 1)
	return tree


func _create_tree(pos: Vector2, data: Dictionary) -> BaseTree:
	var tree = preload("res://src/plants/Oak.gd").new()
	trees_root.add_child(tree)
	tree.global_position = pos
	tree.world_generator = generator
	tree.tree_id = _next_id
	_next_id += 1
	tree.setup(null, tree.tree_id, data)
	EventBus.tree_spawned.emit(tree)
	return tree


# --------------------------------------------------------------------------- #
# REVISION 1: Eichel aufnehmen / an der Maus schweben lassen / platzieren
# --------------------------------------------------------------------------- #
func _ensure_carry_layer() -> void:
	if _carry_layer != null and is_instance_valid(_carry_layer):
		return
	_carry_layer = get_node_or_null("../CarryLayer") as CanvasLayer
	if _carry_layer == null:
		_carry_layer = CanvasLayer.new()
		_carry_layer.name = "CarryLayer"
		_carry_layer.layer = 9
		get_tree().current_scene.add_child(_carry_layer)


## REVISION 4: Einziger SPIELER-Einstieg. Wird nur von
## HUD._on_seed_icon_input() aufgerufen, also nur bei einem echten Klick
## auf das Eichel-Icon im Inventar.
func hud_acorn_clicked() -> bool:
	return pick_up_acorn()


## Oeffentliche API (HUD, Debug-Hooks, Smoke-Tests). Weltklicks rufen sie
## NICHT mehr auf.
func pick_up_acorn() -> bool:
	if carrying:
		return false
	if seed_count <= 0:
		EventBus.toast.emit(tr("MSG_NO_SEEDS"))
		return false
	seed_count -= 1
	EventBus.inventory_changed.emit(seed_count)
	carrying = true
	_ensure_carry_layer()

	_carried_sprite = Sprite2D.new()
	_carried_sprite.name = "SchwebendeEichel"
	_carried_sprite.texture = load(ACORN_PATH)
	_carried_sprite.centered = false
	_carried_sprite.scale = Vector2(2.0, 2.0)
	_carried_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carried_sprite.z_index = 100
	_carry_layer.add_child(_carried_sprite)

	# Halbtransparente Vorschau: wo wuerde die Eichel auf der Oberflaeche landen?
	_carry_marker = Sprite2D.new()
	_carry_marker.name = "PlatzierungsVorschau"
	_carry_marker.texture = load(ACORN_PATH)
	_carry_marker.centered = false
	_carry_marker.scale = Vector2(2.0, 2.0)
	_carry_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carry_marker.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_carry_marker.z_index = 4
	trees_root.add_child(_carry_marker)

	_update_carry_visuals()
	EventBus.toast.emit(tr("MSG_ACORN_CARRY"))
	return true


func _update_carry_visuals() -> void:
	if _carried_sprite == null or not is_instance_valid(_carried_sprite):
		return
	var t := Time.get_ticks_msec() / 1000.0
	var mouse := get_viewport().get_mouse_position()
	if debug_carry_screen.x > -9000.0:
		mouse = debug_carry_screen
	_carried_sprite.position = mouse - Vector2(16.0, 16.0) \
		+ Vector2(0.0, sin(t * 5.0) * 3.0)
	_carried_sprite.rotation = sin(t * 2.0) * 0.08
	if _carry_marker == null or not is_instance_valid(_carry_marker):
		return
	var wx := debug_carry_world_x
	if debug_carry_screen.x <= -9000.0 and camera != null:
		wx = camera.get_global_mouse_position().x
	if generator != null:
		var snapped_x := roundf(wx / float(WorldGenerator.TILE_SIZE)) * float(WorldGenerator.TILE_SIZE)
		var sy := roundf(generator.height_smooth_at(snapped_x) / 4.0) * 4.0
		_carry_marker.global_position = Vector2(snapped_x - 16.0, sy - 32.0)
		_carry_marker.modulate.a = 0.42 + sin(t * 4.0) * 0.10


## Der Platzierungsversuch: erst HIER wird die Eichel verbraucht / der Vogel
## ausgeloest (nicht schon beim Aufnehmen).
func _place_carried(pos: Vector2) -> void:
	var target := Vector2(pos.x, generator.height_smooth_at(pos.x))
	_clear_carry(false)
	plant_seed_at(target, false, true)


func clear_carrying(refund: bool = true) -> void:
	if carrying:
		_clear_carry(refund)
		if refund:
			EventBus.toast.emit(tr("MSG_ACORN_RETURN"))


func _clear_carry(refund: bool) -> void:
	carrying = false
	debug_carry_screen = Vector2(-9999.0, -9999.0)
	if _carried_sprite != null and is_instance_valid(_carried_sprite):
		_carried_sprite.queue_free()
	if _carry_marker != null and is_instance_valid(_carry_marker):
		_carry_marker.queue_free()
	_carried_sprite = null
	_carry_marker = null
	if refund:
		seed_count += 1
		EventBus.inventory_changed.emit(seed_count)


func _spawn_acorn_sprite(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(ACORN_PATH)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos - Vector2(8.0, 16.0)
	trees_root.add_child(s)
	var tw := create_tween()
	# Timing passend zum Vogel: Eichel verschwindet erst beim Picken.
	tw.tween_interval(0.85)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


# --------------------------------------------------------------------------- #
# Auswahl / Wurzel-Hit / Ghost-Preview
# --------------------------------------------------------------------------- #
func find_tree_at(pos: Vector2) -> BaseTree:
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.get_bounds_rect().has_point(pos):
			return tree
	return null


func find_root_hit(world_pos: Vector2) -> Dictionary:
	for tree in get_tree().get_nodes_in_group("trees"):
		var seg: RootSegment = tree.find_root_segment_at(world_pos)
		if seg != null:
			return {"tree": tree, "segment": seg}
	return {}


func select_tree(tree: BaseTree) -> void:
	selected_tree = tree
	EventBus.tree_selected.emit(tree)


func refresh_selection() -> void:
	var trees := get_tree().get_nodes_in_group("trees")
	selected_tree = trees[0] if trees.size() > 0 else null
	EventBus.tree_selected.emit(selected_tree)


## Zeigt im MANUELL-Modus, wohin die Wurzel wachsen wuerde und was es kostet.
func update_ghost(world_pos: Vector2) -> void:
	if ghost == null or Global.auto_mode:
		_hide_ghost()
		return
	var hit := find_root_hit(world_pos)
	if hit.is_empty():
		_hide_ghost()
		return
	var tree: BaseTree = hit["tree"]
	var segment: RootSegment = hit["segment"]
	var tip := tree.tip_for(segment)
	var target := tree.propose_next_tile(tip)
	if target == BaseTree.INVALID_TILE:
		_hide_ghost()
		return
	var gt := tree.global_tile_for(target)
	var kind := generator.material_at(gt.x, gt.y)
	var cost := GrowthCost.for_tile(generator, gt.x, gt.y,
		Global.difficulty_factor("growth_cost"))
	var affordable := tree.glucose >= cost
	var material := GrowthCost.material_name(kind)
	ghost.show_at(Vector2(float(gt.x * WorldGenerator.TILE_SIZE),
		float(gt.y * WorldGenerator.TILE_SIZE)), cost, affordable, material)
	EventBus.ghost_preview.emit(gt, cost, affordable, material)


func _hide_ghost() -> void:
	if ghost != null:
		ghost.hide_ghost()
	EventBus.ghost_preview.emit(Vector2i(-1, -1), 0.0, false, "")


# --------------------------------------------------------------------------- #
# Manuelles Wachstum (PHASE 2)
# --------------------------------------------------------------------------- #
## Klick auf eine Wurzel: naechstes Tile in Erd-Richtung, Kosten = Bodenhärte.
func manual_root_growth(tree: BaseTree, segment: RootSegment) -> bool:
	if tree == null:
		return false
	if tree.growth_blocked:
		EventBus.toast.emit(tr("MSG_WINTER_GROWTH"))
		return false
	var tip := tree.tip_for(segment)
	var target := tree.propose_next_tile(tip)
	if target == BaseTree.INVALID_TILE:
		EventBus.toast.emit(tr("MSG_ROOT_BLOCKED"))
		return false
	var gt := tree.global_tile_for(target)
	var kind := generator.material_at(gt.x, gt.y)
	if kind == WorldGenerator.SoilKind.AIR:
		EventBus.toast.emit(tr("MSG_ROOT_BLOCKED"))
		return false
	var cost := GrowthCost.for_tile(generator, gt.x, gt.y,
		Global.difficulty_factor("growth_cost"))
	if tree.glucose < cost:
		EventBus.toast.emit(tr("MSG_NOT_ENOUGH_GLUCOSE"))
		return false
	var grown := tree.grow_root_from(tip, true)
	if grown == null:
		EventBus.toast.emit(tr("MSG_ROOT_BLOCKED"))
		return false
	tree.glucose -= cost
	EventBus.tree_grew.emit(tree, "root")
	EventBus.root_grown.emit(tree, gt, cost)
	EventBus.toast.emit(tr("MSG_GROW_ROOT_COST") % [GrowthCost.material_name(kind), cost])
	return true


## PHASE-1-kompatibler Einstieg: Klickhoehe entscheidet Wurzel oder Blatt.
func manual_growth(tree: BaseTree, pos: Vector2) -> bool:
	if tree == null:
		return false
	if tree.growth_blocked:
		EventBus.toast.emit(tr("MSG_WINTER_GROWTH"))
		return false
	if pos.y >= tree.global_position.y:
		return manual_root_growth(tree, tree.deepest_tip())
	var cost: float = tree.species.growth_cost
	if not tree.can_grow("leaf"):
		return false
	if tree.glucose < cost:
		EventBus.toast.emit(tr("MSG_NOT_ENOUGH_GLUCOSE"))
		return false
	if not tree.grow_part("leaf"):
		return false
	tree.glucose -= cost
	EventBus.tree_grew.emit(tree, "leaf")
	EventBus.toast.emit(tr("MSG_GROW_LEAF"))
	return true


# --------------------------------------------------------------------------- #
# Save/Load & Debug-Hooks
# --------------------------------------------------------------------------- #
func get_seed_count() -> int:
	return seed_count


func set_seed_count(value: int) -> void:
	# Extern gesetzt (Save/Load, Debug): eine schwebende Eichel verwerfen,
	# damit keine Geister-Sprites uebrig bleiben.
	if carrying:
		_clear_carry(false)
	seed_count = maxi(value, 0)
	EventBus.inventory_changed.emit(seed_count)


func clear_trees() -> void:
	for tree in get_tree().get_nodes_in_group("trees"):
		tree.remove_from_group("trees")
		tree.get_parent().remove_child(tree)
		tree.free()
	selected_tree = null


## Debug-Hooks pflanzen bewusst immer am Welt-Ursprung: reproduzierbar auch
## dann, wenn die Maus-im-Rand-Kamera im Headless-Modus leicht nach links
## driftet. Normale Spieler-Klicks bleiben natuerlich frei positionierbar.
## Debug-Hook: denselben Pfad wie ein echter Linksklick in der Welt testen.
func debug_click_world(pos: Vector2) -> void:
	_left_click(pos)


func debug_plant_twice() -> void:
	# Debug/Screenshot-Preset: stellt sich die benoetigten Eicheln selbst
	# bereit, ohne dem echten Spielstart ein Inventar zu geben.
	set_seed_count(maxi(seed_count, 2))
	var x := 0.0
	var pos := Vector2(x, generator.height_at(x) + 8.0)
	plant_seed_at(pos, true)
	plant_seed_at(pos, true)


## 1. Eichel MIT Vogel-Animation (Screenshot-Preset / manuelles Demo).
func debug_first_seed() -> void:
	set_seed_count(maxi(seed_count, 1))
	plant_seed_at(Vector2(0.0, generator.height_smooth_at(0.0) + 8.0), false)


## REVISION 1: Screenshot-Preset fuer den Schwebe-Zustand.
func debug_carry_at(screen: Vector2, world_x: float) -> void:
	set_seed_count(maxi(seed_count, 1))
	if pick_up_acorn():
		debug_carry_screen = screen
		debug_carry_world_x = world_x
		_update_carry_visuals()


## Debug-Hook: Eichel an einer frei waehlbaren Stelle der Oberflaeche platzieren.
func debug_place_carried_at(world_x: float) -> void:
	if carrying:
		_place_carried(Vector2(world_x, generator.height_smooth_at(world_x)))


## PHASE 2: Wurzel bis zu den Reservoiren wachsen lassen (Screenshot/Smoke).
func debug_grow_roots(count: int) -> void:
	var tree := selected_tree
	if tree == null:
		return
	for _i in count:
		if tree.grow_root_from(tree.deepest_tip(), true) == null:
			break


## PHASE 2: Ghost-Preview ohne echte Mausbewegung sichtbar machen.
func debug_show_ghost() -> void:
	if ghost == null or selected_tree == null:
		return
	var tree := selected_tree
	var tip := tree.deepest_tip()
	var target := tree.propose_next_tile(tip)
	if target == BaseTree.INVALID_TILE:
		return
	var gt := tree.global_tile_for(target)
	var kind := generator.material_at(gt.x, gt.y)
	var cost := GrowthCost.for_tile(generator, gt.x, gt.y,
		Global.difficulty_factor("growth_cost"))
	var affordable := tree.glucose >= cost
	var material := GrowthCost.material_name(kind)
	ghost.show_at(Vector2(float(gt.x * WorldGenerator.TILE_SIZE),
		float(gt.y * WorldGenerator.TILE_SIZE)), cost, affordable, material)
	EventBus.ghost_preview.emit(gt, cost, affordable, material)


## PHASE 2: alle Reservoirs im Startbereich austrocknen (Screenshot).
func debug_drain_reservoirs() -> void:
	if world_state == null:
		return
	var top := generator.surface_tile_y_at(0.0)
	for gx in range(-10, 11):
		for ty in range(top, top + 40):
			if generator.reservoir_at(gx, ty):
				world_state.debug_drain(gx, ty)
