class_name Animal
extends Node2D
## PHASE 5: EIN Tier mit einer einfachen, echten StateMachine
## (Idle / Wander / Eat / HelpTree / Carry).
## REVISION 5:
##   * Regenwuermer leben UNTER der Erde, graben sich langsam durch lockere
##     Schichten und hinterlassen sichtbare Gang-Spuren (Mycelarium-Anmutung).
##   * Wuermer und Ameisen sind deutlich kleiner (~40 % der alten Groesse).
##   * Specht und Eichhoernchen bleiben unveraendert (sie gehoeren nicht zur
##     Bodenfauna und muessen weiter gut anklickbar sein).
## Alle Tiere sind per Linksklick anwaehlbar (Info-Toast + EventBus-Signal).

enum State { IDLE, WANDER, EAT, HELP_TREE, CARRY }

const SPEED := {
	"worm": 8.0,
	"ant": 26.0,
	"woodpecker": 240.0,
	"squirrel": 210.0,
}
const RANGE := {
	"worm": 34.0,
	"ant": 110.0,
	"woodpecker": 360.0,
	"squirrel": 420.0,
}
const FOOD_TIME := 2.4

const WORM_DEPTH_MIN := 20.0
const WORM_DEPTH_MAX := 120.0
const WORM_BURROW_SPEED := 7.0
const BODY_SPAN := {
	"worm": 12.0,
	"ant": 9.0,
	"woodpecker": 40.0,
	"squirrel": 40.0,
}

var species: String = "worm"
var state: int = State.IDLE
var generator: WorldGenerator
var wildlife = null
var home_x: float = 0.0
var base_y: float = 0.0
var surface_y: float = 0.0
var burrow_depth: float = 0.0
var burrow_target: float = 0.0
var target_x: float = 0.0
var host_tree: BaseTree = null
var carrying_seed: bool = false
var timer: float = 0.0
var phase: float = 0.0
var facing: int = 1
var _idle_count: int = 0
var _trail: Array[Vector2] = []
var _trail_timer: float = 0.0


func setup(p_species: String, p_generator: WorldGenerator, p_x: float,
		p_wildlife) -> void:
	species = p_species
	generator = p_generator
	wildlife = p_wildlife
	home_x = p_x
	surface_y = generator.height_smooth_at(p_x)
	reseat(p_x, -1.0)
	timer = 0.4
	_set_state(State.WANDER)


## REVISION 5: Tiefe und Oberflaeche nach Setzen von x neu bestimmen. Wird
## auch von WildlifeSystem.from_dict() benutzt (Savegame kennt die Tiefe).
func reseat(p_x: float, p_depth: float = -1.0) -> void:
	position.x = p_x
	surface_y = generator.height_smooth_at(p_x)
	if species == "worm":
		if p_depth > 0.0:
			burrow_depth = clampf(p_depth, WORM_DEPTH_MIN, WORM_DEPTH_MAX)
		else:
			# Deterministische Starttiefe, leicht unterschiedlich pro Tier.
			burrow_depth = 26.0 + float(absi(int(p_x)) % 42)
		burrow_target = burrow_depth
		base_y = surface_y + burrow_depth
	else:
		burrow_depth = 0.0
		burrow_target = 0.0
		base_y = surface_y - 4.0
	position.y = base_y
	target_x = p_x
	_trail.clear()
	queue_redraw()


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
	if species == "worm" and wildlife != null and wildlife.has_method("rand_range"):
		burrow_target = clampf(burrow_depth
			+ wildlife.rand_range(-24.0, 24.0), WORM_DEPTH_MIN, WORM_DEPTH_MAX)


func speed() -> float:
	return float(SPEED.get(species, 40.0))


func tick(dt: float) -> void:
	phase += dt
	timer -= dt
	if species == "worm":
		_tick_burrow(dt)
	else:
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


## REVISION 5: langsames, leicht welliges Graben in lockerer Erde. Die Gang-
## Spur wird in WELTKOORDINATEN gespeichert, damit sie beim Weiterkriechen
## liegen bleibt statt mit dem Tier mitzuwandern.
func _tick_burrow(dt: float) -> void:
	burrow_depth = move_toward(burrow_depth, burrow_target,
		WORM_BURROW_SPEED * 0.5 * dt)
	surface_y = generator.height_smooth_at(position.x)
	base_y = surface_y + burrow_depth
	position.y = base_y + sin(phase * 2.2) * 1.0
	_trail_timer += dt
	if _trail_timer >= 0.30:
		_trail_timer = 0.0
		_trail.append(global_position)
		if _trail.size() > 30:
			_trail.remove_at(0)


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
	if species == "worm":
		return _worm_blocked(next_x)
	var p := Vector2(next_x, base_y - 8.0)
	for t in get_tree().get_nodes_in_group("trees"):
		if t is BaseTree:
			var bt := t as BaseTree
			var r := bt.get_bounds_rect()
			# REVISION 5: nur der oberflaechennahe Streifen ist Sperrflaeche;
			# der deutlich groesser gewordene Baum soll die Ameisen nicht
			# meterweit unter der Erde blockieren.
			var band := Rect2(Vector2(r.position.x,
				bt.global_position.y - 46.0), Vector2(r.size.x, 92.0))
			if band.has_point(p):
				return true
	return false


## Fels, Stein, Wasser und Hohlraeume sind fuer den Wurm undurchlaessig.
func _worm_blocked(next_x: float) -> bool:
	var tile_depth := int(clampf(burrow_depth / 16.0, 1.0, 7.0))
	var gx := int(floor(next_x / float(WorldGenerator.TILE_SIZE)))
	var gy := generator.surface_tile_y_at(next_x) + tile_depth
	var k := generator.material_at(gx, gy)
	return k == WorldGenerator.SoilKind.AIR \
		or k == WorldGenerator.SoilKind.WATER \
		or k == WorldGenerator.SoilKind.CAVE \
		or k == WorldGenerator.SoilKind.ROCK \
		or k == WorldGenerator.SoilKind.STONE


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
	if species == "worm":
		return Rect2(global_position + Vector2(-7.0, -6.0), Vector2(14.0, 12.0))
	if species == "ant":
		return Rect2(global_position + Vector2(-6.0, -8.0), Vector2(12.0, 10.0))
	return Rect2(global_position + Vector2(-18.0, -30.0), Vector2(36.0, 34.0))


func click() -> void:
	EventBus.animal_clicked.emit(self)
	EventBus.toast.emit(get_info_text())


func debug_set_state(s: int) -> void:
	_set_state(s)


func debug_body_span() -> float:
	return float(BODY_SPAN.get(species, 36.0))


func debug_depth() -> float:
	return burrow_depth


func debug_trail_size() -> int:
	return _trail.size()


func debug_is_underground() -> bool:
	return species == "worm" \
		and position.y > generator.height_smooth_at(position.x) + WORM_DEPTH_MIN * 0.5


# --------------------------------------------------------------------------- #
# Zeichnung
# --------------------------------------------------------------------------- #
func _draw_worm(f: float, w: float) -> void:
	# 1) Gang-Spur: dunkler Tunnel mit hellerer, aufgelockerter Erdmitte.
	if _trail.size() >= 2:
		var n := maxi(_trail.size() - 1, 1)
		for i in range(_trail.size() - 1):
			var a := to_local(_trail[i])
			var b := to_local(_trail[i + 1])
			var fade := 0.45 + 0.45 * float(i) / float(n)
			# Aufgelockerte Erde: dunkler Gang + helle Krumen-Mitte.
			draw_line(a, b, Color(0.15, 0.10, 0.06, fade), 5.4)
			draw_line(a, b, Color(0.66, 0.48, 0.29, fade), 2.1)
			if i % 3 == 0:
				draw_circle(a, 1.3, Color(0.58, 0.42, 0.26, fade))
	# 2) Koerper: ~12 px statt der alten 28 px.
	var pts := PackedVector2Array([
		Vector2(-6.0 * f, -2.0),
		Vector2(-3.0 * f, -2.8 + w * 0.45),
		Vector2(0.0, -2.0),
		Vector2(3.0 * f, -2.8 - w * 0.45),
		Vector2(6.0 * f, -2.0),
	])
	draw_polyline(pts, Color(0.42, 0.24, 0.21, 1.0), 4.0)
	draw_polyline(pts, Color(0.88, 0.52, 0.47, 1.0), 2.6)
	for p in pts:
		draw_circle(p, 1.0, Color(0.96, 0.72, 0.67, 1.0))
	# 3) Aufgewuehlte Krumen vor der Grabespitze.
	for i in range(3):
		var j := float(i)
		draw_circle(Vector2((7.0 + j * 2.4) * f,
			-1.0 - j * 1.2 + sin(phase * 3.0 + j) * 0.8),
			0.9, Color(0.44, 0.31, 0.20, 0.85))
	# 4) Erd-Schleier: der Wurm steckt IM Boden, liegt nicht obendrauf.
	draw_rect(Rect2(-8.0, -6.0, 16.0, 9.0), Color(0.31, 0.21, 0.14, 0.12))


func _draw_ant(w: float) -> void:
	var c := Color(0.16, 0.12, 0.10, 1.0)
	draw_circle(Vector2(-3.4, -3.0), 1.8, c)
	draw_circle(Vector2(0.0, -3.0), 1.4, c)
	draw_circle(Vector2(3.4, -3.0 + w * 0.4), 2.1, c)
	for i in range(3):
		var x := -2.2 + float(i) * 2.2
		draw_line(Vector2(x, -2.2), Vector2(x - 2.2, 0.0),
			Color(0.20, 0.15, 0.12, 1.0), 0.7)
		draw_line(Vector2(x, -2.2), Vector2(x + 2.2, 0.0),
			Color(0.20, 0.15, 0.12, 1.0), 0.7)
	draw_circle(Vector2(4.4, -3.6), 0.6, Color(0.35, 0.25, 0.18, 1.0))


func _draw() -> void:
	var f := float(facing)
	var w := sin(phase * 4.0) * 1.4
	match species:
		"worm":
			_draw_worm(f, w)
		"ant":
			_draw_ant(w)
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
