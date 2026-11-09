class_name ParasiteSystem
extends Node2D
## PHASE 5: Parasiten (Mistel + Wurmbefall) und sichtbare Pilz-Symbiose.
##
## * "MISTLETOE" und "WORM" ziehen pro simulierter Sekunde echte Glucose ab.
## * LEICHT bleibt befallfrei; NORMAL/SCHWER nutzen disaster_rate + Resistenz.
## * "mushroom_node" erzeugt FungusPatch-Pilze; BaseTree.nutrient_mult
##   traegt den +15-%-Naehrstoffeffekt in die Fotosynthese.

const SPAWN_INTERVAL := 18.0
const BASE_SPAWN_CHANCE := 0.15
const MAX_PER_TREE := 2

var generator: WorldGenerator
var trees_root: Node2D
var time_manager: TimeManager
var skill_tree: SkillTree
var forest_health: ForestHealth
var parasites: Array = []
var fungi: Array = []
var spawn_timer: float = 0.0
var last_removed_by: String = ""
var debug_spawns_frozen: bool = false
var _rng := RandomNumberGenerator.new()
var _connected: bool = false


func setup(p_generator: WorldGenerator, p_trees: Node2D,
		p_time: TimeManager, p_skill_tree: SkillTree,
		p_health: ForestHealth) -> void:
	generator = p_generator
	trees_root = p_trees
	time_manager = p_time
	skill_tree = p_skill_tree
	forest_health = p_health
	_rng.seed = (Global.world_seed ^ 0xBEEF5) & 0x7fffffff
	_connect()
	_sync_fungi()


func _ready() -> void:
	_connect()


func _connect() -> void:
	if _connected:
		return
	_connected = true
	EventBus.skilltree_changed.connect(_on_skilltree_changed)
	EventBus.tree_spawned.connect(_on_tree_spawned)
	EventBus.game_loaded.connect(_on_game_loaded)


func _on_skilltree_changed() -> void:
	_sync_fungi()
	if skill_tree == null:
		return
	if skill_tree.is_unlocked("parasite_res"):
		_remove_by_resistance(Parasite.Kind.MISTLETOE, "resistance")
	if skill_tree.is_unlocked("disease_res"):
		_remove_by_resistance(Parasite.Kind.WORM, "resistance")


func _on_tree_spawned(tree: Node) -> void:
	if skill_tree != null and skill_tree.is_unlocked("mushroom_node"):
		_add_fungus_to(tree)


func _on_game_loaded() -> void:
	_sync_fungi()
	if forest_health != null:
		forest_health.recompute()


# --------------------------------------------------------------------------- #
# Pilz-Symbiose
# --------------------------------------------------------------------------- #
func _sync_fungi() -> void:
	_clear_fungi()
	if skill_tree == null or not skill_tree.is_unlocked("mushroom_node"):
		return
	for t in get_tree().get_nodes_in_group("trees"):
		_add_fungus_to(t)


func _add_fungus_to(tree: Node) -> void:
	if not (tree is BaseTree):
		return
	var t := tree as BaseTree
	for f in fungi:
		if is_instance_valid(f) and f.host == t:
			return
	var patch := preload("res://src/symbiosis/FungusPatch.gd").new()
	add_child(patch)
	patch.setup(t)
	fungi.append(patch)
	EventBus.fungus_patch_spawned.emit(t)


func fungus_count() -> int:
	var n := 0
	for f in fungi:
		if is_instance_valid(f):
			n += 1
	return n


func _clear_fungi() -> void:
	for f in fungi:
		if is_instance_valid(f):
			f.queue_free()
	fungi.clear()


# --------------------------------------------------------------------------- #
# Parasiten
# --------------------------------------------------------------------------- #
func _process(delta: float) -> void:
	if generator == null or time_manager == null:
		return
	var dt := time_manager.scaled_delta(delta)
	if dt <= 0.0:
		return
	_tick(dt)


func _tick(dt: float) -> void:
	spawn_timer += dt
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_try_spawn(false)
	for p in parasites.duplicate():
		if is_instance_valid(p):
			p.tick(dt)


func _try_spawn(force: bool) -> bool:
	if not Global.difficulty_toggle("parasites"):
		return false
	if not force and debug_spawns_frozen:
		return false
	var trees := get_tree().get_nodes_in_group("trees")
	if trees.is_empty():
		return false
	var chance := BASE_SPAWN_CHANCE * Global.difficulty_factor("disaster_rate")
	if skill_tree != null:
		chance *= skill_tree.resistance("parasite_risk")
	if not force and _rng.randf() > chance:
		return false
	var tree: Node = trees[_rng.randi_range(0, trees.size() - 1)]
	var kind := Parasite.Kind.MISTLETOE if _rng.randf() < 0.6 \
		else Parasite.Kind.WORM
	return spawn_parasite(kind, tree, false) != null


func spawn_parasite(kind: int, tree: Node, silent: bool = false) -> Parasite:
	if tree == null or not is_instance_valid(tree) or not (tree is BaseTree):
		return null
	var t := tree as BaseTree
	if parasite_count_on(t) >= MAX_PER_TREE:
		return null
	var p := preload("res://src/symbiosis/Parasite.gd").new()
	add_child(p)
	var scale := 1.0
	if skill_tree != null:
		scale = skill_tree.resistance("parasite_risk") if kind == Parasite.Kind.MISTLETOE \
			else skill_tree.resistance("disease_risk")
	p.setup(kind, t, scale)
	parasites.append(p)
	if not silent:
		EventBus.parasite_spawned.emit(t, kind)
		EventBus.toast.emit(tr("MSG_PARASITE_SPAWN"))
	return p


func parasite_count_on(tree: BaseTree) -> int:
	var n := 0
	for p in parasites:
		if is_instance_valid(p) and p.host == tree:
			n += 1
	return n


func parasite_count(kind: int = -1) -> int:
	var n := 0
	for p in parasites:
		if is_instance_valid(p) and (kind < 0 or p.kind == kind):
			n += 1
	return n


func remove_parasite(p: Parasite, by: String) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var t := p.host
	var kind := p.kind
	parasites.erase(p)
	p.queue_free()
	last_removed_by = by
	var by_key := "BY_WOODPECKER" if by == "woodpecker" else "BY_RESISTANCE"
	EventBus.parasite_removed.emit(t, kind, by)
	EventBus.toast.emit(tr("MSG_PARASITE_REMOVED") % tr(by_key))
	return true


func remove_parasites_at(tree: BaseTree, max_count: int) -> int:
	var removed := 0
	for p in parasites.duplicate():
		if removed >= max_count:
			break
		if is_instance_valid(p) and p.host == tree:
			if remove_parasite(p, "woodpecker"):
				removed += 1
	return removed


func _remove_by_resistance(kind: int, by: String) -> int:
	var removed := 0
	for p in parasites.duplicate():
		if is_instance_valid(p) and p.kind == kind:
			if remove_parasite(p, by):
				removed += 1
	if removed > 0:
		EventBus.toast.emit(tr("MSG_RESISTANCE_CLEAN"))
	return removed


# --------------------------------------------------------------------------- #
# Klick / Info
# --------------------------------------------------------------------------- #
func click_at(world_pos: Vector2) -> bool:
	for p in parasites:
		if is_instance_valid(p) and p.hit_rect().has_point(world_pos):
			p.click()
			return true
	for f in fungi:
		if is_instance_valid(f) and f.hit_rect().has_point(world_pos):
			f.click()
			return true
	return false


func right_info_at(world_pos: Vector2) -> bool:
	return click_at(world_pos)


# --------------------------------------------------------------------------- #
# Save / Load (Format v6)
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	var pp: Array = []
	for p in parasites:
		if is_instance_valid(p):
			var tid := -1
			if p.host != null and is_instance_valid(p.host):
				tid = p.host.tree_id
			pp.append({"kind": p.kind, "tree_id": tid})
	return {"parasites": pp, "spawn_timer": spawn_timer}


func from_dict(d: Dictionary) -> void:
	_clear_parasites()
	spawn_timer = float(d.get("spawn_timer", 0.0))
	for e in d.get("parasites", []):
		var kind := int(e.get("kind", Parasite.Kind.MISTLETOE))
		var tid := int(e.get("tree_id", -1))
		var host := _find_tree_by_id(tid)
		if host != null:
			spawn_parasite(kind, host, true)
	_sync_fungi()
	if forest_health != null:
		forest_health.recompute()


func _find_tree_by_id(tid: int) -> BaseTree:
	if tid < 0:
		return null
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree and (t as BaseTree).tree_id == tid:
			return t as BaseTree
	return null


func _clear_parasites() -> void:
	for p in parasites:
		if is_instance_valid(p):
			p.queue_free()
	parasites.clear()


# --------------------------------------------------------------------------- #
# Debug / Smoke
# --------------------------------------------------------------------------- #
func debug_clear() -> void:
	_clear_parasites()
	_clear_fungi()
	spawn_timer = 0.0
	last_removed_by = ""


func debug_set_spawns_frozen(v: bool) -> void:
	debug_spawns_frozen = v


func debug_sync_fungi() -> void:
	_sync_fungi()


func debug_infest(tree: BaseTree, kind: int) -> bool:
	return spawn_parasite(kind, tree, true) != null


func debug_force_spawn() -> bool:
	return _try_spawn(true)


func debug_step(seconds: float) -> void:
	var steps := int(seconds / 0.1)
	for _i in steps:
		_tick(0.1)
	if forest_health != null:
		forest_health.recompute()


func debug_parasite_count(kind: int = -1) -> int:
	return parasite_count(kind)


func debug_fungus_count() -> int:
	return fungus_count()


func debug_last_removed_by() -> String:
	return last_removed_by
