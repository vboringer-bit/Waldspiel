class_name RainEffect
extends Control
## REVISION 3: Regen faellt bis auf die GELOENDEOBERFLAECHE und prasselt dort
## mit kleinen Spritzern auf. Die Tropfen leben in WELT-Koordinaten; gezeichnet
## wird im Bildschirmraum (CanvasLayer) ueber `_to_screen()`.
##
## PHASE 4: Im WINTER wird der Regen durch SCHNEE ersetzt. Der Nieder-
## schlag bleibt dasselbe Event (WaterSystem.raining, Reservoir-Auffuellung,
## x1/x3/x10-Echtzeitpartikel), aber:
##   * langsame, seitlich schwingende weisse Flocken statt blauer Linien,
##   * KEINE Spritzer und keine Rippen (Schnee spritzt nicht),
##   * dafuer liegenbleibende, langsam verblassende Schneepunkte auf
##     der exakten Gelaendelinie,
##   * HUD/Toast-Meldungen auf "Es schneit" umgestellt.
##
## PHASE-4-FIX: Schneepunkte bleiben jetzt 5–9 s liegen. Wird es MITTEN im
## Schneefall Fruehling, gibt es keinen harten Schnitt mehr: `snow_blend`
## laeuft in 3,5 s von 1.0 (Schnee) nach 0.0 (Regen). Flocken, Linien,
## Spritzer und HUD-Text werden dabei ueberblendet; vorhandene Schneepunkte
## schmelzen beschleunigt, statt sofort geloescht zu werden.
## Die R3-Regeln (Winter: keine Reservoir-Entnahme, keine Versickerung,
## Auffuellen laeuft weiter) bleiben unangetastet.

const DROP_COUNT := 240
const SPLASH_DROPS := 3
const GRAVITY := 1150.0
const WIND := 26.0
const MAX_SPLASHES := 320
const MAX_RIPPLES := 140
const SNOW_SPEED_MIN := 55.0
const SNOW_SPEED_MAX := 135.0
const SNOW_DRIFT := 0.35
const MAX_SETTLE := 320
const SNOW_SETTLE_MIN := 5.0
const SNOW_SETTLE_MAX := 9.0
const SETTLE_MELT_MULTIPLIER := 3.0
const MODE_FADE_SECONDS := 3.5
const SNOW_COLOR := Color(0.95, 0.97, 1.0, 0.92)

var raining: bool = false
var snow_mode: bool = false            # Ziel-Jahreszeit: Winter = Schnee
var snow_blend: float = 0.0            # 0 = Regen, 1 = Schnee, dazwischen Uebergang
var camera: Camera2D
var generator: WorldGenerator
var time_manager: TimeManager
var total_splashes: int = 0

var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _settle: Array[Dictionary] = []   # liegengebliebene Flocken
var _rng := RandomNumberGenerator.new()
var _frozen := false
var _clock := 0.0
var _target_blend := 0.0
var _transitioning := false
var _last_emitted_blend := -1.0


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
	EventBus.season_changed.connect(_on_season_changed)
	get_viewport().size_changed.connect(_on_resize)


func setup(p_camera: Camera2D, p_generator: WorldGenerator,
		p_time: TimeManager = null) -> void:
	camera = p_camera
	generator = p_generator
	time_manager = p_time
	_sync_mode(true)
	_reseed()


func _on_resize() -> void:
	size = Vector2(get_viewport().get_visible_rect().size)


## Jahresziel setzen. Ohne aktiven Niederschlag (oder bei neuen Events) wird
## direkt gesnappt; waehrend laufendem Niederschlag startet der weiche Uebergang.
func _sync_mode(snap: bool) -> void:
	var winter := time_manager != null and time_manager.is_winter()
	snow_mode = winter
	_target_blend = 1.0 if winter else 0.0
	if snap or not raining:
		snow_blend = _target_blend
		_transitioning = false
	else:
		_transitioning = absf(snow_blend - _target_blend) > 0.001
	_emit_blend(true)


func _on_season_changed(_year: int, _season: int) -> void:
	var was_winter := snow_mode
	_sync_mode(false)
	if raining and _transitioning:
		# WICHTIG: _settle / _splashes NICHT loeschen. Der liegende Schnee
		# schmilzt in _update_landing() beschleunigt, waehrend Flocken zu
		# Regentropfen ueberblenden.
		if was_winter and not snow_mode:
			EventBus.toast.emit(tr("MSG_SNOW_MELT"))
	_emit_blend(true)
	queue_redraw()


func _emit_blend(force: bool = false) -> void:
	if force or absf(snow_blend - _last_emitted_blend) >= 0.02:
		_last_emitted_blend = snow_blend
		EventBus.precipitation_blend_changed.emit(snow_blend)


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


## Exakte Gelaendehoehe in Welt-Pixeln; ohne Generator faellt der Niederschlag
## bis zum unteren Bildrand (Fallback fuer Headless-Tests ohne Welt).
func surface_y(world_x: float) -> float:
	if generator != null:
		return generator.height_smooth_at(world_x)
	return _world_bottom()


func _to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - _center()) * _zoom() + _vp() * 0.5


# --------------------------------------------------------------------------- #
# Tropfen / Flocken / Auftreffen
# --------------------------------------------------------------------------- #
func _new_drop(scatter: bool) -> Dictionary:
	var bounds := _world_bounds()
	var wx := _rng.randf_range(bounds.x, bounds.y)
	var top := _world_top()
	var ground := surface_y(wx)
	var wy := top - _rng.randf_range(20.0, 220.0)
	if scatter:
		# Beim Start sofort ein vollstaendiges Bild (von oben bis knapp
		# ueber den Boden), sonst wuerde es erst nach ~1 s anfangen.
		wy = _rng.randf_range(top - 120.0, ground - 6.0)
	# Ein Drop traegt BEIDE Parameter; snow_blend entscheidet, wie schnell
	# und wie stark er faellt bzw. schwingt.
	return {
		"wx": wx, "wy": wy,
		"rain_speed": _rng.randf_range(620.0, 1040.0),
		"rain_len": _rng.randf_range(11.0, 24.0),
		"snow_speed": _rng.randf_range(SNOW_SPEED_MIN, SNOW_SPEED_MAX),
		"radius": _rng.randf_range(1.3, 3.1),
		"phase": _rng.randf_range(0.0, TAU),
		"sway": _rng.randf_range(9.0, 30.0),
	}


func _reset_drop(d: Dictionary, scatter: bool = false) -> void:
	var fresh := _new_drop(scatter)
	for k in fresh.keys():
		d[k] = fresh[k]


func _reseed() -> void:
	_drops.clear()
	for _i in DROP_COUNT:
		_drops.append(_new_drop(true))


func _clear_landing() -> void:
	_splashes.clear()
	_ripples.clear()
	_settle.clear()


## PHASE-4-FIX: probabilistischer Crossfade. Reiner Schnee -> nur Punkte,
## reiner Regen -> nur Spritzer, dazwischen nehmen beide langsam zu/ab.
func _spawn_landing(wx: float, wy: float) -> void:
	if snow_blend > 0.02 and _rng.randf() <= snow_blend:
		_add_settle(wx, wy, snow_blend)
	if snow_blend < 0.98 and _rng.randf() <= 1.0 - snow_blend:
		_spawn_splash(wx, wy, 1.0 - snow_blend)


func _add_settle(wx: float, wy: float, alpha: float) -> void:
	if _settle.size() >= MAX_SETTLE:
		return
	var life := _rng.randf_range(SNOW_SETTLE_MIN, SNOW_SETTLE_MAX)
	_settle.append({
		"px": wx + _rng.randf_range(-2.0, 2.0),
		"py": wy - 1.0,
		"r": _rng.randf_range(1.2, 2.6),
		"alpha": clampf(alpha, 0.25, 1.0),
		"life": life, "max": life,
	})


func _spawn_splash(wx: float, wy: float, alpha: float) -> void:
	total_splashes += 1
	var a := clampf(alpha, 0.25, 1.0)
	for _i in SPLASH_DROPS:
		if _splashes.size() >= MAX_SPLASHES:
			break
		var life := _rng.randf_range(0.20, 0.38)
		_splashes.append({
			"px": wx + _rng.randf_range(-3.0, 3.0),
			"py": wy - 1.0,
			"vx": _rng.randf_range(-110.0, 110.0),
			"vy": _rng.randf_range(-215.0, -105.0),
			"alpha": a,
			"life": life, "max": life,
		})
	if _ripples.size() < MAX_RIPPLES:
		_ripples.append({"x": wx, "y": wy, "alpha": a,
			"life": 0.34, "max": 0.34})


func _on_rain_started(_duration: float) -> void:
	# Neues Event snappt auf die aktuelle Jahreszeit. Ein Saisonwechsel
	# WAEHREND des Events benutzt dagegen _on_season_changed() (weich).
	_sync_mode(true)
	raining = true
	_frozen = false
	visible = true
	_clear_landing()
	_reseed()
	_emit_blend(true)
	queue_redraw()


func _on_rain_stopped() -> void:
	raining = false
	visible = false
	_clear_landing()
	_sync_mode(true)


func _process(delta: float) -> void:
	if not raining:
		return
	_step(delta)
	queue_redraw()


func _step(delta: float) -> void:
	if _frozen:
		return
	_clock += delta
	if _transitioning:
		snow_blend = move_toward(snow_blend, _target_blend,
			delta / MODE_FADE_SECONDS)
		if is_equal_approx(snow_blend, _target_blend):
			snow_blend = _target_blend
			_transitioning = false
		_emit_blend()

	var rain_w := 1.0 - snow_blend
	var bounds := _world_bounds()
	for d in _drops:
		var speed := lerpf(float(d["snow_speed"]), float(d["rain_speed"]), rain_w)
		d["wy"] = float(d["wy"]) + speed * delta
		var drift := WIND * delta * lerpf(SNOW_DRIFT, 1.0, rain_w)
		if snow_blend > 0.001:
			drift += sin(_clock * 1.7 + float(d["phase"])) \
				* float(d["sway"]) * delta * snow_blend
		d["wx"] = float(d["wx"]) - drift
		var ground := surface_y(float(d["wx"]))
		if float(d["wy"]) >= ground:
			_spawn_landing(float(d["wx"]), ground)
			_reset_drop(d)
		elif float(d["wx"]) < bounds.x - 120.0:
			_reset_drop(d)
	_update_landing(delta)


func _update_landing(delta: float) -> void:
	# Im Fruehling schmilzt bereits liegender Schnee schneller, aber NICHT
	# augenblicklich. Das ist der sanfte Uebergang des Users.
	var melt := _target_blend == 0.0 and snow_blend < 0.999
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
	for i in range(_settle.size() - 1, -1, -1):
		var q: Dictionary = _settle[i]
		q["life"] = float(q["life"]) - delta \
			* (SETTLE_MELT_MULTIPLIER if melt else 1.0)
		if float(q["life"]) <= 0.0:
			_settle.remove_at(i)


# --------------------------------------------------------------------------- #
# Zeichnen: beides gleichzeitig, alpha folgt snow_blend
# --------------------------------------------------------------------------- #
func _draw() -> void:
	if not raining:
		return
	var z := _zoom()
	var w := size.x
	_draw_settle(z)
	if snow_blend > 0.001:
		_draw_snowflakes(z, w, snow_blend)
	if snow_blend < 0.999:
		_draw_raindrops(z, w, 1.0 - snow_blend)
	_draw_splashes(z)
	_draw_ripples(z)


func _draw_settle(z: float) -> void:
	for q in _settle:
		var sp := _to_screen(Vector2(float(q["px"]), float(q["py"])))
		var a := clampf(float(q["life"]) / maxf(float(q["max"]), 0.001), 0.0, 1.0)
		var c := Color(0.95, 0.97, 1.0, 0.75 * a * float(q["alpha"]))
		draw_circle(sp, clampf(float(q["r"]) * z, 1.0, 4.0), c)


func _draw_snowflakes(z: float, w: float, a: float) -> void:
	var col := SNOW_COLOR
	col.a *= a
	var line := Color(1.0, 1.0, 1.0, 0.55 * a)
	for d in _drops:
		var p := _to_screen(Vector2(float(d["wx"]), float(d["wy"])))
		if p.x < -20.0 or p.x > w + 20.0:
			continue
		var r := clampf(float(d["radius"]) * z, 1.0, 4.5)
		draw_circle(p, r, col)
		if r >= 2.6:
			# Grobe 6-zackige Andeutung fuer die grossen Flocken.
			draw_line(p + Vector2(-r * 1.5, 0.0), p + Vector2(r * 1.5, 0.0), line, 1.0)
			draw_line(p + Vector2(0.0, -r * 1.5), p + Vector2(0.0, r * 1.5), line, 1.0)


func _draw_raindrops(z: float, w: float, a: float) -> void:
	var col := Color(0.40, 0.66, 0.92, 0.72 * a)
	var width := clampf(1.4 * z, 1.0, 2.6)
	for d in _drops:
		var wx := float(d["wx"])
		var wy := float(d["wy"])
		var head := _to_screen(Vector2(wx, wy))
		if head.x < -20.0 or head.x > w + 20.0:
			continue
		var tail := _to_screen(Vector2(wx + 3.0, wy - float(d["rain_len"])))
		draw_line(tail, head, col, width)


func _draw_splashes(z: float) -> void:
	for s in _splashes:
		var p := _to_screen(Vector2(float(s["px"]), float(s["py"])))
		var a := clampf(float(s["life"]) / maxf(float(s["max"]), 0.001), 0.0, 1.0)
		var col := Color(0.72, 0.87, 0.98, 0.95 * a * float(s["alpha"]))
		draw_circle(p, clampf(1.75 * z, 1.2, 3.0), col)


func _draw_ripples(z: float) -> void:
	for r in _ripples:
		var p := _to_screen(Vector2(float(r["x"]), float(r["y"])))
		var age := 1.0 - clampf(float(r["life"]) / maxf(float(r["max"]), 0.001), 0.0, 1.0)
		var half := lerpf(2.0, 11.0, age) * z
		var col := Color(0.72, 0.88, 0.98,
			0.55 * (1.0 - age) * float(r["alpha"]))
		draw_line(p + Vector2(-half, 0.0), p + Vector2(half, 0.0), col, 1.0)


# --------------------------------------------------------------------------- #
# Debug-Hooks (Smoke-Test / reproduzierbare Screenshots)
# --------------------------------------------------------------------------- #
func debug_step(delta: float) -> void:
	raining = true
	_step(delta)


func debug_is_snow() -> bool:
	return snow_blend > 0.5


func debug_snow_blend() -> float:
	return snow_blend


func debug_is_transitioning() -> bool:
	return _transitioning


func debug_snow_settle_count() -> int:
	return _settle.size()


func debug_settle_life_range() -> Vector2:
	if _settle.is_empty():
		return Vector2.ZERO
	var lo := 1.0e9
	var hi := 0.0
	for q in _settle:
		lo = minf(lo, float(q["max"]))
		hi = maxf(hi, float(q["max"]))
	return Vector2(lo, hi)


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


func debug_unfreeze() -> void:
	_frozen = false


## Fuer Screenshots: Auftreffpunkte entlang der sichtbaren Oberflaeche
## einfrieren. Bei Mischblend werden BEIDE Effekte deterministisch gesetzt.
func debug_populate(count: int = 34) -> void:
	raining = true
	visible = true
	_frozen = false
	_clear_landing()
	_reseed()
	var bounds := _world_bounds()
	for i in count:
		var wx := lerpf(bounds.x + 60.0, bounds.y - 60.0,
			float(i + 0.5) / float(maxi(count, 1)))
		var wy := surface_y(wx)
		if snow_blend > 0.01:
			_add_settle(wx, wy, snow_blend)
		if snow_blend < 0.99:
			_spawn_splash(wx, wy, 1.0 - snow_blend)
	if snow_blend < 0.5:
		for _i in 5:
			_step(0.032)
	_frozen = true
	queue_redraw()
