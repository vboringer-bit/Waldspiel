class_name CameraController
extends Camera2D
## PHASE 0 Kamera: Mausrad-Zoom (0.5x - 2.0x, smooth lerp), WASD-Pan und
## Maus-am-Rand-Pan. X ist unbegrenzt (infinite Chunks), Y wird auf den
## sichtbaren Weltausschnitt (Himmel bis Fels-Basement) begrenzt.

const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0

@export var pan_speed: float = 900.0
@export var edge_margin: float = 28.0
@export var edge_speed: float = 650.0
@export var zoom_smoothing: float = 9.0
@export var zoom_step: float = 1.12
@export var min_y: float = -350.0
@export var max_y: float = 1000.0

var _target_pos := Vector2.ZERO
var _target_zoom := 1.0


func _ready() -> void:
	enabled = true
	position_smoothing_enabled = false  # wir lerpen selbst, zoom-abhaengig
	_target_pos = global_position
	_target_zoom = clampf(zoom.x, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * _target_zoom


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom = clampf(_target_zoom * zoom_step, MIN_ZOOM, MAX_ZOOM)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom = clampf(_target_zoom / zoom_step, MIN_ZOOM, MAX_ZOOM)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var direction := Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	var edge := _edge_direction()
	direction += edge * (edge_speed / pan_speed)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var speed := pan_speed / maxf(zoom.x, 0.1)
	_target_pos += direction * speed * delta
	_target_pos.y = clampf(_target_pos.y, min_y, max_y)

	var before := global_position
	global_position = global_position.lerp(_target_pos, 1.0 - exp(-14.0 * delta))
	zoom = zoom.lerp(Vector2.ONE * _target_zoom, 1.0 - exp(-zoom_smoothing * delta))

	if global_position.distance_squared_to(before) > 1.0:
		EventBus.camera_moved.emit(global_position)


func _edge_direction() -> Vector2:
	var size := Vector2(get_viewport_rect().size)
	var mouse := get_viewport().get_mouse_position()
	if mouse.x < 0.0 or mouse.x > size.x or mouse.y < 0.0 or mouse.y > size.y:
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x < edge_margin:
		dir.x -= 1.0
	elif mouse.x > size.x - edge_margin:
		dir.x += 1.0
	if mouse.y < edge_margin:
		dir.y -= 1.0
	elif mouse.y > size.y - edge_margin:
		dir.y += 1.0
	return dir


## Oeffentlicher Teleport (Save/Load, Kamera-folgt-Baum, Smoke-Test).
func teleport_to(p: Vector2) -> void:
	_target_pos = p
	_target_pos.y = clampf(_target_pos.y, min_y, max_y)
	global_position = _target_pos


## Zoom ohne Lerp setzen (Save/Load, reproduzierbare Screenshots).
func set_zoom_immediate(value: float) -> void:
	_target_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * _target_zoom
