class_name SkillTree
extends Node
## PHASE 4 (Master-Punkt 6): Skilltree PRO BAUMART, global synchron.
##
## * `data/skilltrees/oak.tres` enthaelt 24 SkillNodeData-Knoten (15 MVP +
##   3 "Dichte Krone" aus R6 + 6 Licht-/Jahreszeit-Mutationen aus R7).
##   Jeder Knoten hat Glucose-Kosten, Vorbedingungen und echte Effekte.
## * Der Freischalt-Zustand liegt NUR hier. Alle Eichen-Instanzen teilen ihn;
##   beim Freischalten wird `apply_effect(tree_instance)` auf JEDEN Baum
##   angewandt (und auf neu spawnende Baeume automatisch).
## * Glucose bleibt laut Master-Punkt 4.2 PRO BAUMINSTANZ. Die Kosten werden
##   deshalb vom aktuell ausgewaehlten Baum bezahlt (siehe DECISIONS §64).
## * Resistenz-Effekte (Parasiten / Krankheit / Sturm) sind bereits als echte
##   Zahlenwerte im Baum gespeichert; die zugehoerige Ereignis-Simulation
##   bleibt bewusst PHASE 5.

const DATA_PATH := "res://data/skilltrees/oak.tres"

## Statischer Singleton-Zugriff: kein zusaetzlicher Autoload noetig.
static var instance: SkillTree

var data: SkillTreeData
var unlocked: Dictionary = {}          # node_id -> true
var _mods: Dictionary = {}             # effect_key -> Summe aller Werte


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	if data == null and ResourceLoader.exists(DATA_PATH):
		data = load(DATA_PATH) as SkillTreeData
	if not EventBus.tree_spawned.is_connected(_on_tree_spawned):
		EventBus.tree_spawned.connect(_on_tree_spawned)
	_recompute_mods()
	_apply_to_all()
	EventBus.skilltree_changed.emit()


func _on_tree_spawned(tree: Node) -> void:
	_apply_all(tree)


# --------------------------------------------------------------------------- #
# Daten / Abfragen
# --------------------------------------------------------------------------- #
func all_nodes() -> Array[SkillNodeData]:
	return data.nodes if data != null else []


func node_data(id: String) -> SkillNodeData:
	for n in all_nodes():
		if n.id == id:
			return n
	return null


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func unlocked_count() -> int:
	return unlocked.size()


## Alle Vorbedingungen erfuellt?
func is_available(id: String) -> bool:
	var nd := node_data(id)
	if nd == null:
		return false
	for p in nd.prerequisites:
		if not unlocked.has(p):
			return false
	return true


## Master-Punkt 6: `can_unlock()` prueft Kosten + Vorbedingung.
func can_unlock(id: String, payer: BaseTree) -> bool:
	if unlocked.has(id) or not is_available(id) or payer == null:
		return false
	var nd := node_data(id)
	return nd != null and payer.glucose >= nd.cost


func cost_of(id: String) -> float:
	var nd := node_data(id)
	return nd.cost if nd != null else 0.0


func connection_pairs() -> Array:
	var out: Array = []
	for n in all_nodes():
		for p in n.prerequisites:
			out.append([p, n.id])
	return out


# --------------------------------------------------------------------------- #
# Effekte
# --------------------------------------------------------------------------- #
func _recompute_mods() -> void:
	_mods.clear()
	for n in all_nodes():
		if not unlocked.has(n.id):
			continue
		for key in n.effects.keys():
			_mods[key] = float(_mods.get(key, 0.0)) + float(n.effects[key])


## Multiplikator: 1 + Summe aller Werte (z.B. +0.25 => 1.25, -0.20 => 0.80).
func modifier(key: String) -> float:
	return maxf(0.0, 1.0 + float(_mods.get(key, 0.0)))


## Reine Summe (z.B. +2 zusaetzliche Blaetter).
func bonus(key: String) -> float:
	return float(_mods.get(key, 0.0))


## PHASE 5: aktive Widerstandswerte (0.5 = -50 % Spawn-/Entzugs-Risiko).
func resistance(key: String) -> float:
	return modifier(key)


## Master-Punkt 6: wendet den Effekt eines Knotens auf EINE Baum-Instanz an.
## Da der Skilltree global synchron ist, werden alle Instanzen auf denselben
## Stand gebracht; neue Baeume bekommen ihn ueber `tree_spawned` automatisch.
func apply_effect(_node_id: String, tree_instance: Node) -> void:
	if not (tree_instance is BaseTree):
		return
	var t := tree_instance as BaseTree
	t.skill_glucose_mult = modifier("glucose")
	t.skill_water_consumption_mult = modifier("water_consumption")
	t.skill_root_water_mult = modifier("root_water")
	t.skill_max_leaves_bonus = int(roundf(bonus("max_leaves")))
	# REVISION 6: "Dichte Krone" macht aus 2+38 Blaettern eine volle Krone.
	t.skill_leaf_density = int(roundf(bonus("leaf_density")))
	# REVISION 7: Lichtsucher/Waldrand verringern den Schattenwurf des
	# Nachbarn, Schattenlaub kompensiert den Glucose-Verlust im Schatten.
	t.crowd_tolerance = clampf(bonus("crowd_tolerance"), 0.0, 0.80)
	t.shade_gain = clampf(bonus("shade_gain"), 0.0, 1.0)
	# PHASE 5: Pilz-Knoten gibt echte Naehrstoffe (+15 % Fotosynthese).
	t.nutrient_mult = modifier("nutrients")
	# PHASE-4-FIX: "Kronenwuchs" schenkt die +2 Blaetter sofort sichtbar.
	# Idempotent, weil apply_effect() bei jedem Refresh / Spielstand-Laden
	# erneut auf allen Baeumen laeuft.
	t.apply_skill_leaf_grants(int(roundf(bonus("grant_leaves"))))


func _apply_all(tree: Node) -> void:
	for id in unlocked.keys():
		apply_effect(String(id), tree)


func _apply_to_all() -> void:
	for tree in get_tree().get_nodes_in_group("trees"):
		_apply_all(tree)


# --------------------------------------------------------------------------- #
# Freischalten
# --------------------------------------------------------------------------- #
func unlock(id: String, payer: BaseTree) -> bool:
	if not can_unlock(id, payer):
		if not is_available(id):
			EventBus.toast.emit(tr("MSG_SKILL_PREREQ"))
		elif payer == null:
			EventBus.toast.emit(tr("MSG_SKILL_NO_TREE"))
		else:
			EventBus.toast.emit(tr("MSG_SKILL_NO_GLUCOSE"))
		return false
	var nd := node_data(id)
	payer.glucose -= nd.cost
	unlocked[id] = true
	_recompute_mods()
	_apply_to_all()
	EventBus.glucose_changed.emit(payer, payer.glucose)
	EventBus.skill_unlocked.emit(id)
	EventBus.skilltree_changed.emit()
	EventBus.toast.emit(tr("MSG_SKILL_UNLOCKED") % tr(nd.title_key))
	return true


## Debug/Screenshot: ohne Glucose-Kosten freischalten (P4-Presets).
func debug_unlock(id: String) -> bool:
	if not is_available(id) or node_data(id) == null:
		return false
	unlocked[id] = true
	_recompute_mods()
	_apply_to_all()
	EventBus.skill_unlocked.emit(id)
	EventBus.skilltree_changed.emit()
	return true


func reset() -> void:
	unlocked.clear()
	_recompute_mods()
	_apply_to_all()
	EventBus.skilltree_changed.emit()


# --------------------------------------------------------------------------- #
# Save / Load (Format v5)
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	var ids: Array = []
	for id in unlocked.keys():
		ids.append(String(id))
	return {
		"species": data.species_id if data != null else "oak",
		"unlocked": ids,
	}


func from_dict(d: Dictionary) -> void:
	unlocked.clear()
	for id in d.get("unlocked", []):
		var key := String(id)
		if node_data(key) != null:
			unlocked[key] = true
	_recompute_mods()
	_apply_to_all()
	EventBus.skilltree_changed.emit()
