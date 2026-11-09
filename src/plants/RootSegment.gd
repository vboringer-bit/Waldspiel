class_name RootSegment
extends Node2D
## PHASE 2: EIN Wurzelsegment auf dem 16x16-Tile-Raster.
## Node-Hierarchie gemaess Master-Punkt 4.3:
##   BaseTree -> Roots -> RootSegment -> RootTip (Marker2D)
## grid ist relativ zum Baum-Ursprung: (0,0) = Oberflaechen-Tile, +y = Tiefe.

const ROOT_PATH := "res://assets/placeholders/root.png"
const TIP_PATH := "res://assets/placeholders/root_tip.png"

var grid: Vector2i = Vector2i.ZERO
var direction: Vector2i = Vector2i(0, 1)
var parent_segment: RootSegment = null
var children: Array[RootSegment] = []
var is_tip: bool = true
var tree_ref: BaseTree = null

var _sprite: Sprite2D
var _tip_marker: Marker2D


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
	add_child(_sprite)

	_tip_marker = Marker2D.new()
	_tip_marker.name = "RootTip"
	_tip_marker.position = Vector2(8.0, float(WorldGenerator.TILE_SIZE))
	add_child(_tip_marker)
	refresh_sprite()


func refresh_sprite() -> void:
	if _sprite != null:
		_sprite.texture = load(TIP_PATH if is_tip else ROOT_PATH)
		# REVISION 4: Wachstumsstufe + natuerliche Verjuengung. Junge Wurzeln
		# sind duenn, mit dem Baum werden sie dicker; zur Spitze hin bleiben
		# sie feiner. Das 16px-Kollisionsraster (hit_rect) bleibt unberuehrt.
		var stage := tree_ref.growth_stage() if tree_ref != null else 0
		var w := float(BaseTree.STAGE_WIDTHS[stage])
		w *= clampf(1.0 - 0.055 * float(maxi(grid.y, 0)), 0.34, 1.0)
		if is_tip:
			w *= 0.70
		w = maxf(w, 0.14)
		_sprite.scale = Vector2(w, 1.0)
		_sprite.position.x = 8.0 * (1.0 - w)   # im 16px-Tile zentriert
		_sprite.modulate = BaseTree.STAGE_TINT[stage]


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


func hit_rect() -> Rect2:
	return Rect2(world_pos(), Vector2(float(WorldGenerator.TILE_SIZE),
		float(WorldGenerator.TILE_SIZE)))
