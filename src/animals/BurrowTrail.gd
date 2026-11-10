class_name BurrowTrail
extends Node2D
## REVISION 7: Der Wurm-Gang ist ein EIGENER, ortsfester CanvasItem.
##
## Frueher wurde der Tunnel im `_draw()` des Tieres gezeichnet. Dadurch hing
## er am Transform des Wurms: jede Koerperbewegung (auch das kleine visuelle
## Wackeln) verschob die Ganglinie mit. Jetzt liegt der Tunnel als Geschwister
## des Tieres im WildlifeSystem, ist `top_level = true` und hat eine konstante
## Identitaets-Transformation. Die Punkte sind WELT-/Eltern-Koordinaten und
## werden unveraendert gezeichnet. Der Wurm kann sich bewegen, ohne dass der
## Gang auch nur einen Pixel wandert.

const TUNNEL_ALPHA := 0.58
const LOOSE_ALPHA := 0.72

var points: PackedVector2Array = PackedVector2Array()


func set_points(p: PackedVector2Array) -> void:
	points = p
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var tunnel := Color(PixelArt.SOIL_DARK.r, PixelArt.SOIL_DARK.g,
		PixelArt.SOIL_DARK.b, TUNNEL_ALPHA)
	var loose := Color(PixelArt.SOIL_LOOSE.r, PixelArt.SOIL_LOOSE.g,
		PixelArt.SOIL_LOOSE.b, LOOSE_ALPHA)
	draw_polyline(points, tunnel, 5.0)
	draw_polyline(points, loose, 2.1)
	for i in range(2, points.size(), 8):
		draw_circle(points[i], 1.1, loose)


func debug_point_count() -> int:
	return points.size()


func debug_first_point() -> Vector2:
	return points[0] if points.size() > 0 else Vector2.ZERO
