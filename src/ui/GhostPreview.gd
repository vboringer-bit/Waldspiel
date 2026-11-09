class_name GhostPreview
extends Node2D
## PHASE 2: "Zeige Ghost-Preview wohin Wurzel wachsen würde" (Punkt 4.2).
## Halbdurchsichtiges Wurzel-Sprite + Rahmen + Kosten-Label am Ziel-Tile.
## Wird von InteractionController bei Mausbewegung im MANUELL-Modus gefuettert.

const ROOT_PATH := PixelArt.ROOT_TIP

var _sprite: Sprite2D
var _label: Label
var _tile_pos: Vector2 = Vector2.ZERO
var _affordable: bool = true
var _label_settings: LabelSettings


func _ready() -> void:
	name = "GhostPreview"
	z_index = 60

	_sprite = Sprite2D.new()
	_sprite.name = "GhostRoot"
	_sprite.texture = load(ROOT_PATH)
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate = Color(0.72, 1.0, 0.68, 0.48)
	add_child(_sprite)

	_label_settings = LabelSettings.new()
	_label_settings.font_size = 13
	_label_settings.font_color = Color(0.86, 0.95, 0.76)
	_label_settings.shadow_size = 2
	_label_settings.shadow_color = Color(0, 0, 0, 0.9)

	_label = Label.new()
	_label.name = "CostLabel"
	_label.label_settings = _label_settings
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	hide_ghost()


func show_at(world_pos: Vector2, cost: float, affordable: bool, material: String) -> void:
	_tile_pos = world_pos
	_affordable = affordable
	_sprite.position = world_pos
	_sprite.modulate = Color(0.72, 1.0, 0.68, 0.50) if affordable else Color(1.0, 0.55, 0.45, 0.50)
	_label.position = world_pos + Vector2(20.0, -20.0)
	_label.text = "%s  ·  −%.0f %s" % [material, cost, tr("HUD_GLUCOSE")]
	_label.modulate = Color.WHITE if affordable else Color(1.0, 0.68, 0.62)
	visible = true
	queue_redraw()


func hide_ghost() -> void:
	visible = false
	_affordable = true


func _draw() -> void:
	if not visible:
		return
	var col := Color(0.68, 0.94, 0.60, 0.95) if _affordable else Color(0.94, 0.46, 0.40, 0.95)
	var rect := Rect2(_tile_pos, Vector2(16.0, 16.0))
	draw_rect(rect, col, false, 1.5)
	draw_line(Vector2(_tile_pos.x + 8.0, _tile_pos.y - 8.0),
		Vector2(_tile_pos.x + 8.0, _tile_pos.y - 1.0), col, 1.0)
