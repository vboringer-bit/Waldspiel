class_name Parasite
extends Node2D
## PHASE 5: EIN Parasit am Baum. Zwei Auspraegungen gemaess Master-Punkt 6/7:
## Mistel und Borkenlarve ("Wurmbefall"). Beide ziehen echte Glucose ab.
## Frei lebende Regenwuermer bleiben bewusst nuetzliche Futter-Tiere.

enum Kind { MISTLETOE, WORM }

const DRAIN := {
	Kind.MISTLETOE: 0.35,
	Kind.WORM: 0.22,
}

var kind: int = Kind.MISTLETOE
var host: BaseTree = null
var drain_scale: float = 1.0
var phase: float = 0.0


func setup(p_kind: int, p_host: BaseTree, p_drain_scale: float) -> void:
	kind = p_kind
	host = p_host
	drain_scale = maxf(p_drain_scale, 0.0)
	var offset := Vector2(20.0, -58.0) if kind == Kind.MISTLETOE \
		else Vector2(-22.0, -28.0)
	global_position = host.global_position + offset
	z_index = 12
	queue_redraw()


func tick(dt: float) -> void:
	phase += dt
	if host == null or not is_instance_valid(host):
		return
	host.glucose = maxf(host.glucose - float(DRAIN[kind]) * drain_scale * dt, 0.0)
	queue_redraw()


func kind_key() -> String:
	return "MSG_PARASITE_MISTLETOE" if kind == Kind.MISTLETOE \
		else "MSG_PARASITE_WORM"


func get_info_text() -> String:
	return tr("MSG_PARASITE_INFO") % [tr(kind_key())]


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-18.0, -18.0), Vector2(36.0, 32.0))


func click() -> void:
	EventBus.toast.emit(get_info_text())


func _draw() -> void:
	var sway := sin(phase * 3.0) * 1.5
	if kind == Kind.MISTLETOE:
		var green := Color(0.24, 0.48, 0.24, 1.0)
		var light := Color(0.42, 0.68, 0.34, 1.0)
		draw_line(Vector2(0.0, 8.0), Vector2(0.0, -8.0), green, 3.0)
		for i in range(5):
			var a := float(i) * 1.256 + sway * 0.08
			var tip := Vector2(cos(a) * 13.0, sin(a) * 7.0 - 8.0)
			draw_line(Vector2(0.0, -8.0), tip, green, 2.0)
			draw_circle(tip, 3.2, light)
		for i in range(3):
			draw_circle(Vector2(-6.0 + float(i) * 6.0, -4.0 + sway),
				2.2, Color(0.92, 0.90, 0.82, 1.0))
	else:
		var larva := Color(0.82, 0.70, 0.46, 1.0)
		var ring := Color(0.55, 0.42, 0.25, 1.0)
		for i in range(5):
			var x := -12.0 + float(i) * 6.0
			var y := -8.0 + sin(phase * 5.0 + float(i)) * 2.0
			draw_circle(Vector2(x, y), 4.0, larva)
			draw_arc(Vector2(x, y), 4.0, 0.0, TAU, 8, ring, 1.0)
		draw_circle(Vector2(14.0, -8.0), 2.0, ring)
