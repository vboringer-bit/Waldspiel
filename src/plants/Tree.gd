class_name BaseTree
extends Node2D
## Basis-Klasse fuer alle Baeume (Dateiname Tree.gd laut Master-Punkt 9).
## Der class_name heisst BaseTree, weil Godot bereits eine native Control-Klasse
## "Tree" hat (sonst: "member shadows a native class").
##
## PHASE 1: Instanzwerte, Fotosynthese, einfache Wachstumszaehler.
## PHASE 2: echte Wurzel-Segmente auf dem 16px-Raster mit RootTip-Knoten,
## art-spezifischer Richtung (Oak.gd), Bodenhärte und Reservoir-Kontakt.

const TRUNK_PATH := "res://assets/placeholders/trunk.png"
const LEAF_PATH := "res://assets/placeholders/leaf.png"
const ROOT_PATH := "res://assets/placeholders/root.png"
const MAX_LEAVES := 12
const MAX_ROOTS := 32          # PHASE 2: tiefere Pfahlwurzel bis zu Reservoiren
const MAX_TRUNK := 12
const INVALID_TILE := Vector2i(-9999, -9999)

## REVISION 4: Fuenf VISUELLE WACHSTUMSSTUFEN fuer Stamm und Wurzeln.
## Ein Keimling ist duenn (30 % Breite), ein ausgewachsener Baum erreicht
## 100 %. Zusaetzlich verjuengt sich der Stamm nach oben und die Wurzeln
## werden zur Spitze hin duenner -> natuerlicher als gleich dicke 16px-Bloecke.
const STAGE_WIDTHS := [0.30, 0.46, 0.62, 0.80, 1.0]
const STAGE_TINT := [
	Color(0.88, 1.00, 0.84),   # 0 Keimling: leicht gruenlicher, heller Trieb
	Color(0.93, 1.00, 0.91),   # 1 Jungpflanze
	Color(0.97, 0.99, 0.96),   # 2
	Color(1.00, 1.00, 1.00),   # 3
	Color(1.00, 1.00, 1.00),   # 4 ausgewachsen: voller Braunton
]

var species: TreeSpeciesData
var world_generator: WorldGenerator
var tree_id: int = 0
var glucose: float = 0.0
var water: float = 100.0
var health: float = 100.0
var age: float = 0.0
var leaves_count: int = 0
var root_count: int = 0
var trunk_tiles: int = 0

## PHASE 3: Jahreszeit des Baums. Winter = kahl + Wachstum gestoppt.
var season: int = 0
var growth_blocked: bool = false

## PHASE 2: alle Segmente; root_count == root_segments.size().
var root_segments: Array[RootSegment] = []

var _visual: Node2D
var _trunk: Node2D
var _leaves: Node2D
var _roots: Node2D
var _trunk_sprites: Array[Sprite2D] = []
var _occupied: Dictionary = {}      # Vector2i -> RootSegment
var _built: bool = false


func _ready() -> void:
	if not is_in_group("trees"):
		add_to_group("trees")
	_ensure_nodes()


func default_species() -> TreeSpeciesData:
	return load("res://data/species/oak.tres")


func setup(p_species: TreeSpeciesData, p_id: int, p_data: Dictionary = {}) -> void:
	species = p_species if p_species != null else default_species()
	tree_id = p_id
	if not is_in_group("trees"):
		add_to_group("trees")
	_ensure_nodes()
	water = species.starting_water
	if p_data.is_empty():
		build_mini()
	else:
		from_dict(p_data)
	_built = true


## Keimling: Mini-Stamm (2 Tiles), 2 Blaetter, 1 kleine Wurzel (Punkt 4.1).
func build_mini() -> void:
	add_trunk_tile()
	add_trunk_tile()
	add_leaf()
	add_leaf()
	add_root()


func _ensure_nodes() -> void:
	if _visual != null:
		return
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.y_sort_enabled = true
	add_child(_visual)
	_trunk = Node2D.new()
	_trunk.name = "Trunk"
	_leaves = Node2D.new()
	_leaves.name = "Leaves"
	_roots = Node2D.new()
	_roots.name = "Roots"
	_visual.add_child(_trunk)
	_visual.add_child(_leaves)
	_visual.add_child(_roots)


func _sprite(path: String, pos: Vector2, parent: Node2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	parent.add_child(s)
	return s


# --------------------------------------------------------------------------- #
# Wachstum (PHASE 1 API bleibt erhalten)
# --------------------------------------------------------------------------- #
func add_trunk_tile() -> void:
	if trunk_tiles >= MAX_TRUNK:
		return
	var spr := _sprite(TRUNK_PATH,
		Vector2(0.0, -16.0 * float(trunk_tiles + 1)), _trunk)
	_trunk_sprites.append(spr)
	trunk_tiles += 1
	_refresh_growth_visuals()


func add_leaf() -> void:
	if leaves_count >= MAX_LEAVES:
		return
	var i := leaves_count
	var col := i % 4
	var row := int(i / 4)
	var pos := Vector2((float(col) - 1.5) * 16.0, -40.0 - float(row) * 16.0)
	_sprite(LEAF_PATH, pos, _leaves)
	leaves_count += 1
	_refresh_growth_visuals()


## PHASE 2: erzeugt ein echtes RootSegment statt nur einen Zaehler zu erhoehen.
func add_root() -> void:
	if not can_grow("root"):
		return
	if root_segments.is_empty():
		_add_root_segment(Vector2i.ZERO, Vector2i(0, 1), null, true)
	else:
		grow_root_from(deepest_tip(), true)


## PHASE 3: Winter = Laubbaeume kahl, kein Wachstum, keine Fotosynthese.
func set_season(p_season: int) -> void:
	season = p_season
	growth_blocked = (p_season == TimeManager.Season.WINTER)
	if _leaves == null:
		return
	_leaves.visible = not growth_blocked
	if p_season == TimeManager.Season.AUTUMN:
		_leaves.modulate = Color(1.0, 0.68, 0.34)
	else:
		_leaves.modulate = Color.WHITE


func is_bare() -> bool:
	return growth_blocked


func can_grow(part: String) -> bool:
	if growth_blocked:
		return false
	if part == "root":
		return root_segments.size() < MAX_ROOTS
	if part == "leaf":
		return leaves_count < MAX_LEAVES
	if part == "trunk":
		return trunk_tiles < MAX_TRUNK
	return false


func grow_part(part: String) -> bool:
	if not can_grow(part):
		return false
	if part == "root":
		add_root()
	elif part == "leaf":
		add_leaf()
	elif part == "trunk":
		add_trunk_tile()
	else:
		return false
	return true


# --------------------------------------------------------------------------- #
# PHASE 2: Wurzel-Segmente / Richtung / Hierarchie
# --------------------------------------------------------------------------- #
func _add_root_segment(p_grid: Vector2i, p_dir: Vector2i,
		p_parent: RootSegment, p_keep_parent_tip: bool = false) -> RootSegment:
	var seg := RootSegment.new()
	_roots.add_child(seg)
	seg.setup(self, p_grid, p_dir, p_parent)
	if p_parent != null:
		p_parent.children.append(seg)
		if not p_keep_parent_tip:
			p_parent.is_tip = false
	root_segments.append(seg)
	_occupied[p_grid] = seg
	root_count = root_segments.size()
	_refresh_growth_visuals()
	return seg


func _refresh_root_sprites() -> void:
	_refresh_growth_visuals()


## REVISION 4: Reifegrad aus allen drei Wachstumszaehlern (0..1).
func growth_progress() -> float:
	var p := float(trunk_tiles) / float(MAX_TRUNK) * 0.45 \
		+ float(root_count) / float(MAX_ROOTS) * 0.35 \
		+ float(leaves_count) / float(MAX_LEAVES) * 0.20
	return clampf(p, 0.0, 1.0)


func growth_stage() -> int:
	var p := growth_progress()
	if p < 0.18:
		return 0
	if p < 0.36:
		return 1
	if p < 0.56:
		return 2
	if p < 0.78:
		return 3
	return 4


## Einmal pro Wachstumsschritt: Breite/Farbe von Stamm und Wurzeln an die
## aktuelle Stufe anpassen. Die 16px-Kollision bleibt unveraendert.
func _refresh_growth_visuals() -> void:
	var stage := growth_stage()
	for i in _trunk_sprites.size():
		var sp: Sprite2D = _trunk_sprites[i]
		if sp == null or not is_instance_valid(sp):
			continue
		# Unten am dicksten, nach oben natuerlich verjuengt.
		var w := maxf(float(STAGE_WIDTHS[stage]) \
			* (1.0 - 0.045 * float(i)), 0.16)
		sp.scale = Vector2(w, 1.0)
		sp.position.x = -8.0 * w       # zentriert auf der Stammachse x=0
		sp.modulate = STAGE_TINT[stage]
	for seg in root_segments:
		seg.refresh_sprite()


# --------------------------------------------------------------------------- #
# Debug-Hooks (Smoke-Test Revision 4)
# --------------------------------------------------------------------------- #
func debug_stage() -> int:
	return growth_stage()


func debug_trunk_width(i: int = 0) -> float:
	if i < 0 or i >= _trunk_sprites.size():
		return -1.0
	return _trunk_sprites[i].scale.x


func debug_root_width(i: int = 0) -> float:
	if i < 0 or i >= root_segments.size():
		return -1.0
	return root_segments[i]._sprite.scale.x


## Von Oak.gd ueberschrieben: Pfahlwurzel + Herzwurzelsystem.
func root_candidates(_tip: RootSegment) -> Array[Vector2i]:
	return [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1),
		Vector2i(-1, 0), Vector2i(1, 0)]


func global_tile_for(local_grid: Vector2i) -> Vector2i:
	var ox := int(floor(global_position.x / float(WorldGenerator.TILE_SIZE)))
	var oy := int(floor(global_position.y / float(WorldGenerator.TILE_SIZE)))
	# REVISION 1: Baeume stehen auf der fliessenden 4px-Oberkante. Ihr
	# Wurzel-Ursprung bleibt deshalb bewusst die logische 16px-Oberflaechenzeile
	# (und nicht floor(y/16), das bei halben Hoehen um 1 Tile springen wuerde).
	if world_generator != null:
		oy = world_generator.surface_tile_y_at(global_position.x)
	return Vector2i(ox + local_grid.x, oy + local_grid.y)


func _is_free(local_grid: Vector2i) -> bool:
	if local_grid.y < 0 or _occupied.has(local_grid):
		return false
	if world_generator != null:
		var gt := global_tile_for(local_grid)
		if world_generator.material_at(gt.x, gt.y) == WorldGenerator.SoilKind.AIR:
			return false
	return true


## Naechstes freies Tile in Erd-Richtung (Ghost-Preview + Kauf nutzen denselben Wert).
func propose_next_tile(tip: RootSegment) -> Vector2i:
	if tip == null or not can_grow("root"):
		return INVALID_TILE
	for delta in root_candidates(tip):
		var target: Vector2i = tip.grid + delta
		if _is_free(target):
			return target
	return INVALID_TILE


func has_next_root_tile(tip: RootSegment) -> bool:
	return propose_next_tile(tip) != INVALID_TILE


## Waechst vom angegebenen Tip. Bei der Eiche entsteht zusaetzlich alle
## root_side_every Tiles eine Seitenwurzel (Herzwurzelsystem), waehrend die
## Pfahlwurzel weiter nach unten laeuft.
func grow_root_from(tip: RootSegment, allow_branch: bool = true) -> RootSegment:
	if tip == null or not can_grow("root"):
		return null
	var target := propose_next_tile(tip)
	if target == INVALID_TILE:
		return null
	var seg := _add_root_segment(target, target - tip.grid, tip, false)
	if allow_branch and species != null and species.root_side_every > 0:
		var every: int = maxi(species.root_side_every, 1)
		if target.y > 0 and target.y % every == 0 and can_grow("root"):
			var side := 1 if (int(target.y / every) % 2 == 0) else -1
			var side_target: Vector2i = target + Vector2i(side, 0)
			if _is_free(side_target):
				_add_root_segment(side_target, Vector2i(side, 0), seg, true)
	return seg


## Tiefster Tip = Ende der Pfahlwurzel (AUTO / PHASE-1-Kompatibilitaet).
func deepest_tip() -> RootSegment:
	var best: RootSegment = null
	for s in root_segments:
		if not s.is_tip:
			continue
		if best == null or s.grid.y > best.grid.y or (
				s.grid.y == best.grid.y and absi(s.grid.x) < absi(best.grid.x)):
			best = s
	return best


## Tip des Astes, auf den der Spieler geklickt hat.
func tip_for(segment: RootSegment) -> RootSegment:
	if segment == null:
		return deepest_tip()
	if segment.is_tip:
		return segment
	var best: RootSegment = null
	for child in segment.children:
		var t := tip_for(child)
		if best == null or t.grid.y > best.grid.y:
			best = t
	return best if best != null else segment


func find_root_segment_at(world_pos: Vector2) -> RootSegment:
	var best: RootSegment = null
	var best_dist := 1.0e9
	for s in root_segments:
		if s.hit_rect().has_point(world_pos):
			var d := world_pos.distance_squared_to(s.hit_rect().get_center())
			if d < best_dist:
				best_dist = d
				best = s
	return best


# --------------------------------------------------------------------------- #
# Simulation
# --------------------------------------------------------------------------- #
## Punkt 4.2: glucose += leaves * efficiency * sunlight * dt; water -= rate * dt
## sunlight_factor = 1.0 (immer Tag, kein Tag/Nacht-Zyklus im MVP).
func photosynthesize(dt: float, sunlight: float = 1.0,
		growth: float = 1.0) -> void:
	if not _built or leaves_count <= 0 or water <= 10.0:
		return
	age += dt
	# Winter: sunlight = 0 und growth = 0 -> Winterruhe (nichts passiert).
	if sunlight <= 0.0 or growth <= 0.0:
		return
	glucose += float(leaves_count) * species.photosynthesis_efficiency \
		* sunlight * growth * Global.difficulty_factor("photosynthesis") * dt
	water = maxf(water - species.water_consumption_rate \
		* Global.difficulty_factor("water_consumption") * dt, 0.0)


## rate kommt von WaterSystem (Boden + Reservoir + Regen).
func absorb_water(dt: float, rate: float) -> void:
	if not _built:
		return
	water = clampf(water + rate * dt, 0.0, 100.0)


# --------------------------------------------------------------------------- #
# Info / Save
# --------------------------------------------------------------------------- #
func get_bounds_rect() -> Rect2:
	var root_depth := float(maxi(2, root_segments.size())) * float(WorldGenerator.TILE_SIZE)
	return Rect2(global_position + Vector2(-48.0, -112.0), Vector2(96.0, 176.0 + root_depth))


func get_info_text() -> String:
	return tr("MSG_TREE_INFO") % [glucose, water, health, leaves_count, root_count]


func to_dict() -> Dictionary:
	var segments: Array[Dictionary] = []
	for s in root_segments:
		segments.append({
			"x": s.grid.x,
			"y": s.grid.y,
			"dx": s.direction.x,
			"dy": s.direction.y,
			"parent": root_segments.find(s.parent_segment) if s.parent_segment != null else -1,
			"tip": s.is_tip,
		})
	return {
		"id": tree_id,
		"x": global_position.x,
		"y": global_position.y,
		"glucose": glucose,
		"water": water,
		"health": health,
		"age": age,
		"leaves": leaves_count,
		"roots": root_count,
		"trunk": trunk_tiles,
		"root_segments": segments,
	}


func from_dict(d: Dictionary) -> void:
	glucose = float(d.get("glucose", 0.0))
	water = float(d.get("water", species.starting_water))
	health = float(d.get("health", 100.0))
	age = float(d.get("age", 0.0))
	for _i in int(d.get("trunk", 0)):
		add_trunk_tile()
	for _i in int(d.get("leaves", 0)):
		add_leaf()

	root_segments.clear()
	_occupied.clear()
	var segments: Array = d.get("root_segments", [])
	if segments.is_empty():
		# Rueckwaertskompatibilitaet: PHASE-1-Savegames kannten nur den Zaehler.
		for _i in int(d.get("roots", 0)):
			add_root()
	else:
		for e in segments:
			var pi := int(e.get("parent", -1))
			var parent: RootSegment = null
			if pi >= 0 and pi < root_segments.size():
				parent = root_segments[pi]
			_add_root_segment(
				Vector2i(int(e.get("x", 0)), int(e.get("y", 0))),
				Vector2i(int(e.get("dx", 0)), int(e.get("dy", 1))),
				parent, true)
		for i in segments.size():
			root_segments[i].is_tip = bool(segments[i].get("tip", false))
	_refresh_growth_visuals()
	root_count = root_segments.size()
