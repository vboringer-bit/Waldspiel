extends Node
## Autoload: globale Einstellungen, Welt-Seed, InputMap-Bootstrap.
## PHASE 1: Der Welt-Seed wird bei JEDEM Neustart neu gewuerfelt (User-Wunsch).
## Ueber --seed=<int> / --phase1-seed=<int> laesst er sich fuer Tests,
## Screenshots und Save/Load reproduzierbar setzen. Gleiche Seed = gleiche Welt.

enum Difficulty { LEICHT, NORMAL, SCHWER }

const SAVE_PATH := "user://savegame.json"
const TILE_SIZE := 16
const CHUNK_WIDTH_PX := 2048
const WORLD_DEPTH_PX := 1080

@export var world_seed: int = 0
var seed_is_random: bool = false
var difficulty: Difficulty = Difficulty.NORMAL
## PHASE 3: Schwierigkeit ist VOR Spielstart waehlbar (StartMenu) und danach
## jederzeit im HUD. --difficulty=... setzt sie fuer Tests/Screenshots.
var difficulty_chosen: bool = false
var auto_mode: bool = true
var locale: String = "de":
	set(value):
		locale = value
		TranslationServer.set_locale(locale)
		EventBus.locale_changed.emit(locale)


func _ready() -> void:
	_setup_input_map()
	_setup_localization()
	_resolve_seed()
	_resolve_difficulty()
	TranslationServer.set_locale(locale)
	print("[Global] seed=%d (%s) | difficulty=%s | auto=%s | Godot %s" % [
		world_seed,
		"Zufall" if seed_is_random else "CLI/Save",
		Difficulty.keys()[difficulty],
		"ON" if auto_mode else "OFF",
		Engine.get_version_info()["string"],
	])


## Zufalls-Seed pro Prozessstart; CLI-Override hat Vorrang.
func _resolve_seed() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--seed=") or arg.begins_with("--phase1-seed="):
			var raw := arg.split("=", true, 1)[1]
			if raw.is_valid_int():
				world_seed = int(raw)
				seed_is_random = false
				return
	# Globalen RNG mit Zeit + Mikrosekunden neu seeden => bei jedem Start anders.
	seed(int(Time.get_unix_time_from_system() * 1000.0) + Time.get_ticks_usec())
	world_seed = randi_range(1, 2147483646)
	seed_is_random = true


## PHASE 3: alle Schwierigkeits-Modifikatoren an EINEM Ort. NORMAL ist
## bewusst die Referenz (1.0), damit P0/P1/P2-Smokes unveraendert bleiben.
## pH-Wert / N-P-K / Mykorrhiza / Katastrophen gehoeren laut Master-Punkt 4.2
## zur "vollen Simulation", sind aber PHASE 5 vorbehalten (siehe DECISIONS).
func difficulty_factor(key: String) -> float:
	match difficulty:
		Difficulty.LEICHT:
			match key:
				"photosynthesis": return 1.50
				"soil_water": return 2.00
				"rain_boost": return 1.20
				"rain_refill": return 1.30
				"growth_cost": return 0.80
				"water_consumption": return 0.70
				"acorn_chance": return 1.50
				"germination": return 1.40
				"seed_density": return 1.45
				"disaster_rate": return 0.00
				"soil_complexity": return 0.00
		Difficulty.SCHWER:
			match key:
				"photosynthesis": return 0.70
				"soil_water": return 0.60
				"rain_boost": return 0.80
				"rain_refill": return 0.80
				"growth_cost": return 1.35
				"water_consumption": return 1.40
				"acorn_chance": return 0.60
				"germination": return 0.60
				"seed_density": return 0.70
				"disaster_rate": return 2.00
				"soil_complexity": return 1.00
	if key == "disaster_rate":
		return 0.35
	if key == "soil_complexity":
		return 0.50
	return 1.0


## PHASE 3 legt die Schalter bereits fest; die eigentliche Simulation von
## pH-Wert / N-P-K / Mykorrhiza / Duerrre-Sturm-Borkenkaefer folgt in PHASE 5.
## LEICHT: keine Katastrophen, kein pH. NORMAL: seltene Stuerme/Parasiten.
## SCHWER: volle Simulation (alle Schalter an).
func difficulty_toggle(key: String) -> bool:
	match difficulty:
		Difficulty.LEICHT:
			return false
		Difficulty.NORMAL:
			return key == "disasters" or key == "parasites"
		Difficulty.SCHWER:
			return true
	return false


func difficulty_name_key() -> String:
	match difficulty:
		Difficulty.LEICHT: return "DIFFICULTY_EASY"
		Difficulty.SCHWER: return "DIFFICULTY_HARD"
	return "DIFFICULTY_NORMAL"


func set_difficulty(value: int) -> void:
	difficulty = value
	difficulty_chosen = true
	EventBus.difficulty_changed.emit(int(value))


func difficulty_from_name(name: String) -> Difficulty:
	var n := name.to_lower()
	if n == "leicht" or n == "easy" or n == "0":
		return Difficulty.LEICHT
	if n == "schwer" or n == "hard" or n == "2":
		return Difficulty.SCHWER
	return Difficulty.NORMAL


func _resolve_difficulty() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--difficulty="):
			difficulty = difficulty_from_name(arg.split("=", true, 1)[1])
			difficulty_chosen = true
			return


func set_seed_from_save(p_seed: int) -> void:
	world_seed = p_seed
	seed_is_random = false


## Input-Actions werden zur Laufzeit registriert statt in project.godot.
func _setup_input_map() -> void:
	_add_key_action("pan_left", KEY_A)
	_add_key_action("pan_right", KEY_D)
	_add_key_action("pan_up", KEY_W)
	_add_key_action("pan_down", KEY_S)


func _add_key_action(action: String, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


## Liest res://data/localization.csv zur Laufzeit und registriert DE/EN am
## TranslationServer. So funktioniert tr() ohne importierte .translation-Dateien.
func _setup_localization() -> void:
	const CSV_PATH := "res://data/localization.csv"
	if not FileAccess.file_exists(CSV_PATH):
		push_warning("[Global] localization.csv fehlt.")
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var header := file.get_csv_line()
	if header.size() < 3:
		return
	var de := Translation.new()
	de.locale = "de"
	var en := Translation.new()
	en.locale = "en"
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		de.add_message(row[0], row[1].replace("\\n", "\n"))
		en.add_message(row[0], row[2].replace("\\n", "\n"))
	TranslationServer.add_translation(de)
	TranslationServer.add_translation(en)
