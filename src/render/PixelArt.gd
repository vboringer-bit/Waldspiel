class_name PixelArt
extends RefCounted
## REVISION 6: EINZIGE zentrale Stelle fuer alle Platzhalter-Texturen.
##
## Ziel: spaeter kann jedes 16x16-Pixelart einfach durch eine gleich grosse
## PNG ersetzt werden, OHNE dass Simulationscode angefasst werden muss.
## Alle Pfade, Slots, Groessen und die Grundpalette liegen hier. Die
## Platzhalter sind bewusst 16x16 (Nearest-Filter ist global aktiv), groessere
## Hintergruende duerfen eigene Groessen haben (siehe PIXELART.md).
##
## draw_fibre() legt eine Textur GEKACHELT entlang einer freien Kurve. Damit
## sind auch die neuen organischen Staemme/Wurzeln/Aeste texture-basiert:
## trunk.png / root.png / branch.png austauschen genuegt.
## draw_sprite() zeichnet ein rotiertes Tier-Sprite (Wurm folgt der Grab-
## richtung). Feinere Vektor-Details (Hyphen, Gang-Spuren, Krumen) bleiben
## bewusst Geometrie und nutzen PALETTE-Farben statt eigener Magic Numbers.

const DIR := "res://assets/placeholders/"

const ACORN := DIR + "acorn.png"
const BIRD := DIR + "bird.png"
const BRANCH := DIR + "branch.png"
const GLUCOSE := DIR + "glucose.png"
const ICON := DIR + "icon.png"
const LEAF := DIR + "leaf.png"
const MOUNTAINS_FAR := DIR + "mountains_far.png"
const MOUNTAINS_NEAR := DIR + "mountains_near.png"
const ROOT := DIR + "root.png"
const ROOT_TIP := DIR + "root_tip.png"
const SEED_MOUND := DIR + "seed_mound.png"
const SKY := DIR + "sky_gradient.png"
const SOIL_ATLAS := DIR + "soil_atlas.png"
const STUMP_A := DIR + "stump_a.png"
const STUMP_B := DIR + "stump_b.png"
const STUMP_C := DIR + "stump_c.png"
const SUN_HAZE := DIR + "sun_haze.png"
const TRUNK := DIR + "trunk.png"
const WATER := DIR + "water.png"
## REVISION 6: eigene Slots fuer die Bodenfauna (vorher nur Vektor-Zeichnung).
const WORM := DIR + "worm.png"
const ANT := DIR + "ant.png"

const PATHS := {
	"acorn": ACORN, "bird": BIRD, "branch": BRANCH, "glucose": GLUCOSE,
	"icon": ICON, "leaf": LEAF, "mountains_far": MOUNTAINS_FAR,
	"mountains_near": MOUNTAINS_NEAR, "root": ROOT, "root_tip": ROOT_TIP,
	"seed_mound": SEED_MOUND, "sky": SKY, "soil_atlas": SOIL_ATLAS,
	"stump_a": STUMP_A, "stump_b": STUMP_B, "stump_c": STUMP_C,
	"sun_haze": SUN_HAZE, "trunk": TRUNK, "water": WATER,
	"worm": WORM, "ant": ANT,
}

## Grundpalette der Vektor-Details. Auch diese Farben sind zentral, damit ein
## spaeterer Pixelart-Satz die Geometrie farblich passend ergaenzen kann.
const BARK_DARK := Color(0.19, 0.13, 0.09)
const BARK := Color(0.40, 0.27, 0.16)
const ROOT_FIBRE := Color(0.74, 0.57, 0.34)
const ROOT_HALO := Color(0.60, 0.45, 0.27, 0.30)
const HYPHA := Color(0.70, 0.54, 0.33, 0.88)
const SOIL_DARK := Color(0.15, 0.10, 0.06)
const SOIL_LOOSE := Color(0.66, 0.48, 0.29)
const WORM_BODY := Color(0.88, 0.52, 0.47)
const ANT_BODY := Color(0.16, 0.12, 0.10)


static func path(name: String) -> String:
	return String(PATHS.get(name, DIR + name + ".png"))


static func tex(p: String) -> Texture2D:
	if not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D


## Gekachelte 16x16-Textur entlang einer Strecke. Die Texturhoehe wird auf die
## gewuenschte Faserbreite skaliert; die Breite kachelt entlang der Strecke.
## Damit bleiben freie Kurven weiterhin pixelart-faehig.
static func draw_fibre(ci: CanvasItem, p: String, a: Vector2, b: Vector2,
		width: float, modulate: Color = Color.WHITE) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.5:
		return
	var texture := tex(p)
	if texture == null:
		ci.draw_line(a, b, modulate, maxf(width, 1.0))
		return
	var sy := maxf(width, 1.0) / 16.0
	ci.draw_set_transform(a, d.angle(), Vector2(1.0, sy))
	ci.draw_texture_rect(texture, Rect2(0.0, 0.0, length, 16.0),
		true, modulate, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rotiertes, zentriertes 16x16-Sprite (Wurm folgt seiner Graberichtung).
static func draw_sprite(ci: CanvasItem, p: String, center: Vector2,
		angle: float, scale: Vector2, modulate: Color = Color.WHITE) -> void:
	var texture := tex(p)
	if texture == null:
		return
	ci.draw_set_transform(center, angle, scale)
	ci.draw_texture_rect_region(texture, Rect2(-8.0, -8.0, 16.0, 16.0),
		Rect2(0.0, 0.0, 16.0, 16.0), modulate, false, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
