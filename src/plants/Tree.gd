class_name BaseTree
extends Node2D
## Basis-Klasse fuer alle Baeume (Dateiname Tree.gd laut Master-Punkt 9).
## Der class_name heisst BaseTree, weil Godot bereits eine native Control-Klasse
## "Tree" hat (sonst: "member shadows a native class").
##
## PHASE 1: Instanzwerte, Fotosynthese, einfache Wachstumszaehler.
## PHASE 2: echte Wurzel-Segmente auf dem 16px-Raster mit RootTip-Knoten.
## REVISION 4: fuenf visuelle Wuchsstufen.
## REVISION 5: organische, vom Raster ENTkoppelte Geometrie fuer Stamm,
##   Aeste und Wurzeln (Mycelarium-artige Verzweigung), ~3x groessere
##   Endgroesse, ~5x langsamere Glucose und eine echte Versorgungs-Bilanz
##   aus Wasser, Sonne, Naehrstoffen und Wurzelmasse.
##   Das logische 16px-Raster bleibt NUR noch fuer Wasser/Reservoir, Klick-
##   Hitboxen und Savegames erhalten (siehe DECISIONS.md §71).

const TRUNK_PATH := "res://assets/placeholders/trunk.png"
const LEAF_PATH := "res://assets/placeholders/leaf.png"
const ROOT_PATH := "res://assets/placeholders/root.png"
const MAX_LEAVES := 12
const MAX_ROOTS := 72          # REVISION 5: deutlich tieferes Myzel-Netz
const MAX_TRUNK := 28          # REVISION 5: 28 Schritte statt 12
const INVALID_TILE := Vector2i(-9999, -9999)

## REVISION 5: EIN Wuchsschritt ist 17 px freie Geometrie statt eines 16px-Felds.
## Ausgewachsen: 28 * 17 = 476 px Stammhoehe (vorher 12 * 16 = 192 px).
const TRUNK_STEP := 17.0
const BRANCH_EVERY := 4
## REVISION 5: Grundtempo der Glucose-Produktion. 0.2 = ca. 5x langsamer als
## der PHASE-5-Stand. Zusaetzlich drosselt environment_factor() schlecht
## versorgte Baeume (vor allem mit winziger Wurzel) weiter.
const GLUCOSE_PACE := 0.2
## REVISION 5: AUTO kauft nur, wenn genug "Wuchskraft" aus der Versorgung
## aufgelaufen ist. Ein Keimling mit 1 Wurzel braucht dadurch deutlich laenger.
const AUTO_GROWTH_INTERVAL := 1.1

## REVISION 4: Fuenf VISUELLE WACHSTUMSSTUFEN fuer Stamm und Wurzeln.
const STAGE_WIDTHS := [0.30, 0.46, 0.62, 0.80, 1.0]
const STAGE_TINT := [
	Color(0.88, 1.00, 0.84),
	Color(0.93, 1.00, 0.91),
	Color(0.97, 0.99, 0.96),
	Color(1.00, 1.00, 1.00),
	Color(1.00, 1.00, 1.00),
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

## PHASE 4: vom globalen Skilltree per apply_effect(tree_instance)
var skill_glucose_mult: float = 1.0
var skill_water_consumption_mult: float = 1.0
var skill_root_water_mult: float = 1.0
var skill_max_leaves_bonus: int = 0
var skill_leaf_grants: int = 0
## PHASE 5: Pilz-Symbiose erhoeht die Naehrstoff-Versorgung (mushroom_node).
var nutrient_mult: float = 1.0

## REVISION 5: Versorgungsabhaengige Wuchskraft + zuletzt gesehene Sonne.
var growth_vigor: float = AUTO_GROWTH_INTERVAL
var last_sunlight: float = 1.0

## PHASE 2: alle Segmente; root_count == root_segments.size().
var root_segments: Array[RootSegment] = []

var _visual: Node2D
var _trunk: Node2D
var _leaves: Node2D
var _roots: Node2D
var _trunk_sprites: Array[Sprite2D] = []
var _leaf_sprites: Array[Sprite2D] = []
var _leaf_decor_a: Array[Sprite2D] = []
var _leaf_decor_b: Array[Sprite2D] = []
var _occupied: Dictionary = {}
var _built: bool = false

## REVISION 5: gecachte, deterministische Freiform-Geometrie. Sie wird bei
## jedem Wachstumsschritt neu berechnet, aber NICHT pro Frame zufaellig
## verwuerfelt -> kein Flackern, Save/Load ohne extra Geometrie-Daten.
var _skel_trunk: Array[Vector2] = []
var _skel_branches: Array[Dictionary] = []
var _skel_anchors: Array[Vector2] = []


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
	queue_redraw()


## Keimling: Mini-Stamm (2 Schritte), 2 Blaetter, 1 kleine Wurzel (Punkt 4.1).
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
func add_trunk_tile() -> bool:
	if trunk_tiles >= MAX_TRUNK:
		return false
	# REVISION 5: Der Sprite bleibt NUR als kompatibler Breiten-Traeger fuer
	# debug_trunk_width()/Revision4Smoke. Sichtbar gezeichnet wird die freie
	# Kurve in _draw() -> kein 16px-Kachelmuster mehr.
	var spr := _sprite(TRUNK_PATH,
		Vector2(0.0, -TRUNK_STEP * float(trunk_tiles + 1)), _trunk)
	spr.visible = false
	_trunk_sprites.append(spr)
	trunk_tiles += 1
	_refresh_growth_visuals()
	return true


func add_leaf() -> bool:
	# PHASE-4-FIX: dieselbe Obergrenze wie can_grow("leaf") verwenden!
	if leaves_count >= MAX_LEAVES + skill_max_leaves_bonus:
		return false
	# REVISION 5: Blaetter sitzen an freien Astspitzen statt im 4-Spalten-Raster.
	# Zwei kleine Deko-Blaetter pro logischem Blatt verdichten die Krone,
	# ohne leaves_count (und damit die P0-P5-Smokes) zu veraendern.
	var main := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	var a := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	var b := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	a.modulate = Color(0.86, 0.96, 0.80, 0.95)
	b.modulate = Color(0.94, 1.00, 0.88, 0.95)
	_leaf_sprites.append(main)
	_leaf_decor_a.append(a)
	_leaf_decor_b.append(b)
	leaves_count += 1
	_refresh_growth_visuals()
	return true


## PHASE 2: erzeugt ein echtes RootSegment statt nur einen Zaehler zu erhoehen.
func add_root() -> bool:
	if not can_grow("root"):
		return false
	if root_segments.is_empty():
		_add_root_segment(Vector2i.ZERO, Vector2i(0, 1), null, true)
		return true
	return grow_root_from(deepest_tip(), true) != null


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
	queue_redraw()


func is_bare() -> bool:
	return growth_blocked


func can_grow(part: String) -> bool:
	if growth_blocked:
		return false
	if part == "root":
		return maxi(root_segments.size(), root_count) < MAX_ROOTS
	if part == "leaf":
		return leaves_count < MAX_LEAVES + skill_max_leaves_bonus
	if part == "trunk":
		return trunk_tiles < MAX_TRUNK
	return false


func grow_part(part: String) -> bool:
	if not can_grow(part):
		return false
	# PHASE-4-FIX: nur bei ECHTEM Zuwachs true zurueckgeben.
	if part == "root":
		return add_root()
	if part == "leaf":
		return add_leaf()
	if part == "trunk":
		return add_trunk_tile()
	return false


## PHASE-4-FIX: "Kronenwuchs" gibt die +2 Blaetter SOFORT sichtbar.
func apply_skill_leaf_grants(total: int) -> void:
	var want := clampi(total, 0, skill_max_leaves_bonus)
	while skill_leaf_grants < want and add_leaf():
		skill_leaf_grants += 1


# --------------------------------------------------------------------------- #
# PHASE 2: logische Wurzel-Segmente (Wasser / Klick / Save)
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


## Einmal pro Wachstumsschritt: Breite/Farbe der kompatiblen Traeger-Sprites,
## danach Freiform-Skelett und Blattpositionen neu berechnen.
func _refresh_growth_visuals() -> void:
	var stage := growth_stage()
	for i in _trunk_sprites.size():
		var sp: Sprite2D = _trunk_sprites[i]
		if sp == null or not is_instance_valid(sp):
			continue
		var w := maxf(float(STAGE_WIDTHS[stage]) \
			* (1.0 - 0.045 * float(i)), 0.16)
		sp.scale = Vector2(w, 1.0)
		sp.position.x = -8.0 * w
		sp.modulate = STAGE_TINT[stage]
	for seg in root_segments:
		seg.refresh_sprite()
	_rebuild_skeleton()
	_layout_leaves(stage)
	queue_redraw()


# --------------------------------------------------------------------------- #
# REVISION 5: freie, deterministische Geometrie (Mycelarium-artig)
# --------------------------------------------------------------------------- #
## Stabiler Hash aus tree_id + Index. Kein randf() im _draw(): sonst wuerde
## der Baum bei jedem Redraw flackern und Save/Load andere Aeste erzeugen.
func _h(a: int, b: int, c: int = 0) -> float:
	var n: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) \
		^ (tree_id * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n % 10000)) / 10000.0


func _curve(a: Vector2, b: Vector2, c: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		pts.append(a * (u * u) + b * (2.0 * u * t) + c * (t * t))
	return pts


func _rebuild_skeleton() -> void:
	_skel_trunk.clear()
	_skel_branches.clear()
	_skel_anchors.clear()
	var h := float(trunk_tiles) * TRUNK_STEP
	var stage := growth_stage()
	var n := maxi(trunk_tiles, 2)
	var phase := _h(0, 0, 1) * TAU
	var amp := 2.0 + 1.5 * float(stage)
	for i in range(n + 1):
		var t := float(i) / float(n)
		# Basis bleibt exakt bei x=0, die Krone schwingt leicht aus.
		var x := (sin(t * 5.0 + phase) - sin(phase)) * amp * (0.35 + 0.65 * t)
		_skel_trunk.append(Vector2(x, -h * t))
	var count := clampi(int(trunk_tiles / BRANCH_EVERY), 0, 7)
	for k in range(count):
		var frac := minf(0.34 + 0.085 * float(k), 0.92)
		var idx := clampi(int(roundf(frac * float(n))), 1, n - 1)
		var origin: Vector2 = _skel_trunk[idx]
		var side := 1 if k % 2 == 0 else -1
		var j := _h(k, 11, 2)
		var ang := deg_to_rad(36.0 + 26.0 * j)
		var blen := (30.0 + 13.0 * float(stage) + 6.0 * float(k)) \
			* (0.8 + 0.4 * j)
		var dir := Vector2(float(side) * sin(ang), -cos(ang))
		var bend := origin + dir * blen + Vector2(float(side) * 3.0, -7.0)
		var mid := origin.lerp(bend, 0.55) + Vector2(0.0, -5.0 - 3.0 * j)
		var twigs: Array[Vector2] = []
		for m in range(2):
			var j2 := _h(k, 20 + m, 3)
			var a2 := ang + (0.42 if m == 0 else -0.52) + (j2 - 0.5) * 0.36
			var l2 := blen * (0.34 + 0.20 * j2)
			twigs.append(bend + Vector2(float(side) * sin(a2), -cos(a2)) * l2)
		_skel_branches.append({
			"origin": origin, "mid": mid, "end": bend, "twigs": twigs,
		})
		_skel_anchors.append(bend)
		_skel_anchors.append(origin.lerp(bend, 0.7))
		for tw in twigs:
			_skel_anchors.append(tw)
	if _skel_anchors.is_empty():
		var top: Vector2 = _skel_trunk[n]
		_skel_anchors.append(top + Vector2(-11.0, -8.0))
		_skel_anchors.append(top + Vector2(11.0, -8.0))


func _leaf_anchor(i: int) -> Vector2:
	var base: Vector2 = _skel_anchors[i % maxi(_skel_anchors.size(), 1)]
	var spread := 8.0 + 2.0 * float(growth_stage())
	return base + Vector2((_h(i, 2, 8) - 0.5) * 2.0 * spread,
		(_h(i, 3, 9) - 0.5) * 1.4 * spread)


func _layout_leaves(stage: int) -> void:
	var sc := 1.05 + 0.14 * float(stage)
	for i in _leaf_sprites.size():
		var anchor := _leaf_anchor(i)
		var main := _leaf_sprites[i]
		main.scale = Vector2(sc, sc)
		main.position = anchor - Vector2(8.0 * sc, 8.0 * sc)
		var a := _leaf_decor_a[i]
		var b := _leaf_decor_b[i]
		var off := 10.0 + 3.0 * float(stage)
		var ds := sc * 0.55
		a.scale = Vector2(ds, ds)
		b.scale = Vector2(ds, ds)
		a.position = anchor + Vector2(-off, 4.0) - Vector2(8.0 * ds, 8.0 * ds)
		b.position = anchor + Vector2(off * 0.7, -off * 0.6) \
			- Vector2(8.0 * ds, 8.0 * ds)


func _draw() -> void:
	if trunk_tiles <= 0 or _skel_trunk.is_empty():
		return
	var stage := growth_stage()
	var bark := Color(0.34, 0.23, 0.15).lerp(
		Color(0.46, 0.31, 0.19), float(stage) / 4.0)
	var dark := Color(0.19, 0.13, 0.09)
	# Wurzelhals: kurze freie Strahlen vom Stamm in den Boden.
	for r in range(5):
		var j := _h(r, 30, 5)
		var e := Vector2((float(r) - 2.0) * 7.0 + (j - 0.5) * 6.0,
			9.0 + 12.0 * j + 2.0 * float(stage))
		draw_line(Vector2.ZERO, e, dark, 2.4)
		draw_line(Vector2.ZERO, e, bark, 1.2)
	# Stamm: leicht geschwungene, nach oben verjuengte Freiform-Kurve.
	var segs := maxi(_skel_trunk.size() - 1, 1)
	for i in range(_skel_trunk.size() - 1):
		var t := float(i) / float(segs)
		var w := lerpf(3.0 + 2.8 * float(stage), 1.0, t)
		draw_line(_skel_trunk[i], _skel_trunk[i + 1], dark, w + 1.4)
		draw_line(_skel_trunk[i], _skel_trunk[i + 1], bark, w)
	# Aeste mit zwei weiteren Verzweigungen pro Ast.
	for k in _skel_branches.size():
		var bd := _skel_branches[k]
		var o: Vector2 = bd["origin"]
		var m: Vector2 = bd["mid"]
		var e: Vector2 = bd["end"]
		var bw := maxf(1.2, 3.4 - 0.30 * float(k) + 0.35 * float(stage))
		var pts := _curve(o, m, e, 7)
		for i in range(pts.size() - 1):
			var w := bw * (1.0 - 0.60 * float(i) / float(maxi(pts.size() - 1, 1)))
			draw_line(pts[i], pts[i + 1], dark, w + 1.0)
			draw_line(pts[i], pts[i + 1], bark, w)
		var twigs: Array = bd["twigs"]
		for tw in twigs:
			var tip: Vector2 = tw
			var mid2 := e.lerp(tip, 0.55) + Vector2(0.0, -2.0)
			draw_polyline(_curve(e, mid2, tip, 5), bark, maxf(0.8, bw * 0.45))
		draw_circle(e, maxf(1.0, bw * 0.55), Color(0.52, 0.38, 0.22))


# --------------------------------------------------------------------------- #
# Debug-Hooks (Smoke-Tests Revision 4 / Revision 5)
# --------------------------------------------------------------------------- #
func debug_mark_full() -> void:
	leaves_count = MAX_LEAVES + skill_max_leaves_bonus
	trunk_tiles = MAX_TRUNK
	root_count = MAX_ROOTS
	root_segments.clear()
	growth_vigor = 0.0


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


func debug_trunk_height() -> float:
	return float(trunk_tiles) * TRUNK_STEP


func debug_branch_count() -> int:
	return _skel_branches.size()


func debug_leaf_spread() -> float:
	var best := 0.0
	for a in _skel_anchors:
		best = maxf(best, absf(a.x))
	return best


func debug_growth_vigor() -> float:
	return growth_vigor


func debug_env_parts() -> Dictionary:
	return environment_parts()


## Von Oak.gd ueberschrieben: Pfahlwurzel + Herzwurzelsystem.
func root_candidates(_tip: RootSegment) -> Array[Vector2i]:
	return [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1),
		Vector2i(-1, 0), Vector2i(1, 0)]


func global_tile_for(local_grid: Vector2i) -> Vector2i:
	var ox := int(floor(global_position.x / float(WorldGenerator.TILE_SIZE)))
	var oy := int(floor(global_position.y / float(WorldGenerator.TILE_SIZE)))
	# REVISION 1: logische 16px-Oberflaechenzeile bleibt die Wasser-Referenz.
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
## root_side_every Tiles eine Seitenwurzel (Herzwurzelsystem).
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


func deepest_tip() -> RootSegment:
	var best: RootSegment = null
	for s in root_segments:
		if not s.is_tip:
			continue
		if best == null or s.grid.y > best.grid.y or (
				s.grid.y == best.grid.y and absi(s.grid.x) < absi(best.grid.x)):
			best = s
	return best


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
# REVISION 5: Versorgungs-Bilanz (Wasser / Sonne / Naehrstoffe / Wurzeln)
# --------------------------------------------------------------------------- #
static func fertility_of(kind: int) -> float:
	match kind:
		WorldGenerator.SoilKind.ASH:     return 0.75
		WorldGenerator.SoilKind.HUMUS:   return 1.25
		WorldGenerator.SoilKind.TOPSOIL: return 1.00
		WorldGenerator.SoilKind.CLAY:    return 0.80
		WorldGenerator.SoilKind.ROCK:    return 0.35
		WorldGenerator.SoilKind.STONE:   return 0.30
		WorldGenerator.SoilKind.WATER:   return 1.10
		WorldGenerator.SoilKind.CAVE:    return 0.40
		WorldGenerator.SoilKind.AIR:     return 0.20
	return 1.0


## Echte Bodenqualitaet aus ALLEN Wurzelsegmenten. Ohne Welt (Headless-Smoke)
## bleibt der neutrale Default 1.0, damit alte Tests deterministisch bleiben.
func soil_fertility() -> float:
	if world_generator == null or root_segments.is_empty():
		return 1.0
	var sum := 0.0
	for s in root_segments:
		var gt: Vector2i = s.global_tile()
		sum += fertility_of(world_generator.material_at(gt.x, gt.y))
	return clampf(sum / float(root_segments.size()), 0.25, 1.25)


func environment_parts(p_sunlight: float = -1.0) -> Dictionary:
	var sun := p_sunlight if p_sunlight >= 0.0 else last_sunlight
	var w := clampf((water - 8.0) / 72.0, 0.0, 1.0)
	var s := clampf(sun, 0.0, 1.25)
	var n := clampf(soil_fertility() * nutrient_mult, 0.15, 1.35)
	# Quadratische Wurzelkurve: 1 Wurzel = 0.24, 18 Wurzeln = 1.0.
	var r := clampf(sqrt(float(maxi(root_count, 1)) / 18.0), 0.12, 1.0)
	return {
		"water": w, "sun": s, "nutrients": n, "roots": r,
		"total": clampf(w * s * n * r, 0.0, 1.30),
	}


func environment_factor(p_sunlight: float = -1.0) -> float:
	return float(environment_parts(p_sunlight)["total"])


# --------------------------------------------------------------------------- #
# Simulation
# --------------------------------------------------------------------------- #
## REVISION 5: glucose += leaves * efficiency * growth * difficulty * skill
##   * GLUCOSE_PACE * environment_factor(sunlight) * dt
## Sonne, Wasser, Naehrstoffe und Wurzelmasse wirken jetzt MULTIPLIKATIV.
## Ein Baum mit einer winzigen Wurzel produziert nur noch ~1/4 der Glucose
## eines gut durchwurzelten Baums; zusaetzlich ist das Grundtempo 5x langsamer.
func photosynthesize(dt: float, sunlight: float = 1.0,
		growth: float = 1.0) -> void:
	if not _built or leaves_count <= 0 or water <= 10.0:
		return
	age += dt
	last_sunlight = sunlight
	# Winter: sunlight = 0 und growth = 0 -> Winterruhe (nichts passiert).
	if sunlight <= 0.0 or growth <= 0.0:
		return
	glucose += float(leaves_count) * species.photosynthesis_efficiency \
		* growth * Global.difficulty_factor("photosynthesis") \
		* skill_glucose_mult * GLUCOSE_PACE \
		* environment_factor(sunlight) * dt
	water = maxf(water - species.water_consumption_rate \
		* Global.difficulty_factor("water_consumption") \
		* skill_water_consumption_mult * dt, 0.0)


## rate kommt von WaterSystem (Boden + Reservoir + Regen).
func absorb_water(dt: float, rate: float) -> void:
	if not _built:
		return
	water = clampf(water + rate * skill_root_water_mult * dt, 0.0, 100.0)


# --------------------------------------------------------------------------- #
# Info / Save
# --------------------------------------------------------------------------- #
func get_bounds_rect() -> Rect2:
	var h := float(trunk_tiles) * TRUNK_STEP
	var crown := 90.0 + 20.0 * float(growth_stage())
	var deepest := 2
	for s in root_segments:
		deepest = maxi(deepest, s.grid.y + 2)
	var rd := float(deepest) * float(WorldGenerator.TILE_SIZE)
	var top := -h - crown
	return Rect2(global_position + Vector2(-170.0, top),
		Vector2(340.0, h + crown + rd))


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
		"skill_leaf_grants": skill_leaf_grants,
		"nutrient_mult": nutrient_mult,
		"root_segments": segments,
	}


func from_dict(d: Dictionary) -> void:
	# PHASE-4-FIX: geskillte Blattobergrenze muss VOR add_leaf() bekannt sein.
	var st := SkillTree.instance
	if st != null:
		skill_glucose_mult = st.modifier("glucose")
		skill_water_consumption_mult = st.modifier("water_consumption")
		skill_root_water_mult = st.modifier("root_water")
		skill_max_leaves_bonus = int(roundf(st.bonus("max_leaves")))
		nutrient_mult = float(d.get("nutrient_mult", st.modifier("nutrients")))
	else:
		nutrient_mult = float(d.get("nutrient_mult", 1.0))
	skill_leaf_grants = int(d.get("skill_leaf_grants", 0))
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
