class_name WildlifeSystem
extends Node2D
## PHASE 5 (Master-Punkt 7): Spawn, StateMachine-Koordination und Interaktion
## aller Tiere. Bewusst getrennt von ForestHealth / ParasiteSystem.
##
## Basis (immer): 2 Regenwuermer + 2 Ameisen + 1 Ameisenhuegel.
## Ab Wald-Gesundheit > 50 %: 1 Specht + 1 Eichhoernchen.
## Wurm/Ameise geben Futter, Ameisen vermehren sich langsam, der Specht
## reagiert auf parasite_spawned, das Eichhoernchen traegt Samen in Chunk 1.
## Alles nutzt TimeManager.scaled_delta (x1/x3/x10 + Pause).
## REVISION 5: Würmer graben unter der Erde; ihre Tiefe wird im Savegame
## mitgeschrieben (Format v6 bleibt abwärtslesbar).

const BASE_WORMS := 2
const BASE_ANTS := 2
const MAX_ANTS := 8
const MAX_ANIMALS := 20
const COLONY_INTERVAL := 10.0
const CARRY_INTERVAL := 22.0
const REMOTE_OFFSET := 2304.0
const ADVANCED := ["woodpecker", "squirrel"]
const BASELINE_WORM_X := [-260.0, -120.0]
const BASELINE_ANT_X := [80.0, 220.0]
const ADVANCED_WOODPECKER_X := -120.0
const ADVANCED_SQUIRREL_X := 460.0

var generator: WorldGenerator
var trees_root: Node2D
var camera: CameraController
var time_manager: TimeManager
var season_system: SeasonSystem
var interaction: InteractionController
var skill_tree: SkillTree
var forest_health: ForestHealth
var parasite_system: ParasiteSystem

var animals: Array = []
var anthills: Array = []
var food: int = 0
var colony: int = 0
var colony_timer: float = 0.0
var carry_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _connected: bool = false


func setup(p_generator: WorldGenerator, p_trees: Node2D,
		p_camera: CameraController, p_time: TimeManager,
		p_season: SeasonSystem, p_interaction: InteractionController,
		p_skill_tree: SkillTree, p_health: ForestHealth,
		p_parasites: ParasiteSystem) -> void:
	generator = p_generator
	trees_root = p_trees
	camera = p_camera
	time_manager = p_time
	season_system = p_season
	interaction = p_interaction
	skill_tree = p_skill_tree
	forest_health = p_health
	parasite_system = p_parasites
	_rng.seed = (Global.world_seed ^ 0xA11FA) & 0x7fffffff
	_connect()
	reset()


func _ready() -> void:
	_connect()


func _connect() -> void:
	if _connected:
		return
	_connected = true
	EventBus.forest_health_changed.connect(_on_health_changed)
	EventBus.parasite_spawned.connect(_on_parasite_spawned)
	EventBus.game_loaded.connect(_on_game_loaded)


func _on_health_changed(value: float) -> void:
	_sync_advanced(value)


func _on_parasite_spawned(tree: Node, _kind: int) -> void:
	_assign_woodpecker(tree)


func _on_game_loaded() -> void:
	if forest_health != null:
		forest_health.recompute()


# --------------------------------------------------------------------------- #
# Basis / Reset
# --------------------------------------------------------------------------- #
func reset() -> void:
	_clear()
	food = 0
	colony = 0
	colony_timer = 0.0
	carry_timer = 0.0
	for x in BASELINE_WORM_X:
		_spawn_animal("worm", float(x), true)
	for x in BASELINE_ANT_X:
		_spawn_animal("ant", float(x), true)
	_spawn_anthill(180.0, 1)
	colony = count_species("ant")
	EventBus.food_changed.emit(food)
	EventBus.wildlife_changed.emit()
	if forest_health != null:
		forest_health.recompute()


func _clear() -> void:
	for a in animals:
		if is_instance_valid(a):
			a.queue_free()
	for h in anthills:
		if is_instance_valid(h):
			h.queue_free()
	animals.clear()
	anthills.clear()


func _spawn_animal(species: String, p_x: float, silent: bool = false) -> Animal:
	var a := preload("res://src/animals/Animal.gd").new()
	add_child(a)
	a.setup(species, generator, p_x, self)
	animals.append(a)
	if not silent:
		EventBus.animal_spawned.emit(species)
	return a


func _spawn_anthill(p_x: float, colony_size: int = 1) -> Anthill:
	var h := preload("res://src/animals/Anthill.gd").new()
	add_child(h)
	h.setup(p_x, generator.height_smooth_at(p_x), self, colony_size)
	anthills.append(h)
	EventBus.anthill_built.emit(Vector2(p_x, generator.height_smooth_at(p_x)))
	return h


func _remove_animal(a: Animal) -> void:
	if a == null or not is_instance_valid(a):
		return
	animals.erase(a)
	a.queue_free()


# --------------------------------------------------------------------------- #
# Arten / Gesundheit
# --------------------------------------------------------------------------- #
func count_species(species: String) -> int:
	var n := 0
	for a in animals:
		if is_instance_valid(a) and a.species == species:
			n += 1
	return n


func has_species(species: String) -> bool:
	return count_species(species) > 0


func species_count() -> int:
	var d := {}
	for a in animals:
		if is_instance_valid(a):
			d[a.species] = true
	return d.size()


func _sync_advanced(health: float) -> void:
	var want := health > ForestHealth.THRESHOLD
	var changed := false
	if want:
		if not has_species("woodpecker"):
			_spawn_animal("woodpecker", ADVANCED_WOODPECKER_X, true)
			changed = true
		if not has_species("squirrel"):
			_spawn_animal("squirrel", ADVANCED_SQUIRREL_X, true)
			changed = true
		if changed:
			EventBus.wildlife_changed.emit()
			EventBus.toast.emit(tr("MSG_WILDLIFE_ARRIVED"))
	else:
		for a in animals.duplicate():
			if is_instance_valid(a) and ADVANCED.has(a.species):
				_remove_animal(a)
				changed = true
		if changed:
			EventBus.wildlife_changed.emit()
			EventBus.toast.emit(tr("MSG_WILDLIFE_LEFT"))


func _assign_woodpecker(tree: Node) -> void:
	if not (tree is BaseTree) or not has_species("woodpecker"):
		return
	for a in animals:
		if is_instance_valid(a) and a.species == "woodpecker" \
				and a.state != Animal.State.HELP_TREE:
			a.assign_help(tree as BaseTree)
			return


# --------------------------------------------------------------------------- #
# Simulation
# --------------------------------------------------------------------------- #
func _process(delta: float) -> void:
	if generator == null or time_manager == null:
		return
	var dt := time_manager.scaled_delta(delta)
	if dt <= 0.0:
		return
	_tick(dt)


func _tick(dt: float) -> void:
	for a in animals.duplicate():
		if is_instance_valid(a):
			a.tick(dt)
	for h in anthills.duplicate():
		if is_instance_valid(h):
			h.tick(dt)
	colony_timer += dt
	if colony_timer >= COLONY_INTERVAL and count_species("ant") > 0 \
			and count_species("ant") < MAX_ANTS and animals.size() < MAX_ANIMALS:
		colony_timer = 0.0
		var x := _rng.randf_range(-300.0, 300.0)
		_spawn_animal("ant", x, false)
		colony += 1
		for h in anthills:
			if is_instance_valid(h):
				h.grow(1)
		EventBus.colony_grown.emit(colony)
		EventBus.wildlife_changed.emit()
		EventBus.toast.emit(tr("MSG_ANTHILL_GROWN"))
		if colony >= 6 and anthills.size() < 3:
			_spawn_anthill(180.0 + float(anthills.size()) * 420.0, colony)
	carry_timer += dt
	if carry_timer >= CARRY_INTERVAL and has_species("squirrel"):
		carry_timer = 0.0
		var sq := _first_animal("squirrel")
		if sq != null and sq.state != Animal.State.CARRY:
			var base_x := 0.0
			var t0 := _first_tree()
			if t0 != null:
				base_x = t0.global_position.x
			var target := base_x + REMOTE_OFFSET
			sq.assign_carry(target)
			EventBus.seed_carried.emit(Vector2(base_x, 0.0), Vector2(target, 0.0))
			EventBus.toast.emit(tr("MSG_SEED_CARRIED"))


func rand_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func on_animal_food(a: Animal) -> void:
	food += 1
	EventBus.food_changed.emit(food)
	if a != null and a.species == "worm":
		EventBus.toast.emit(tr("MSG_FOOD_GAINED"))


func on_woodpecker_help(a: Animal) -> int:
	if parasite_system == null or a == null or a.host_tree == null:
		return 0
	var removed := parasite_system.remove_parasites_at(a.host_tree, 1)
	if removed > 0:
		EventBus.toast.emit(tr("MSG_WOODPECKER_HELP"))
	return removed


func on_seed_delivered(_a: Animal) -> void:
	debug_force_remote_seed()


func debug_force_remote_seed() -> BaseTree:
	if interaction == null or generator == null:
		return null
	var base_x := 0.0
	var t0 := _first_tree()
	if t0 != null:
		base_x = t0.global_position.x
	var x := base_x + REMOTE_OFFSET
	if x <= float(WorldGenerator.CHUNK_WIDTH_PX):
		x = float(WorldGenerator.CHUNK_WIDTH_PX) + 320.0
	var y := generator.height_smooth_at(x)
	var nt := interaction.spawn_tree_at(Vector2(x, y), {})
	EventBus.seed_carried.emit(Vector2(base_x, y), Vector2(x, y))
	EventBus.seed_planted_remote.emit(Vector2(x, y))
	EventBus.toast.emit(tr("MSG_TREE_PLANTED_REMOTE"))
	if forest_health != null:
		forest_health.recompute()
	return nt


func _first_tree() -> BaseTree:
	var trees := get_tree().get_nodes_in_group("trees")
	if trees.is_empty():
		return null
	return trees[0] as BaseTree


func _first_animal(species: String) -> Animal:
	for a in animals:
		if is_instance_valid(a) and a.species == species:
			return a
	return null


# --------------------------------------------------------------------------- #
# Klick / Info
# --------------------------------------------------------------------------- #
func click_at(world_pos: Vector2) -> bool:
	for a in animals:
		if is_instance_valid(a) and a.hit_rect().has_point(world_pos):
			a.click()
			return true
	for h in anthills:
		if is_instance_valid(h) and h.hit_rect().has_point(world_pos):
			EventBus.toast.emit(h.info_text())
			return true
	return false


func right_info_at(world_pos: Vector2) -> bool:
	return click_at(world_pos)


# --------------------------------------------------------------------------- #
# Save / Load (Format v6)
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	var aa: Array = []
	for a in animals:
		if is_instance_valid(a):
			aa.append({"species": a.species, "x": a.position.x,
				"home_x": a.home_x, "depth": a.burrow_depth})
	var hh: Array = []
	for h in anthills:
		if is_instance_valid(h):
			hh.append({"x": h.position.x, "colony": h.colony_size})
	return {
		"food": food, "colony": colony, "colony_timer": colony_timer,
		"carry_timer": carry_timer, "animals": aa, "anthills": hh,
	}


func from_dict(d: Dictionary) -> void:
	_clear()
	food = int(d.get("food", 0))
	colony = int(d.get("colony", BASE_ANTS))
	colony_timer = float(d.get("colony_timer", 0.0))
	carry_timer = float(d.get("carry_timer", 0.0))
	for e in d.get("animals", []):
		var sp := String(e.get("species", "worm"))
		var x := float(e.get("x", 0.0))
		var a := _spawn_animal(sp, x, true)
		var hx := float(e.get("home_x", x))
		a.reseat(x, float(e.get("depth", -1.0)))
		a.home_x = hx
		a.position.x = x
	for e in d.get("anthills", []):
		_spawn_anthill(float(e.get("x", 180.0)), int(e.get("colony", 1)))
	if animals.is_empty():
		for x in BASELINE_WORM_X:
			_spawn_animal("worm", float(x), true)
		for x in BASELINE_ANT_X:
			_spawn_animal("ant", float(x), true)
	if anthills.is_empty():
		_spawn_anthill(180.0, 1)
	EventBus.food_changed.emit(food)
	EventBus.wildlife_changed.emit()


# --------------------------------------------------------------------------- #
# Debug / Smoke
# --------------------------------------------------------------------------- #
func debug_step(seconds: float) -> void:
	var steps := int(seconds / 0.1)
	for _i in steps:
		_tick(0.1)
	if forest_health != null:
		forest_health.recompute()


func debug_total_animal_count() -> int:
	var n := 0
	for a in animals:
		if is_instance_valid(a):
			n += 1
	return n


func debug_animal_count(species: String) -> int:
	return count_species(species)


func debug_state_count(species: String, state: int) -> int:
	var n := 0
	for a in animals:
		if is_instance_valid(a) and a.species == species and a.state == state:
			n += 1
	return n


func debug_force_state(species: String, state: int) -> bool:
	for a in animals:
		if is_instance_valid(a) and a.species == species:
			a.debug_set_state(state)
			return true
	return false


func debug_food() -> int:
	return food


func debug_colony_size() -> int:
	return colony


func debug_anthill_count() -> int:
	return anthills.size()


func debug_species_count() -> int:
	return species_count()


func debug_sync_advanced() -> void:
	if forest_health != null:
		_sync_advanced(forest_health.debug_value())


func debug_force_advanced() -> bool:
	_sync_advanced(1.0)
	return has_species("woodpecker") and has_species("squirrel")


func debug_force_baseline_only() -> void:
	_sync_advanced(0.0)


func debug_remove_species(species: String) -> int:
	var n := 0
	for a in animals.duplicate():
		if is_instance_valid(a) and a.species == species:
			_remove_animal(a)
			n += 1
	EventBus.wildlife_changed.emit()
	return n


func debug_force_help(tree: BaseTree) -> bool:
	if not has_species("woodpecker"):
		debug_force_advanced()
	var wp := _first_animal("woodpecker")
	if wp == null:
		return false
	wp.assign_help(tree)
	# Debug/Smoke: deterministisch in Reichweite setzen, damit nicht eine
	# vorherige Wanderposition die Hilfe verzoegert.
	wp.position.x = tree.global_position.x - 60.0
	wp.position.y = tree.global_position.y - 40.0
	wp.queue_redraw()
	return true


func debug_pose_help(tree: BaseTree) -> bool:
	if not debug_force_help(tree):
		return false
	var wp := _first_animal("woodpecker")
	wp.position.x = tree.global_position.x - 38.0
	wp.position.y = tree.global_position.y - 44.0
	wp.queue_redraw()
	return true


func debug_pose_carry() -> bool:
	if not has_species("squirrel"):
		debug_force_advanced()
	var sq := _first_animal("squirrel")
	if sq == null:
		return false
	sq.assign_carry(REMOTE_OFFSET)
	sq.position.x = REMOTE_OFFSET - 70.0
	sq.position.y = sq.base_y
	sq.queue_redraw()
	return true


func debug_worm_depths() -> Array:
	var out: Array = []
	for a in animals:
		if is_instance_valid(a) and a.species == "worm":
			out.append(a.burrow_depth)
	return out


func debug_trail_lengths() -> Array:
	var out: Array = []
	for a in animals:
		if is_instance_valid(a) and a.species == "worm":
			out.append(a.debug_trail_size())
	return out


func debug_body_span(species: String) -> float:
	for a in animals:
		if is_instance_valid(a) and a.species == species:
			return a.debug_body_span()
	return -1.0


func debug_worm_positions() -> Array:
	var out: Array = []
	for a in animals:
		if is_instance_valid(a) and a.species == "worm":
			out.append(a.global_position)
	return out


func debug_remote_positions() -> Array:
	var out: Array = []
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree and (t as BaseTree).global_position.x > float(WorldGenerator.CHUNK_WIDTH_PX):
			out.append((t as BaseTree).global_position)
	return out
