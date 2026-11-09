class_name RainEffect
extends Control
## REVISION 3: Regen faellt bis auf die GELOENDEOBERFLAECHE und prasselt dort
## mit kleinen Spritzern auf. Vorher zogen die Linien einfach bis zum unteren
## Bildschirmrand durch den Boden hindurch.
##
## Die Tropfen leben in WELT-Koordinaten. Beim Aufprall auf
## `generator.height_smooth_at(wx)` werden 3 kleine Tropfen mit Aufwaerts-
## Geschwindigkeit plus eine kurze, sich ausbreitende Rippe erzeugt. Gezeichnet
## wird weiterhin im Bildschirmraum (CanvasLayer), dafuer rechnet `_to_screen()`
## Kameraposition und Zoom ein. Keine Addons, keine neuen Assets.

const DROP_COUNT := 240
const SPLASH_DROPS := 3
const GRAVITY := 1150.0
const WIND := 26.0
const MAX_SPLASHES := 320
const MAX_RIPPLES := 140

var raining: bool = false
var camera: Camera2D
var generator: WorldGenerator
var total_splashes: int = 0

var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _frozen := false


func _ready() -> void:
	# Explizite Rect-Groesse: ein Control unter einem CanvasLayer hat keinen
	# Control-Parent, Anker-Presets allein ergeben dort size == (0,0).
	position = Vector2.ZERO
	size = Vector2(get_viewport().get_visible_rect().size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("rain_effect")
	visible = false
	_rng.randomize()
	_reseed()
	EventBus.rain_started.connect(_on_rain_started)
	EventBus.rain_stopped.connect(_on_rain_stopped)
	get_viewport().size_changed.connect(_on_resize)


func setup(p_camera: Camera2D, p_generator: WorldGenerator) -> void:
	camera = p_camera
	generator = p_generator
	_reseed()


func _on_resize() -> void:
	size = Vector2(get_viewport().get_visible_rect().size)


# --------------------------------------------------------------------------- #
# Welt <-> Bildschirm
# --------------------------------------------------------------------------- #
func _vp() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)


func _zoom() -> float:
	return clampf(camera.zoom.x, 0.01, 8.0) if camera != null else 1.0


func _center() -> Vector2:
	return camera.global_position if camera != null else Vector2.ZERO


func _world_bounds() -> Vector2:
	var z := _zoom()
	var half := _vp().x / (2.0 * z)
	return Vector2(_center().x - half - 80.0, _center().x + half + 80.0)


func _world_top() -> float:
	return _center().y - _vp().y / (2.0 * _zoom())


func _world_bottom() -> float:
	return _center().y + _vp().y / (2.0 * _zoom())


## Exakte Geländehöhe in Welt-Pixeln; ohne Generator faellt der Regen bis
## zum unteren Bildrand (Fallback fuer Headless-Tests ohne Welt).
func surface_y(world_x: float) -> float:
	if generator != null:
		return generator.height_smooth_at(world_x)
	return _world_bottom()


func _to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - _center()) * _zoom() + _vp() * 0.5


# --------------------------------------------------------------------------- #
# Tropfen / Spritzer
# --------------------------------------------------------------------------- #
func _new_drop(scatter: bool) -> Dictionary:
	var bounds := _world_bounds()
	var wx := _rng.randf_range(bounds.x, bounds.y)
	var top := _world_top()
	var ground := surface_y(wx)
	var wy := top - _rng.randf_range(20.0, 220.0)
	if scatter:
		# Beim Start sofort ein vollständiges Regenbild (von oben bis knapp
		# über den Boden), sonst würde es erst nach ~1 s anfangen zu regnen.
		wy = _rng.randf_range(top - 120.0, ground - 6.0)
	return {
		"wx": wx, "wy": wy,
		"speed": _rng.randf_range(620.0, 1040.0),
		"len": _rng.randf_range(11.0, 24.0),
	}


func _reset_drop(d: Dictionary, scatter: bool = false) -> void:
	var fresh := _new_drop(scatter)
	for k in fresh.keys():
		d[k] = fresh[k]


func _reseed() -> void:
	_drops.clear()
	for _i in DROP_COUNT:
		_drops.append(_new_drop(true))


func _spawn_splash(wx: float, wy: float) -> void:
	total_splashes += 1
	for _i in SPLASH_DROPS:
		if _splashes.size() >= MAX_SPLASHES:
			break
		var life := _rng.randf_range(0.20, 0.38)
		_splashes.append({
			"px": wx + _rng.randf_range(-3.0, 3.0),
			"py": wy - 1.0,
			"vx": _rng.randf_range(-110.0, 110.0),
			"vy": _rng.randf_range(-215.0, -105.0),
			"life": life, "max": life,
		})
	if _ripples.size() < MAX_RIPPLES:
		_ripples.append({"x": wx, "y": wy, "life": 0.34, "max": 0.34})


func _on_rain_started(_duration: float) -> void:
	raining = true
	_frozen = false
	visible = true
	_reseed()
	queue_redraw()


func _on_rain_stopped() -> void:
	raining = false
	visible = false
	_splashes.clear()
	_ripples.clear()


func _process(delta: float) -> void:
	if not raining:
		return
	_step(delta)
	queue_redraw()


func _step(delta: float) -> void:
	if _frozen:
		return
	var bounds := _world_bounds()
	for d in _drops:
		d["wy"] = float(d["wy"]) + float(d["speed"]) * delta
		d["wx"] = float(d["wx"]) - WIND * delta
		var ground := surface_y(float(d["wx"]))
		if float(d["wy"]) >= ground:
			# Aufprall GENAU auf der Oberfläche -> Spritzer, dann neu oben.
			_spawn_splash(float(d["wx"]), ground)
			_reset_drop(d)
		elif float(d["wx"]) < bounds.x - 120.0:
			_reset_drop(d)

	for i in range(_splashes.size() - 1, -1, -1):
		var s: Dictionary = _splashes[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_splashes.remove_at(i)
			continue
		s["px"] = float(s["px"]) + float(s["vx"]) * delta
		s["py"] = float(s["py"]) + float(s["vy"]) * delta
		s["vy"] = float(s["vy"]) + GRAVITY * delta
		if float(s["py"]) > surface_y(float(s["px"])) + 2.0:
			_splashes.remove_at(i)
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) <= 0.0:
			_ripples.remove_at(i)


func _draw() -> void:
	if not raining:
		return
	var z := _zoom()
	var w := size.x
	for d in _drops:
		var wx := float(d["wx"])
		var wy := float(d["wy"])
		var head := _to_screen(Vector2(wx, wy))
		if head.x < -20.0 or head.x > w + 20.0:
			continue
		var tail := _to_screen(Vector2(wx + 3.0, wy - float(d["len"])))
		draw_line(tail, head, Color(0.40, 0.66, 0.92, 0.72),
			clampf(1.4 * z, 1.0, 2.6))
	for s in _splashes:
		var p := _to_screen(Vector2(float(s["px"]), float(s["py"])))
		var a := clampf(float(s["life"]) / maxf(float(s["max"]), 0.001), 0.0, 1.0)
		draw_circle(p, clampf(1.75 * z, 1.2, 3.0),
			Color(0.72, 0.87, 0.98, 0.95 * a))
	for r in _ripples:
		var p := _to_screen(Vector2(float(r["x"]), float(r["y"])))
		var age := 1.0 - clampf(float(r["life"]) / maxf(float(r["max"]), 0.001), 0.0, 1.0)
		var half := lerpf(2.0, 11.0, age) * z
		draw_line(p + Vector2(-half, 0.0), p + Vector2(half, 0.0),
			Color(0.72, 0.88, 0.98, 0.55 * (1.0 - age)), 1.0)


# --------------------------------------------------------------------------- #
# Debug-Hooks (Smoke-Test / reproduzierbare Screenshots)
# --------------------------------------------------------------------------- #
func debug_step(delta: float) -> void:
	raining = true
	_step(delta)


func debug_splash_count() -> int:
	return total_splashes


func debug_active_splashes() -> int:
	return _splashes.size()


func debug_drops_below_surface() -> int:
	var n := 0
	for d in _drops:
		if float(d["wy"]) > surface_y(float(d["wx"])) + 1.0:
			n += 1
	return n


func debug_surface_y(world_x: float) -> float:
	return surface_y(world_x)


## Fuer Screenshots: Tropfen + viele Spritzer entlang der sichtbaren
## Oberflaeche einfrieren, damit der Aufprall im Einzelbild sichtbar bleibt.
func debug_populate(count: int = 34) -> void:
	raining = true
	visible = true
	_frozen = false
	_reseed()
	var bounds := _world_bounds()
	for i in count:
		var wx := lerpf(bounds.x + 60.0, bounds.y - 60.0,
			float(i + 0.5) / float(maxi(count, 1)))
		_spawn_splash(wx, surface_y(wx))
	# Ein paar Simulationsschritte, damit die Spritzer sichtbar NACH OBEN
	# fliegen (statt als Punkt direkt auf der Bodenlinie zu kleben).
	for _i in 5:
		_step(0.032)
	_frozen = true
	queue_redraw()
