class_name TerrainContours
extends Node2D
## REVISION 2: „schoenere Kanten" fuer ALLE Untergrund-Strukturen.
## REVISION 3: stufenloser Pegel (anteilig gefuellte 4px-Zelle).
## REVISION 4: PERFORMANCE / Ruckler-Beseitigung.
##
##   Vorher: EIN _draw() kostete ~67 ms pro Chunk (bei 5 geladenen Chunks
##   ~335 ms) aus zehntausenden draw_rect-Befehlen und Noise-Abfragen. Weil
##   der Pegel 25x/s ein queue_redraw() ausloeste, wurden Erdschichten,
##   Hoehlen, Atlas-Kacheln und Wasser staendig neu berechnet -> das SPIEL
##   ruckelte extrem (2 FPS statt fluessig).
##
##   Jetzt:
##     1. Statik (Atlas, Erdschichten, Hoehlen) zeichnet dieser Node EINMAL;
##        nur TerrainWaterPainter (Kind) wird bei Pegelaenderung neu gezeichnet.
##     2. Isolinien-Geometrie wird EINMAL pro Chunk (+Seed) berechnet und in
##        einem klassenweiten Cache gehalten -> kein Rechnen beim Kamera-Pan.
##     3. Zusammenhaengende Zellen und Randstreifen gleicher Farbe werden zu
##        EINEM Streifen zusammengefasst (statt tausender draw_rect).
##     4. Der Wasser-Redraw wird gedrosselt und nur bei einer sichtbaren
##        Pegelaenderung (>= 0.4 px) ausgeloest.
##   Das Bild bleibt pixelgleich; es werden nur weniger Befehle erzeugt.

const SUB := 4.0
const SUB_PER_TILE := 4
const TS := 16.0
const CHUNK_W := 2048.0
const STEPS := 512                    # 2048 / 4
const BAND := 10.0
const MAX_WATER_GAP := 9              # 4px-Zellen: schliesst Loecher bis 32px

var index: int = 0
var origin: float = 0.0
var generator: WorldGenerator
var world_state: WorldState
var cave_tiles: Dictionary = {}       # Vector2i(gx,ty) -> true (global)
var water_tiles: Dictionary = {}
var water_painter: TerrainWaterPainter

var _layers: Array = []
var _atlas: Texture2D

## REVISION 4: klassenweiter Geometrie-Cache. Chunks werden beim Kamera-Pan
## freigegeben und neu erzeugt; die Isolinien sind aber deterministisch.
static var _geo_bank: Dictionary = {}
static var _layer_bank: Dictionary = {}

## REVISION 3/4: nur bei sichtbarer Pegelaenderung neu zeichnen.
## Debug-Zaehler fuer den REVISION-4-Smoke: wie oft wurde die STATISCHE
## bzw. die WASSER-Befehlsliste neu aufgebaut?
var debug_static_draws := 0
var debug_water_draws := 0

var _water_dirty := false
var _redraw_timer := 0.0
var _last_probe_line := -1.0e9

# Atlas-Grundtoene (tools/generate_placeholders.py, soil_atlas.png)
const C_ASH := Color(0.212, 0.196, 0.184)
const C_HUMUS := Color(0.227, 0.176, 0.137)
const C_TOPSOIL := Color(0.361, 0.259, 0.173)
const C_CLAY := Color(0.471, 0.318, 0.212)
const C_ROCK := Color(0.306, 0.325, 0.353)

const CAVE_FILL := Color(0.086, 0.094, 0.106)
const CAVE_RIM := Color(0.043, 0.047, 0.053)
const CAVE_LIGHT := Color(0.145, 0.153, 0.165)
const WATER_FILL := Color(0.204, 0.424, 0.588)
const WATER_RIM := Color(0.098, 0.235, 0.353)
const WATER_SURFACE := Color(0.573, 0.753, 0.839)
const DRY_FILL := Color(0.639, 0.616, 0.518)
const DRY_RIM := Color(0.43, 0.41, 0.35)


func setup(p_index: int, p_generator: WorldGenerator, p_state: WorldState,
		p_caves: Dictionary, p_water: Dictionary) -> void:
	index = p_index
	origin = float(p_index * WorldGenerator.CHUNK_WIDTH_PX)
	generator = p_generator
	world_state = p_state
	cave_tiles = p_caves
	water_tiles = p_water
	name = "Contours"
	z_index = 1                       # ueber tile_layer (0), neben TerrainSurface
	_atlas = load(PixelArt.SOIL_ATLAS) as Texture2D
	_layers = [
		{"depth": 16.0, "salt": 1.0, "top": C_ASH, "bottom": C_HUMUS},
		{"depth": 32.0, "salt": 2.0, "top": C_HUMUS, "bottom": C_TOPSOIL},
		{"depth": 208.0, "salt": 3.0, "top": C_TOPSOIL, "bottom": C_CLAY},
		{"depth": 608.0, "salt": 4.0, "top": C_CLAY, "bottom": C_ROCK},
	]
	if not EventBus.reservoir_level_changed.is_connected(_on_level_changed):
		EventBus.reservoir_level_changed.connect(_on_level_changed)
	if not EventBus.reservoir_volume_changed.is_connected(_on_volume_changed):
		EventBus.reservoir_volume_changed.connect(_on_volume_changed)
	water_painter = TerrainWaterPainter.new()
	water_painter.name = "WaterContour"
	water_painter.host = self
	add_child(water_painter)
	queue_redraw()
	queue_water_redraw()


func _bank_key(kind: String) -> String:
	return "%d|%d|%s" % [generator.world_seed, index, kind]


## Oeffentlicher Hook fuer Chunk._on_level_changed(): NUR das Wasser Kind
## bekommt einen Redraw, die statische Befehlsliste bleibt unangetastet.
func queue_water_redraw() -> void:
	if water_painter != null:
		water_painter.queue_redraw()


func _on_level_changed() -> void:
	queue_water_redraw()


func _on_volume_changed() -> void:
	_water_dirty = true


func _process(delta: float) -> void:
	if _redraw_timer > 0.0:
		_redraw_timer -= delta
	if not _water_dirty or _redraw_timer > 0.0:
		return
	var line := _probe_line()
	if absf(line - _last_probe_line) < 0.4:
		return
	_last_probe_line = line
	_water_dirty = false
	_redraw_timer = 0.08
	queue_water_redraw()


func _probe_line() -> float:
	if world_state == null:
		return 0.0
	for tv in water_tiles.keys():
		var t: Vector2i = tv as Vector2i
		return world_state.waterline_px(t.x, t.y)
	return 0.0


# --------------------------------------------------------------------------- #
# STATISCH: wird genau einmal pro Chunk-Instanz aufgebaut
# --------------------------------------------------------------------------- #
func _draw() -> void:
	if generator == null:
		return
	debug_static_draws += 1
	_erase_structure_tiles(self)
	_draw_layers(self)
	_draw_blobs(self, cave_tiles, 11.0, false)


## DYNAMISCH: vom Kind aufgerufen, nur Wasser.
func paint_water(ci: CanvasItem) -> void:
	if generator == null:
		return
	debug_water_draws += 1
	_draw_blobs(ci, water_tiles, 29.0, true)


func debug_geometry_cached() -> bool:
	return _geo_bank.has(_bank_key("cave")) \
		and _geo_bank.has(_bank_key("water")) \
		and _layer_bank.has(_bank_key("layerops"))


## Die alten 16px-Hoehlen-/Wasser-Tiles mit dem echten Boden-Atlas uebermalen.
func _erase_structure_tiles(ci: CanvasItem) -> void:
	if _atlas == null:
		return
	for tv in cave_tiles.keys():
		_erase_one(ci, tv as Vector2i)
	for tv in water_tiles.keys():
		_erase_one(ci, tv as Vector2i)


func _erase_one(ci: CanvasItem, t: Vector2i) -> void:
	var lx := float(t.x * int(TS)) - origin
	# REVISION 2: NUR Tiles des EIGENEN Chunks uebermalen. Wuerde ein
	# Rand-Tile des Nachbarn hier geloescht, aber (weil ausserhalb des
	# Zeichenbereichs) nicht neu gezeichnet, entstuende eine braune Naht.
	if lx < 0.0 or lx >= CHUNK_W:
		return
	var slot := generator.soil_slot_at(t.x, t.y)
	if slot < 0:
		return
	ci.draw_texture_rect_region(_atlas,
		Rect2(lx, float(t.y * int(TS)), TS, TS),
		Rect2(float(slot * int(TS)), 0.0, TS, TS))


# --------------------------------------------------------------------------- #
# Erdschichten: weicher Farbuebergang + Rim + heller Saum
# --------------------------------------------------------------------------- #
func _layer_ops() -> Array:
	var key := _bank_key("layerops")
	if _layer_bank.has(key):
		return _layer_bank[key]
	var ops: Array = []
	for layer in _layers:
		var ys := PackedFloat32Array()
		ys.resize(STEPS + 1)
		for s in range(STEPS + 1):
			ys[s] = generator.layer_edge_y(origin + float(s) * SUB,
				float(layer["depth"]), float(layer["salt"]))
		var top: Color = layer["top"]
		var bottom: Color = layer["bottom"]
		var mid := Color((top.r + bottom.r) * 0.5,
			(top.g + bottom.g) * 0.5, (top.b + bottom.b) * 0.5, 0.78)
		var fade_top := Color(top.r, top.g, top.b, 0.0)
		var fade_bottom := Color(bottom.r, bottom.g, bottom.b, 0.0)

		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for s in range(STEPS + 1):
			pts.append(Vector2(float(s) * SUB, ys[s] - BAND))
			cols.append(fade_top)
		for s in range(STEPS, -1, -1):
			pts.append(Vector2(float(s) * SUB, ys[s]))
			cols.append(mid)
		ops.append({"t": "poly", "p": pts, "c": cols})

		pts = PackedVector2Array()
		cols = PackedColorArray()
		for s in range(STEPS + 1):
			pts.append(Vector2(float(s) * SUB, ys[s]))
			cols.append(mid)
		for s in range(STEPS, -1, -1):
			pts.append(Vector2(float(s) * SUB, ys[s] + BAND))
			cols.append(fade_bottom)
		ops.append({"t": "poly", "p": pts, "c": cols})

		var prof := PackedVector2Array()
		var lite := PackedVector2Array()
		for s in range(STEPS + 1):
			prof.append(Vector2(float(s) * SUB, ys[s]))
			lite.append(Vector2(float(s) * SUB, ys[s] + 3.0))
		var rim := Color(top.r * 0.45, top.g * 0.45, top.b * 0.45, 0.85)
		var light := Color(minf(bottom.r * 1.35, 1.0),
			minf(bottom.g * 1.35, 1.0), minf(bottom.b * 1.35, 1.0), 0.55)
		ops.append({"t": "line", "p": prof, "c": rim, "w": 2.0})
		ops.append({"t": "line", "p": lite, "c": light, "w": 1.0})
	_layer_bank[key] = ops
	return ops


func _draw_layers(ci: CanvasItem) -> void:
	for op in _layer_ops():
		if op["t"] == "poly":
			ci.draw_polygon(op["p"], op["c"])
		else:
			ci.draw_polyline(op["p"], op["c"], float(op["w"]))


# --------------------------------------------------------------------------- #
func _s(gx: int, gy: int, is_water: bool) -> float:
	var inside := (generator.reservoir_at(gx, gy) if is_water
		else generator.cave_at(gx, gy))
	return 1.0 if inside else -1.0


func _field(px: float, py: float, salt: float, is_water: bool) -> float:
	var tx := px / TS - 0.5
	var ty := py / TS - 0.5
	var gx0 := int(floor(tx))
	var gy0 := int(floor(ty))
	var fx := tx - float(gx0)
	var fy := ty - float(gy0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var v := lerpf(
		lerpf(_s(gx0, gy0, is_water), _s(gx0 + 1, gy0, is_water), fx),
		lerpf(_s(gx0, gy0 + 1, is_water), _s(gx0 + 1, gy0 + 1, is_water), fx),
		fy)
	# REVISION 4: Der Noise-Wackler betraegt hoechstens 0.22 * 0.85 = 0.187.
	# Weit innerhalb / ausserhalb der Isolinie kann er das Vorzeichen nie
	# kippen -> die teure Noise-Abfrage wird dort uebersprungen. Das sind
	# ~90 % aller 4px-Zellen und der Hauptteil der Ladezeit.
	if v > 0.21 or v < -0.21:
		return v
	return v + generator.edge_wobble_at(px, py, salt) * 0.85


func _close_water_gaps(filled: Dictionary, rows: Dictionary) -> void:
	for sy in rows.keys():
		var xs: Array = rows[sy]
		xs.sort()
		for i in range(xs.size() - 1):
			var a: int = xs[i]
			var b: int = xs[i + 1]
			if b - a > 1 and b - a <= MAX_WATER_GAP:
				for sx in range(a + 1, b):
					var c := Vector2i(sx, sy)
					if not filled.has(c):
						filled[c] = true
						xs.append(sx)


func _line_of(tile: Vector2i, cache: Dictionary) -> float:
	if cache.has(tile):
		return float(cache[tile])
	var line := world_state.waterline_px(tile.x, tile.y)
	cache[tile] = line
	return line


# --------------------------------------------------------------------------- #
# Geometrie EINMAL berechnen (teuer), dann nur noch malen (guenstig)
# --------------------------------------------------------------------------- #
func _prepare(cellset: Dictionary, salt: float, is_water: bool) -> Dictionary:
	var active: Dictionary = {}
	for tv in cellset.keys():
		var t0: Vector2i = tv as Vector2i
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				active[Vector2i(t0.x + ox, t0.y + oy)] = true

	var filled: Dictionary = {}
	var rows: Dictionary = {}
	for tv in active.keys():
		var t: Vector2i = tv as Vector2i
		for i in SUB_PER_TILE:
			for j in SUB_PER_TILE:
				var sx := t.x * SUB_PER_TILE + i
				var sy := t.y * SUB_PER_TILE + j
				var px := float(sx * 4 + 2)
				var py := float(sy * 4 + 2)
				var lx := px - 2.0 - origin
				if lx < 0.0 or lx >= CHUNK_W:
					continue
				if _field(px, py, salt, is_water) < -0.02:
					continue
				var c := Vector2i(sx, sy)
				filled[c] = true
				if not rows.has(sy):
					rows[sy] = []
				rows[sy].append(sx)

	if is_water:
		_close_water_gaps(filled, rows)

	# Zeilenweise sortiert -> horizontale Streifen moeglich.
	var cells: Array[Vector2i] = []
	var row_keys: Array = rows.keys()
	row_keys.sort()
	for sy in row_keys:
		var xs: Array = rows[sy]
		xs.sort()
		for sx in xs:
			cells.append(Vector2i(int(sx), int(sy)))

	var probe: Dictionary = {}
	var row_line: Dictionary = {}
	if is_water:
		var line_cache: Dictionary = {}
		for sy in row_keys:
			var xs: Array = rows[sy]
			var line := 1.0e9
			for sx in xs:
				var tx := int(floor(float(int(sx) * 4) / TS))
				var ty := int(floor(float(int(sy) * 4) / TS))
				if generator.reservoir_at(tx, ty):
					line = _line_of(Vector2i(tx, ty), line_cache)
					break
			row_line[sy] = line
		for c in cells:
			var tk := Vector2i(int(floor(float(c.x * 4) / TS)),
				int(floor(float(c.y * 4) / TS)))
			var best := tk
			if not generator.reservoir_at(tk.x, tk.y):
				best = Vector2i(-999999, -999999)
				for dx in [0, -1, 1, -2, 2, -3, 3]:
					var near := Vector2i(tk.x + int(dx), tk.y)
					if generator.reservoir_at(near.x, near.y):
						best = near
						break
			probe[c] = best

	# Nur Randzellen mit ihren Flags (nicht alle Zellen).
	var rims: Array[Dictionary] = []
	for c in cells:
		var above := Vector2i(c.x, c.y - 1)
		var below := Vector2i(c.x, c.y + 1)
		var left := Vector2i(c.x - 1, c.y)
		var right := Vector2i(c.x + 1, c.y)
		var lx := float(c.x * 4) - origin
		var top_edge := not filled.has(above)
		var bot_edge := not filled.has(below)
		var l_edge := not filled.has(left) and lx > 0.0
		var r_edge := not filled.has(right) and lx < CHUNK_W - SUB
		if top_edge or bot_edge or l_edge or r_edge:
			rims.append({"c": c, "top": top_edge, "bottom": bot_edge,
				"left": l_edge, "right": r_edge, "above": above})
	return {"filled": filled, "rows": rows, "row_line": row_line,
		"cells": cells, "probe": probe, "rims": rims}


func _cell_line(c: Vector2i, prep: Dictionary, cache: Dictionary) -> float:
	var p: Vector2i = prep["probe"].get(c, Vector2i(-999999, -999999))
	if p.x > -900000:
		return _line_of(p, cache)
	return float((prep["row_line"] as Dictionary).get(c.y, 1.0e9))


## code: 0 = trocken, 1 = voll nass, 2 = anteilig (Pegel in der Zelle),
##       3 = Hoehle. Nur Code 2 braucht eigene Zeichenbefehle.
func _flush_run(ci: CanvasItem, start: Vector2i, length: int, code: int) -> void:
	if length <= 0:
		return
	var col := CAVE_FILL
	if code == 0:
		col = DRY_FILL
	elif code == 1:
		col = WATER_FILL
	ci.draw_rect(Rect2(float(start.x * 4) - origin, float(start.y * 4),
		float(length) * SUB, SUB), col)


func _draw_blobs(ci: CanvasItem, cellset: Dictionary, salt: float,
		is_water: bool) -> void:
	if cellset.is_empty():
		return
	var bkey := _bank_key("water" if is_water else "cave")
	if not _geo_bank.has(bkey):
		_geo_bank[bkey] = _prepare(cellset, salt, is_water)
	var prep: Dictionary = _geo_bank[bkey]
	var cells: Array[Vector2i] = prep["cells"]
	var filled: Dictionary = prep["filled"]
	var cache: Dictionary = {}
	var wet: Dictionary = {}
	var partial: Dictionary = {}

	# Schritt 4: gleiche Farben zu horizontalen Streifen zusammenfassen.
	var run_start := Vector2i.ZERO
	var run_len := 0
	var run_code := -1
	for c in cells:
		var code := 3
		var line := 0.0
		var wet_h := SUB
		if is_water:
			line = _cell_line(c, prep, cache)
			wet_h = clampf(float(c.y * 4) + SUB - line, 0.0, SUB)
			if wet_h <= 0.001:
				code = 0
			elif wet_h >= SUB - 0.001:
				code = 1
			else:
				code = 2
		if code == 1:
			wet[c] = true
		elif code == 2:
			wet[c] = true
			partial[c] = true
		if code == 2:
			_flush_run(ci, run_start, run_len, run_code)
			run_len = 0
			run_code = -1
			var lx := float(c.x * 4) - origin
			var ly := float(c.y * 4)
			ci.draw_rect(Rect2(lx, ly, SUB, SUB), DRY_FILL)
			ci.draw_rect(Rect2(lx, ly + SUB - wet_h, SUB, wet_h), WATER_FILL)
			ci.draw_rect(Rect2(lx, line, SUB, 1.0), WATER_SURFACE)
			continue
		if run_len > 0 and c.y == run_start.y \
				and c.x == run_start.x + run_len and code == run_code:
			run_len += 1
		else:
			_flush_run(ci, run_start, run_len, run_code)
			run_start = c
			run_len = 1
			run_code = code
	_flush_run(ci, run_start, run_len, run_code)

	# Schritt 5: Umrisslinie + Wasserlinie / Hoehlen-Glanz, ebenfalls als
	# horizontale bzw. vertikale Laufstreifen statt pro Randzelle.
	var top_runs: Array = []
	var bot_runs: Array = []
	var left_runs: Array = []
	var right_runs: Array = []
	var peg_runs: Array = []
	var v_left: Dictionary = {}
	var v_right: Dictionary = {}
	for e in prep["rims"]:
		var c: Vector2i = e["c"]
		var k := "c" if not is_water else ("w" if wet.has(c) else "d")
		var extra := 0
		if bool(e["top"]):
			if is_water and wet.has(c) and not partial.has(c):
				extra = 1
			elif not is_water:
				extra = 2
		if bool(e["top"]):
			_add_h(top_runs, c, k, extra)
		if bool(e["bottom"]):
			_add_h(bot_runs, c, k, 0)
		if bool(e["left"]):
			_add_v(left_runs, v_left, c, k)
		if bool(e["right"]):
			_add_v(right_runs, v_right, c, k)
		# Innerer Pegel: oben trocken, hier nass -> helle horizontale Linie.
		if is_water and wet.has(c) and not partial.has(c) \
				and filled.has(e["above"]) and not wet.has(e["above"]):
			_add_h(peg_runs, c, "p", 0)

	for r in top_runs:
		var x := float(r["c"].x * 4) - origin
		var y := float(r["c"].y * 4)
		var w := float(r["n"]) * SUB
		ci.draw_rect(Rect2(x, y, w, 2.0), _rim_color(r["k"]))
		var ex := int(r["extra"])
		if ex == 1:
			ci.draw_rect(Rect2(x, y + 2.0, w, 1.0), WATER_SURFACE)
		elif ex == 2:
			ci.draw_rect(Rect2(x, y + 2.0, w, 1.0), CAVE_LIGHT)
	for r in bot_runs:
		var x := float(r["c"].x * 4) - origin
		var y := float(r["c"].y * 4)
		var w := float(r["n"]) * SUB
		ci.draw_rect(Rect2(x, y + 2.0, w, 2.0), _rim_color(r["k"]))
	for r in left_runs:
		var x := float(r["c"].x * 4) - origin
		var y := float(r["c"].y * 4)
		var h := float(r["n"]) * SUB
		ci.draw_rect(Rect2(x, y, 2.0, h), _rim_color(r["k"]))
	for r in right_runs:
		var x := float(r["c"].x * 4) - origin
		var y := float(r["c"].y * 4)
		var h := float(r["n"]) * SUB
		ci.draw_rect(Rect2(x + 2.0, y, 2.0, h), _rim_color(r["k"]))
	for r in peg_runs:
		var x := float(r["c"].x * 4) - origin
		var y := float(r["c"].y * 4)
		var w := float(r["n"]) * SUB
		ci.draw_rect(Rect2(x, y, w, 2.0), WATER_SURFACE)


func _rim_color(k: String) -> Color:
	if k == "w":
		return WATER_RIM
	if k == "d":
		return DRY_RIM
	return CAVE_RIM


func _add_h(runs: Array, c: Vector2i, k: String, extra: int) -> void:
	if not runs.is_empty():
		var last: Dictionary = runs[runs.size() - 1]
		if last["c"].y == c.y and last["c"].x + last["n"] == c.x \
				and last["k"] == k and last["extra"] == extra:
			last["n"] = int(last["n"]) + 1
			return
	runs.append({"c": c, "n": 1, "k": k, "extra": extra})


func _add_v(runs: Array, last_of_col: Dictionary, c: Vector2i, k: String) -> void:
	var key := "%d|%s" % [c.x, k]
	if last_of_col.has(key):
		var last: Dictionary = runs[int(last_of_col[key])]
		if last["c"].y + last["n"] == c.y:
			last["n"] = int(last["n"]) + 1
			return
	last_of_col[key] = runs.size()
	runs.append({"c": c, "n": 1, "k": k, "extra": 0})
