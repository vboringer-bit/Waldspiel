class_name Anthill
extends Node2D
## PHASE 5: kleiner Erd-Pixelhaufen der Ameisen. Waechst langsam mit der
## Kolonie; jeder Huegel ist anklickbar und zeigt die aktuelle Groesse.
## Kein externes Asset: das Mound wird zur Laufzeit gezeichnet.

var colony_size: int = 1
var growth: float = 1.0
var wildlife = null
var _phase: float = 0.0


func setup(p_x: float, p_y: float, p_wildlife, p_colony: int = 1) -> void:
	position = Vector2(p_x, p_y)
	wildlife = p_wildlife
	colony_size = maxi(p_colony, 1)
	growth = clampf(1.0 + 0.14 * float(colony_size - 1), 1.0, 3.0)
	queue_redraw()


func grow(amount: int = 1) -> void:
	colony_size += maxi(amount, 1)
	growth = clampf(growth + 0.12 * float(amount), 1.0, 3.0)
	queue_redraw()


func tick(dt: float) -> void:
	_phase += dt
	# Sehr langsame Atem-Bewegung der Huegeloberkante.
	if int(_phase * 2.0) % 2 == 0:
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-22.0, -30.0), Vector2(44.0, 32.0))


func info_text() -> String:
	return tr("MSG_ANTHILL_INFO") % colony_size


func click() -> void:
	EventBus.toast.emit(info_text())


func _draw() -> void:
	var h := 12.0 * growth
	var w := 20.0 * growth
	var pts := PackedVector2Array([
		Vector2(-w, 0.0),
		Vector2(-w * 0.55, -h * 0.55),
		Vector2(-w * 0.15, -h),
		Vector2(w * 0.20, -h * 0.82),
		Vector2(w * 0.62, -h * 0.42),
		Vector2(w, 0.0),
	])
	draw_colored_polygon(pts, Color(0.34, 0.24, 0.15, 1.0))
	draw_polyline(pts, Color(0.20, 0.14, 0.09, 1.0), 2.0)
	draw_circle(Vector2(0.0, -h * 0.42), 2.2,
		Color(0.10, 0.08, 0.06, 1.0))
	for i in range(3):
		var x := -w * 0.6 + float(i) * w * 0.6
		draw_circle(Vector2(x, -h * 0.2), 1.2,
			Color(0.48, 0.35, 0.21, 1.0))
