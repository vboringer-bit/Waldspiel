class_name SkillTree
extends Node
## PHASE 4 (Master-Punkt 6): Skilltree PRO BAUMART, global synchron.
## REVISION 8: GEMEINSAMER GLUCOSE-POOL PRO BAUMART.
##
## * `data/skilltrees/oak.tres` enthaelt 24 SkillNodeData-Knoten (15 MVP +
##   3 "Dichte Krone" aus R6 + 6 Licht-/Jahreszeit-Mutationen aus R7).
##   Jeder Knoten hat Glucose-Kosten, Vorbedingungen und echte Effekte.
## * Der Freischalt-Zustand liegt NUR hier. Alle Baeume DERSELBEN ART teilen
##   ihn; beim Freischalten wird `apply_effect()` auf JEDEN Baum dieser Art
##   angewandt (und auf neu spawnende Baeume automatisch).
## * Die Glucose fuer den Skilltree ist die SUMME ueber ALLE Baeume dieser
##   Art - nicht mehr nur der ausgewaehlte Baum. Die Kosten werden anteilig
##   aus diesem Pool bezahlt, und die gekauften Effekte gelten fuer ALLE
##   Baeume dieser Art. Ohne Auswahl ist der Kauf trotzdem moeglich, solange
##   mindestens ein Baum der Art existiert.
## * Normale Wachstumskosten (Wurzel/Stamm/Blatt/Ziehen) bleiben weiterhin
##   pro Baum - nur der Skilltree nutzt den gemeinsamen Pool.
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
	if _matches_species(tree):
		_apply_all(tree)


# --------------------------------------------------------------------------- #
# REVISION 8: Baumart + gemeinsamer Glucose-Pool
# --------------------------------------------------------------------------- #
## "oak.tres" -> "oak", damit der Vergleich mit SkillTreeData.species_id
## ("oak") exakt ist. Ohne Ressourcenpfad (zur Laufzeit erzeugte Resource)
## wird der Artname als Fallback benutzt.
func species_key(tree: Node) -> String:
	if not (tree is BaseTree):
		return ""
	var sp := (tree as BaseTree).species
	if sp == null:
		return ""
	var rp := String(sp.resource_path)
	if rp != "":
		return rp.get_file().get_basename().to_lower()
	return String(sp.species_name).to_lower()


func skilltree_species_key() -> String:
	return String(data.species_id).to_lower() if data != null else "oak"


func _matches_species(tree: Node) -> bool:
	var key := species_key(tree)
	var sid := skilltree_species_key()
	if key.is_empty():
		return false
	if key == sid:
		return true
	# Fallback: Artname ("eiche") statt Dateiname ("oak").
	return sid == "oak" and (key.contains("eich") or key.contains("oak"))


func all_trees() -> Array[BaseTree]:
	var out: Array[BaseTree] = []
	for n in get_tree().get_nodes_in_group("trees"):
		if n is BaseTree and is_instance_valid(n):
			out.append(n as BaseTree)
	return out


## Alle Baeume, deren Art zum Skilltree passt. `payer` ist nur ein Anker:
## bei null wird automatisch die Art des Skilltrees verwendet. Es werden
## ALLE Instanzen im SceneTree betrachtet - auch weit ausserhalb des
## sichtbaren Kameraausschnitts und ausserhalb geladener Chunks.
func pool_trees(payer: BaseTree = null) -> Array[BaseTree]:
	var wanted := species_key(payer) if payer != null else ""
	if wanted.is_empty():
		wanted = skilltree_species_key()
	var out: Array[BaseTree] = []
	for t in all_trees():
		var key := species_key(t)
		if key == wanted or (wanted == "oak" and _matches_species(t)):
			out.append(t)
	return out


## Die im Skilltree verfuegbare Glucose = Summe aller Baeume dieser Art.
func pooled_glucose(payer: BaseTree = null) -> float:
	var total := 0.0
	for t in pool_trees(payer):
		total += maxf(t.glucose, 0.0)
	return total


func debug_pool_size(payer: BaseTree = null) -> int:
	return pool_trees(payer).size()


## Kosten ANTEILIG aus dem Pool bezahlen. Der letzte Baum traegt den
## Rundungsrest; damit ist die abgebuchte Summe exakt `cost` und kein Baum
## wird negativ. Jeder betroffene Baum meldet seine neue Glucose.
func spend_pooled(payer: BaseTree, cost: float) -> void:
	var members := pool_trees(payer)
	var total := pooled_glucose(payer)
	if members.is_empty() or total <= 0.0:
		return
	var budget := minf(maxf(cost, 0.0), total)
	var paid := 0.0
	for i in range(members.size()):
		var t := members[i]
		var g := maxf(t.glucose, 0.0)
		var share := budget * (g / total) if i < members.size() - 1 \
			else budget - paid
		share = clampf(share, 0.0, g)
		t.glucose = maxf(0.0, t.glucose - share)
		paid += share
		EventBus.glucose_changed.emit(t, t.glucose)


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


## REVISION 8: Kosten gegen den GEMEINSAMEN Pool pruefen. Ein ausgewaehlter
## Baum ist nicht mehr noetig - es genuegt, dass Baeume dieser Art existieren.
func can_unlock(id: String, payer: BaseTree = null) -> bool:
	if unlocked.has(id) or not is_available(id):
		return false
	var nd := node_data(id)
	return nd != null and pooled_glucose(payer) >= nd.cost


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


## Wendet den Gesamtzustand auf EINE Baum-Instanz an. Da der Skilltree
## global synchron ist, werden alle Instanzen DERSELBEN ART auf denselben
## Stand gebracht; neue Baeume bekommen ihn ueber `tree_spawned`.
func apply_effect(_node_id: String, tree_instance: Node) -> void:
	if not (tree_instance is BaseTree) or not _matches_species(tree_instance):
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
	t.apply_skill_leaf_grants(int(roundf(bonus("grant_leaves"))))


func _apply_all(tree: Node) -> void:
	for id in unlocked.keys():
		apply_effect(String(id), tree)


## REVISION 8: NUR Baeume dieser Art, aber alle - auch off-screen.
func _apply_to_all() -> void:
	for tree in all_trees():
		if _matches_species(tree):
			_apply_all(tree)


# --------------------------------------------------------------------------- #
# Freischalten
# --------------------------------------------------------------------------- #
func unlock(id: String, payer: BaseTree = null) -> bool:
	if not can_unlock(id, payer):
		if not is_available(id):
			EventBus.toast.emit(tr("MSG_SKILL_PREREQ"))
		elif pool_trees(payer).is_empty():
			EventBus.toast.emit(tr("MSG_SKILL_NO_TREE"))
		else:
			EventBus.toast.emit(tr("MSG_SKILL_NO_GLUCOSE"))
		return false
	var nd := node_data(id)
	spend_pooled(payer, nd.cost)
	unlocked[id] = true
	_recompute_mods()
	_apply_to_all()                     # ALLE Baeume dieser Art
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
