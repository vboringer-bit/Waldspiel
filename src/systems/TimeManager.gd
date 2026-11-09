class_name TimeManager
extends Node
## PHASE 3: Jahreszeiten, Zeitspulen und Pause (Master-Punkt 5).
##
##   1 Spiel-Jahr = 900 Echtzeit-Sekunden (15 Minuten), konfigurierbar ueber
##   `year_length_seconds`. Vier gleich lange Jahreszeiten a 225 s.
##   KEIN Tag/Nacht-Wechsel (User-Wunsch) — `sunlight_factor` ist immer der
##   jahreszeitliche Tageswert.
##
##   Alles Simulierte benutzt `scaled_delta(delta) = delta * time_scale`
##   (bzw. 0 bei Pause): GrowthSystem, WaterSystem, SeasonSystem und
##   Baumbalter. Regen-Partikel und Tweens bleiben bewusst in Echtzeit, damit
##   der Effekt bei x10 nicht in 2 Sekunden vorbei ist (siehe DECISIONS).
##
##   Die Zeitskala ist 1 / 3 / 10; Pause per Leertaste oder HUD-Button.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
const SCALES := [1.0, 3.0, 10.0]
const SEASON_COUNT := 4

@export var year_length_seconds: float = 900.0   # 15 Minuten / Jahr

var year: int = 1
var season: int = Season.SPRING
var time_scale: float = 1.0
var paused: bool = false

## Summe aller simulierten Sekunden seit Spielstart (auch fuer Saves).
var total_elapsed: float = 0.0
var _season_elapsed: float = 0.0


func _ready() -> void:
	add_to_group("time_manager")


func _process(delta: float) -> void:
	advance(delta * time_scale if not paused else 0.0)


## Simulationszeit vorschieben (schon skaliert). Wird auch von Debug-Hooks
## und Smoke-Tests direkt benutzt.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	total_elapsed += seconds
	_season_elapsed += seconds
	var season_len := season_length()
	var guard := 0
	while _season_elapsed >= season_len and guard < 64:
		_season_elapsed -= season_len
		season += 1
		if season >= SEASON_COUNT:
			season = Season.SPRING
			year += 1
		EventBus.season_changed.emit(year, season)
		guard += 1


func season_length() -> float:
	return maxf(year_length_seconds / float(SEASON_COUNT), 1.0)


func season_progress() -> float:
	return clampf(_season_elapsed / season_length(), 0.0, 1.0)


## Faktor, mit dem alle simulierten Systeme laufen. Bei Pause = 0.
func scaled_delta(delta: float) -> float:
	return 0.0 if paused else delta * time_scale


# --------------------------------------------------------------------------- #
# Klima (Master-Punkt 5)
# --------------------------------------------------------------------------- #
func season_name_key() -> String:
	match season:
		Season.SUMMER: return "SEASON_SUMMER"
		Season.AUTUMN: return "SEASON_AUTUMN"
		Season.WINTER: return "SEASON_WINTER"
	return "SEASON_SPRING"


func season_name() -> String:
	return tr(season_name_key())


## Fruehling = Wachstumsboost, Sommer = normal, Herbst = langsamer,
## Winter = Wachstum stoppt. Wird als Multiplikator auf Fotosynthese und
## AUTO-Kauf verwendet (0 => keine Glucose, kein Wachstum).
func growth_factor() -> float:
	match season:
		Season.SPRING: return 1.35
		Season.SUMMER: return 1.00
		Season.AUTUMN: return 0.80
	return 0.0


func sunlight_factor() -> float:
	match season:
		Season.SPRING: return 1.25
		Season.SUMMER: return 1.00
		Season.AUTUMN: return 0.70
	return 0.0                       # kahle Baeume / Winterruhe


func is_winter() -> bool:
	return season == Season.WINTER


func is_autumn() -> bool:
	return season == Season.AUTUMN


func get_label() -> String:
	var suffix := ""
	if paused:
		suffix = " · " + tr("UI_PAUSE")
	elif not is_equal_approx(time_scale, 1.0):
		suffix = " · x%d" % int(time_scale)
	return "%s %d · %s%s" % [tr("HUD_YEAR"), year, season_name(), suffix]


# --------------------------------------------------------------------------- #
# Zeitspulen / Pause
# --------------------------------------------------------------------------- #
func set_time_scale(value: float) -> void:
	var best := SCALES[0]
	for s in SCALES:
		if absf(float(s) - value) < absf(best - value):
			best = float(s)
	time_scale = best
	paused = false
	EventBus.time_scale_changed.emit(time_scale, paused)


func toggle_pause() -> void:
	paused = not paused
	EventBus.time_scale_changed.emit(time_scale, paused)


func set_paused(value: bool) -> void:
	paused = value
	EventBus.time_scale_changed.emit(time_scale, paused)


# --------------------------------------------------------------------------- #
# Save / Load (Format v4) und Debug
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	return {
		"year": year, "season": season, "total_elapsed": total_elapsed,
		"season_elapsed": _season_elapsed, "time_scale": time_scale,
		"paused": paused,
	}


func from_dict(d: Dictionary) -> void:
	year = maxi(int(d.get("year", 1)), 1)
	season = clampi(int(d.get("season", Season.SPRING)), 0, SEASON_COUNT - 1)
	total_elapsed = maxf(float(d.get("total_elapsed", 0.0)), 0.0)
	_season_elapsed = clampf(float(d.get("season_elapsed", 0.0)),
		0.0, season_length() - 0.001)
	time_scale = float(d.get("time_scale", 1.0))
	paused = bool(d.get("paused", false))
	EventBus.season_changed.emit(year, season)
	EventBus.time_scale_changed.emit(time_scale, paused)


## Screenshot-/Test-Hook: direkt in eine Jahreszeit springen.
func debug_set_season(p_season: int, p_year: int = 1,
		p_progress: float = 0.0) -> void:
	season = clampi(p_season, 0, SEASON_COUNT - 1)
	year = maxi(p_year, 1)
	_season_elapsed = clampf(p_progress, 0.0, 0.999) * season_length()
	EventBus.season_changed.emit(year, season)


## Simulationssekunden ohne Echtzeit warten (deterministisch).
func debug_advance(seconds: float) -> void:
	advance(seconds)
