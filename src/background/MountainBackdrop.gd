class_name MountainBackdrop
extends Node2D
## Berg-Silhouetten: nur Deko, keine Kollision (Master-Punkt 2).
## Welt-Raum + X-Parallax ueber sich wiederholende, nahtlose Textur-Kopien.
## Hoeher aufgeloest als die Pixel-Art -> linearer Filter erlaubt.

const FAR_PATH := PixelArt.MOUNTAINS_FAR
const NEAR_PATH := PixelArt.MOUNTAINS_NEAR
const COPIES := 6

@export var far_factor: float = 0.18
@export var near_factor: float = 0.38

var camera: Camera2D
var _far: Array[Sprite2D] = []
var _near: Array[Sprite2D] = []


func _ready() -> void:
	_build_layers()
	call_deferred("_late_camera")


func setup(p_camera: Camera2D) -> void:
	camera = p_camera


func _late_camera() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()


func _build_layers() -> void:
	if not _far.is_empty():
		return
	for i in COPIES:
		_far.append(_make_sprite(FAR_PATH, "Far_%d" % i))
		_near.append(_make_sprite(NEAR_PATH, "Near_%d" % i))


func _make_sprite(path: String, sprite_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = sprite_name
	s.texture = load(path)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(s)
	return s


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	var cam_x := camera.global_position.x
	_place_layer(_far, cam_x, far_factor,
		WorldGenerator.BASE_SURFACE_Y - 240.0 + 40.0)
	_place_layer(_near, cam_x, near_factor,
		WorldGenerator.BASE_SURFACE_Y - 200.0 + 25.0)


func _place_layer(layer: Array[Sprite2D], cam_x: float, factor: float, y: float) -> void:
	if layer.is_empty() or layer[0].texture == null:
		return
	var tile_w := float(layer[0].texture.get_width())
	# Bildschirmbewegung = cam_x * factor  =>  Weltposition = cam_x * (1-factor)
	var parallax_x := cam_x * (1.0 - factor)
	var wrap := fmod(parallax_x, tile_w)
	if wrap < 0.0:
		wrap += tile_w
	var base := parallax_x - wrap
	for i in layer.size():
		layer[i].position = Vector2(base + float(i - 2) * tile_w, y)
