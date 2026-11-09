class_name FungusPatch
extends Node2D
## PHASE 5: sichtbarer Pilz-Knoten der Eiche. Wird aktiv, sobald der
## Skilltree-Knoten "mushroom_node" freigeschaltet ist. Die Naehrstoffe
## selbst wirken als `BaseTree.nutrient_mult` (SkillTree.apply_effect).
## Der Patch ist anklickbar und liefert eine Info.

var host: BaseTree = null


func setup(p_host: BaseTree) -> void:
	host = p_host
	global_position = host.global_position + Vector2(26.0, 10.0)
	queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-18.0, -18.0), Vector2(36.0, 22.0))


func info_text() -> String:
	return tr("MSG_FUNGUS_INFO")


func click() -> void:
	EventBus.toast.emit(info_text())


func _draw() -> void:
	var stem := Color(0.88, 0.84, 0.70, 1.0)
	var cap := Color(0.72, 0.24, 0.20, 1.0)
	var dot := Color(0.96, 0.92, 0.82, 1.0)
	for i in range(3):
		var x := -12.0 + float(i) * 12.0
		var h := 7.0 + float(i % 2) * 3.0
		draw_rect(Rect2(x - 2.0, -h, 4.0, h), stem)
		draw_circle(Vector2(x, -h), 6.0, cap)
		draw_circle(Vector2(x - 2.0, -h - 2.0), 1.4, dot)
		draw_circle(Vector2(x + 2.0, -h - 1.0), 1.1, dot)
	draw_line(Vector2(-18.0, 2.0), Vector2(18.0, 2.0),
		Color(0.32, 0.42, 0.24, 0.8), 2.0)
