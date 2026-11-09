class_name SaveManager
extends Node
## JSON in user://savegame.json (Master-Punkt 9). Wird bereits in PHASE 1
## geliefert, weil der Welt-Seed bei jedem Neustart neu gewuerfelt wird.
## PHASE 2: `root_segments` pro Baum (in BaseTree.to_dict/from_dict).
## REVISION 2: `world_state` enthaelt die Volumen der ZUSAMMENHAENGENDEN
## Becken (`groups`) statt einzelner trockener Tiles.
## PHASE 3: Format v4 speichert zusaetzlich Schwierigkeitsgrad, Zeit/
## Jahreszeit/Zeitskala und bereits eingesammelte Samen.
## PHASE 4: Format v5 speichert zusaetzlich den globalen Skilltree-Fortschritt
## pro Baumart. v4/v3/v2/v1 bleiben lesbar (fehlende Felder = Defaults).
## PHASE-4-FIX: fehlt auto_mode, wird MANUELL (false) angenommen.
## PHASE 5: Format v6 speichert zusaetzlich Tiere/Futter/Huegel und Parasiten.
## v5/v4/v3/v2/v1 bleiben lesbar (fehlende Felder = Defaults).

const SAVE_PATH := "user://savegame.json"
const FORMAT_VERSION := 6

var interaction: InteractionController
var chunk_manager: ChunkManager
var world_state: WorldState
var time_manager: TimeManager
var season_system: SeasonSystem
var wildlife: WildlifeSystem = null
var parasite_system: ParasiteSystem = null
var forest_health: ForestHealth = null


func setup(p_interaction: InteractionController, p_chunk_manager: ChunkManager,
		p_world_state: WorldState = null, p_time: TimeManager = null,
		p_season: SeasonSystem = null, p_wildlife: WildlifeSystem = null,
		p_parasites: ParasiteSystem = null,
		p_health: ForestHealth = null) -> void:
	interaction = p_interaction
	chunk_manager = p_chunk_manager
	world_state = p_world_state
	time_manager = p_time
	season_system = p_season
	wildlife = p_wildlife
	parasite_system = p_parasites
	forest_health = p_health


func save_game() -> bool:
	var trees: Array[Dictionary] = []
	for tree in get_tree().get_nodes_in_group("trees"):
		trees.append(tree.to_dict())
	var data := {
		"version": FORMAT_VERSION,
		"seed": Global.world_seed,
		"auto_mode": Global.auto_mode,
		"locale": Global.locale,
		# Eine schwebende Eichel gehoert weiterhin dem Spieler.
		"inventory": interaction.get_seed_count() + (1 if interaction.carrying else 0),
		"bird_event_done": interaction.first_seed_eaten,
		"difficulty": int(Global.difficulty),
		"time": time_manager.to_dict() if time_manager != null else {},
		"seeds": season_system.to_dict() if season_system != null else {},
		"skills": SkillTree.instance.to_dict() if SkillTree.instance != null else {},
		"wildlife": wildlife.to_dict() if wildlife != null else {},
		"parasites": parasite_system.to_dict() if parasite_system != null else {},
		"trees": trees,
		"world_state": world_state.to_dict() if world_state != null else {},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		EventBus.toast.emit(tr("MSG_SAVE_ERROR"))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.game_saved.emit()
	EventBus.toast.emit(tr("MSG_SAVED"))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		EventBus.toast.emit(tr("MSG_NO_SAVE"))
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		EventBus.toast.emit(tr("MSG_SAVE_ERROR"))
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		EventBus.toast.emit(tr("MSG_SAVE_ERROR"))
		return false
	var data: Dictionary = parsed

	Global.set_seed_from_save(int(data.get("seed", Global.world_seed)))
	chunk_manager.set_world_seed(Global.world_seed)
	Global.auto_mode = bool(data.get("auto_mode", false))
	Global.locale = String(data.get("locale", "de"))
	Global.set_difficulty(int(data.get("difficulty", 1)))

	# Weltzustand NACH dem Chunk-Neuaufbau wiederherstellen und die Tiles
	# passend einfaerben (trockene Reservoirs bleiben trocken).
	if world_state != null:
		world_state.from_dict(data.get("world_state", {}))
		chunk_manager.refresh_water_visuals()
	if time_manager != null:
		time_manager.from_dict(data.get("time", {}))
	if season_system != null:
		season_system.from_dict(data.get("seeds", {}))
	# PHASE 4: Skill-Fortschritt VOR dem Neuaufbau der Baeume wiederherstellen,
	# damit apply_effect() sofort auf die geladenen Instanzen wirkt.
	if SkillTree.instance != null:
		SkillTree.instance.from_dict(data.get("skills", {}))

	interaction.clear_carrying(false)
	interaction.clear_trees()
	var trees: Array = data.get("trees", [])
	for entry in trees:
		if entry is Dictionary:
			interaction.spawn_tree_from_dict(entry)
	interaction.set_seed_count(int(data.get("inventory", 0)))
	interaction.first_seed_eaten = bool(data.get("bird_event_done", true))
	interaction.refresh_selection()

	# PHASE 5: Tiere und Parasiten NACH den Baeumen wiederherstellen, weil
	# Parasiten tree_id und Pilz-Patches eine Baum-Instanz brauchen.
	if wildlife != null:
		wildlife.from_dict(data.get("wildlife", {}))
	if parasite_system != null:
		parasite_system.from_dict(data.get("parasites", {}))
	if forest_health != null:
		forest_health.recompute()

	EventBus.game_loaded.emit()
	EventBus.toast.emit(tr("MSG_LOADED"))
	return true
