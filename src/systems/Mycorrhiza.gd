class_name Mycorrhiza
extends Node2D
## PHASE 6 (Master-Punkt 4.2/6): echtes Mykorrhiza-Netz.
##
## Sobald der Skilltree-Knoten "symbiosis" (bzw. "mushroom_node") frei-
## geschaltet ist, verbindet ein Pilzgeflecht alle Baeume innerhalb von
## LINK_RADIUS. Die Hyphen werden als eigener, ortsfester Node2D im
## Bodenquerschnitt gezeichnet (top_level, absolute z=38) - dieselbe
## Technik wie der BurrowTrail aus REVISION 7.
##
## Wirkung: Bei SCHWER ist das Netz NOETIG. Ohne Symbiose wird der
## Naehrstofffaktor auf NO_NETWORK_PENALTY gedrosselt; mit Netz erhalten
## vernetzte Baeume gradabhaengig bis zu +40 % Naehrstoffe. Bei LEICHT/
## NORMAL bleibt der Faktor exakt 1.0, damit alle R0-R8-Smokes unveraendert
## bleiben. Gezeichnet wird das Netz in allen Schwierigkeiten, sobald der
## Skill aktiv ist.

const LINK_RADIUS := 280.0
const REBUILD_INTERVAL := 0.5
const NO_NETWORK_PENALTY := 0.55
const DEGREE_GAIN := 0.08
const MAX_BONUS := 1.40

static var instance: Mycorrhiza

var generator: WorldGenerator = null
var time_manager: TimeManager = null
var skill_tree: SkillTree = null
var links: Array = []              # [{"a": int, "b": int, "p1": Vector2, "p2": Vector2}]
var _rebuild_timer: float = 0.0
var _phase: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	# top_level: der Netz-Node erbt KEINEN Parent-Transform und zeichnet
	# unveraenderte Weltkoordinaten (siehe DECISIONS §73).
	top_level = true
	z_as_relative = false
	z_index = 38
	EventBus.tree_spawned.connect(_on_tree_spawned)
	EventBus.skill_unlocked.connect(_on_skill_changed)
	EventBus.skilltree_changed.connect(_on_skilltree_changed)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	rebuild()


func setup(p_generator: WorldGenerator, p_time: TimeManager,
		p_skill_tree: SkillTree) -> void:
	generator = p_generator
	time_manager = p_time
	skill_tree = p_skill_tree
	rebuild()


func _on_tree_spawned(_tree: Node) -> void:
	_rebuild_timer = REBUILD_INTERVAL


func _on_skill_changed(_id: String) -> void:
	rebuild()


func _on_skilltree_changed() -> void:
	rebuild()


func _on_difficulty_changed(_value: int) -> void:
	rebuild()


func symbiosis_active() -> bool:
	var st := skill_tree if skill_tree != null else SkillTree.instance
	if st == null:
		return false
	return st.is_unlocked("symbiosis") or st.is_unlocked("mushroom_node")


func is_active() -> bool:
	return Global.difficulty_toggle("mycorrhiza") and symbiosis_active()


func trees() -> Array[BaseTree]:
	var out: Array[BaseTree] = []
	for n in get_tree().get_nodes_in_group("trees"):
		if n is BaseTree and is_instance_valid(n):
			out.append(n as BaseTree)
	return out


## Verbindet alle Baeume paarweise. Bewusst KEIN Viewport-/Kamera-Bezug:
## das Netz gilt weltweit, auch ausserhalb des sichtbaren Ausschnitts.
func rebuild() -> void:
	links.clear()
	if symbiosis_active():
		var ts := trees()
		for i in range(ts.size()):
			for j in range(i + 1, ts.size()):
				var a := ts[i]
				var b := ts[j]
				var d := absf(a.global_position.x - b.global_position.x)
				if d < 1.0 or d >= LINK_RADIUS:
					continue
				links.append({
					"a": a.tree_id, "b": b.tree_id,
					"p1": a.global_position, "p2": b.global_position,
				})
	EventBus.mycorrhiza_changed.emit(links.size())
	queue_redraw()


func degree(tree: BaseTree) -> int:
	var n := 0
	for l in links:
		if int(l["a"]) == tree.tree_id or int(l["b"]) == tree.tree_id:
			n += 1
	return n


## Naehrstoff-Faktor. Nur bei SCHWER wirksam; ohne Netz gibt es dort einen
## echten Malus, mit Netz einen gradabhaengigen Bonus.
func nutrient_bonus(tree: BaseTree) -> float:
	if not Global.difficulty_toggle("mycorrhiza"):
		return 1.0
	if not symbiosis_active():
		return NO_NETWORK_PENALTY
	if tree == null:
		return 1.0
	return clampf(1.0 + DEGREE_GAIN * float(degree(tree)), 1.0, MAX_BONUS)


func _process(delta: float) -> void:
	var dt := time_manager.scaled_delta(delta) if time_manager != null else delta
	_phase += dt
	_rebuild_timer += delta
	if _rebuild_timer >= REBUILD_INTERVAL:
		_rebuild_timer = 0.0
		rebuild()
	if symbiosis_active():
		queue_redraw()


func _draw() -> void:
	if links.is_empty():
		return
	var strong := is_active()
	var hypha := Color(0.72, 0.68, 0.48, 0.52 if strong else 0.32)
	var glow := Color(0.86, 0.80, 0.56, 0.20 if strong else 0.10)
	for l in links:
		var p1: Vector2 = l["p1"]
		var p2: Vector2 = l["p2"]
		var mid := (p1 + p2) * 0.5
		var sag := 26.0 + 10.0 * sin(_phase * 0.7 + float(l["a"]))
		var curve := PackedVector2Array()
		curve.append(Vector2(p1.x, p1.y + 8.0))
		curve.append(Vector2(lerpf(p1.x, mid.x, 0.5), p1.y + 14.0 + sag))
		curve.append(Vector2(mid.x, mid.y + 18.0 + sag))
		curve.append(Vector2(lerpf(mid.x, p2.x, 0.5), p2.y + 14.0 + sag))
		curve.append(Vector2(p2.x, p2.y + 8.0))
		draw_polyline(curve, glow, 5.0)
		draw_polyline(curve, hypha, 1.6)
		for i in range(1, 4):
			draw_circle(curve[i], 1.4, hypha)
	# Kleine Fruchtkoerper an den Stammbasen.
	var seen := {}
	for l in links:
		for key in ["p1", "p2"]:
			var q: Vector2 = l[key]
			var id := "%d:%d" % [int(round(q.x)), int(round(q.y))]
			if seen.has(id):
				continue
			seen[id] = true
			draw_circle(Vector2(q.x, q.y + 9.0), 2.4,
				Color(0.78, 0.70, 0.48, 0.62 if strong else 0.38))


func to_dict() -> Dictionary:
	return {"active": symbiosis_active(), "links": links.size()}


func from_dict(_d: Dictionary) -> void:
	rebuild()


# --------------------------------------------------------------------------- #
# Debug-Hooks
# --------------------------------------------------------------------------- #
func debug_link_count() -> int:
	return links.size()


func debug_active() -> bool:
	return is_active()


func debug_skill_active() -> bool:
	return symbiosis_active()


func debug_bonus(tree: BaseTree) -> float:
	return nutrient_bonus(tree)


func debug_penalty() -> float:
	return NO_NETWORK_PENALTY


func debug_force_rebuild() -> void:
	rebuild()
