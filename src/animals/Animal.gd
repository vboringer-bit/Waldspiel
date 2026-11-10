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
## REVISION 6:
##   * Der Gang liegt auf einer STABILEN Mittellinie (kein Wackeln durch die
##     Koerper-Animation) und wird geglaettet gezeichnet.
##   * Der Wurm ist ein rotiertes 16x16-Pixelart-Sprite; bei senkrechtem
##     Graben steht er senkrecht, bei waagerechtem Graben waagerecht.
##   * Ameisen folgen der Geländeoberkante und laufen nicht mehr in der Luft.
## REVISION 7 (endgueltige Gang-Fixierung):
##   * Der Tunnel ist ein EIGENER `BurrowTrail`-Node mit `top_level = true`
##     und Identitaets-Transformation. Er kann sich nicht mehr mitbewegen.
##   * Der Wurmkoerper hat KEIN sinusfoermiges Wackeln mehr; `position.y`
##     ist exakt die stabile Gang-Mittellinie.
##   * Die Tiefe richtet sich nach der sichtbaren 4px-Gelaendekante, nicht
##     mehr nach dem fliessenden Rohwert -> kein langsames Wegdriften.
##   * Wurm-Pixelart und gezeichnete Details sind deutlich dunkler/erdiger.
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
## REVISION 7: ruhige, ortsfeste Gang-Spur. Nur echte Bewegung >= 2 px und
## hoechstens alle 0,30 s erzeugt einen neuen Stuetzpunkt.
const BURROW_SAMPLE_STEP := 2.0
const BURROW_SAMPLE_TIME := 0.30
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
## REVISION 6: stabile Grab-Mittellinie in Eltern-Koordinaten. Der Koerper
## wackelt nur VISUELL um diese Linie; der Gang selbst bleibt ortsfest.
var _burrow_center: Vector2 = Vector2.ZERO
var _body_angle: float = 0.0
## REVISION 6: echtes Sprite2D statt CanvasItem-Drawcall. Godot 4.7 ersetzt
## bei draw_texture_* bei diesem Slot die RGB-Werte durch modulate (weisser
## Block); ein Sprite2D rendert die Pixelart-Textur dagegen korrekt.
var _body_sprite: Sprite2D = null
## REVISION 7: ortsfester Tunnel ausserhalb des Tier-Transforms.
var _trail_node: BurrowTrail = null
var _debug_frozen: bool = false


func setup(p_species: String, p_generator: WorldGenerator, p_x: float,
		p_wildlife) -> void:
	species = p_species
	generator = p_generator
	wildlife = p_wildlife
	_ensure_body_sprite()
	_ensure_trail_node()
	home_x = p_x
	surface_y = generator.height_smooth_at(p_x)
	reseat(p_x, -1.0)
	timer = 0.4
	_set_state(State.WANDER)


## REVISION 5: Tiefe und Oberflaeche nach Setzen von x neu bestimmen. Wird
## auch von WildlifeSystem.from_dict() benutzt (Savegame kennt die Tiefe).
func reseat(p_x: float, p_depth: float = -1.0) -> void:
	position.x = p_x
	surface_y = generator.ground_y_at(p_x)
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
		# REVISION 6/7: Ameisen stehen mit den Fuessen AUF der sichtbaren Kante.
		base_y = surface_y - (1.0 if species == "ant" else 4.0)
	position.y = base_y
	target_x = p_x
	_burrow_center = Vector2(p_x, base_y)
	_body_angle = 0.0
	_debug_frozen = false
	_trail.clear()
	if species == "worm":
		_trail.append(_burrow_center)
		_publish_trail()
	queue_redraw()


## REVISION 7: Der Tunnel ist KEIN Kind des Wurms. Er haengt am
## WildlifeSystem, ist top_level und bleibt deshalb ortsfest, egal was der
## Wurmkoerper tut. Beim Entfernen des Tiers wird er mit aufgeraeumt.
func _ensure_trail_node() -> void:
	if species != "worm" or get_parent() == null:
		return
	if _trail_node == null or not is_instance_valid(_trail_node):
		_trail_node = BurrowTrail.new()
		_trail_node.name = "BurrowTrail"
		_trail_node.top_level = true
		# top_level ignoriert den Parent-Transform; mit z_as_relative=false
		# liegt der Tunnel absolut bei 39 (ueber Boden/Baeumen, unter Tieren).
		_trail_node.z_as_relative = false
		_trail_node.z_index = 39
		get_parent().add_child(_trail_node)


func _exit_tree() -> void:
	if _trail_node != null and is_instance_valid(_trail_node):
		_trail_node.queue_free()
		_trail_node = null


func _publish_trail() -> void:
	if _trail_node == null or not is_instance_valid(_trail_node):
		return
	_trail_node.set_points(_world_trail())


func _ensure_body_sprite() -> void:
	if species != "worm" and species != "ant":
		return
	if _body_sprite == null or not is_instance_valid(_body_sprite):
		_body_sprite = Sprite2D.new()
		_body_sprite.name = "PixelBody"
		_body_sprite.centered = true
		_body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_body_sprite)
	_body_sprite.texture = load(PixelArt.WORM if species == "worm" else PixelArt.ANT)
	_body_sprite.position = Vector2(0.0, -3.0) if species == "ant" else Vector2.ZERO
	_body_sprite.visible = true


func _update_body_sprite() -> void:
	if _body_sprite == null or not is_instance_valid(_body_sprite):
		return
	if species == "worm":
		_body_sprite.rotation = _body_angle
		_body_sprite.scale = Vector2(0.80, 0.75)
	elif species == "ant":
		_body_sprite.rotation = 0.0
		var flip := 1.0 if facing >= 0 else -1.0
		_body_sprite.scale = Vector2(0.56 * flip, 0.56)


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
	# REVISION 7 Debug: Tier laeuft weiter durch die Simulation, bewegt sich
	# aber NICHT. Damit ist pruefbar, dass der Tunnel auch bei laufenden
	# Ticks keinen einzigen neuen Punkt / kein Wackeln erzeugt.
	if _debug_frozen:
		if species == "worm":
			_sync_worm_motion(dt)
		elif species == "ant":
			_follow_ground()
		_update_body_sprite()
		queue_redraw()
		return
	if species == "worm":
		_tick_burrow(dt)
	elif species == "ant":
		_follow_ground()
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
	# REVISION 6: NACH der x-Bewegung die stabile Mittellinie fortschreiben.
	if species == "worm":
		_sync_worm_motion(dt)
	elif species == "ant":
		_follow_ground()
	_update_body_sprite()
	queue_redraw()


## REVISION 6: nur noch TIEFE aktualisieren. Die Gang-Spur wird aus der
## stabilen Mittellinie gebildet, NICHT aus der animierten Koerperposition.
func _tick_burrow(dt: float) -> void:
	burrow_depth = move_toward(burrow_depth, burrow_target,
		WORM_BURROW_SPEED * 0.5 * dt)


func _sync_worm_motion(dt: float) -> void:
	var prev := _burrow_center
	# REVISION 7: sichtbare, auf 4px gerastete Gelaendekante. Der Rohwert
	# height_smooth_at() aenderte sich in JEDEM Frame und liess den Gang
	# langsam mitdriften; jetzt bleibt er zwischen zwei Kantenpixeln exakt
	# stehen.
	surface_y = generator.ground_y_at(position.x)
	base_y = surface_y + burrow_depth
	_burrow_center = Vector2(position.x, base_y)
	# KEIN Koerper-Wackeln mehr: das Tier sitzt exakt auf der Mittellinie.
	position.y = base_y
	var vel := _burrow_center - prev
	if vel.length() > 0.02:
		# atan2: oben/unten -> ±PI/2 (senkrecht), links/rechts -> 0/PI.
		var target_angle := atan2(vel.y, vel.x)
		_body_angle = lerp_angle(_body_angle, target_angle,
			clampf(dt * 10.0, 0.0, 1.0))
	_trail_timer += dt
	if _trail_timer >= BURROW_SAMPLE_TIME:
		_trail_timer = 0.0
		var last := _burrow_center
		if not _trail.is_empty():
			last = _trail[_trail.size() - 1]
		if _burrow_center.distance_to(last) >= BURROW_SAMPLE_STEP:
			_trail.append(_burrow_center)
			if _trail.size() > 30:
				_trail.remove_at(0)
			_publish_trail()


## REVISION 6: Ameisen sind strikt bodengebunden. Nach jeder x-Bewegung wird
## die lokale Geländehöhe neu abgefragt; kein Schweben über Senken mehr.
func _follow_ground() -> void:
	# REVISION 7: ebenfalls auf die sichtbare Kante rasten.
	surface_y = generator.ground_y_at(position.x)
	base_y = surface_y - 1.0
	position.y = base_y + sin(phase * 5.0) * 0.15


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


## REVISION 6 Debug-Hooks ----------------------------------------------------
func debug_body_angle() -> float:
	return _body_angle


func debug_ground_gap() -> float:
	return position.y - generator.ground_y_at(position.x)


func debug_trail_point(i: int) -> Vector2:
	if i < 0 or i >= _trail.size():
		return Vector2.ZERO
	return _trail[i]


## REVISION 7 Debug-Hooks ----------------------------------------------------
func debug_body_offset() -> float:
	return position.y - base_y


## REVISION 7: Bewegung einfrieren, aber weiter ticken (Stabilitaetsprobe).
func debug_freeze_motion() -> void:
	_debug_frozen = true
	target_x = position.x
	burrow_target = burrow_depth
	timer = 9999.0


func debug_trail_node() -> BurrowTrail:
	return _trail_node


func debug_trail_signature() -> Vector2:
	var acc := Vector2.ZERO
	for q in _trail:
		acc += q
	return acc


## Direkter, kollisionsfreier Test-Schub (Smoke: waagerechte Rotation).
func debug_nudge_horizontal(dx: float) -> void:
	if species != "worm":
		return
	position.x += dx
	_sync_worm_motion(0.1)


## Erzwingt reine Vertikalbewegung (Smoke/Screenshot: senkrechter Wurm).
func debug_hold_vertical(depth: float) -> void:
	if species != "worm":
		return
	target_x = position.x
	timer = 10.0
	state = State.WANDER
	burrow_target = clampf(depth, WORM_DEPTH_MIN, WORM_DEPTH_MAX)


## Erzwingt reine Horizontalbewegung (Smoke: waagerechter Wurm).
func debug_hold_horizontal() -> void:
	if species != "worm":
		return
	burrow_target = burrow_depth
	target_x = position.x + 30.0
	timer = 10.0
	state = State.WANDER


func debug_is_underground() -> bool:
	return species == "worm" \
		and position.y > generator.height_smooth_at(position.x) + WORM_DEPTH_MIN * 0.5


# --------------------------------------------------------------------------- #
# Zeichnung
# --------------------------------------------------------------------------- #
func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		t: float) -> Vector2:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t \
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## REVISION 6: Catmull-Rom-Glaettung der STABILEN Mittellinie. Die Punkte
## liegen in Eltern-Koordinaten; `position` (mit Koerper-Wackeln) wird hier
## abgezogen, damit der Gang beim Redraw nicht mitwackelt.
## REVISION 7: Catmull-Rom-Glaettung in WELT-/Eltern-Koordinaten. Es wird
## NICHTS mehr vom Tier-Transform abgezogen: der BurrowTrail besitzt seine
## eigene Identitaets-Transformation und zeichnet diese Punkte unveraendert.
func _world_trail() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _trail.size() < 2:
		return out
	for i in range(_trail.size() - 1):
		var p0: Vector2 = _trail[maxi(i - 1, 0)]
		var p1: Vector2 = _trail[i]
		var p2: Vector2 = _trail[i + 1]
		var p3: Vector2 = _trail[mini(i + 2, _trail.size() - 1)]
		for q in range(3):
			out.append(_catmull(p0, p1, p2, p3, float(q) / 3.0))
	out.append(_trail[_trail.size() - 1])
	return out


func _draw_worm(_f: float, _w: float) -> void:
	# 1) Der GANG wird vom separaten BurrowTrail gezeichnet (ortsfest).
	#    Hier bleiben nur Koerperdetails - deutlich dunkler als in R6.
	# 2) Segment-Highlights in gedecktem Rosabraun statt leuchtendem Pink.
	draw_set_transform(Vector2.ZERO, _body_angle, Vector2.ONE)
	for x in [-4.0, 0.0, 4.0]:
		draw_circle(Vector2(x, -1.0), 0.75, Color(0.55, 0.34, 0.30, 0.90))
	draw_circle(Vector2(7.0, -1.0), 0.8, Color(0.60, 0.40, 0.34, 0.90))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 3) Krumen vor der Grabespitze, erdfarben und unauffaellig.
	var head := Vector2(9.0, 0.0).rotated(_body_angle)
	var side := Vector2(0.0, 1.0).rotated(_body_angle)
	for i in range(3):
		var off := float(i)
		var crumb := head + side * (off * 1.4 - 1.4) \
			+ Vector2(off * 1.2, 0.0).rotated(_body_angle)
		draw_circle(crumb, 0.9, Color(0.34, 0.24, 0.16, 0.80))
	# 4) Staerkerer Erd-Schleier: der Wurm faellt weniger auf.
	draw_circle(Vector2.ZERO, 7.0, Color(0.26, 0.18, 0.12, 0.20))


func _draw_ant(w: float) -> void:
	# REVISION 6: Koerper ist ein Sprite2D-Kind, hier nur noch die Beine.
	var leg := Color(PixelArt.ANT_BODY.r, PixelArt.ANT_BODY.g,
		PixelArt.ANT_BODY.b, 0.85)
	for i in range(3):
		var x := -2.2 + float(i) * 2.2
		draw_line(Vector2(x, -2.2), Vector2(x - 2.2, w * 0.08), leg, 0.7)
		draw_line(Vector2(x, -2.2), Vector2(x + 2.2, -w * 0.08), leg, 0.7)


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
