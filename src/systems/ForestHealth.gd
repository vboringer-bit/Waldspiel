class_name ForestHealth
extends Node
## PHASE 5 (Master-Punkt 7): Wald-Gesundheit als echte Metrik.
## Blaetter + Baeume + Tierarten + Pilz-Patches, geklemmt auf 0..1.
## Ab > 0.5 siedeln sich Specht und Eichhoernchen an.

const THRESHOLD := 0.5
const LEAF_WEIGHT := 0.02
const TREE_WEIGHT := 0.12
const SPECIES_WEIGHT := 0.08
const FUNGUS_WEIGHT := 0.04

var wildlife = null
var parasite_system = null
var skill_tree: SkillTree = null
var value: float = 0.0
var biodiversity: int = 0
var _biodiversity_override: int = -1
var _last_emitted: float = -1.0
var _connected: bool = false


func setup(p_wildlife, p_parasites, p_skill_tree) -> void:
	wildlife = p_wildlife
	parasite_system = p_parasites
	skill_tree = p_skill_tree
	_connect()
	recompute()


func _ready() -> void:
	_connect()
	recompute()


func _connect() -> void:
	if _connected:
		return
	_connected = true
	EventBus.tree_spawned.connect(func(_t): recompute())
	EventBus.tree_grew.connect(func(_t, _p): recompute())
	EventBus.wildlife_changed.connect(func(): recompute())
	EventBus.animal_spawned.connect(func(_s): recompute())
	EventBus.colony_grown.connect(func(_s): recompute())
	EventBus.fungus_patch_spawned.connect(func(_t): recompute())
	EventBus.parasite_spawned.connect(func(_t, _k): recompute())
	EventBus.parasite_removed.connect(func(_t, _k, _b): recompute())
	EventBus.game_loaded.connect(func(): recompute())


func recompute() -> float:
	var trees := get_tree().get_nodes_in_group("trees")
	var total_leaves := 0
	for t in trees:
		if t is BaseTree:
			total_leaves += (t as BaseTree).leaves_count
	var species := 0
	if _biodiversity_override >= 0:
		species = _biodiversity_override
	elif wildlife != null and wildlife.has_method("species_count"):
		species = int(wildlife.species_count())
	var fungi := 0
	if parasite_system != null and parasite_system.has_method("fungus_count"):
		fungi = int(parasite_system.fungus_count())
	var raw := float(total_leaves) * LEAF_WEIGHT \
		+ float(trees.size()) * TREE_WEIGHT \
		+ float(species) * SPECIES_WEIGHT \
		+ float(fungi) * FUNGUS_WEIGHT
	value = clampf(raw, 0.0, 1.0)
	biodiversity = species + fungi
	# Nur bei echter Aenderung senden: verhindert eine Signalschleife mit
	# WildlifeSystem, das beim Gesundheitswechsel neue Arten spawnt.
	if not is_equal_approx(value, _last_emitted):
		_last_emitted = value
		EventBus.forest_health_changed.emit(value)
	return value


func is_healthy() -> bool:
	return value > THRESHOLD


func debug_value() -> float:
	return recompute()


func debug_biodiversity() -> int:
	recompute()
	return biodiversity


func debug_set_biodiversity(n: int) -> void:
	_biodiversity_override = maxi(n, 0)
	recompute()


func debug_clear_override() -> void:
	_biodiversity_override = -1
	recompute()
