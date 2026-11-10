class_name Anthill
extends Node2D
## PHASE 5: kleiner Erd-Pixelhaufen der Ameisen. Waechst langsam mit der
## Kolonie; jeder Huegel ist anklickbar und zeigt die aktuelle Groesse.
## REVISION 7: Der Huegel schliesst LINIENGETREU mit dem Boden ab. Frueher
## sass er auf einer einzigen, waagerechten Grundlinie in `height_smooth_at(x)`;
## bei geneigtem Gelaende hing damit eine Seite in der Luft. Jetzt wird die
## sichtbare 4px-Gelaendekante (`WorldGenerator.ground_y_at()`) ueber die
## gesamte Huegelbreite abgetastet und die Basis folgt jedem Schritt.
##
## Zeichentechnik: ein einziges konkaves Polygon mit einer 4px-Saegezahn-
## Basis bringt Godot 4.7 bei manchen Seeds mit "Invalid polygon data,
## triangulation failed". Deshalb wird der Huegel aus konvexen DREIECKS-
## STREIFEN zwischen Basiskante und oberer Glockenkontur gezeichnet. Jedes
## Dreieck ist garantiert nicht degeneriert -> keine Triangulierungsfehler.

const BASE_SAMPLES := 9

var colony_size: int = 1
var growth: float = 1.0
var wildlife = null
var generator: WorldGenerator = null
var _phase: float = 0.0
var _h: float = 12.0
var _w: float = 20.0
var _base_profile: Array[Vector2] = []


func setup(p_x: float, p_y: float, p_wildlife, p_colony: int = 1,
		p_generator: WorldGenerator = null) -> void:
	generator = p_generator
	position = Vector2(p_x, p_y)
	wildlife = p_wildlife
	colony_size = maxi(p_colony, 1)
	_sync_size()
	queue_redraw()


func _sync_size() -> void:
	growth = clampf(1.0 + 0.14 * float(colony_size - 1), 1.0, 3.0)
	_h = 12.0 * growth
	_w = 20.0 * growth


func grow(amount: int = 1) -> void:
	colony_size += maxi(amount, 1)
	growth = clampf(growth + 0.12 * float(amount), 1.0, 3.0)
	_sync_size()
	queue_redraw()


func tick(dt: float) -> void:
	_phase += dt
	# Sehr langsame Atem-Bewegung der Huegeloberkante (nur Redraw, KEINE
	# Positionsaenderung -> der Huegel bleibt am Boden kleben).
	if int(_phase * 2.0) % 2 == 0:
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-_w - 4.0, -_h - 8.0),
		Vector2(2.0 * _w + 8.0, _h + 12.0))


func info_text() -> String:
	return tr("MSG_ANTHILL_INFO") % colony_size


func click() -> void:
	EventBus.toast.emit(info_text())


## REVISION 7: exakt die Linie, auf der der Huegel aufsitzt (lokale Koordinaten).
func _ground_line() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(BASE_SAMPLES):
		var lx := -_w + 2.0 * _w * float(i) / float(BASE_SAMPLES - 1)
		var gy := position.y
		if generator != null:
			gy = generator.ground_y_at(position.x + lx)
		out.append(Vector2(lx, gy - position.y))
	return out


## Obere Glockenkontur: in der Mitte `_h` ueber der Basis, an den Raendern
## nur 0.5 px. Damit liegt JEDER obere Punkt strikt ueber seinem Basispunkt.
func _top_line(base: Array[Vector2]) -> Array[Vector2]:
	var hi := 0.0
	for b in base:
		hi = minf(hi, b.y)
	var out: Array[Vector2] = []
	for b in base:
		var t := clampf(absf(b.x) / maxf(_w, 0.001), 0.0, 1.0)
		var shape: float = 1.0 - pow(t, 1.7)
		out.append(Vector2(b.x, minf(hi, b.y) - 0.5 - _h * shape))
	return out


func _draw() -> void:
	var base := _ground_line()
	var top := _top_line(base)
	_base_profile.clear()
	for b in base:
		_base_profile.append(Vector2(position.x + b.x, position.y + b.y))
	var hill := Color(0.34, 0.24, 0.15, 1.0)
	var outline_col := Color(0.20, 0.14, 0.09, 1.0)
	# Konvexe Dreiecke statt eines konkaven Gesamtpolygons.
	for i in range(base.size() - 1):
		var a := PackedVector2Array()
		a.append(base[i])
		a.append(base[i + 1])
		a.append(top[i + 1])
		draw_colored_polygon(a, hill)
		var b := PackedVector2Array()
		b.append(base[i])
		b.append(top[i + 1])
		b.append(top[i])
		draw_colored_polygon(b, hill)
	# Obere Kontur + beide Flanken als geschlossene Umrandung.
	var outline := PackedVector2Array()
	for q in top:
		outline.append(q)
	outline.append(base[base.size() - 1])
	for i in range(base.size() - 2, -1, -1):
		outline.append(base[i])
	draw_polyline(outline, outline_col, 2.0)
	# Dunkler Rim direkt auf der sichtbaren Gelaendekante.
	var rim := PackedVector2Array()
	for q in base:
		rim.append(q)
	draw_polyline(rim, Color(0.17, 0.12, 0.08, 1.0), 2.2)
	# Eingang + drei Erdkrümel, alle relativ zur echten Basis.
	var mid := base[BASE_SAMPLES / 2]
	var mid_top := top[BASE_SAMPLES / 2]
	draw_circle(Vector2(mid.x, lerpf(mid.y, mid_top.y, 0.40)), 2.2,
		Color(0.10, 0.08, 0.06, 1.0))
	for i in range(3):
		var idx := 2 + i * 2
		if idx >= base.size():
			idx = base.size() - 1
		draw_circle(Vector2(base[idx].x,
			lerpf(base[idx].y, top[idx].y, 0.20)), 1.2,
			Color(0.48, 0.35, 0.21, 1.0))


# --------------------------------------------------------------------------- #
# REVISION 7 Debug-Hooks
# --------------------------------------------------------------------------- #
func _profile_now() -> Array[Vector2]:
	if generator == null:
		return []
	var out: Array[Vector2] = []
	for b in _ground_line():
		out.append(Vector2(position.x + b.x, position.y + b.y))
	return out


func debug_base_profile() -> Array[Vector2]:
	return _profile_now()


func debug_base_gap() -> float:
	if generator == null:
		return 999.0
	var worst := 0.0
	for q in _profile_now():
		worst = maxf(worst, absf(q.y - generator.ground_y_at(q.x)))
	return worst


func debug_ground_gap() -> float:
	if generator == null:
		return 999.0
	return absf(position.y - generator.ground_y_at(position.x))


func debug_ground_y() -> float:
	return position.y
