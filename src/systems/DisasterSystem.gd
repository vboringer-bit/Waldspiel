class_name DisasterSystem
extends Node2D
## PHASE 6 (Master-Punkt 4.2): Naturkatastrophen.
##
## LEICHT: keine Katastrophen (difficulty_toggle("disasters") = false).
## NORMAL: seltene Stuerme / Borkenkaefer (disaster_rate = 0.35).
## SCHWER: haeufige Duerre / Sturm / Borkenkaefer (disaster_rate = 2.0).
##
## Drei Typen mit ECHTEN, messbaren Auswirkungen:
##   DROUGHT  - Wasser aller Baeume sinkt, Boden-Regeneration gestoppt.
##   STORM    - Gesundheit sinkt; "Holz-Haerte" (storm_risk) halbiert.
##   BEETLE   - Glucose wird entzogen; "Parasiten-Resistenz" halbiert.
##
## Resistenzen kommen direkt aus SkillTree.resistance(). Alles nutzt
## TimeManager.scaled_delta (x1/x3/x10 + Pause). Eine GRACE-Periode
## verhindert, dass die kurzen Headless-Smokes der R0-R8-Regressionen
## jemals ein Zufallsereignis ausloesen. Aktive Ereignisse haben einen
## dezenten, rein prozeduralen Overlay (keine externen Assets).

enum Kind { NONE, DROUGHT, STORM, BEETLE }

const GRACE_SECONDS := 300.0
const MIN_INTERVAL := 180.0
const EVENT_DURATION := 24.0
const DROUGHT_DRAIN := 1.60
const STORM_DAMAGE := 2.20
const BEETLE_DRAIN := 0.90

static var instance: DisasterSystem

var time_manager: TimeManager = null
var water_system: WaterSystem = null
var skill_tree: SkillTree = null
var soil: SoilChemistry = null

var active_kind: int = Kind.NONE
var time_left: float = 0.0
var event_count: int = 0
var last_event: String = ""
var total_damage: float = 0.0
var _elapsed: float = 0.0
var _next: float = GRACE_SECONDS
var _phase: float = 0.0
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	instance = self
	_rng.seed = Global.world_seed + 7919


func _ready() -> void:
	instance = self
	top_level = true
	z_as_relative = false
	z_index = 60
	queue_redraw()


func setup(p_time: TimeManager, p_water: WaterSystem,
		p_skill_tree: SkillTree, p_soil: SoilChemistry) -> void:
	time_manager = p_time
	water_system = p_water
	skill_tree = p_skill_tree
	soil = p_soil
	_rng.seed = Global.world_seed + 7919


func _sim_delta(delta: float) -> float:
	return time_manager.scaled_delta(delta) if time_manager != null else delta


func enabled() -> bool:
	return Global.difficulty_toggle("disasters")


func rate() -> float:
	return Global.difficulty_factor("disaster_rate")


func kind_name(kind: int) -> String:
	match kind:
		Kind.DROUGHT: return "DROUGHT"
		Kind.STORM: return "STORM"
		Kind.BEETLE: return "BEETLE"
	return "NONE"


func allowed_kinds() -> Array[int]:
	var out: Array[int] = []
	if not enabled():
		return out
	if Global.difficulty == Global.Difficulty.NORMAL:
		out.append(Kind.STORM)
		out.append(Kind.BEETLE)
		return out
	out.append(Kind.DROUGHT)
	out.append(Kind.STORM)
	out.append(Kind.BEETLE)
	return out


func is_kind_allowed(kind: int) -> bool:
	return allowed_kinds().has(kind)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	var dt := _sim_delta(delta)
	if dt <= 0.0:
		return                          # Pause
	_elapsed += dt
	_phase += dt
	if active_kind != Kind.NONE:
		time_left -= dt
		_apply(dt)
		queue_redraw()
		if time_left <= 0.0:
			_end()
		return
	if not enabled() or _elapsed < GRACE_SECONDS:
		return
	_next -= dt * maxf(rate(), 0.01)
	if _next <= 0.0:
		_start_random()


func _start_random() -> void:
	var kinds := allowed_kinds()
	if kinds.is_empty():
		return
	var pool: Array[int] = []
	for k in kinds:
		if k == Kind.DROUGHT and water_system != null and water_system.raining:
			continue
		pool.append(k)
	if pool.is_empty():
		pool.append(Kind.STORM)
	_start(int(pool[_rng.randi() % pool.size()]))


func start(kind: int) -> bool:
	if kind == Kind.NONE or active_kind != Kind.NONE:
		return false
	if not enabled() or not is_kind_allowed(kind):
		return false
	return _start(kind)


func _start(kind: int) -> bool:
	active_kind = kind
	time_left = EVENT_DURATION
	event_count += 1
	last_event = kind_name(kind)
	var key := ""
	match kind:
		Kind.DROUGHT: key = "MSG_DISASTER_DROUGHT"
		Kind.STORM: key = "MSG_DISASTER_STORM"
		Kind.BEETLE: key = "MSG_DISASTER_BEETLE"
	EventBus.toast.emit(tr(key))
	EventBus.disaster_started.emit(kind, EVENT_DURATION)
	queue_redraw()
	return true


func _resistance(key: String) -> float:
	var st := skill_tree if skill_tree != null else SkillTree.instance
	return st.resistance(key) if st != null else 1.0


func _apply(dt: float) -> void:
	var ts := get_tree().get_nodes_in_group("trees")
	if ts.is_empty():
		return
	match active_kind:
		Kind.DROUGHT:
			for t in ts:
				if t is BaseTree:
					var bt := t as BaseTree
					bt.water = maxf(0.0, bt.water - DROUGHT_DRAIN * dt)
					total_damage += DROUGHT_DRAIN * dt
			if soil != null:
				soil.raining = false
		Kind.STORM:
			var r := _resistance("storm_risk")
			for t in ts:
				if t is BaseTree:
					var bt := t as BaseTree
					var dmg := STORM_DAMAGE * r * dt
					bt.health = maxf(0.0, bt.health - dmg)
					total_damage += dmg
		Kind.BEETLE:
			var r2 := _resistance("parasite_risk")
			for t in ts:
				if t is BaseTree:
					var bt2 := t as BaseTree
					var drain := BEETLE_DRAIN * r2 * dt
					bt2.glucose = maxf(0.0, bt2.glucose - drain)
					total_damage += drain


func _end() -> void:
	var ended := active_kind
	active_kind = Kind.NONE
	time_left = 0.0
	_next = MIN_INTERVAL / maxf(rate(), 0.01)
	EventBus.toast.emit(tr("MSG_DISASTER_OVER"))
	EventBus.disaster_ended.emit(ended)
	queue_redraw()


func _draw() -> void:
	if active_kind == Kind.NONE:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view_size: Vector2 = get_viewport_rect().size / cam.zoom
	var origin: Vector2 = cam.global_position - view_size * 0.5
	var rect := Rect2(origin, view_size)
	var tint := Color(0.18, 0.18, 0.18, 0.08)
	match active_kind:
		Kind.DROUGHT:
			tint = Color(0.62, 0.36, 0.10, 0.11)
			for i in range(9):
				var y := origin.y + float(i) * view_size.y / 9.0 \
					+ sin(_phase * 1.2 + float(i)) * 3.0
				draw_line(Vector2(origin.x, y),
					Vector2(origin.x + view_size.x, y),
					Color(0.95, 0.72, 0.32, 0.10), 2.0)
		Kind.STORM:
			tint = Color(0.10, 0.14, 0.20, 0.15)
			for i in range(28):
				var fx := float((i * 61 + event_count * 19) % 991) / 991.0
				var x := origin.x + fx * view_size.x \
					+ sin(_phase * 2.0 + float(i)) * 8.0
				var y := origin.y + float(i % 7) * view_size.y / 7.0
				draw_line(Vector2(x, y), Vector2(x - 18.0, y + 34.0),
					Color(0.72, 0.80, 0.90, 0.18), 2.0)
		Kind.BEETLE:
			tint = Color(0.24, 0.16, 0.08, 0.10)
			for i in range(30):
				var fx := float((i * 73 + event_count * 31) % 997) / 997.0
				var fy := float((i * 149 + event_count * 17) % 991) / 991.0
				var wobble := sin(_phase * 1.8 + float(i)) * 6.0
				draw_circle(origin + Vector2(fx * view_size.x + wobble,
					fy * view_size.y), 2.2, Color(0.12, 0.08, 0.05, 0.42))
	draw_rect(rect, tint)


func to_dict() -> Dictionary:
	return {
		"kind": active_kind, "left": time_left,
		"count": event_count, "damage": total_damage,
		"last": last_event,
	}


func from_dict(d: Dictionary) -> void:
	event_count = int(d.get("count", 0))
	total_damage = float(d.get("damage", 0.0))
	last_event = str(d.get("last", ""))
	# Ein laufendes Ereignis wird NICHT fortgesetzt: nach dem Laden beginnt
	# eine frische Grace-Periode (deterministisch, kein Ueberraschungsschaden).
	active_kind = Kind.NONE
	time_left = 0.0
	_elapsed = 0.0
	_phase = 0.0
	_next = GRACE_SECONDS
	queue_redraw()


# --------------------------------------------------------------------------- #
# Debug-Hooks
# --------------------------------------------------------------------------- #
func debug_force(kind: int) -> bool:
	return start(kind)


func debug_allowed_kinds() -> Array[int]:
	return allowed_kinds()


func debug_tick(seconds: float) -> void:
	tick(seconds)


func debug_active_kind() -> int:
	return active_kind


func debug_time_left() -> float:
	return time_left


func debug_event_count() -> int:
	return event_count


func debug_last_event() -> String:
	return last_event


func debug_damage() -> float:
	return total_damage


func debug_rate() -> float:
	return rate()


func debug_end() -> void:
	if active_kind != Kind.NONE:
		_end()


func debug_set_grace(seconds: float) -> void:
	_elapsed = maxf(seconds, 0.0)
	_next = GRACE_SECONDS
