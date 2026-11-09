class_name SkyBackground
extends CanvasLayer
## Himmel als hoeher aufgeloester, bildschirmfester Verlauf (Ausnahme laut
## Master-Prompt). Liegt hinter der Welt; der Bodenquerschnitt ueberdeckt ihn
## vollstaendig, sobald die Kamera nach unten faehrt.

const SKY_PATH := PixelArt.SKY
const HAZE_PATH := PixelArt.SUN_HAZE

var _sky_rect: TextureRect
var _haze: TextureRect


func _ready() -> void:
	_sky_rect = TextureRect.new()
	_sky_rect.name = "SkyGradient"
	_sky_rect.texture = load(SKY_PATH)
	_sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_sky_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky_rect)

	_haze = TextureRect.new()
	_haze.name = "SunHaze"
	_haze.texture = load(HAZE_PATH)
	_haze.stretch_mode = TextureRect.STRETCH_SCALE
	_haze.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_haze)

	get_viewport().size_changed.connect(refresh_layout)
	refresh_layout()


func refresh_layout() -> void:
	if _sky_rect == null:
		return
	var size := Vector2(get_viewport().get_visible_rect().size)
	_sky_rect.position = Vector2.ZERO
	_sky_rect.size = size
	_haze.size = Vector2(720.0, 720.0)
	_haze.position = Vector2(size.x * 0.72 - 360.0, -180.0)
