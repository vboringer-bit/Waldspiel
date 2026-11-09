class_name WaterSystem
extends Node
## PHASE 1 + 2: alle drei Wasserquellen aus Master-Punkt 4.2.
##   1) Normaler Boden : root_count * 0.1 * dt          (NORMAL; LEICHT = P3)
##   2) Reservoir      : 2.0 * dt pro beruehrtem Tile, ENDLICH (WorldState)
##   3) Regen          : zufaellig 2-5 Min / 20-60 s, 5x -> root_count * 0.5 * dt
## REVISION 2: ein Reservoir ist EIN zusammenhaengendes Becken mit gemeinsamem
## Volumen. Der Pegel sinkt von oben nach unten; obere Tiles werden zuerst
## trocken (SLOT_DRY_WATER). Dazu langsame Versickerung + Regen-Auffuellung.
##
## BUGFIX vor PHASE 3: Der Regen fuellte die Becken praktisch NICHT auf
## (fixe 1.2 Einheiten/s unabhaengig von der Beckengroesse, und Wurzeln
## entnahmen gleichzeitig schneller). Jetzt skaliert die Auffuellung mit der
## Beckengroesse, laeuft NACH der Wurzelentnahme und hat sichtbares Feedback.

const REGEN_MIN_INTERVALL := 120.0
const REGEN_MAX_INTERVALL := 300.0
const REGEN_DAUER_MIN := 20.0
const REGEN_DAUER_MAX := 60.0
const REGEN_FAKTOR := 5.0
const RESERVOIR_GAIN := 2.0        # Master-Punkt 4.2

var raining: bool = false
var rain_time_left: float = 0.0
var _next_rain: float = 150.0

var generator: WorldGenerator
var world_state: WorldState
var time_manager: TimeManager
var last_reservoir_rate: float = 0.0   # fuer HUD / Smoke-Test


func setup(p_world_state: WorldState, p_generator: WorldGenerator,
		p_time: TimeManager = null) -> void:
	world_state = p_world_state
	generator = p_generator
	time_manager = p_time


func _ready() -> void:
	_next_rain = randf_range(REGEN_MIN_INTERVALL, REGEN_MAX_INTERVALL)


func _process(delta: float) -> void:
	tick(delta)


func _sim_delta(delta: float) -> float:
	return time_manager.scaled_delta(delta) if time_manager != null else delta


func tick(delta: float) -> void:
	# Regen-Event bleibt in ECHTZEIT: auch bei x10 soll der Partikeleffekt
	# 20-60 s sichtbar bleiben (nur die Simulation wird gespult).
	if raining:
		rain_time_left -= delta
		if rain_time_left <= 0.0:
			_stop_rain()
	else:
		_next_rain -= delta
		if _next_rain <= 0.0:
			start_rain(randf_range(REGEN_DAUER_MIN, REGEN_DAUER_MAX))

	var dt := _sim_delta(delta)
	if dt <= 0.0:
		return                      # Pause: keine Entnahme, kein Auffuellen

	last_reservoir_rate = 0.0
	# REVISION 3: Im Winter ruht der Baum. Er darf KEIN Wasser aus den
	# Reservoirs ziehen; auch die Boden-Versickerung ist bei Frost gestoppt.
	# Regen fuellt weiterhin auf (der Niederschlag faellt ja trotzdem).
	var winter := time_manager != null and time_manager.is_winter()
	var soil_factor := Global.difficulty_factor("soil_water")
	for tree in get_tree().get_nodes_in_group("trees"):
		var rate: float = tree.species.base_water_gain * float(tree.root_count) \
			* soil_factor
		if raining:
			rate *= REGEN_FAKTOR * Global.difficulty_factor("rain_boost")
		# REVISION 2: jedes Wurzelsegment im NASSEN Teil entnimmt dem
		# GESAMTEN Becken Wasser (nicht nur seinem eigenen Tile).
		if not winter and world_state != null and generator != null:
			var bonus := 0.0
			for seg in tree.root_segments:
				var gt: Vector2i = seg.global_tile()
				if world_state.is_reservoir(gt.x, gt.y) and not world_state.is_dry(gt.x, gt.y):
					bonus += world_state.consume(gt.x, gt.y, RESERVOIR_GAIN * dt)
			if bonus > 0.0:
				rate += bonus / dt
				last_reservoir_rate += bonus / dt
		tree.absorb_water(dt, rate)

	# Absichtlich NACH der Wurzelentnahme: sonst frisst der Verbrauch den
	# Regen-Zuwachs wieder auf und der Spieler sieht "kein Auffuellen".
	if world_state != null:
		if raining:
			world_state.refill(dt, Global.difficulty_factor("rain_refill"))
		elif not winter:
			world_state.tick_passive(dt)


## Anteil des ausgewaehlten Baums am naechstgelegenen Reservoir (0..1) fuer HUD.
func reservoir_fraction(tree: BaseTree) -> float:
	if tree == null or world_state == null or generator == null:
		return -1.0
	var best := -1.0
	for seg in tree.root_segments:
		var gt: Vector2i = seg.global_tile()
		if world_state.is_reservoir(gt.x, gt.y):
			best = maxf(best, world_state.fill_fraction(gt.x, gt.y))
	return best


func start_rain(duration: float) -> void:
	raining = true
	rain_time_left = maxf(duration, 0.1)
	EventBus.rain_started.emit(rain_time_left)
	EventBus.toast.emit(tr("MSG_RAIN_REFILL"))


func _stop_rain() -> void:
	raining = false
	rain_time_left = 0.0
	_next_rain = randf_range(REGEN_MIN_INTERVALL, REGEN_MAX_INTERVALL)
	EventBus.rain_stopped.emit()


## Dev-Hook (Taste R / CLI / Smoke-Test): Regen sofort ausloesen.
func force_rain(duration: float = 30.0) -> void:
	start_rain(duration)
