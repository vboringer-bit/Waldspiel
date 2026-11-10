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
## REVISION 6: Stamm, Aeste und Wurzeln sind GEZIELT ZIEHBAR (Drag), jede
##   bereits verbundene Faser verdickt sich bei weiterem Wachstum, alle
##   Hauptfasern laufen ueber PixelArt.draw_fibre() und der Skilltree kann
##   genug Blaetter fuer eine wirklich dichte Krone liefern.

const TRUNK_PATH := PixelArt.TRUNK
const LEAF_PATH := PixelArt.LEAF
const ROOT_PATH := PixelArt.ROOT
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

## REVISION 6: freie Zug-Schritte. Das logische 16px-Raster bleibt fuer
## Wasser/Save erhalten, die SICHTBARE Geometrie folgt dem Mauspfad.
const DRAG_STEP := 16.0
const MAX_CUSTOM_BRANCHES := 24
const MAX_GUIDE_POINTS := 96
const NO_FREE_TARGET := Vector2(1.0e9, 1.0e9)

## REVISION 7: Lichtkonkurrenz. Stehen Baeume dichter als CROWD_RADIUS,
## beschattet der groessere Nachbar den kleineren. Statt zwei ausgewachsene
## Kronen uebereinander zu zeichnen, bleibt der beschattete Baum sichtbar
## kleiner (Stamm, Blaetter, Wurzeln und gezogene Aeste werden mitbegrenzt)
## und produziert entsprechend weniger Glucose.
const CROWD_RADIUS := 170.0
const CROWD_MIN_LIGHT := 0.38
const CROWD_SHADE_STRENGTH := 0.75

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
## REVISION 6: "Dichte Krone" schaltet zusaetzliche Deko-Blaetter frei.
var skill_leaf_density: int = 0
## PHASE 5: Pilz-Symbiose erhoeht die Naehrstoff-Versorgung (mushroom_node).
var nutrient_mult: float = 1.0
## REVISION 7: Skilltree-Mods gegen die Lichtkonkurrenz.
var crowd_tolerance: float = 0.0
var shade_gain: float = 0.0

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
var _leaf_decor_c: Array[Sprite2D] = []
var _leaf_decor_d: Array[Sprite2D] = []
var _occupied: Dictionary = {}
var _built: bool = false

## REVISION 5: gecachte, deterministische Freiform-Geometrie. Sie wird bei
## jedem Wachstumsschritt neu berechnet, aber NICHT pro Frame zufaellig
## verwuerfelt -> kein Flackern, Save/Load ohne extra Geometrie-Daten.
var _skel_trunk: Array[Vector2] = []
var _skel_branches: Array[Dictionary] = []
var _skel_anchors: Array[Vector2] = []

## REVISION 6: vom Spieler gezogene Geometrie (lokal zum Baum).
## trunk_guide = Form des Stammes; branch_paths = zusaetzliche freie Aeste.
## Beide werden im Savegame mitgefuehrt (Format v6, optionale Felder).
var trunk_guide: Array[Vector2] = []
var branch_paths: Array = []
var _growth_preview: PackedVector2Array = PackedVector2Array()
var _growth_preview_kind: String = ""


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
# REVISION 7: Lichtkonkurrenz / Beschattung durch Nachbarbaeume
# --------------------------------------------------------------------------- #
## Staerkster Schattenwurf aller Nachbarn innerhalb von CROWD_RADIUS. Ein
## Keimling beschattet kaum, ein ausgewachsener Baum voll. `crowd_tolerance`
## aus dem Skilltree reduziert den Schatten (Lichtsucher / Waldrand).
func neighbor_shade() -> float:
	if not is_inside_tree():
		return 0.0
	var shade := 0.0
	for n in get_tree().get_nodes_in_group("trees"):
		if n == self or not (n is BaseTree):
			continue
		var other := n as BaseTree
		var d := absf(other.global_position.x - global_position.x)
		# Exakt gleiche Position = Snapshot-/Test-Duplikat, kein echter
		# Nachbar (sonst wuerde z.B. ein Save-Probe den Originalbaum beschatten).
		if d < 1.0 or d >= CROWD_RADIUS:
			continue
		var maturity := clampf(float(other.trunk_tiles) / float(MAX_TRUNK),
			0.25, 1.0)
		shade = maxf(shade, (1.0 - d / CROWD_RADIUS) * maturity)
	return clampf(shade * (1.0 - clampf(crowd_tolerance, 0.0, 0.80)),
		0.0, 1.0)


func light_factor() -> float:
	return clampf(1.0 - CROWD_SHADE_STRENGTH * neighbor_shade(),
		CROWD_MIN_LIGHT, 1.0)


func crowd_cap_of(max_value: int, minimum: int) -> int:
	var lf := light_factor()
	if lf >= 0.999:
		return max_value
	return maxi(minimum, int(roundf(float(max_value) * lf)))


## Harte, aber weiche Obergrenze: ein dichter Stand bleibt klein, statt
## irgendwann doch die volle Krone in den Nachbarn hineinzuschieben.
func crowd_cap(part: String) -> int:
	match part:
		"trunk": return crowd_cap_of(MAX_TRUNK, 2)
		"leaf": return crowd_cap_of(MAX_LEAVES + skill_max_leaves_bonus, 2)
		"root": return crowd_cap_of(MAX_ROOTS, 1)
		"branch": return crowd_cap_of(MAX_CUSTOM_BRANCHES, 2)
	return 999999


# --------------------------------------------------------------------------- #
# Wachstum (PHASE 1 API bleibt erhalten)
# --------------------------------------------------------------------------- #
func add_trunk_tile() -> bool:
	if trunk_tiles >= crowd_cap("trunk"):
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
	# REVISION 7: beschattete Baeume behalten eine kleinere Krone.
	if leaves_count >= crowd_cap("leaf"):
		return false
	# REVISION 5: Blaetter sitzen an freien Astspitzen statt im 4-Spalten-Raster.
	# Zwei kleine Deko-Blaetter pro logischem Blatt verdichten die Krone,
	# ohne leaves_count (und damit die P0-P5-Smokes) zu veraendern.
	var main := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	var a := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	var b := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	var c := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	var d := _sprite(LEAF_PATH, Vector2.ZERO, _leaves)
	a.modulate = Color(0.86, 0.96, 0.80, 0.95)
	b.modulate = Color(0.94, 1.00, 0.88, 0.95)
	c.modulate = Color(0.80, 0.94, 0.74, 0.95)
	d.modulate = Color(0.90, 0.98, 0.84, 0.95)
	c.visible = false
	d.visible = false
	_leaf_sprites.append(main)
	_leaf_decor_a.append(a)
	_leaf_decor_b.append(b)
	_leaf_decor_c.append(c)
	_leaf_decor_d.append(d)
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
		return maxi(root_segments.size(), root_count) < crowd_cap("root")
	if part == "leaf":
		return leaves_count < crowd_cap("leaf")
	if part == "trunk":
		return trunk_tiles < crowd_cap("trunk")
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
		p_parent: RootSegment, p_keep_parent_tip: bool = false,
		p_free_target: Vector2 = NO_FREE_TARGET) -> RootSegment:
	var seg := RootSegment.new()
	_roots.add_child(seg)
	seg.setup(self, p_grid, p_dir, p_parent)
	seg.set_free_target(p_free_target)
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
		# REVISION 6: ALLE vorhandenen Stammsegmente werden dicker, sobald
		# weiterer Stamm waechst (nicht nur das neueste Segment).
		var w := minf(_trunk_width_at(i, stage), 1.0)
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


func _trunk_width_at(i: int, stage: int) -> float:
	return maxf(float(STAGE_WIDTHS[stage]) \
		* (1.0 + 0.012 * float(trunk_tiles)) \
		* (1.0 - 0.045 * float(i)), 0.16)


## REVISION 6: Bogenlaengen-normalisierter Punkt auf einer freien Polylinie.
func _sample_polyline(points: Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		var only: Vector2 = points[0]
		return only
	var total := 0.0
	for i in range(points.size() - 1):
		var pa: Vector2 = points[i]
		var pb: Vector2 = points[i + 1]
		total += (pb - pa).length()
	if total <= 0.001:
		var first: Vector2 = points[0]
		return first
	var want := clampf(t, 0.0, 1.0) * total
	var walked := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var d := (b - a).length()
		if walked + d >= want:
			return a.lerp(b, (want - walked) / maxf(d, 0.001))
		walked += d
	var last: Vector2 = points[points.size() - 1]
	return last


## Pfad in gleichmaessige freie Schritte zerlegen (fuer Drag + Guides).
func _resample_path(points: Array, step: float, limit: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if points.is_empty():
		return out
	var start: Vector2 = points[0]
	out.append(start)
	var carry := 0.0
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var remaining := (b - a).length()
		while remaining >= maxf(step - carry, 0.001):
			var need := maxf(step - carry, 0.001)
			var f := clampf(need / maxf(remaining, 0.001), 0.0, 1.0)
			var q := a.lerp(b, f)
			out.append(q)
			if out.size() >= limit:
				return out
			a = q
			remaining = (b - a).length()
			carry = 0.0
		carry += remaining
	return out


func _rebuild_skeleton() -> void:
	_skel_trunk.clear()
	_skel_branches.clear()
	_skel_anchors.clear()
	var h := float(trunk_tiles) * TRUNK_STEP
	var stage := growth_stage()
	var n := maxi(trunk_tiles, 2)
	var phase := _h(0, 0, 1) * TAU
	var amp := 2.0 + 1.5 * float(stage)
	if trunk_guide.size() >= 2:
		# REVISION 6: der Spieler hat den Stamm gezogen. Die x-Form folgt
		# dem Pfad, die Hoehe bleibt deterministisch aus trunk_tiles.
		var guide := _resample_path(trunk_guide, TRUNK_STEP, MAX_GUIDE_POINTS)
		for i in range(n + 1):
			var t := float(i) / float(n)
			var gp := _sample_polyline(guide, t)
			_skel_trunk.append(Vector2(gp.x, -h * t))
	else:
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
		var curve_pts := _curve(origin, mid, bend, 7)
		for ci in range(1, curve_pts.size()):
			_skel_anchors.append(curve_pts[ci])
		for tw in twigs:
			_skel_anchors.append(tw)
			_skel_anchors.append(bend.lerp(tw, 0.30))
			_skel_anchors.append(bend.lerp(tw, 0.75))
	# REVISION 6: auch die Stammspitze traegt Blaetter (kein kahler Gipfel).
	if not _skel_trunk.is_empty():
		var tip_top: Vector2 = _skel_trunk[_skel_trunk.size() - 1]
		for q in range(6):
			var ang2 := TAU * float(q) / 6.0
			_skel_anchors.append(tip_top + Vector2(
				cos(ang2) * 18.0, -6.0 + sin(ang2) * 12.0))
	# REVISION 6: gezogene Aeste liefern zusaetzliche Blatt-Anker, damit
	# geskillte Blaetter auch wirklich an den neuen Zweigen sitzen.
	for bp in branch_paths:
		var cp: PackedVector2Array = bp
		if cp.size() < 2:
			continue
		for j in range(1, cp.size(), 2):
			_skel_anchors.append(cp[j])
		_skel_anchors.append(cp[cp.size() - 1])
	if _skel_anchors.is_empty():
		var top: Vector2 = _skel_trunk[n]
		_skel_anchors.append(top + Vector2(-11.0, -8.0))
		_skel_anchors.append(top + Vector2(11.0, -8.0))


func _leaf_anchor_index(i: int) -> int:
	var n := maxi(_skel_anchors.size(), 1)
	# Goldener-Schnitt-Folge: auch WENIGE Blaetter verteilen sich ueber die
	# ganze Krone statt nur die ersten Aeste zu belegen (kahl bleibende Aeste).
	var f := fmod(float(i) * 0.61803398875, 1.0)
	return clampi(int(f * float(n)), 0, n - 1)


func _leaf_anchor(i: int) -> Vector2:
	var base: Vector2 = _skel_anchors[_leaf_anchor_index(i)]
	var spread := (8.0 + 2.0 * float(growth_stage())) \
		* (1.0 + 0.30 * float(skill_leaf_density))
	return base + Vector2((_h(i, 2, 8) - 0.5) * 2.0 * spread,
		(_h(i, 3, 9) - 0.5) * 1.4 * spread)


func _layout_leaves(stage: int) -> void:
	var density := 1.0 + 0.30 * float(skill_leaf_density)
	var sc := (1.05 + 0.14 * float(stage)) * (1.0 + 0.06 * float(skill_leaf_density))
	for i in _leaf_sprites.size():
		var anchor := _leaf_anchor(i)
		var main := _leaf_sprites[i]
		main.scale = Vector2(sc, sc)
		main.position = anchor - Vector2(8.0 * sc, 8.0 * sc)
		var a := _leaf_decor_a[i]
		var b := _leaf_decor_b[i]
		var off := (10.0 + 3.0 * float(stage)) * density
		var ds := sc * 0.55
		a.scale = Vector2(ds, ds)
		b.scale = Vector2(ds, ds)
		a.position = anchor + Vector2(-off, 4.0) - Vector2(8.0 * ds, 8.0 * ds)
		b.position = anchor + Vector2(off * 0.7, -off * 0.6) \
			- Vector2(8.0 * ds, 8.0 * ds)
		var c := _leaf_decor_c[i]
		var d := _leaf_decor_d[i]
		c.visible = skill_leaf_density >= 1
		d.visible = skill_leaf_density >= 2
		c.scale = Vector2(ds, ds)
		d.scale = Vector2(ds, ds)
		c.position = anchor + Vector2(-off * 0.45, -off * 0.85) \
			- Vector2(8.0 * ds, 8.0 * ds)
		d.position = anchor + Vector2(off * 0.95, off * 0.40) \
			- Vector2(8.0 * ds, 8.0 * ds)


func _draw() -> void:
	if trunk_tiles <= 0 or _skel_trunk.is_empty():
		return
	var stage := growth_stage()
	var bark := Color(0.34, 0.23, 0.15).lerp(
		Color(0.46, 0.31, 0.19), float(stage) / 4.0)
	var dark := PixelArt.BARK_DARK
	# Wurzelhals: kurze freie Strahlen vom Stamm in den Boden.
	for r in range(5):
		var j := _h(r, 30, 5)
		var e := Vector2((float(r) - 2.0) * 7.0 + (j - 0.5) * 6.0,
			9.0 + 12.0 * j + 2.0 * float(stage))
		draw_line(Vector2.ZERO, e, dark, 2.4)
		draw_line(Vector2.ZERO, e, bark, 1.2)
	# Stamm: leicht geschwungene, nach oben verjuengte Freiform-Kurve.
	# REVISION 6: Hauptfaser ist eine gekachelte 16x16-Pixelart-Textur.
	var segs := maxi(_skel_trunk.size() - 1, 1)
	for i in range(_skel_trunk.size() - 1):
		var t := float(i) / float(segs)
		var w := lerpf(3.0 + 2.8 * float(stage) + 0.10 * float(trunk_tiles), 1.2, t)
		var a: Vector2 = _skel_trunk[i]
		var b: Vector2 = _skel_trunk[i + 1]
		draw_line(a, b, dark, w + 1.4)
		PixelArt.draw_fibre(self, PixelArt.TRUNK, a, b, w,
			Color(1.0, 1.0, 1.0, 0.96))
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
			PixelArt.draw_fibre(self, PixelArt.BRANCH, pts[i], pts[i + 1], w,
				Color(1.0, 1.0, 1.0, 0.94))
		var twigs: Array = bd["twigs"]
		for tw in twigs:
			var tip: Vector2 = tw
			var mid2 := e.lerp(tip, 0.55) + Vector2(0.0, -2.0)
			var twig_pts := _curve(e, mid2, tip, 5)
			var twig_w := maxf(0.8, bw * 0.45)
			draw_polyline(twig_pts, dark, twig_w + 0.9)
			for q in range(twig_pts.size() - 1):
				PixelArt.draw_fibre(self, PixelArt.BRANCH,
					twig_pts[q], twig_pts[q + 1], twig_w,
					Color(1.0, 1.0, 1.0, 0.92))
		draw_circle(e, maxf(1.0, bw * 0.55), Color(0.52, 0.38, 0.22))
	# REVISION 6: vom Spieler gezogene Aeste (frei, texture-basiert).
	for bp in branch_paths:
		var cp: PackedVector2Array = bp
		if cp.size() < 2:
			continue
		for i in range(cp.size() - 1):
			var cw := maxf(1.2, 2.8 - 0.06 * float(i))
			draw_line(cp[i], cp[i + 1], dark, cw + 1.0)
			PixelArt.draw_fibre(self, PixelArt.BRANCH, cp[i], cp[i + 1], cw,
				Color(1.0, 1.0, 1.0, 0.94))
		draw_circle(cp[cp.size() - 1], 2.0, Color(0.58, 0.42, 0.24))
	# REVISION 6: halbtransparente Vorschau waehrend des Ziehens.
	if _growth_preview.size() >= 2:
		var hint := Color(0.72, 1.0, 0.68, 0.55)
		for i in range(_growth_preview.size() - 1):
			if i % 2 == 0:
				draw_line(_growth_preview[i], _growth_preview[i + 1], hint, 2.2)
		draw_circle(_growth_preview[_growth_preview.size() - 1], 4.0, hint)


# --------------------------------------------------------------------------- #
# REVISION 6: gezielt ziehen (Mycelarium-artig)
# --------------------------------------------------------------------------- #
func show_growth_preview(kind: String, world_points: PackedVector2Array) -> void:
	_growth_preview_kind = kind
	_growth_preview = PackedVector2Array()
	for p in world_points:
		_growth_preview.append(to_local(p))
	queue_redraw()


func clear_growth_preview() -> void:
	_growth_preview = PackedVector2Array()
	_growth_preview_kind = ""
	queue_redraw()


func _nearest_wood_anchor(local_pos: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := 1.0e9
	for p in _skel_trunk:
		var d := local_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	for a in _skel_anchors:
		var d2 := local_pos.distance_to(a)
		if d2 < best_d:
			best_d = d2
			best = a
	return best


## Zieht eine Wurzel entlang des Mauspfades. Das LOGISCHE 16px-Raster bleibt
## fuer Wasser/Save/Klick erhalten; die gezeichnete Faser folgt `free_target`.
func grow_root_along(world_points: PackedVector2Array, max_steps: int,
		from_segment: RootSegment = null) -> int:
	if world_points.size() < 2 or max_steps <= 0:
		return 0
	var locals: Array[Vector2] = []
	for w in world_points:
		locals.append(to_local(w))
	var sampled := _resample_path(locals, DRAG_STEP, max_steps + 2)
	var tip := tip_for(from_segment)
	if tip == null:
		tip = deepest_tip()
	if tip == null:
		return 0
	var made := 0
	for idx in range(1, sampled.size()):
		if made >= max_steps or not can_grow("root"):
			break
		var p: Vector2 = sampled[idx]
		p.y = maxf(p.y, 8.0)
		var wanted := Vector2i(int(roundf(p.x / float(WorldGenerator.TILE_SIZE))),
			int(roundf(p.y / float(WorldGenerator.TILE_SIZE))))
		wanted.y = maxi(wanted.y, 0)
		var delta := wanted - tip.grid
		if delta == Vector2i.ZERO:
			continue
		var primary := Vector2i(clampi(delta.x, -1, 1), clampi(delta.y, -1, 1))
		var options: Array[Vector2i] = [
			primary,
			Vector2i(primary.x, 0), Vector2i(0, primary.y),
			Vector2i(primary.x, -primary.y), Vector2i(-primary.x, primary.y),
			Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		]
		var chosen := Vector2i.ZERO
		var chosen_grid := Vector2i.ZERO
		for opt in options:
			if opt == Vector2i.ZERO:
				continue
			var g: Vector2i = tip.grid + opt
			if g.y < 0 or not _is_free(g):
				continue
			chosen = opt
			chosen_grid = g
			break
		if chosen == Vector2i.ZERO:
			continue
		var seg := _add_root_segment(chosen_grid, chosen, tip, false, p)
		if seg == null:
			continue
		tip = seg
		made += 1
	_refresh_growth_visuals()
	return made


## Zieht den Stamm nach oben oder einen neuen Ast in eine freie Richtung.
## Rueckgabe = Anzahl bezahlter Wachstumsschritte.
func grow_wood_along(world_points: PackedVector2Array, max_steps: int) -> int:
	if world_points.size() < 2 or max_steps <= 0:
		return 0
	var locals: Array[Vector2] = []
	for w in world_points:
		locals.append(to_local(w))
	var length := 0.0
	for i in range(1, locals.size()):
		length += (locals[i] - locals[i - 1]).length()
	var steps := clampi(int(ceilf(length / DRAG_STEP)), 1, max_steps)
	var start: Vector2 = locals[0]
	var finish: Vector2 = locals[locals.size() - 1]
	var is_trunk := finish.y < start.y - 8.0 and absf(start.x) < 70.0
	if is_trunk:
		var guide: Array[Vector2] = []
		for sp in _skel_trunk:
			guide.append(sp)
		for lp in locals:
			if guide.is_empty() or (lp - guide[guide.size() - 1]).length() > 3.0:
				guide.append(lp)
		trunk_guide = _resample_path(guide, DRAG_STEP, MAX_GUIDE_POINTS)
		var addable := mini(steps, crowd_cap("trunk") - trunk_tiles)
		var added := 0
		for _i in addable:
			if add_trunk_tile():
				added += 1
		_refresh_growth_visuals()
		return maxi(added, 1)
	var origin := _nearest_wood_anchor(start)
	var raw: Array[Vector2] = [origin]
	for lp in locals:
		raw.append(lp)
	raw = _resample_path(raw, DRAG_STEP, 64)
	var path := PackedVector2Array()
	for rp in raw:
		path.append(rp)
	if path.size() < 2:
		return 0
	# REVISION 7: auch frei gezogene Aeste bleiben bei dichtem Stand kleiner.
	if branch_paths.size() >= crowd_cap("branch"):
		return 0
	branch_paths.append(path)
	while branch_paths.size() > crowd_cap("branch"):
		branch_paths.remove_at(0)
	# Ein Astzug verdickt ebenfalls alle bereits vorhandenen Stammsegmente.
	if trunk_tiles < MAX_TRUNK:
		add_trunk_tile()
	_refresh_growth_visuals()
	return steps


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


## REVISION 7 Debug-Hooks ----------------------------------------------------
func debug_neighbor_shade() -> float:
	return neighbor_shade()


func debug_light_factor() -> float:
	return light_factor()


func debug_is_crowded() -> bool:
	return neighbor_shade() > 0.001


func debug_crowd_cap(part: String) -> int:
	return crowd_cap(part)


func debug_leaf_spread() -> float:
	var best := 0.0
	for a in _skel_anchors:
		best = maxf(best, absf(a.x))
	return best


func debug_growth_vigor() -> float:
	return growth_vigor


func debug_env_parts() -> Dictionary:
	return environment_parts()


## REVISION 6 Debug-Hooks ----------------------------------------------------
func debug_custom_branch_count() -> int:
	return branch_paths.size()


func debug_anchor_count() -> int:
	return _skel_anchors.size()


func debug_leaf_anchor_indices() -> Array:
	var out: Array = []
	for i in _leaf_sprites.size():
		out.append(_leaf_anchor_index(i))
	return out


func debug_trunk_segment_widths() -> Array:
	var out: Array = []
	var stage := growth_stage()
	for i in _trunk_sprites.size():
		out.append(_trunk_width_at(i, stage))
	return out


func debug_trunk_draw_width() -> float:
	return lerpf(3.0 + 2.8 * float(growth_stage()) \
		+ 0.10 * float(trunk_tiles), 1.2, 0.0)


func debug_root_free_target(i: int) -> Vector2:
	if i < 0 or i >= root_segments.size():
		return Vector2.ZERO
	var seg := root_segments[i]
	return seg.free_target if seg.has_free_target else Vector2.ZERO


func debug_preview_length() -> float:
	return float(_growth_preview.size())


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
	# REVISION 7: weniger Licht durch den Nachbarn = weniger Glucose.
	# "Schattenlaub" (shade_gain) kompensiert einen Teil davon.
	var shade := neighbor_shade()
	var lf := clampf(1.0 - CROWD_SHADE_STRENGTH * shade,
		CROWD_MIN_LIGHT, 1.0)
	var compensation := 1.0 + shade_gain * shade
	glucose += float(leaves_count) * species.photosynthesis_efficiency \
		* growth * Global.difficulty_factor("photosynthesis") \
		* skill_glucose_mult * GLUCOSE_PACE \
		* environment_factor(sunlight) * lf * compensation * dt
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


func _vecs_to_data(points: Array) -> Array:
	var out: Array = []
	for v in points:
		var p: Vector2 = v
		out.append([p.x, p.y])
	return out


func _vecs_from_data(data: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e in data:
		var pair: Array = e
		if pair.size() >= 2:
			out.append(Vector2(float(pair[0]), float(pair[1])))
	return out


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
			# REVISION 6: freier Zielpunkt der gezeichneten Faser.
			"free": s.has_free_target,
			"fx": s.free_target.x,
			"fy": s.free_target.y,
		})
	var paths: Array = []
	for bp in branch_paths:
		var cp: PackedVector2Array = bp
		var arr: Array = []
		for q in cp:
			arr.append([q.x, q.y])
		paths.append(arr)
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
		# REVISION 6: optionale Felder. Alte v6-Saves ohne sie bleiben lesbar.
		"trunk_guide": _vecs_to_data(trunk_guide),
		"branch_paths": paths,
		"skill_leaf_density": skill_leaf_density,
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
		# REVISION 7: Licht-Skills auch nach Spielstand-Laden wirksam.
		crowd_tolerance = clampf(st.bonus("crowd_tolerance"), 0.0, 0.80)
		shade_gain = clampf(st.bonus("shade_gain"), 0.0, 1.0)
	else:
		nutrient_mult = float(d.get("nutrient_mult", 1.0))
		crowd_tolerance = 0.0
		shade_gain = 0.0
	skill_leaf_grants = int(d.get("skill_leaf_grants", 0))
	# REVISION 6: gezogene Geometrie + Blattdichte VOR den Blatt-Sprites laden.
	var saved_guide: Array = d.get("trunk_guide", [])
	trunk_guide = _vecs_from_data(saved_guide)
	branch_paths.clear()
	var saved_paths: Array = d.get("branch_paths", [])
	for bp in saved_paths:
		var path_data: Array = bp
		var cp := PackedVector2Array()
		for e in path_data:
			var pair: Array = e
			if pair.size() >= 2:
				cp.append(Vector2(float(pair[0]), float(pair[1])))
		if cp.size() >= 2:
			branch_paths.append(cp)
	skill_leaf_density = int(d.get("skill_leaf_density", 0))
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
			var free := NO_FREE_TARGET
			if bool(e.get("free", false)):
				free = Vector2(float(e.get("fx", 0.0)), float(e.get("fy", 0.0)))
			_add_root_segment(
				Vector2i(int(e.get("x", 0)), int(e.get("y", 0))),
				Vector2i(int(e.get("dx", 0)), int(e.get("dy", 1))),
				parent, true, free)
		for i in segments.size():
			root_segments[i].is_tip = bool(segments[i].get("tip", false))
	_refresh_growth_visuals()
	root_count = root_segments.size()
