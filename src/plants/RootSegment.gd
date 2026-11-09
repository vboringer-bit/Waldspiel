class_name RootSegment
extends Node2D
## PHASE 2: EIN logisches Wurzelsegment auf dem 16x16-Tile-Raster.
## REVISION 5: gezeichnet wird es als FREIE, gekruemmte Faser mit feinen
## Seiten-Hyphen (Mycelarium-Stil), nicht mehr als 16px-Kachel.
## REVISION 6:
##   * Der Spieler kann die Faser GEZIELT ZIEHEN: `free_target` ist der freie
##     Endpunkt in Baum-lokalen Koordinaten, die Kurve folgt ihm exakt.
##   * Jede bereits gewachsene UND verbundene Wurzel wird dicker, wenn das
##     Netz weiterwaechst (`age` + Anzahl Nachkommen).
##   * Die Hauptfaser nutzt `PixelArt.draw_fibre()` -> root.png austauschbar.
## Das logische 16px-Raster bleibt NUR fuer Wasser/Reservoir, Hitbox und
## Savegame erhalten. Node-Hierarchie gemaess Master-Punkt 4.3:
##   BaseTree -> Roots -> RootSegment -> RootTip (Marker2D)
## grid ist relativ zum Baum-Ursprung: (0,0) = Oberflaechen-Tile, +y = Tiefe.

const ROOT_PATH := PixelArt.ROOT
const TIP_PATH := PixelArt.ROOT_TIP
const NO_FREE := Vector2(1.0e9, 1.0e9)

var grid: Vector2i = Vector2i.ZERO
var direction: Vector2i = Vector2i(0, 1)
var parent_segment: RootSegment = null
var children: Array[RootSegment] = []
var is_tip: bool = true
var tree_ref: BaseTree = null

## REVISION 6: freier Zeichen-Endpunkt (Baum-lokal). Fehlt er, wird die
## deterministische R5-Jitter-Kurve benutzt (Savegames ohne neue Felder).
var has_free_target: bool = false
var free_target: Vector2 = Vector2.ZERO

var _sprite: Sprite2D
var _tip_marker: Marker2D
var _width: float = 3.0


func setup(p_tree: BaseTree, p_grid: Vector2i, p_dir: Vector2i,
		p_parent: RootSegment) -> void:
	tree_ref = p_tree
	grid = p_grid
	direction = p_dir
	parent_segment = p_parent
	name = "Root_%d_%d" % [grid.x, grid.y]
	position = Vector2(float(grid.x * WorldGenerator.TILE_SIZE),
		float(grid.y * WorldGenerator.TILE_SIZE))

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(ROOT_PATH)
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# REVISION 5/6: nur noch Breiten-Traeger fuer debug_root_width() und die
	# REVISION-4-Smokes. Die sichtbare Faser zeichnet _draw().
	_sprite.visible = false
	add_child(_sprite)

	_tip_marker = Marker2D.new()
	_tip_marker.name = "RootTip"
	_tip_marker.position = Vector2(8.0, float(WorldGenerator.TILE_SIZE))
	add_child(_tip_marker)
	refresh_sprite()


func set_free_target(p_free: Vector2) -> void:
	if p_free.x < 1.0e8 and p_free.y < 1.0e8:
		has_free_target = true
		free_target = p_free
		if _tip_marker != null:
			_tip_marker.position = p_free - position
	else:
		has_free_target = false
		free_target = Vector2.ZERO
	refresh_sprite()


## Anzahl aller verbundenen Nachkommen. Iterativ (kein Rekursionslimit) und
## zyklensicher; wird bei jedem Wachstumsschritt fuer ALLE Segmente neu
## berechnet -> auch alte Wurzeln verdicken sich.
func descendant_count() -> int:
	var seen: Dictionary = {}
	var stack: Array[RootSegment] = []
	for c in children:
		if is_instance_valid(c):
			stack.append(c)
	var n := 0
	while not stack.is_empty():
		var seg: RootSegment = stack.pop_back()
		if seen.has(seg):
			continue
		seen[seg] = true
		n += 1
		for c in seg.children:
			if is_instance_valid(c):
				stack.append(c)
	return n


func refresh_sprite() -> void:
	var stage := tree_ref.growth_stage() if tree_ref != null else 0
	var age := (1.0 + 0.010 * float(tree_ref.root_count)) \
		if tree_ref != null else 1.0
	var net := 1.0 + 0.030 * float(descendant_count())
	var depth_fade := clampf(1.0 - 0.030 * float(maxi(grid.y, 0)), 0.30, 1.0)
	if _sprite != null:
		_sprite.texture = load(TIP_PATH if is_tip else ROOT_PATH)
		var w := float(BaseTree.STAGE_WIDTHS[stage]) * age * net * depth_fade
		if is_tip:
			w *= 0.70
		w = clampf(w, 0.14, 1.0)
		_sprite.scale = Vector2(w, 1.0)
		_sprite.position.x = 8.0 * (1.0 - w)
		_sprite.modulate = BaseTree.STAGE_TINT[stage]
	_width = (2.6 + 5.2 * float(BaseTree.STAGE_WIDTHS[stage])) \
		* age * net * depth_fade
	if is_tip:
		_width *= 0.60
	_width = clampf(_width, 1.4, 14.0)
	queue_redraw()


# --------------------------------------------------------------------------- #
# REVISION 5/6: deterministische Freiform-Faser
# --------------------------------------------------------------------------- #
func _r(salt: int) -> float:
	var id := tree_ref.tree_id if tree_ref != null else 0
	var n: int = (grid.x * 73856093) ^ (grid.y * 19349663) \
		^ (salt * 83492791) ^ (id * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n % 10000)) / 10000.0


func _jitter() -> Vector2:
	return Vector2((_r(3) - 0.5) * 10.0, (_r(4) - 0.5) * 10.0)


func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * (u * u) + b * (2.0 * u * t) + c * (t * t)


func _draw() -> void:
	if tree_ref == null:
		return
	var tile := float(WorldGenerator.TILE_SIZE)
	var centre := Vector2(tile * 0.5, tile * 0.5)
	var start := Vector2.ZERO
	var end := centre + _jitter() * 0.55
	if has_free_target:
		# Der gezogene Endpunkt liegt in Baum-Koordinaten; dieses Segment
		# ist um `position` verschoben -> in Segment-Koordinaten umrechnen.
		end = free_target - position
	if parent_segment != null:
		if parent_segment.has_free_target:
			start = parent_segment.free_target - position
		else:
			var delta := Vector2(
				float((parent_segment.grid.x - grid.x) * int(tile)),
				float((parent_segment.grid.y - grid.y) * int(tile)))
			start = centre + delta + parent_segment._jitter() * 0.55
	else:
		# Erste Wurzel beginnt direkt am Wurzelhals des Stamms.
		start = Vector2(0.0, -8.0) + _jitter() * 0.25
	var bend := 1.0 if not has_free_target else 0.25
	var ctrl := (start + end) * 0.5 \
		+ Vector2((_r(5) - 0.5) * 13.0, (_r(6) - 0.5) * 11.0) * bend
	var stage := tree_ref.growth_stage()
	var width := _width
	var halo := PixelArt.ROOT_HALO
	var dark := PixelArt.BARK_DARK
	var fibre := PixelArt.ROOT_FIBRE.lerp(
		Color(0.86, 0.70, 0.43), 0.45 * float(stage) / 4.0)
	if is_tip:
		fibre = Color(0.90, 0.76, 0.48)
	var pts := PackedVector2Array()
	for i in range(7):
		pts.append(_quad(start, ctrl, end, float(i) / 6.0))
	draw_polyline(pts, halo, width + 4.0)
	draw_polyline(pts, dark, width + 1.8)
	# REVISION 6: gekachelte 16x16-Pixelart laengs der freien Kurve.
	# Ein Austausch von root.png genuegt fuer einen kompletten Art-Satz.
	for i in range(pts.size() - 1):
		PixelArt.draw_fibre(self, PixelArt.ROOT, pts[i], pts[i + 1], width,
			Color(1.0, 1.0, 1.0, 0.95))
	# Mycelarium-Netz: feine, schraeg abzweigende Hyphen mit eigener Gabel.
	var shallow := grid.y < 2
	var hyphae := 2 if shallow else 4
	if grid.x != 0:
		hyphae += 1
	for j in range(hyphae):
		var ang := (_r(10 + j) * 2.0 - 1.0) * PI
		var length := (10.0 if shallow else 14.0) \
			+ _r(20 + j) * (18.0 if shallow else 22.0)
		var base: Vector2 = pts[1 + (j % 5)]
		var tip := base + Vector2(cos(ang), sin(ang)) * length
		var bend2 := base.lerp(tip, 0.55) \
			+ Vector2((_r(30 + j) - 0.5) * 8.0, -3.0)
		var hyph := PackedVector2Array()
		for q in range(5):
			hyph.append(_quad(base, bend2, tip, float(q) / 4.0))
		draw_polyline(hyph, PixelArt.HYPHA, 1.5)
		var fork_ang := ang + (0.7 if j % 2 == 0 else -0.7)
		var fork := tip + Vector2(cos(fork_ang), sin(fork_ang)) * (5.0 + _r(40 + j) * 8.0)
		draw_line(tip, fork, Color(0.78, 0.62, 0.39, 0.80), 1.0)
		draw_circle(tip, 1.1, Color(0.84, 0.68, 0.43, 0.90))
	if is_tip:
		draw_circle(end, 2.0, Color(0.94, 0.81, 0.53))


## Globales Tile dieses Segments (fuer Bodenhärte / Reservoir-Abfrage).
func global_tile() -> Vector2i:
	if tree_ref == null:
		return grid
	var ox := int(floor(tree_ref.global_position.x / float(WorldGenerator.TILE_SIZE)))
	var oy := int(floor(tree_ref.global_position.y / float(WorldGenerator.TILE_SIZE)))
	return Vector2i(ox + grid.x, oy + grid.y)


func world_pos() -> Vector2:
	return Vector2(float(grid.x * WorldGenerator.TILE_SIZE),
		float(grid.y * WorldGenerator.TILE_SIZE)) + (
		tree_ref.global_position if tree_ref != null else Vector2.ZERO)


## REVISION 5/6: Bewusst UNVERAENDERT 16x16. Wasserlogik, Ghost-Preview und
## Revision4Smoke verlassen sich auf diese logische Kollisionsflaeche.
func hit_rect() -> Rect2:
	return Rect2(world_pos(), Vector2(float(WorldGenerator.TILE_SIZE),
		float(WorldGenerator.TILE_SIZE)))


func debug_visual_jitter() -> Vector2:
	return _jitter()


func debug_uses_organic_draw() -> bool:
	return _sprite != null and not _sprite.visible


func debug_draw_width() -> float:
	return _width


func debug_has_free_target() -> bool:
	return has_free_target
