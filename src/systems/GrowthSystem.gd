class_name GrowthSystem
extends Node
## PHASE 1: Fotosynthese + Glucose-Verteilung.
## PHASE 2: AUTO zahlt fuer Wurzeln die BODENHÄRTE des Ziel-Tiles
## (GrowthCost), fuer Blaetter/Stamm den art-spezifischen Basispreis.
## MANUELL: kein Auto-Kauf, der Spieler klickt selbst.
## PHASE 3: alles nutzt `TimeManager.scaled_delta` (Zeitspulen / Pause),
## jahreszeitliche Sonne + Wachstumsboost, Winterruhe und
## schwierigkeitsabhaengige Fotosynthese / Kosten.

@export var auto_growth_enabled: bool = true
const DURST_SCHWELLE := 40.0
const DEBUG_STEP := 0.1

var generator: WorldGenerator
var time_manager: TimeManager


func setup(p_generator: WorldGenerator, p_time: TimeManager = null) -> void:
	generator = p_generator
	time_manager = p_time


func _ready() -> void:
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.tree_spawned.connect(_on_tree_spawned)


func _sim_delta(delta: float) -> float:
	return time_manager.scaled_delta(delta) if time_manager != null else delta


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	var dt := _sim_delta(delta)
	if dt <= 0.0:
		return                          # Pause
	var sun := time_manager.sunlight_factor() if time_manager != null else 1.0
	var growth := time_manager.growth_factor() if time_manager != null else 1.0
	var st := SkillTree.instance
	var cost_scale := Global.difficulty_factor("growth_cost") \
		* (st.modifier("growth_cost") if st != null else 1.0)
	var root_scale := cost_scale * (st.modifier("root_cost") if st != null else 1.0)
	for tree in get_tree().get_nodes_in_group("trees"):
		tree.photosynthesize(dt, sun, growth)
		if not Global.auto_mode or not auto_growth_enabled or growth <= 0.0:
			continue
		# Prioritaet: Wurzeln bei Durst, sonst Blaetter (Stamm als Fallback).
		var part := "root" if tree.water < DURST_SCHWELLE else "leaf"
		if not tree.can_grow(part):
			part = "trunk"
		var cost: float = tree.species.growth_cost * cost_scale
		if part == "root":
			cost = GrowthCost.for_root(tree, generator, root_scale)
			if cost < 0.0:
				part = "leaf"
				cost = tree.species.growth_cost * cost_scale
		if tree.glucose < cost:
			continue
		if tree.grow_part(part):
			tree.glucose -= cost
			EventBus.tree_grew.emit(tree, part)


func _on_season_changed(_year: int, season: int) -> void:
	for tree in get_tree().get_nodes_in_group("trees"):
		tree.set_season(season)


func _on_tree_spawned(tree: Node) -> void:
	if tree is BaseTree and time_manager != null:
		(tree as BaseTree).set_season(time_manager.season)


## Deterministische Zeit-Simulation fuer Screenshots / Smoke-Tests.
func debug_advance(seconds: float) -> void:
	var steps := int(seconds / DEBUG_STEP)
	for _i in steps:
		tick(DEBUG_STEP)
