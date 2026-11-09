class_name Animal
extends Node2D
## PHASE 5: EIN Tier mit einer einfachen, echten StateMachine
## (Idle / Wander / Eat / HelpTree / Carry). Kein externes Asset: Wurm,
## Ameise, Specht und Eichhoernchen werden mit CanvasItem.draw_* gezeichnet.
##
## * WANDER: bewegt sich in einem Heimatbereich und weicht Baum-Bounds aus.
## * EAT: Wurm/Ameise geben Futter (WildlifeSystem.food).
## * HELP_TREE: Specht fliegt zu einem befallenen Baum und pickt Parasiten.
## * CARRY: Eichhoernchen traegt eine Eichel in einen entfernten Chunk.
## Alle Tiere sind per Linksklick anwaehlbar (Info-Toast + EventBus-Signal).

enum State { IDLE, WANDER, EAT, HELP_TREE, CARRY }

const SPEED := {
	"worm": 18.0,
	"ant": 34.0,
	"woodpecker": 240.0,
	"squirrel": 210.0,
}
const RANGE := {
	"worm": 70.0,
	"ant": 150.0,
	"woodpecker": 360.0,
	"squirrel": 420.0,
}
const FOOD_TIME := 2.4

var species: String = "worm"
var state: int = State.IDLE
var generator: WorldGenerator
var wildlife = null
var home_x: float = 0.0
var base_y: float = 0.0
var target_x: float = 0.0
var host_tree: BaseTree = null
var carrying_seed: bool = false
var timer: float = 0.0
var phase: float = 0.0
var facing: int = 1
var _idle_count: int = 0


func setup(p_species: String, p_generator: WorldGenerator, p_x: float,
		p_wildlife) -> void:
	species = p_species
	generator = p_generator
	wildlife = p_wildlife
	home_x = p_x
	base_y = generator.height_smooth_at(p_x) - 4.0
	position = Vector2(p_x, base_y)
	target_x = p_x
	timer = 0.4
	_set_state(State.WANDER)


func _set_state(new_state: int) -> void:
	state = new_state
	match state:
		State.IDLE:
			timer = 0.8
		State.WANDER:
			_pick_target()
		State.EAT:
			timer = FOOD_TIME
		State.HELP_TREE:
			timer = 0.0
		State.CARRY:
			timer = 0.0
	EventBus.animal_state_changed.emit(self, state)
	queue_redraw()


func _pick_target() -> void:
	var r := float(RANGE.get(species, 120.0))
	var delta := 0.0
	if wildlife != null and wildlife.has_method("rand_range"):
		delta = wildlife.rand_range(-r, r)
	else:
		delta = r * 0.5
	target_x = clampf(home_x + delta, home_x - r, home_x + r)
	if absf(target_x - position.x) < 8.0:
		target_x = home_x + r * 0.5
	timer = 1.4
	if wildlife != null and wildlife.has_method("rand_range"):
		timer += wildlife.rand_range(0.0, 1.2)


func speed() -> float:
	return float(SPEED.get(species, 40.0))


func tick(dt: float) -> void:
	phase += dt
	timer -= dt
	position.y = base_y + sin(phase * 6.0) * 1.2
	match state:
		State.IDLE:
			if timer <= 0.0:
				_idle_count += 1
				# Wurm/Ameise geben regelmaessig Futter: jede zweite
				# Ruhephase geht in EAT statt in WANDER.
				if (species == "worm" or species == "ant") \
						and _idle_count % 2 == 1:
					_set_state(State.EAT)
				else:
					_set_state(State.WANDER)
		State.WANDER:
			_move_toward(target_x, speed() * dt)
			if absf(position.x - target_x) < 4.0:
				_set_state(State.IDLE)
		State.EAT:
			if timer <= 0.0:
				_eat()
		State.HELP_TREE:
			_help(dt)
		State.CARRY:
			_carry(dt)
	queue_redraw()


func _move_toward(target: float, step: float) -> void:
	var dist := absf(target - position.x)
	if dist <= 0.01:
		return
	if step > dist:
		step = dist
	var dir := signf(target - position.x)
	var next := position.x + dir * step
	if _blocked(next):
		facing = -facing
		target_x = home_x
		_set_state(State.IDLE)
		return
	position.x = next
	facing = int(dir)


func _blocked(next_x: float) -> bool:
	# Specht und Eichhoernchen duerfen fuer ihre Aufgabe direkt an den Baum.
	if state == State.HELP_TREE or state == State.CARRY:
		return false
	var p := Vector2(next_x, base_y - 8.0)
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree and (t as BaseTree).get_bounds_rect().has_point(p):
			return true
	return false


func _eat() -> void:
	if wildlife != null and wildlife.has_method("on_animal_food"):
		wildlife.on_animal_food(self)
	_set_state(State.IDLE)
	timer = 1.2
	if wildlife != null and wildlife.has_method("rand_range"):
		timer += wildlife.rand_range(0.0, 0.8)


func assign_help(tree: BaseTree) -> void:
	host_tree = tree
	if tree != null:
		target_x = tree.global_position.x
	_set_state(State.HELP_TREE)


func assign_carry(target: float) -> void:
	target_x = target
	carrying_seed = true
	_set_state(State.CARRY)


func _help(dt: float) -> void:
	if host_tree == null or not is_instance_valid(host_tree):
		host_tree = null
		_set_state(State.IDLE)
		return
	target_x = host_tree.global_position.x
	_move_toward(target_x, 240.0 * dt)
	if absf(position.x - target_x) < 26.0:
		if wildlife != null and wildlife.has_method("on_woodpecker_help"):
			wildlife.on_woodpecker_help(self)
		host_tree = null
		_set_state(State.IDLE)


func _carry(dt: float) -> void:
	_move_toward(target_x, 260.0 * dt)
	if absf(position.x - target_x) < 18.0:
		if wildlife != null and wildlife.has_method("on_seed_delivered"):
			wildlife.on_seed_delivered(self)
		carrying_seed = false
		position.x = home_x
		_set_state(State.IDLE)


func state_key() -> String:
	match state:
		State.WANDER: return "STATE_WANDER"
		State.EAT: return "STATE_EAT"
		State.HELP_TREE: return "STATE_HELP_TREE"
		State.CARRY: return "STATE_CARRY"
	return "STATE_IDLE"


func get_info_text() -> String:
	var name_key := "ANIMAL_" + species.to_upper()
	return tr("MSG_ANIMAL_INFO") % [tr(name_key), tr(state_key())]


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-18.0, -30.0), Vector2(36.0, 34.0))


func click() -> void:
	EventBus.animal_clicked.emit(self)
	EventBus.toast.emit(get_info_text())


func debug_set_state(s: int) -> void:
	_set_state(s)


func _draw() -> void:
	var f := float(facing)
	var w := sin(phase * 4.0) * 1.4
	match species:
		"worm":
			var pts := PackedVector2Array([
				Vector2(-14.0, -5.0), Vector2(-7.0, -7.0 + w),
				Vector2(0.0, -5.0), Vector2(7.0, -7.0 - w),
				Vector2(14.0, -5.0),
			])
			draw_polyline(pts, Color(0.76, 0.45, 0.42, 1.0), 6.0)
			for p in pts:
				draw_circle(p, 2.2, Color(0.92, 0.66, 0.62, 1.0))
		"ant":
			var c := Color(0.16, 0.12, 0.10, 1.0)
			draw_circle(Vector2(-7.0, -7.0), 4.0, c)
			draw_circle(Vector2(0.0, -7.0), 3.2, c)
			draw_circle(Vector2(7.0, -7.0 + w), 4.6, c)
			for i in range(3):
				var x := -5.0 + float(i) * 5.0
				draw_line(Vector2(x, -5.0), Vector2(x - 5.0, 0.0),
					Color(0.20, 0.15, 0.12, 1.0), 1.5)
				draw_line(Vector2(x, -5.0), Vector2(x + 5.0, 0.0),
					Color(0.20, 0.15, 0.12, 1.0), 1.5)
		"woodpecker":
			var body := Color(0.18, 0.20, 0.20, 1.0)
			draw_circle(Vector2(0.0, -16.0), 9.0, body)
			draw_circle(Vector2(7.0 * f, -22.0), 6.0, body)
			draw_rect(Rect2(3.0 * f - 4.0, -29.0, 8.0, 5.0),
				Color(0.82, 0.18, 0.14, 1.0))
			var beak := PackedVector2Array([
				Vector2(12.0 * f, -22.0), Vector2(20.0 * f, -20.0),
				Vector2(12.0 * f, -18.0),
			])
			draw_colored_polygon(beak, Color(0.90, 0.76, 0.38, 1.0))
			draw_circle(Vector2(9.0 * f, -23.0), 1.3, Color.WHITE)
			var tail := PackedVector2Array([
				Vector2(-7.0, -14.0), Vector2(-18.0 * f, -10.0),
				Vector2(-6.0, -10.0),
			])
			draw_colored_polygon(tail, body)
			draw_line(Vector2(-3.0, -8.0), Vector2(-3.0, -2.0), body, 2.0)
			draw_line(Vector2(3.0, -8.0), Vector2(3.0, -2.0), body, 2.0)
		"squirrel":
			var fur := Color(0.88, 0.45, 0.12, 1.0)
			var dark := Color(0.60, 0.28, 0.08, 1.0)
			draw_circle(Vector2(-11.0 * f, -15.0), 11.0, dark)
			draw_circle(Vector2(-15.0 * f, -24.0), 8.0, fur)
			draw_circle(Vector2(0.0, -12.0), 9.0, fur)
			draw_circle(Vector2(7.0 * f, -20.0), 6.0, fur)
			draw_circle(Vector2(9.0 * f, -23.0), 1.4, Color.WHITE)
			draw_circle(Vector2(11.0 * f, -21.0), 1.0, Color.BLACK)
			draw_line(Vector2(-4.0, -5.0), Vector2(-4.0, 0.0), dark, 2.0)
			draw_line(Vector2(4.0, -5.0), Vector2(4.0, 0.0), dark, 2.0)
			if carrying_seed:
				draw_circle(Vector2(13.0 * f, -16.0), 4.0,
					Color(0.55, 0.34, 0.12, 1.0))
				draw_rect(Rect2(11.0 * f, -22.0, 4.0, 3.0),
					Color(0.32, 0.20, 0.08, 1.0))
