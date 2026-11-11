class_name SoilChemistry
extends Node2D
## PHASE 6 (Master-Punkt 4.2, Schwierigkeit SCHWER): Bodenchemie.
##
## Pro 64px-Region (4 Tiles) gibt es einen seed-deterministischen Satz aus
## pH-Wert und N/P/K. Gleiche Welt-Seed + gleiche X-Position = gleiche Werte.
## Die Verfuegbarkeit folgt zwei echten Regeln:
##   * pH-Glocke: Eichen bevorzugen leicht sauren Boden (Optimum pH 6.0).
##   * Liebigsches Minimum: der KNAPPSTE der drei Naehrstoffe limitiert.
##
## Daten sind in ALLEN Schwierigkeiten sichtbar (Rechtsklick / HUD / Save),
## aber die WIRKUNG auf Fotosynthese und Wachstum greift nur bei SCHWER.
## LEICHT hat laut §4.2 ausdruecklich keinen pH-Wert; NORMAL behaelt die
## einfachere R0-R8-Simulation. Dadurch bleiben alle alten Smokes exakt gruen.
## Bei SCHWER zeichnet dieser Node2D zusaetzlich eine dezente, ortsfeste
## Bodeneinfaerbung im sichtbaren Kameraausschnitt.

const REGION_PX := 64.0
const PH_MIN := 4.2
const PH_MAX := 7.8
const PH_OPT := 6.0
const PH_TOLERANCE := 1.8
const NPK_MAX := 100.0
const REGEN_BASE := 0.22          # N/P/K pro simulierter Sekunde
const REGEN_RAIN := 0.75

static var instance: SoilChemistry

var generator: WorldGenerator = null
var time_manager: TimeManager = null
var world_seed: int = 0
## 0.0 = LEICHT, 0.5 = NORMAL, 1.0 = SCHWER (nur SCHWER ist aktiv).
var complexity: float = 0.0
var raining: bool = false
## region_index -> {"ph": float, "n": float, "p": float, "k": float}
var cells: Dictionary = {}
var total_consumed: float = 0.0
var _overlay_acc: float = 0.0


func _enter_tree() -> void:
	instance = self
	world_seed = Global.world_seed
	complexity = Global.difficulty_factor("soil_complexity")


func _ready() -> void:
	instance = self
	top_level = true
	z_as_relative = false
	z_index = 1
	if cells.is_empty():
		reset(Global.world_seed)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	EventBus.rain_started.connect(_on_rain_started)
	EventBus.rain_stopped.connect(_on_rain_stopped)
	queue_redraw()


func setup(p_generator: WorldGenerator, p_time: TimeManager,
		p_seed: int = -1) -> void:
	generator = p_generator
	time_manager = p_time
	reset(Global.world_seed if p_seed < 0 else p_seed)


func reset(p_seed: int) -> void:
	world_seed = p_seed
	cells.clear()
	total_consumed = 0.0
	complexity = Global.difficulty_factor("soil_complexity")
	queue_redraw()


func _on_difficulty_changed(_value: int) -> void:
	complexity = Global.difficulty_factor("soil_complexity")
	queue_redraw()


func _on_rain_started(_duration: float) -> void:
	raining = true


func _on_rain_stopped() -> void:
	raining = false


func region_at(world_x: float) -> int:
	return int(floor(world_x / REGION_PX))


## Kleiner, stabiler Integer-Hash. Kein FastNoiseLite noetig: die Werte
## muessen bei gleichem Seed und gleicher Region IMMER identisch sein, auch
## nach Save/Load und nach einem Chunk-Wechsel.
func _hash01(region: int, salt: int) -> float:
	var x: int = region * 374761393 + salt * 668265263 \
		+ world_seed * 2246822519
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(absi(x % 1000003)) / 1000003.0


func cell(region: int) -> Dictionary:
	if cells.has(region):
		return cells[region]
	var c := {
		"ph": PH_MIN + (PH_MAX - PH_MIN) * _hash01(region, 1),
		"n": 20.0 + 80.0 * _hash01(region, 2),
		"p": 20.0 + 80.0 * _hash01(region, 3),
		"k": 20.0 + 80.0 * _hash01(region, 4),
	}
	cells[region] = c
	return c


func ph_at(world_x: float) -> float:
	return float(cell(region_at(world_x))["ph"])


## N / P / K als Vector3 (0..100).
func npk_at(world_x: float) -> Vector3:
	var c := cell(region_at(world_x))
	return Vector3(float(c["n"]), float(c["p"]), float(c["k"]))


## pH-Glocke (0.2..1.0): je weiter vom Eichen-Optimum, desto schlechter
## koennen die Wurzeln die Naehrstoffe aufschliessen.
func ph_fit_at(world_x: float) -> float:
	return clampf(1.0 - absf(ph_at(world_x) - PH_OPT) / PH_TOLERANCE,
		0.20, 1.0)


## Liebigsches Minimum: der knappste Naehrstoff bestimmt die Verfuegbarkeit.
func limiting_at(world_x: float) -> float:
	var v := npk_at(world_x)
	return clampf(minf(v.x, minf(v.y, v.z)) / 80.0, 0.20, 1.0)


func availability_at(world_x: float) -> float:
	return clampf(0.25 + 0.95 * ph_fit_at(world_x)
		* limiting_at(world_x), 0.25, 1.20)


func is_active() -> bool:
	return Global.difficulty_toggle("ph") \
		and Global.difficulty_toggle("nutrients")


## WIRKFAKTOR fuer environment_parts(). Bei LEICHT/NORMAL exakt 1.0 -> alle
## alten Smokes bleiben unveraendert. Bei SCHWER wird die echte Verfuegbarkeit
## mit `soil_complexity` (1.0) eingeblendet.
func soil_factor_at(world_x: float) -> float:
	if not is_active():
		return 1.0
	return clampf(lerpf(1.0, availability_at(world_x), complexity),
		0.35, 1.20)


## Wachstum verbraucht N/P/K in der Region der Wurzelspitze.
func consume(world_x: float, amount: float) -> void:
	if not is_active():
		return
	var region := region_at(world_x)
	var c := cell(region)
	var a := maxf(amount, 0.0)
	c["n"] = maxf(0.0, float(c["n"]) - a)
	c["p"] = maxf(0.0, float(c["p"]) - a * 0.7)
	c["k"] = maxf(0.0, float(c["k"]) - a * 0.85)
	total_consumed += a
	EventBus.soil_changed.emit(region)
	queue_redraw()


## Humus, Regen und Mykorrhiza bauen die Naehrstoffe langsam wieder auf.
func regenerate(dt: float) -> void:
	var gain := (REGEN_BASE + (REGEN_RAIN if raining else 0.0)) * maxf(dt, 0.0)
	if gain <= 0.0 or cells.is_empty():
		return
	for region in cells.keys():
		var c: Dictionary = cells[region]
		c["n"] = minf(NPK_MAX, float(c["n"]) + gain)
		c["p"] = minf(NPK_MAX, float(c["p"]) + gain * 0.8)
		c["k"] = minf(NPK_MAX, float(c["k"]) + gain * 0.9)
	queue_redraw()


func _process(delta: float) -> void:
	var dt := time_manager.scaled_delta(delta) if time_manager != null else delta
	if dt > 0.0:
		regenerate(dt)
	if is_active():
		_overlay_acc += delta
		if _overlay_acc >= 0.12:
			_overlay_acc = 0.0
			queue_redraw()


func _draw() -> void:
	if not is_active() or generator == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view_w := get_viewport_rect().size.x / maxf(cam.zoom.x, 0.01)
	var half := view_w * 0.5 + REGION_PX * 2.0
	var left := cam.global_position.x - half
	var right := cam.global_position.x + half
	var first := region_at(left) - 1
	var last := region_at(right) + 1
	for r in range(first, last + 1):
		var wx := float(r) * REGION_PX
		var cx := wx + REGION_PX * 0.5
		var gy := generator.ground_y_at(cx)
		var fit := ph_fit_at(cx)
		var limit := limiting_at(cx)
		var poor := clampf(1.0 - fit, 0.0, 1.0)
		var low := clampf(1.0 - limit, 0.0, 1.0)
		var bottom := maxf(float(Global.WORLD_DEPTH_PX), gy + 96.0)
		draw_rect(Rect2(wx, gy, REGION_PX, bottom - gy),
			Color(0.55 + 0.35 * poor, 0.30 + 0.42 * fit,
				0.20 + 0.35 * limit,
				0.05 + 0.10 * poor + 0.06 * low))
		draw_rect(Rect2(wx + 2.0, gy + 4.0, REGION_PX - 4.0, 5.0),
			Color(0.86 - 0.35 * poor, 0.62 + 0.22 * fit,
				0.30 + 0.25 * limit, 0.45))
		draw_line(Vector2(wx, gy), Vector2(wx, bottom),
			Color(1.0, 1.0, 1.0, 0.025), 1.0)


func to_dict() -> Dictionary:
	var out := {}
	for region in cells.keys():
		var c: Dictionary = cells[region]
		out[str(region)] = [c["ph"], c["n"], c["p"], c["k"]]
	return {
		"seed": world_seed,
		"consumed": total_consumed,
		"cells": out,
	}


func from_dict(d: Dictionary) -> void:
	world_seed = int(d.get("seed", world_seed))
	total_consumed = float(d.get("consumed", 0.0))
	cells.clear()
	var src: Dictionary = d.get("cells", {})
	for key in src.keys():
		var a: Array = src[key]
		if a.size() >= 4:
			cells[int(str(key))] = {
				"ph": float(a[0]), "n": float(a[1]),
				"p": float(a[2]), "k": float(a[3]),
			}
	complexity = Global.difficulty_factor("soil_complexity")
	queue_redraw()


# --------------------------------------------------------------------------- #
# Debug-Hooks (PHASE-6-Smoke / Presets)
# --------------------------------------------------------------------------- #
func debug_region_count() -> int:
	return cells.size()


func debug_is_active() -> bool:
	return is_active()


func debug_ph(world_x: float) -> float:
	return ph_at(world_x)


func debug_npk(world_x: float) -> Vector3:
	return npk_at(world_x)


func debug_ph_fit(world_x: float) -> float:
	return ph_fit_at(world_x)


func debug_limiting(world_x: float) -> float:
	return limiting_at(world_x)


func debug_set_npk(world_x: float, n: float, p: float, k: float) -> void:
	var c := cell(region_at(world_x))
	c["n"] = clampf(n, 0.0, NPK_MAX)
	c["p"] = clampf(p, 0.0, NPK_MAX)
	c["k"] = clampf(k, 0.0, NPK_MAX)
	EventBus.soil_changed.emit(region_at(world_x))
	queue_redraw()


func debug_set_ph(world_x: float, ph: float) -> void:
	cell(region_at(world_x))["ph"] = clampf(ph, PH_MIN, PH_MAX)
	EventBus.soil_changed.emit(region_at(world_x))
	queue_redraw()


func debug_set_all(world_x: float, ph: float, n: float, p: float,
		k: float) -> void:
	debug_set_ph(world_x, ph)
	debug_set_npk(world_x, n, p, k)


func debug_availability(world_x: float) -> float:
	return availability_at(world_x)


func debug_soil_factor(world_x: float) -> float:
	return soil_factor_at(world_x)


func debug_consumed() -> float:
	return total_consumed


func debug_regenerate(dt: float) -> void:
	regenerate(dt)


func debug_set_raining(value: bool) -> void:
	raining = value
