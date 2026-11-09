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


func _initialize() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		push_error("[ChunkManager] Keine Camera2D im Viewport gefunden.")
		return
	_refresh()


func _process(_delta: float) -> void:
	if camera == null:
		return
	var center := int(floor(camera.global_position.x / float(WorldGenerator.CHUNK_WIDTH_PX)))
	if center != _center_chunk:
		_refresh()


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
			EventBus.chunk_unloaded.emit(key)
			old.queue_free()

	for i in range(center - load_radius, center + load_radius + 1):
		if not _chunks.has(i):
			var chunk := TerrainChunk.new()
			chunk.setup(i, generator, tile_set, world_state)
			add_child(chunk)
			_chunks[i] = chunk
			EventBus.chunk_loaded.emit(i)
		var node: Node2D = _chunks[i]
		node.process_mode = (Node.PROCESS_MODE_INHERIT
			if absi(i - center) <= active_radius
			else Node.PROCESS_MODE_DISABLED)


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
	_center_chunk = 1 << 30
	call_deferred("_refresh")
	_center_chunk = 1 << 30
	_refresh()
