class_name TerrainWaterPainter
extends Node2D
## REVISION 4: Eigener CanvasItem NUR fuer die dynamische Wasser-Kontur.
##
## Das Problem: Ein Node2D merkt sich seine draw_rect/draw_polygon-Befehle und
## fuehrt sie in JEDEM Frame erneut aus, ABER queue_redraw() baut die ganze
## Liste neu auf. Vor REVISION 4 wurden bei jedem Pegelschritt alle Hoehlen,
## Erdschichten, Atlas-Kacheln UND Wasserzellen neu berechnet (~67 ms pro
## Chunk, 5 Chunks -> ~335 ms Ruckler).
##
## Jetzt zeichnet TerrainContours (Parent) die statischen Teile EINMAL, und
## dieses Kind zeichnet ausschliesslich das Wasser. queue_redraw() auf dem
## Kind beruehrt die statische Befehlsliste nicht mehr. Das Kind wird nach dem
## Parent gezeichnet -> Wasser liegt korrekt ueber Erde/Hoehlen.

var host: TerrainContours


func _draw() -> void:
	if host != null:
		host.paint_water(self)
