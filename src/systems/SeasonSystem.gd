class_name SeasonSystem
extends Node
## PHASE 3: Samen finden / vergraben + Herbst-Eichelfall (Master-Punkt 7).
##
## * `WorldGenerator.ground_seeds_for_chunk()` liefert eine seed-deterministische,
##   per Noise verteilte Kandidatenliste. `SeasonSystem` erzeugt daraus pro
##   geladenem Chunk Sprites: frei liegende Eicheln (anklickbar) und flach
##   vergrabene Eicheln (kleiner Huegel, NUR mit einer Wurzel erreichbar).
## * Bereits eingesammelte IDs werden gemerkt (und in Savegame v4 gespeichert),
##   damit sie nach einem Chunk-Reload nicht wieder auftauchen.
## * Im Herbst werfen Baeume Eicheln ab ("fallen unter Krone"). Manche keimen,
##   wenn Wasser + Licht stimmen. Wahrscheinlichkeit haengt am Baumalter, am
##   Schwierigkeitsgrad und am reservierten Skill "Verbreitung" (PHASE 4).
## * Alles benutzt TimeManager.scaled_delta (x1/x3/x10 + Pause).

const ACORN_PATH := "res://assets/placeholders/acorn.png"
const MOUND_PATH := "res://assets/placeholders/seed_mound.png"
const HIT_SIZE := Vector2(32.0, 32.0)
const DROP_INTERVAL := 12.0            # simulierte Sekunden
const DROP_CHANCE := 0.55              # pro Baum und Intervall (bei Reife)
const GERMINATION_CHANCE := 0.22
const MATURE_AGE_YEARS := 3.0          # Master: "z.B. 3 Spiel-Jahre"
const MAX_DROPS_PER_AUTUMN := 14
const MAX_TREES := 100
## REVISION 4: Statt 2 Eicheln IM INVENTAR liegen genau 2 Eicheln AUF DEM
## BODEN. Sie liegen links und rechts der Startposition gut sichtbar im
## Startbild und werden wie bisher mit einem Linksklick eingesammelt.
const STARTER_WORLD_X := [-224.0, 288.0]
## In der Start-Zone werden die zufaelligen Noise-Samen unterdrueckt, damit
## beim Spielstart exakt diese zwei Eicheln sichtbar sind. Alle weiteren
## Chunks behalten das P3-System "Samen finden / vergraben".
const START_ZONE := [-1, 0, 1]

var chunk_manager: ChunkManager
var generator: WorldGenerator
var trees_root: Node2D
var camera: CameraController
var time_manager: TimeManager
var interaction: InteractionController

var seed_layer: Node2D
## id -> {id, chunk, x, y, gx, ty, buried, roll, dropped, node}
var seeds: Dictionary = {}
var collected: Dictionary = {}
var spread_bonus: float = 0.0          # PHASE 4: Skill "Verbreitung"
var debug_no_germination: bool = false # Smoke-Test: Eicheln bleiben liegen

var _rng := RandomNumberGenerator.new()
var _drop_timer := 0.0
var _buried_timer := 0.0
var _drops_this_autumn := 0
var _drop_counter := 0
var _falling: Array[Dictionary] = []


func setup(p_chunks: ChunkManager, p_trees: Node2D, p_camera: CameraController,
		p_time: TimeManager, p_interaction: InteractionController) -> void:
	chunk_manager = p_chunks
	generator = p_chunks.generator
	trees_root = p_trees
	camera = p_camera
	time_manager = p_time
	interaction = p_interaction
	_rng.seed = (Global.world_seed ^ 0x5eed) & 0x7fffffff

	if seed_layer == null:
		seed_layer = Node2D.new()
		seed_layer.name = "GroundSeeds"
		seed_layer.z_index = 4
		trees_root.get_parent().add_child(seed_layer)
	_connect()
	_sync_skills()
	_refresh_all_loaded()


func _connect() -> void:
	if not EventBus.chunk_loaded.is_connected(_on_chunk_loaded):
		EventBus.chunk_loaded.connect(_on_chunk_loaded)
	if not EventBus.chunk_unloaded.is_connected(_on_chunk_unloaded):
		EventBus.chunk_unloaded.connect(_on_chunk_unloaded)
	if not EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.connect(_on_season_changed)
	if not EventBus.difficulty_changed.is_connected(_on_difficulty_changed):
		EventBus.difficulty_changed.connect(_on_difficulty_changed)
	if not EventBus.root_grown.is_connected(_on_root_grown):
		EventBus.root_grown.connect(_on_root_grown)
	if not EventBus.skilltree_changed.is_connected(_sync_skills):
		EventBus.skilltree_changed.connect(_sync_skills)


func _ready() -> void:
	_connect()


func _process(delta: float) -> void:
	if generator == null or time_manager == null:
		return
	var dt := time_manager.scaled_delta(delta)
	if dt <= 0.0:
		return
	_buried_timer += dt
	if _buried_timer >= 0.5:
		_buried_timer = 0.0
		_check_buried()
	if time_manager.is_autumn():
		_drop_timer += dt
		if _drop_timer >= DROP_INTERVAL:
			_drop_timer = 0.0
			_autumn_drops()


# --------------------------------------------------------------------------- #
# Samen auf dem Boden / vergraben
# --------------------------------------------------------------------------- #
func density_threshold() -> float:
	return clampf(0.55 * Global.difficulty_factor("seed_density"), 0.10, 0.95)


func _refresh_all_loaded() -> void:
	if chunk_manager == null:
		return
	for idx in chunk_manager.loaded_chunk_indices():
		_spawn_chunk(int(idx))


func _on_chunk_loaded(index: int) -> void:
	if generator == null:
		return
	_spawn_chunk(index)


func _on_chunk_unloaded(index: int) -> void:
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if int(e.get("chunk", 0)) == index and not bool(e.get("dropped", false)):
			_remove_seed(String(id))


func _spawn_chunk(index: int) -> void:
	# REVISION 4: Start-Zone = exakt 2 frei liegende, anklickbare Eicheln.
	if START_ZONE.has(index):
		if index == 0:
			for entry in _starter_entries():
				_spawn_seed(entry)
		return
	for entry in generator.ground_seeds_for_chunk(index):
		_spawn_seed(entry)


## Zwei feste, seed-unabhaengige Start-Eicheln auf der fliessenden Oberkante.
func _starter_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in STARTER_WORLD_X.size():
		var wx := float(STARTER_WORLD_X[i])
		var sy := roundf(generator.height_smooth_at(wx) / 4.0) * 4.0
		out.append({
			"id": "starter:%d" % i,
			"chunk": 0,
			"x": wx,
			"y": sy,
			"gx": int(floor(wx / float(WorldGenerator.TILE_SIZE))),
			"ty": generator.surface_tile_y_at(wx) + 2,
			"buried": false,
			"roll": 0.0,
			"dropped": false,
			"starter": true,
		})
	return out


func _spawn_seed(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	if id.is_empty() or seeds.has(id) or collected.has(id):
		return
	if float(entry.get("roll", 0.0)) > density_threshold():
		return
	_spawn_seed_node(entry)


func _spawn_seed_node(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	var buried := bool(entry.get("buried", false))
	var sprite := Sprite2D.new()
	sprite.name = "Samen_" + id.replace(":", "_")
	sprite.texture = load(MOUND_PATH if buried else ACORN_PATH)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Generator-X ist CHUNK-LOKAL; der Sprite lebt aber in Welt-Koordinaten.
	var wx := float(entry.get("chunk", 0)) * WorldGenerator.CHUNK_WIDTH_PX \
		+ float(entry.get("x", 0.0))
	sprite.position = Vector2(wx, float(entry.get("y", 0.0)) - 16.0)
	seed_layer.add_child(sprite)
	var e := entry.duplicate()
	e["wx"] = wx
	e["node"] = sprite
	seeds[id] = e


func _remove_seed(id: String) -> void:
	if not seeds.has(id):
		return
	var e: Dictionary = seeds[id]
	var n: Node = e.get("node", null)
	if n != null and is_instance_valid(n):
		n.queue_free()
	seeds.erase(id)


func _hit_rect(e: Dictionary) -> Rect2:
	return Rect2(Vector2(float(e.get("wx", 0.0)) - 8.0,
		float(e.get("y", 0.0)) - 24.0), HIT_SIZE)


## Linksklick: frei liegende Eichel einsammeln. Liefert true bei Treffer.
func collect_at(world_pos: Vector2) -> bool:
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if bool(e.get("buried", false)):
			continue
		if _hit_rect(e).has_point(world_pos):
			_collect(String(id))
			return true
	return false


func has_buried_at(world_pos: Vector2) -> bool:
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if bool(e.get("buried", false)) and _hit_rect(e).has_point(world_pos):
			return true
	return false


func _collect(id: String) -> void:
	if collected.has(id) or not seeds.has(id):
		return
	var e: Dictionary = seeds[id]
	var buried := bool(e.get("buried", false))
	collected[id] = true
	_remove_seed(id)
	if interaction != null:
		interaction.set_seed_count(interaction.get_seed_count() + 1)
	EventBus.seed_collected.emit("Eiche")
	EventBus.seed_found.emit(id, buried)
	EventBus.toast.emit(tr("MSG_SEED_DUG_UP") if buried else tr("MSG_SEED_FOUND"))


## Vergrabene Eicheln werden frei, sobald eine Wurzel ihr Tile erreicht.
func _check_buried() -> void:
	var pending: Array[String] = []
	for id in seeds.keys():
		if bool(seeds[id].get("buried", false)):
			pending.append(String(id))
	if pending.is_empty():
		return
	for tree in get_tree().get_nodes_in_group("trees"):
		for seg in tree.root_segments:
			var gt: Vector2i = seg.global_tile()
			for id in pending:
				if not seeds.has(id):
					continue
				var e: Dictionary = seeds[id]
				if absi(gt.x - int(e.get("gx", 0))) <= 1 \
						and absi(gt.y - int(e.get("ty", 0))) <= 1:
					_collect(id)


func _on_root_grown(_tree: Node, _tile: Vector2i, _cost: float) -> void:
	_check_buried()


# --------------------------------------------------------------------------- #
# Herbst: Eicheln fallen unter den Kronen (Master-Punkt 7)
# --------------------------------------------------------------------------- #
func _on_season_changed(_year: int, season: int) -> void:
	_drop_timer = 0.0
	if season == TimeManager.Season.AUTUMN:
		_drops_this_autumn = 0
	if season == TimeManager.Season.AUTUMN:
		EventBus.toast.emit(tr("MSG_AUTUMN_DROP"))
	else:
		EventBus.toast.emit(tr("MSG_SEASON_CHANGED") % _season_name(season))


func _season_name(season: int) -> String:
	match season:
		TimeManager.Season.SUMMER: return tr("SEASON_SUMMER")
		TimeManager.Season.AUTUMN: return tr("SEASON_AUTUMN")
		TimeManager.Season.WINTER: return tr("SEASON_WINTER")
	return tr("SEASON_SPRING")


func debug_maturity(years: float) -> float:
	return clampf(years / MATURE_AGE_YEARS, 0.0, 1.0)


func _autumn_drops() -> void:
	if _drops_this_autumn >= MAX_DROPS_PER_AUTUMN:
		return
	var trees := get_tree().get_nodes_in_group("trees")
	if trees.is_empty():
		return
	var year_len := maxf(time_manager.year_length_seconds, 1.0)
	for tree in trees:
		var age_years := float(tree.age) / year_len
		var maturity := clampf(age_years / MATURE_AGE_YEARS, 0.0, 1.0)
		var chance := DROP_CHANCE * (0.20 + 0.80 * maturity) \
			* Global.difficulty_factor("acorn_chance") * (1.0 + spread_bonus)
		if _rng.randf() > chance:
			continue
		_drops_this_autumn += 1
		spawn_falling_acorn(tree.global_position.x
			+ _rng.randf_range(-40.0, 40.0), tree.global_position.y - 48.0)
		if _drops_this_autumn >= MAX_DROPS_PER_AUTUMN:
			break


func spawn_falling_acorn(world_x: float, from_y: float,
		instant: bool = false) -> void:
	var ground_y := generator.height_smooth_at(world_x)
	var sprite := Sprite2D.new()
	sprite.texture = load(ACORN_PATH)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(world_x, from_y)
	seed_layer.add_child(sprite)
	_drop_counter += 1
	var rec := {"sprite": sprite, "x": world_x, "ground_y": ground_y}
	_falling.append(rec)
	if instant:
		_land(rec)
		return
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", ground_y - 16.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land.bind(rec))


func _land(rec: Dictionary) -> void:
	_falling.erase(rec)
	var sprite: Sprite2D = rec.get("sprite", null)
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	var x := float(rec.get("x", 0.0))
	var ground_y := float(rec.get("ground_y", 0.0))
	EventBus.acorn_dropped.emit(Vector2(x, ground_y))

	var sunlight := time_manager.sunlight_factor() if time_manager != null else 1.0
	var chance := GERMINATION_CHANCE * Global.difficulty_factor("germination") \
		* (1.0 + spread_bonus)
	var can_germinate := (sunlight > 0.4
		and (time_manager == null or not time_manager.is_winter())
		and get_tree().get_nodes_in_group("trees").size() < MAX_TREES)
	if can_germinate and not debug_no_germination and _rng.randf() < chance:
		interaction.spawn_tree_at(Vector2(x, ground_y), {})
		return
	# Sonst bleibt die Eichel als einsammelbares Boden-Item liegen.
	var chunk_idx := int(floor(x / float(WorldGenerator.CHUNK_WIDTH_PX)))
	var id := "drop:%d" % _drop_counter
	var entry := {
		"id": id, "chunk": chunk_idx,
		"x": x - float(chunk_idx * WorldGenerator.CHUNK_WIDTH_PX),
		"y": ground_y,
		"gx": int(floor(x / 16.0)), "ty": generator.surface_tile_y_at(x) + 2,
		"buried": false, "roll": 0.0, "dropped": true,
	}
	if not collected.has(id):
		_spawn_seed_node(entry)


# --------------------------------------------------------------------------- #
# Schwierigkeit / Save / Debug
# --------------------------------------------------------------------------- #
func _on_difficulty_changed(_value: int) -> void:
	# Dichte neu auswerten, ohne bereits eingesammelte Samen zurueckzubringen.
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if not bool(e.get("dropped", false)):
			_remove_seed(String(id))
	_refresh_all_loaded()


func set_spread_bonus(value: float) -> void:
	spread_bonus = maxf(value, 0.0)     # PHASE 4: Skill "Verbreitung"


## PHASE 4: der globale Skilltree treibt den reservierten "Verbreitung"-
## Anschluss. Greift auch nach Save/Load und beim Freischalten.
func _sync_skills() -> void:
	var st := SkillTree.instance
	set_spread_bonus(st.bonus("spread") if st != null else 0.0)


func to_dict() -> Dictionary:
	var ids: Array = []
	for id in collected.keys():
		ids.append(String(id))
	return {"collected": ids, "drop_counter": _drop_counter}


func from_dict(d: Dictionary) -> void:
	collected.clear()
	for id in d.get("collected", []):
		collected[String(id)] = true
	_drop_counter = int(d.get("drop_counter", 0))
	for id in seeds.keys():
		_remove_seed(String(id))
	_refresh_all_loaded()


func debug_is_collected(id: String) -> bool:
	return collected.has(id)


func debug_seed_position(id: String) -> Vector2:
	if seeds.has(id):
		var e: Dictionary = seeds[id]
		return Vector2(float(e.get("wx", 0.0)), float(e.get("y", 0.0)))
	return Vector2(-9999.0, -9999.0)


## REVISION 4: Anzahl / Positionen der beiden Start-Eicheln (Smoke-Test).
func debug_starter_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if bool(e.get("starter", false)):
			out.append(Vector2(float(e.get("wx", 0.0)), float(e.get("y", 0.0))))
	return out


func debug_ground_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if not bool(e.get("buried", false)):
			out.append(Vector2(float(e.get("wx", 0.0)), float(e.get("y", 0.0))))
	return out


func debug_ground_seed_count() -> int:
	var n := 0
	for id in seeds.keys():
		if not bool(seeds[id].get("buried", false)):
			n += 1
	return n


func debug_buried_seed_count() -> int:
	var n := 0
	for id in seeds.keys():
		if bool(seeds[id].get("buried", false)):
			n += 1
	return n


func debug_collected_count() -> int:
	return collected.size()


func debug_first_ground_position() -> Vector2:
	for id in seeds.keys():
		var e: Dictionary = seeds[id]
		if not bool(e.get("buried", false)):
			return Vector2(float(e.get("wx", 0.0)), float(e.get("y", 0.0)))
	return Vector2(-9999.0, -9999.0)


## Deterministisch einen Samen an einer festen Weltposition anlegen.
func debug_spawn_seed_at(world_x: float, buried: bool) -> String:
	var chunk_idx := int(floor(world_x / float(WorldGenerator.CHUNK_WIDTH_PX)))
	_drop_counter += 1
	var id := "dbg:%d" % _drop_counter
	var lx := world_x - float(chunk_idx * WorldGenerator.CHUNK_WIDTH_PX)
	var entry := {
		"id": id, "chunk": chunk_idx, "x": lx,
		"y": generator.height_smooth_at(world_x),
		"gx": int(floor(world_x / 16.0)),
		"ty": generator.surface_tile_y_at(world_x) + 2,
		"buried": buried, "roll": 0.0, "dropped": true,
	}
	_spawn_seed_node(entry)
	return id


## Herbstfall ohne Warterei (Screenshots / Smoke-Test).
func debug_drop_acorns(count: int, instant: bool = true) -> void:
	var trees := get_tree().get_nodes_in_group("trees")
	for i in count:
		var x := 0.0
		var y := 280.0
		if not trees.is_empty():
			var t: BaseTree = trees[i % trees.size()]
			x = t.global_position.x + float(i * 26 - count * 13)
			y = t.global_position.y - 48.0
		spawn_falling_acorn(x, y, instant)


func debug_force_buried_collection() -> int:
	var before := collected.size()
	_check_buried()
	return collected.size() - before
