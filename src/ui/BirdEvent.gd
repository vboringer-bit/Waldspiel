class_name BirdEvent
extends Node2D
## Scripted Tutorial-Event (Punkt 4.1): Vogel fliegt rein, pickt die erste
## Eichel und fliegt wieder weg. Reine Tween-Animation, keine Spiellogik hier.
##
## BUGFIX vor PHASE 3: Frueher endete der Abflug bei `at + (-780,-280)` und
## der Vogel wurde mitten in der Luft entfernt (je nach Klickposition noch
## weit innerhalb des Bildes). Jetzt wird der ABFLUG in `_set_exit_position`
## jede Frame an die aktuelle linke Bildschirmkante gekoppelt: Der Vogel
## fliegt so lange weiter, bis er tatsaechlich AUS DEM BILD heraus ist, und
## erst dann wird das Sprite freigegeben. Funktioniert bei jedem Zoom und
## auch wenn waehrend des Flugs die Kamera geschwenkt wird.

const BIRD_PATH := "res://assets/placeholders/bird.png"
const ENTER_MARGIN := 140.0        # Start rechts ausserhalb des Bildes
const EXIT_MARGIN := 240.0         # Ziel links ausserhalb des Bildes
const PECK_OFFSET := Vector2(-8.0, -22.0)
const FLY_SPEED := 900.0           # px/s -> Flugdauer aus der Distanz

var last_exit_world_x: float = 0.0
var last_flight_duration: float = 0.0

var _active_sprite: Sprite2D
var _active_tween: Tween
var _active_flap: Tween
var _peck_position: Vector2 = Vector2.ZERO


## Linke Bildschirmkante in WELT-Koordinaten (zoom- und pan-abhaengig).
func screen_left_world_x() -> float:
	var vp := get_viewport().get_visible_rect().size
	var zoom := 1.0
	var cam_x := 0.0
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		zoom = maxf(cam.zoom.x, 0.001)
		cam_x = cam.global_position.x
	return cam_x - vp.x / (2.0 * zoom)


func screen_right_world_x() -> float:
	var vp := get_viewport().get_visible_rect().size
	var zoom := 1.0
	var cam_x := 0.0
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		zoom = maxf(cam.zoom.x, 0.001)
		cam_x = cam.global_position.x
	return cam_x + vp.x / (2.0 * zoom)


func is_offscreen_x(world_x: float) -> bool:
	return world_x < screen_left_world_x()


## Das Ziel des Abflugs: immer links ausserhalb des sichtbaren Bereichs.
func exit_world_x(_at: Vector2) -> float:
	return screen_left_world_x() - EXIT_MARGIN


func spawn_bird(at: Vector2, instant: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Vogel"
	sprite.texture = load(BIRD_PATH)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 50
	var enter := Vector2(maxf(at.x + 700.0,
		screen_right_world_x() + ENTER_MARGIN), at.y - 220.0)
	sprite.position = enter
	add_child(sprite)

	if instant:
		sprite.queue_free()
		return

	_peck_position = at + PECK_OFFSET
	last_exit_world_x = exit_world_x(at)
	var dist := absf(_peck_position.x - last_exit_world_x)
	last_flight_duration = clampf(dist / FLY_SPEED, 1.3, 3.4)
	_active_sprite = sprite

	# Kleiner Fluegelschlag waehrend des gesamten Flugs.
	var flap := create_tween().set_loops()
	_active_flap = flap
	flap.tween_property(sprite, "scale:y", 0.82, 0.16)
	flap.tween_property(sprite, "scale:y", 1.0, 0.16)

	var tw := create_tween()
	_active_tween = tw
	tw.tween_property(sprite, "position", _peck_position, 0.85) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_peck.bind(sprite))
	tw.tween_interval(0.30)
	# tween_method statt tween_property: die linke Bildkante wird bei jedem
	# Schritt neu abgefragt -> Kamera-Pan waehrend des Abflugs ist egal.
	var flight_start := _peck_position + Vector2(0.0, 10.0)
	tw.tween_method(_set_exit_position.bind(sprite, flight_start),
		0.0, 1.0, last_flight_duration).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(_finish.bind(sprite, flap))


## progress 0 = beim Picken, 1 = endgueltig aus dem Bild heraus.
func _set_exit_position(progress: float, sprite: Sprite2D,
		start: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	var target_x := screen_left_world_x() - EXIT_MARGIN
	last_exit_world_x = target_x
	var y := lerpf(start.y, start.y - 260.0, progress)
	sprite.position = Vector2(lerpf(start.x, target_x, progress), y)
	sprite.flip_h = true


func _finish(sprite: Sprite2D, flap: Tween) -> void:
	if flap.is_valid():
		flap.kill()
	if is_instance_valid(sprite):
		sprite.queue_free()
	if _active_sprite == sprite:
		_active_sprite = null
	_active_tween = null


func _peck(sprite: Sprite2D) -> void:
	sprite.flip_h = true
	sprite.position.y += 10.0


# --------------------------------------------------------------------------- #
# Debug-Hooks fuer Screenshots / Smoke-Test
# --------------------------------------------------------------------------- #
## Friere den Abflug bei `progress` ein (0..1), damit man den Vogel noch
## kurz VOR dem Bildrand screenshotten kann.
func debug_bird_progress(progress: float) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	if _active_sprite != null and is_instance_valid(_active_sprite):
		_set_exit_position(clampf(progress, 0.0, 1.0),
			_active_sprite, _peck_position + Vector2(0.0, 10.0))


func debug_active_sprite() -> Sprite2D:
	return _active_sprite


## Smoke-Test: Vogel samt Fluegel-Tween sauber entfernen.
func debug_cleanup() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	if _active_flap != null and _active_flap.is_valid():
		_active_flap.kill()
	_active_flap = null
	if _active_sprite != null and is_instance_valid(_active_sprite):
		_active_sprite.queue_free()
	_active_sprite = null
