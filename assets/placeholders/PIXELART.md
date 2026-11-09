# Pixelart-Slots (REVISION 6)

Alle Platzhalter liegen in `assets/placeholders/` und werden **ausschließlich**
über `src/render/PixelArt.gd` referenziert. Für einen späteren Pixelart-Satz
einfach die PNGs gleicher Größe ersetzen — Simulations- und Zeichencode muss
nicht geändert werden. Der globale Nearest-Filter ist bereits aktiv
(`project.godot`), daher bleiben die Pixel hart.

| Slot | Datei | Größe | Verwendung |
|---|---|---|---|
| `trunk` | `trunk.png` | 16×16 | Stamm-Faser (`PixelArt.draw_fibre`) + kompatibler Breiten-Träger |
| `branch` | `branch.png` | 16×16 | gezogene Äste (`PixelArt.draw_fibre`) |
| `root` | `root.png` | 16×16 | Wurzel-Hauptfaser (`PixelArt.draw_fibre`) + Sprite-Träger |
| `root_tip` | `root_tip.png` | 16×16 | Wurzelspitzen-Sprite + Ghost-Preview |
| `leaf` | `leaf.png` | 16×16 | Blätter + Deko-Blätter (Skalierung pro Wuchsstufe) |
| `worm` | `worm.png` | 16×16 | Wurm-`Sprite2D`, rotiert entlang der Graberichtung, Skalierung 0.80 |
| `ant` | `ant.png` | 16×16 | Ameisen-`Sprite2D`, Skalierung 0.56 |
| `acorn`, `glucose`, `icon`, `seed_mound` | … | 16×16 | HUD / Eicheln / Samenhügel |
| `bird`, `stump_a/b/c`, `water` | … | 16×16 | Vogel, Stümpfe, Wasser |
| `soil_atlas` | `soil_atlas.png` | Atlas | Boden-Tilemap (17 Slots) |
| `sky_gradient`, `sun_haze`, `mountains_far/near` | … | groß | Hintergrund, eigene Größen erlaubt |

**Freie Geometrie.** Stamm, Äste und Wurzeln sind gekrümmte Kurven; die
Hauptfaser wird mit `PixelArt.draw_fibre()` gekachelt, feine Hyphen/Gabeln,
Wurm-Gänge und Krumen bleiben Vektor-Details und nutzen die zentrale
`PixelArt`-Palette (`BARK_DARK`, `ROOT_FIBRE`, `SOIL_LOOSE`, …). Ein
Pixelart-Satz kann diese Details später entweder behalten oder durch
zusätzliche 16×16-Slots ersetzen — die Farbwerte stehen dann an einer Stelle.

**Größenregel:** neue Tier-/Pflanzen-Slots bitte 16×16 mit transparentem
Hintergrund anlegen. Tierkoerper werden als `Sprite2D`-Kinder mit `centered = true` gesetzt;
`PixelArt.draw_sprite()` bleibt als generischer Helfer fuer weitere Slots. `PixelArt.PATHS` muss bei neuen Slots nur um einen
Eintrag ergänzt werden.
