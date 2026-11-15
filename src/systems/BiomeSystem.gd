class_name BiomeSystem
extends Node
## PHASE 7 (Master 3.1): die drei Welt-Biome als laufendes System.
##
## `WorldGenerator` liefert die reine, seed-deterministische Geografie.
## Dieses System verfolgt die Kamera WELTWEIT (kein Viewport-Bezug), meldet
## Biom-Wechsel ueber den EventBus, zaehlt Entdeckungen/Besuche, stoesst
## Toasts an und schreibt einen optionalen "biomes"-Key ins Save v6.
##
## Der temperierte Startkern |x| <= 2048 px bleibt in allen Faktoren exakt
## 1.0 / blend 0.0 -> saemtliche R0-R8- und P6-Regressionen bleiben gruen.

static var instance: BiomeSystem

var generator: WorldGenerator = null
var camera: Camera2D = null

var current_kind: int = WorldGenerator.BiomeKind.TEMPERIERT
var current_blend: float = 0.0
var current_x: float = 0.0
var visit_count: int = 0
## String(kind) -> true. String-Keys, damit to_dict() JSON-sicher ist.
var discovered: Dictionary = {}

var _acc: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	EventBus.game_loaded.connect(_on_game_loaded)
	_update_at(0.0, false)


func setup(p_generator: WorldGenerator, p_camera: Camera2D) -> void:
	generator = p_generator
	camera = p_camera
	_update_at(camera.global_position.x if camera != null else 0.0, false)


func _on_game_loaded() -> void:
	# SaveManager hat from_dict() schon ausgefuehrt; nur Anzeige auffrischen.
	EventBus.biome_changed.emit(current_kind, current_blend)


func _process(delta: float) -> void:
	# 10 Hz reichen: Biom-Blenden aendern sich nur beim Kamera-Pan.
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	if camera != null:
		_update_at(camera.global_position.x, true)


func _update_at(world_x: float, notify: bool) -> void:
	if generator == null:
		return
	current_x = world_x
	var kind := int(generator.biome_at(world_x))
	var blend := generator.biome_blend_at(world_x)
	var kind_changed := kind != current_kind
	var blend_changed := absf(blend - current_blend) > 0.02
	current_kind = kind
	current_blend = blend
	var key := str(kind)
	var first := not discovered.has(key)
	if first:
		discovered[key] = true
	if kind_changed:
		visit_count += 1
	if kind_changed or blend_changed or first:
		EventBus.biome_changed.emit(kind, blend)
	if first:
		EventBus.biome_discovered.emit(kind)
		if notify:
			EventBus.toast.emit(tr("MSG_BIOME_DISCOVERED") % [
				generator.biome_label(world_x)])
	elif notify and kind_changed:
		EventBus.toast.emit(tr(_toast_key(kind)))


func _toast_key(kind: int) -> String:
	match kind:
		WorldGenerator.BiomeKind.TROCKEN: return "MSG_BIOME_DRY"
		WorldGenerator.BiomeKind.FEUCHT: return "MSG_BIOME_WET"
	return "MSG_BIOME_TEMPERATE"


func kind_name_key(kind: int) -> String:
	match kind:
		WorldGenerator.BiomeKind.TROCKEN: return "BIOME_TROCKEN"
		WorldGenerator.BiomeKind.FEUCHT: return "BIOME_FEUCHT"
	return "BIOME_TEMPERIERT"


func kind_label(kind: int) -> String:
	return TranslationServer.translate(kind_name_key(kind))


## Anzeigezeile des HUD. Im Uebergang wird das ZIEL-Biom mit Prozent genannt.
func display_text() -> String:
	if generator == null:
		return ""
	var name := kind_label(current_kind)
	var target := int(generator.biome_target_at(current_x))
	if current_blend > 0.01 and target != current_kind:
		return tr("BIOME_TRANSITION") % [name,
			kind_label(target), int(roundf(current_blend * 100.0))]
	return tr("HUD_BIOME") % [name,
		int(roundf(generator.biome_moisture_at(current_x) * 100.0))]


func reset() -> void:
	current_kind = WorldGenerator.BiomeKind.TEMPERIERT
	current_blend = 0.0
	current_x = 0.0
	visit_count = 0
	discovered.clear()
	_acc = 0.0
	_update_at(0.0, false)


func to_dict() -> Dictionary:
	return {
		"discovered": discovered.keys(),
		"visits": visit_count,
		"last": current_kind,
		"x": current_x,
	}


func from_dict(d: Dictionary) -> void:
	discovered.clear()
	for k in d.get("discovered", []):
		discovered[str(k)] = true
	visit_count = int(d.get("visits", 0))
	current_kind = int(d.get("last", WorldGenerator.BiomeKind.TEMPERIERT))
	current_x = float(d.get("x", 0.0))
	current_blend = 0.0
	_event_refresh()


func _event_refresh() -> void:
	EventBus.biome_changed.emit(current_kind, current_blend)


# --------------------------------------------------------------------------- #
# PHASE-7-Debug-Hooks (Smoke + Presets)
# --------------------------------------------------------------------------- #
func debug_force_at(world_x: float) -> void:
	_update_at(world_x, true)


func debug_kind() -> int:
	return current_kind


func debug_blend() -> float:
	return current_blend


func debug_x() -> float:
	return current_x


func debug_discovered() -> int:
	return discovered.size()


func debug_has_discovered(kind: int) -> bool:
	return discovered.has(str(kind))


func debug_visits() -> int:
	return visit_count


func debug_moisture_at(world_x: float) -> float:
	return generator.biome_moisture_at(world_x) if generator != null else 0.5


func debug_label_at(world_x: float) -> String:
	return generator.biome_label(world_x) if generator != null else ""


func debug_display() -> String:
	return display_text()
