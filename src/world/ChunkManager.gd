class_name ChunkManager
extends Node2D
## Laedt/entlaedt horizontale Chunks um die Kamera herum.
## Logik nach GDQuest infinite_space/world_generator.gd: Sektor aus Kamera-X
## ableiten, nur neue Zeilen erzeugen, entfernte Zeilen freigeben.
## Chunks ausserhalb des aktiven Rings werden per process_mode pausiert.
## PHASE 2: besitzt den WorldState (endliche Reservoirs) und gibt ihn weiter.

@export var load_radius: int = 2        # 5 Chunks gleichzeitig sichtbar
@export var active_radius: int = 1      # restliche Chunks: PROCESS_MODE_DISABLED

var generator: WorldGenerator
var world_state: WorldState
var tile_set: TileSet
var camera: Camera2D

var _chunks: Dictionary = {}
var _center_chunk: int = 1 << 30

## KORREKTUR P8.1: Chunks werden im Spielbetrieb in 4-Spalten-Scheiben
## gebaut und pro Frame mit einem Zeit-Budget abgearbeitet. Ein kompletter
## Chunk in EINEM Frame war die Ursache des Rucklers beim schnellen WASD-Pan.
## Headless-Smokes und Screenshot-Presets schalten das ab (synchron).
const SLICE_COLS := 2
const BUILD_BUDGET_USEC := 4000       # 4 ms pro Frame
var _sliced_build: bool = false
var _auto_slice: bool = false
var _jobs: Array[int] = []


func _ready() -> void:
	if generator == null:
		generator = WorldGenerator.new(Global.world_seed)
	if world_state == null:
		world_state = WorldState.new()
		world_state.setup(generator)
	if tile_set == null:
		tile_set = TerrainAtlas.create_tile_set()
	# Kamera erst nach dem Ready aller Geschwister abfragen.
	call_deferred("_initialize")


func setup(p_camera: Camera2D) -> void:
	camera = p_camera


## Nur im echten Spielbetrieb aktiv. Direkte `_refresh()`-Aufrufe der
## Headless-Smokes bleiben damit weiterhin vollstaendig synchron.
func set_sliced_build(value: bool) -> void:
	_sliced_build = value
	if not value:
		_drain_jobs(-1)


func _drain_jobs(budget_usec: int) -> void:
	var started := Time.get_ticks_usec()
	while not _jobs.is_empty():
		var i: int = _jobs[0]
		var chunk := _chunks.get(i, null) as TerrainChunk
		if chunk == null or not is_instance_valid(chunk):
			_jobs.pop_front()
			continue
		if chunk.build_slice(SLICE_COLS):
			_jobs.pop_front()
		if budget_usec >= 0 \
				and Time.get_ticks_usec() - started >= budget_usec:
			return


func _initialize() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		push_error("[ChunkManager] Keine Camera2D im Viewport gefunden.")
		return
	_refresh()
	# KORREKTUR P8.1: die START-Chunks bleiben synchron (keine sichtbaren
	# Loecher beim Start). Erst alle spaeteren Chunks werden gescheitelt.
	if _auto_slice:
		_sliced_build = true


func enable_sliced_build_after_init() -> void:
	_auto_slice = true


func _process(_delta: float) -> void:
	if camera == null:
		return
	var center := int(floor(camera.global_position.x / float(WorldGenerator.CHUNK_WIDTH_PX)))
	if center != _center_chunk:
		_refresh()
	if not _jobs.is_empty():
		_drain_jobs(BUILD_BUDGET_USEC)


func _refresh() -> void:
	if camera == null:
		return
	var center := int(floor(camera.global_position.x / float(WorldGenerator.CHUNK_WIDTH_PX)))
	_center_chunk = center

	# Exakt load_radius*2+1 Chunks (Standard: 5); alles ausserhalb wird
	# freigegeben. Die beiden aeusseren Ringe laufen trotzdem unter
	# PROCESS_MODE_DISABLED, solange sie sichtbar bleiben.
	var keep_min := center - load_radius
	var keep_max := center + load_radius
	for key in _chunks.keys():
		if key < keep_min or key > keep_max:
			var old: Node2D = _chunks[key]
			_chunks.erase(key)
			_jobs.erase(int(key))
			EventBus.chunk_unloaded.emit(key)
			old.queue_free()

	for i in range(center - load_radius, center + load_radius + 1):
		if not _chunks.has(i):
			var chunk := TerrainChunk.new()
			chunk.setup(i, generator, tile_set, world_state, _sliced_build)
			add_child(chunk)
			_chunks[i] = chunk
			EventBus.chunk_loaded.emit(i)
			if _sliced_build:
				_jobs.push_back(i)
		var node: Node2D = _chunks[i]
		node.process_mode = (Node.PROCESS_MODE_INHERIT
			if absi(i - center) <= active_radius
			else Node.PROCESS_MODE_DISABLED)
	if not _sliced_build:
		_drain_jobs(-1)


func loaded_chunk_count() -> int:
	return _chunks.size()


func loaded_chunk_indices() -> Array:
	var keys := _chunks.keys()
	keys.sort()
	return keys


## Oeffentlicher Zugriff fuer Smoke-Tests / Debug (kein Editor-Widget).
func get_chunk(index: int) -> TerrainChunk:
	return _chunks.get(index, null) as TerrainChunk


## Nach dem Laden eines Spielstands die trockenen Reservoirs sichtbar machen.
func refresh_dry_tiles() -> void:
	for key in _chunks.keys():
		var chunk: TerrainChunk = _chunks[key]
		chunk.refresh_reservoirs()


## Nach Save/Load: Tile-Farben UND weiche Konturen an den neuen Pegel anpassen.
func refresh_water_visuals() -> void:
	refresh_dry_tiles()
	EventBus.reservoir_level_changed.emit()


func set_world_seed(p_seed: int) -> void:
	Global.world_seed = p_seed
	generator.set_world_seed(p_seed)
	world_state.setup(generator)     # frische Welt -> alle Reservoirs wieder voll
	for key in _chunks.keys():
		var old: Node2D = _chunks[key]
		_chunks.erase(key)
		# PHASE 3: SeasonSystem muss die Samen des alten Chunks entfernen.
		EventBus.chunk_unloaded.emit(int(key))
		old.queue_free()
	# Bisher blieb _center_chunk stehen: nach Save/Load wurden die Chunks erst
	# beim naechsten Kamera-Wechsel neu erzeugt. Jetzt sofort neu aufbauen.
	_jobs.clear()
	_center_chunk = 1 << 30
	call_deferred("_refresh")
	_center_chunk = 1 << 30
	_refresh()


# --------------------------------------------------------------------------- #
# KORREKTUR P8.1: Debug-Hooks
# --------------------------------------------------------------------------- #
func debug_pending_builds() -> int:
	return _jobs.size()


func debug_finish_builds() -> void:
	_drain_jobs(-1)


func debug_sliced_build() -> bool:
	return _sliced_build


func debug_incomplete_chunks() -> int:
	var n := 0
	for key in _chunks.keys():
		var c := _chunks[key] as TerrainChunk
		if c != null and not c.is_build_complete():
			n += 1
	return n


## Misst die Kosten eines vollstaendigen, synchronen Chunk-Baus in ms.
## Dient als Beleg fuer den Ruckler und den Effekt der Scheitelung.
func debug_bench_build_ms(p_index: int) -> float:
	if generator == null or tile_set == null:
		return -1.0
	var t0 := Time.get_ticks_usec()
	var c := TerrainChunk.new()
	c.setup(p_index, generator, tile_set, world_state, false)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	c.free()
	return ms
