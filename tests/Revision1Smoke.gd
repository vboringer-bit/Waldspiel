extends Node
## Headless-Smoke-Test fuer REVISION 1 (vor PHASE 3):
##   godot --headless --path . -- --rev1-smoke
## 1) Vollbild skaliert den Monitor aus (kein grauer Rand).
## 2) Unterirdische Strukturen sind unregelmaessig, aber zusammenhaengend.
## 3) Die Oberflaeche hat keine grossen 16px-Ecken mehr.
## 4) Eichel: aufnehmen -> schweben -> frei platzieren -> DANN Vogel.

var interaction: InteractionController
var save_manager: SaveManager
var chunk_manager: ChunkManager
var camera: CameraController

var _failures: Array[String] = []
var _placed: Array[Vector2] = []


func setup(p_interaction: InteractionController, p_save: SaveManager,
		p_chunks: ChunkManager, p_camera: CameraController) -> void:
	interaction = p_interaction
	save_manager = p_save
	chunk_manager = p_chunks
	camera = p_camera


func _check(condition: bool, label: String) -> void:
	print("[SMOKE] %-56s %s" % [label, "OK" if condition else "FEHLER"])
	if not condition:
		_failures.append(label)


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	run()


func run() -> void:
	print("[SMOKE] === REVISION 1 (vor PHASE 3) ===")
	var gen := chunk_manager.generator

	# --- 1) Vollbild / Skalierung -------------------------------------------
	var mode := int(ProjectSettings.get_setting("display/window/size/mode"))
	var aspect := String(ProjectSettings.get_setting("display/window/stretch/aspect"))
	var stretch := String(ProjectSettings.get_setting("display/window/stretch/mode"))
	_check(mode == 3, "Startet direkt im Vollbild (mode=%d)" % mode)
	_check(aspect == "expand", "Kein Letterboxing: expand + dynamischer Faktor")
	_check(get_tree().root.content_scale_factor >= 0.99,
		"Inhalt skaliert gleichmaessig auf die Fensterflaeche")
	_check(stretch == "canvas_items", "Stretch-Modus canvas_items (Pixel-Look)")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080,
		"Design-Aufloesung bleibt 1920x1080")

	# --- 2) Fliessende Oberflaeche ------------------------------------------
	var max_step := 0.0
	var big_corners := 0
	var continuous := 0
	var prev := roundf(gen.height_smooth_at(-2048.0) / 4.0) * 4.0
	for x in range(-2048, 2049, 4):
		var y := roundf(gen.height_smooth_at(float(x)) / 4.0) * 4.0
		var d := absf(y - prev)
		max_step = maxf(max_step, d)
		if d >= 16.0:
			big_corners += 1
		if not is_equal_approx(y, gen.height_at(float(x))):
			continuous += 1
		prev = y
	_check(big_corners == 0 and max_step <= 4.0,
		"Keine 16px-Ecken: max. Sprung %.0f px / %d Ecken" % [max_step, big_corners])
	_check(continuous > 200,
		"Hoehenlinie ist kontinuierlich (%d von 1025 Stuetzstellen)" % continuous)
	var chunk0 := chunk_manager.get_chunk(0)
	_check(chunk0 != null and chunk0.surface != null,
		"TerrainSurface-Profil pro Chunk vorhanden")

	# --- 3) Unregelmaessige, aber zusammenhaengende Strukturen ---------------
	var top := gen.surface_tile_y_at(0.0)
	var cave_tiles: Array[Vector2i] = []
	var water_tiles: Array[Vector2i] = []
	# PHASE 3 / PHASE 6: breiteres Fenster als Phase2Smoke. REVISION 2
	# halbiert die Hoehlenflaeche; bei unguenstigen Zufalls-Seeds lieferte
	# das alte -48..48-Fenster nur 2 Komponenten / 2 Groessen, obwohl die
	# Welt direkt daneben weitere organische Kammern hat. -64..64 entspricht
	# dem robusten Fenster von Revision2Smoke und macht den Flood-Fill-Test
	# seed-unabhaengig, ohne die Mindestanforderungen zu senken.
	for gx in range(-64, 65):
		for ty in range(top + 5, top + 45):
			if gen.cave_at(gx, ty):
				cave_tiles.append(Vector2i(gx, ty))
			if gen.reservoir_at(gx, ty):
				water_tiles.append(Vector2i(gx, ty))
	_check(cave_tiles.size() > 40 and water_tiles.size() > 8,
		"Hoehlen (%d) + Reservoirs (%d) vorhanden" % [cave_tiles.size(), water_tiles.size()])

	# Kohärenz: fast jedes Hoehlen-Tile hat einen direkten Nachbarn (kein Static).
	var cave_set := {}
	for t in cave_tiles:
		cave_set[t] = true
	var lonely := 0
	for t in cave_tiles:
		var has_neighbour := (cave_set.has(t + Vector2i(1, 0))
			or cave_set.has(t + Vector2i(-1, 0))
			or cave_set.has(t + Vector2i(0, 1))
			or cave_set.has(t + Vector2i(0, -1)))
		if not has_neighbour:
			lonely += 1
	_check(float(lonely) / float(maxi(cave_tiles.size(), 1)) < 0.12,
		"Zusammenhaengende Blobs (nur %d Solitaer-Tiles)" % lonely)

	# Unregelmaessigkeit: Flood-Fill der Hoehlen-Komponenten. Ein regelmaessiges
	# Raster haette lauter gleich grosse Blasen; hier muessen Groesse und Anzahl
	# der Kammern deutlich variieren.
	var visited := {}
	var sizes: Array[int] = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for t in cave_tiles:
		if visited.has(t):
			continue
		var queue: Array[Vector2i] = [t]
		visited[t] = true
		var n := 0
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			n += 1
			for d in dirs:
				var nb: Vector2i = c + d
				if cave_set.has(nb) and not visited.has(nb):
					visited[nb] = true
					queue.append(nb)
		sizes.append(n)
	var distinct_sizes := {}
	for n in sizes:
		distinct_sizes[n] = true
	_check(sizes.size() >= 3 and distinct_sizes.size() >= 3,
		"Unregelmaessige Kammern (%d Komponenten / %d Groessen)" % [sizes.size(), distinct_sizes.size()])

	# Jeder Seed wuerfelt die Anordnung neu (nicht immer dasselbe Muster).
	var other := WorldGenerator.new((Global.world_seed + 1234567) & 0x7fffffff)
	var different := 0
	var union := 0
	for gx in range(-30, 31, 2):
		for ty in range(top + 6, top + 28, 2):
			var a := gen.cave_at(gx, ty)
			var b := other.cave_at(gx, ty)
			if a or b:
				union += 1
			if a != b:
				different += 1
	# Relativ zur Gesamtzahl der Kammern (REVISION 2 hat halb so viele).
	_check(union > 0 and float(different) / float(union) > 0.45,
		"Strukturen variieren mit dem Seed (%d%% der Kammern anders)" % [
			int(100.0 * different / maxi(union, 1))])

	# Starter-Reservoir: garantierter Kern + zerfranste, unregelmaessige Linse.
	_check(gen.reservoir_at(0, top + 10), "Starter-Reservoir: Kern weiterhin garantiert")
	var outside_core := 0
	for gx in range(-9, 10):
		for d in range(8, 16):
			if gen.reservoir_at(gx, top + d) \
					and not (absi(gx) <= 1 and d >= 10 and d <= 12):
				outside_core += 1
	_check(outside_core > 3,
		"Starter-Reservoir ist organisch geformt (%d Tiles ausserhalb 3x3)" % outside_core)

	# --- 4) Eichel: aufnehmen -> schweben -> platzieren -> Vogel -------------
	interaction.clear_trees()
	interaction.clear_carrying(false)
	interaction.set_seed_count(2)
	interaction.first_seed_eaten = false
	_placed.clear()
	if not EventBus.seed_placed.is_connected(_on_seed_placed):
		EventBus.seed_placed.connect(_on_seed_placed)
	var bird_layer: BirdEvent = interaction.bird_layer

	_check(interaction.pick_up_acorn(), "Eichel anklicken: aufgenommen")
	_check(interaction.carrying and interaction.get_seed_count() == 1,
		"Eichel schwebt an der Maus, Inventar = 1")
	_check(interaction._carried_sprite != null and interaction._carry_marker != null,
		"Schwebe-Sprite + Platzierungs-Vorschau sichtbar")
	_check(not interaction.first_seed_eaten and bird_layer.get_child_count() == 0,
		"Vogel kommt NOCH NICHT beim Aufnehmen")

	interaction.clear_carrying(true)
	_check(not interaction.carrying and interaction.get_seed_count() == 2
		and not interaction.first_seed_eaten,
		"Rechtsklick/Esc legt Eichel zurueck, kein Vogel")

	_check(interaction.pick_up_acorn(), "Erneut aufgenommen")
	interaction.debug_place_carried_at(320.0)
	await get_tree().process_frame
	_check(not interaction.carrying and interaction.get_seed_count() == 1,
		"Platzierungsversuch verbraucht genau 1 Eichel")
	_check(_placed.size() == 1 and absf(_placed[0].x - 320.0) < 0.01,
		"Erste Eichel an frei waehlbarer Stelle x=320 platziert")
	_check(interaction.first_seed_eaten and bird_layer.get_child_count() > 0,
		"Vogel ERST NACH der Platzierung (Diebstahl bleibt erhalten)")
	_check(get_tree().get_nodes_in_group("trees").size() == 0,
		"Gestohlene Eichel keimt nicht")

	_check(interaction.pick_up_acorn(), "Zweite Eichel aufgenommen")
	interaction.debug_place_carried_at(-640.0)
	var trees := get_tree().get_nodes_in_group("trees")
	var placed_ok := trees.size() == 1
	if placed_ok:
		var t := trees[0] as BaseTree
		placed_ok = absf(t.global_position.x - (-640.0)) < 0.01 \
			and absf(t.global_position.y - gen.height_smooth_at(-640.0)) <= 4.0
	_check(placed_ok and interaction.get_seed_count() == 0,
		"Zweite Eichel keimt auf der fliessenden Oberflaeche (x=-640)")

	# --- 5) Save/Load mit schwebender Eichel ---------------------------------
	interaction.set_seed_count(2)
	interaction.pick_up_acorn()
	_check(save_manager.save_game(), "Speichern waehrend Eichel schwebt")
	var raw := FileAccess.get_file_as_string("user://savegame.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary and int(parsed.get("inventory", -1)) == 2,
		"Savegame enthaelt die schwebende Eichel (inventory=2)")
	_check(save_manager.load_game() and not interaction.carrying
		and interaction.get_seed_count() == 2,
		"Laden verwirft Schwebe-Sprite sauber, Eichel bleibt erhalten")

	# --- 6) Regression: 5 Chunks + P2-Settings -------------------------------
	camera.teleport_to(Vector2(4300.0, 300.0))
	chunk_manager._refresh()
	await get_tree().process_frame
	_check(chunk_manager.loaded_chunk_count() == 5, "Weiterhin 5 aktive Chunks")
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"Nearest-Filter weiterhin aktiv")

	print("[SMOKE] Ergebnis: %s" % ("OK" if _failures.is_empty() else "FEHLER (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _on_seed_placed(pos: Vector2) -> void:
	_placed.append(pos)
