class_name WorldState
extends RefCounted
## REVISION 2: Wasser ist eine ZUSAMMENHAENGENDE FLUESSIGKEIT.
##
## Vorher hatte jedes Reservoir-Tile seinen eigenen 60..120-Vorrat; nur Tiles
## mit einer Wurzel wurden leer und blieben einzeln trocken. Jetzt gehoeren alle
## 4-fach verbundenen Wasser-Tiles zu EINEM Reservoir mit EINEM Gesamtvolumen.
## Wurzeln entnehmen dem ganzen Becken. Der Pegel sinkt von OBEN nach UNTEN:
## alle Tiles oberhalb `level_row` sind trocken, darunter steht noch Wasser.
## Der sichtbare Wasserspiegel wandert dadurch langsam nach unten.
## REVISION 3: `waterline_px()` ist STUFENLOS. Frueher sprang der Pegel in
## 16px-Schritten (level_row), weil die Zeilen-Zaehlung ganzzahlig war. Jetzt
## wird aus dem Volumen ein Zwischenwert INNERHALB einer Tile-Zeile berechnet;
## `level_row` bleibt nur noch fuer die (unsichtbare) Tile-Slot-Umschaltung.
##
## Wo Reservoirs liegen bestimmt weiterhin nur der Seed (WorldGenerator); WIE
## VIEL Wasser noch drin ist, ist Spielzustand und steht im Savegame (v3).
## Kein Node/Autoload: ChunkManager besitzt die Instanz.

const PER_TILE_VOLUME := 90.0            # Wasser-Einheiten pro Tile
const PASSIVE_DRAIN_PER_TILE := 0.015   # sehr langsame Versickerung / s
## REVISION 3 / PHASE 3: Regen fuellt PRO TILE auf. Ein Becken mit 114 Tiles
## hat ~10260 Einheiten Kapazitaet - ein fester Zuwachs von 1.2/s waere
## unsichtbar (0.01 %/s). 0.9/Tile/s => ~1 %/s => in 30 s Regen ~+30 %.
const RAIN_REFILL_PER_TILE := 0.9
const MAX_GROUP_TILES := 1200           # Schutz vor ausufernder Flood-Fill-Suche
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)]

var generator: WorldGenerator

var _groups: Dictionary = {}          # id:String -> Becken-Dictionary
var _tile_group: Dictionary = {}      # "gx:ty" -> id:String
var _dry: Dictionary = {}             # "gx:ty" -> true (abgeleitet aus Pegel)
var _saved_volumes: Dictionary = {}   # id -> volume (aus Savegame v3)
var _legacy_dry: Dictionary = {}      # "gx:ty" -> true (alte v2-Saves)


func setup(p_generator: WorldGenerator) -> void:
	generator = p_generator
	reset()


func reset() -> void:
	_groups.clear()
	_tile_group.clear()
	_dry.clear()
	_saved_volumes.clear()
	_legacy_dry.clear()


static func key(global_tile_x: int, tile_y: int) -> String:
	return "%d:%d" % [global_tile_x, tile_y]


# --------------------------------------------------------------------------- #
# Becken-Erkennung (lazy, pro Tile gecacht)
# --------------------------------------------------------------------------- #
func _ensure_group(gx: int, ty: int) -> Dictionary:
	if generator == null or not generator.reservoir_at(gx, ty):
		return {}
	var k := key(gx, ty)
	if _tile_group.has(k):
		return _groups[String(_tile_group[k])]
	return _build_group(gx, ty)


func _build_group(gx: int, ty: int) -> Dictionary:
	var start := Vector2i(gx, ty)
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var tiles: Array[Vector2i] = []
	while not queue.is_empty() and tiles.size() < MAX_GROUP_TILES:
		var c: Vector2i = queue.pop_back()
		tiles.append(c)
		for d in NEIGHBORS:
			var nb: Vector2i = c + d
			if not seen.has(nb) and generator.reservoir_at(nb.x, nb.y):
				seen[nb] = true
				queue.append(nb)
	# Oben nach unten sortieren -> der Pegel faellt zeilenweise.
	tiles.sort_custom(func(a, b): return (a.y < b.y) if a.y != b.y else (a.x < b.x))
	var id := key(tiles[0].x, tiles[0].y)
	var capacity := float(tiles.size()) * PER_TILE_VOLUME
	var volume := clampf(float(_saved_volumes.get(id, capacity)), 0.0, capacity)
	for t in tiles:
		_tile_group[key(t.x, t.y)] = id
		if _legacy_dry.has(key(t.x, t.y)):
			volume = 0.0
	# Zeilen-Histogramm: wie viele Becken-Tiles liegen in jeder y-Zeile?
	# Damit laesst sich aus dem Volumen ein stufenloser Pegel interpolieren.
	var rows: Array[Dictionary] = []
	for t in tiles:
		if rows.is_empty() or int(rows[rows.size() - 1]["y"]) != t.y:
			rows.append({"y": t.y, "count": 1.0})
		else:
			var last: Dictionary = rows[rows.size() - 1]
			last["count"] = float(last["count"]) + 1.0
	var group := {
		"id": id, "tiles": tiles, "rows": rows, "capacity": capacity,
		"volume": volume, "level_row": tiles[0].y,
		"level_px": float(tiles[0].y * WorldGenerator.TILE_SIZE),
		"announced_empty": false,
	}
	_groups[id] = group
	_recompute_level(group, false)
	return group


## REVISION 3: Volumen -> Pegel in WELT-PIXELN, ohne 16px-Spruenge.
## Von unten nach oben werden ganze Zeilen aufsummiert; in der Zeile, in der
## das Restvolumen endet, wird der Wasserstand anteilig interpoliert.
func _compute_level_px(group: Dictionary) -> float:
	var rows: Array = group["rows"]
	if rows.is_empty():
		return float(WorldGenerator.BOTTOM_TILE_Y * WorldGenerator.TILE_SIZE)
	var n := float((group["tiles"] as Array).size())
	var fill := clampf(float(group["volume"]) /
		maxf(float(group["capacity"]), 0.001), 0.0, 1.0)
	var wet := fill * n
	var acc := 0.0
	for k in range(rows.size() - 1, -1, -1):
		var row: Dictionary = rows[k]
		var cnt := float(row["count"])
		if acc + cnt >= wet - 0.00001:
			var f := clampf((wet - acc) / maxf(cnt, 0.001), 0.0, 1.0)
			return float(int(row["y"]) * WorldGenerator.TILE_SIZE) \
				+ float(WorldGenerator.TILE_SIZE) * (1.0 - f)
		acc += cnt
	return float(int(rows[0]["y"]) * WorldGenerator.TILE_SIZE)


func _recompute_level(group: Dictionary, notify: bool) -> bool:
	var px := _compute_level_px(group)
	var moved := absf(px - float(group["level_px"])) > 0.0001
	group["level_px"] = px
	# level_row bleibt diskret: es steuert NUR noch die Atlas-Slots der
	# (von TerrainContours uebermalten) 16px-Tiles und die Trocken-Logik.
	var new_row := int(floor(px / float(WorldGenerator.TILE_SIZE)))
	var changed := new_row != int(group["level_row"])
	group["level_row"] = new_row
	if changed:
		_apply_dry(group)
	if notify:
		# FEIN: Konturen bei jeder noch so kleinen Aenderung neu zeichnen.
		if moved:
			EventBus.reservoir_volume_changed.emit()
		# GROB: teure Tile-Slot-Umschaltung nur beim Zeilenwechsel.
		if changed:
			EventBus.reservoir_level_changed.emit()
	return changed


func _apply_dry(group: Dictionary) -> void:
	var row := int(group["level_row"])
	for t in group["tiles"]:
		var k := key(t.x, t.y)
		if t.y < row:
			_dry[k] = true
		else:
			_dry.erase(k)


# --------------------------------------------------------------------------- #
# Oeffentliche Abfragen (Generator bleibt rein; hier der Laufzeit-Zustand)
# --------------------------------------------------------------------------- #
func is_reservoir(global_tile_x: int, tile_y: int) -> bool:
	return generator.reservoir_at(global_tile_x, tile_y) if generator != null else false


func is_dry(global_tile_x: int, tile_y: int) -> bool:
	if generator == null or not generator.reservoir_at(global_tile_x, tile_y):
		return false
	_ensure_group(global_tile_x, tile_y)
	return _dry.has(key(global_tile_x, tile_y))


## Y-Koordinate des Wasserspiegels in Welt-Pixeln. Alles oberhalb ist leer.
func waterline_px(global_tile_x: int, tile_y: int) -> float:
	var g := _ensure_group(global_tile_x, tile_y)
	if g.is_empty():
		return 1.0e9
	return float(g["level_px"])


func fill_fraction(global_tile_x: int, tile_y: int) -> float:
	var g := _ensure_group(global_tile_x, tile_y)
	if g.is_empty():
		return 0.0
	return clampf(float(g["volume"]) / maxf(float(g["capacity"]), 0.001), 0.0, 1.0)


## Restmenge auf die alte "pro Tile"-Skala umgerechnet (HUD + P2-Smoke).
func remaining_at(global_tile_x: int, tile_y: int) -> float:
	if generator == null:
		return 0.0
	return generator.reservoir_capacity_at(global_tile_x, tile_y) \
		* fill_fraction(global_tile_x, tile_y)


func group_id_for(global_tile_x: int, tile_y: int) -> String:
	if generator == null or not generator.reservoir_at(global_tile_x, tile_y):
		return ""
	_ensure_group(global_tile_x, tile_y)
	return String(_tile_group.get(key(global_tile_x, tile_y), ""))


## Fuer Tests: alle Tiles eines Beckens (oben nach unten sortiert).
func group_tiles(group_id: String) -> Array:
	return (Array(_groups[group_id]["tiles"]).duplicate()
		if _groups.has(group_id) else [])


func group_volume(group_id: String) -> float:
	return float(_groups[group_id]["volume"]) if _groups.has(group_id) else 0.0


func known_group_ids() -> Array:
	return _groups.keys()


# --------------------------------------------------------------------------- #
# Verbrauch
# --------------------------------------------------------------------------- #
## Entnimmt dem GANZEN Becken, nicht nur dem beruehrten Tile.
func consume(global_tile_x: int, tile_y: int, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var g := _ensure_group(global_tile_x, tile_y)
	if g.is_empty():
		return 0.0
	var taken := minf(amount, float(g["volume"]))
	if taken <= 0.0:
		return 0.0
	g["volume"] = float(g["volume"]) - taken
	_recompute_level(g, true)
	if float(g["volume"]) <= 0.001:
		if not bool(g["announced_empty"]):
			g["announced_empty"] = true
			EventBus.reservoir_dried.emit(Vector2i(global_tile_x, tile_y))
			EventBus.toast.emit(tr("MSG_RESERVOIR_DRY"))
	else:
		EventBus.reservoir_consumed.emit(Vector2i(global_tile_x, tile_y),
			float(g["volume"]))
	return taken


## Sehr langsame natuerliche Versickerung aller bereits entdeckten Becken.
func tick_passive(delta: float) -> void:
	if delta <= 0.0:
		return
	for id in _groups.keys():
		var g: Dictionary = _groups[id]
		if float(g["volume"]) <= 0.0:
			continue
		var drain := PASSIVE_DRAIN_PER_TILE * float((g["tiles"] as Array).size()) * delta
		g["volume"] = maxf(0.0, float(g["volume"]) - drain)
		_recompute_level(g, true)


## Regen fuellt die entdeckten Becken LANGSAM, aber SICHTBAR wieder auf.
## Der Zuwachs skaliert mit der Beckengroesse (nicht fix 1.2/s), sonst sieht
## der Spieler bei einem 100-Tile-Becken keinerlei Veraenderung.
## `factor` kommt aus Global.difficulty_factor("rain_refill").
func refill(delta: float, factor: float = 1.0) -> void:
	if delta <= 0.0:
		return
	for id in _groups.keys():
		var g: Dictionary = _groups[id]
		var capacity := float(g["capacity"])
		if float(g["volume"]) >= capacity:
			continue
		var rate := RAIN_REFILL_PER_TILE \
			* float((g["tiles"] as Array).size()) * maxf(factor, 0.0)
		g["volume"] = minf(capacity, float(g["volume"]) + rate * delta)
		if float(g["volume"]) > 0.001:
			g["announced_empty"] = false
		_recompute_level(g, true)


func dry_count() -> int:
	return _dry.size()


## Fuer Screenshots / Tests: ein ganzes Becken direkt leer machen.
func debug_drain(global_tile_x: int, tile_y: int) -> void:
	if is_reservoir(global_tile_x, tile_y):
		consume(global_tile_x, tile_y, 1.0e9)


## Fuer Screenshots: Becken auf einen bestimmten Fuellstand setzen.
func debug_set_fill(global_tile_x: int, tile_y: int, fraction: float) -> void:
	var g := _ensure_group(global_tile_x, tile_y)
	if g.is_empty():
		return
	g["volume"] = clampf(fraction, 0.0, 1.0) * float(g["capacity"])
	g["announced_empty"] = float(g["volume"]) <= 0.001
	_recompute_level(g, true)


# --------------------------------------------------------------------------- #
# Save / Load (Format v3, liest v2 und v1 weiter)
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	var groups := {}
	for id in _groups.keys():
		groups[String(id)] = float(_groups[id]["volume"])
	var dry: Array = []
	for k in _dry.keys():
		var parts := String(k).split(":")
		dry.append([int(parts[0]), int(parts[1])])
	return {"groups": groups, "dry": dry}


func from_dict(d: Dictionary) -> void:
	reset()
	var groups: Dictionary = d.get("groups", {})
	for id in groups.keys():
		_saved_volumes[String(id)] = float(groups[id])
	# Nur bei ALTEN v2/v1-Saves: `dry`/`remaining` duerfen ein v3-Volumen
	# nicht ueberschreiben (sonst wuerde jedes teilweise geleerte Becken
	# beim Laden komplett trocken).
	if not groups.is_empty():
		return
	for pair in d.get("dry", []):
		if pair is Array and pair.size() >= 2:
			_legacy_dry[key(int(pair[0]), int(pair[1]))] = true
	var rem: Dictionary = d.get("remaining", {})
	for k in rem.keys():
		if float(rem[k]) <= 0.001:
			_legacy_dry[String(k)] = true
