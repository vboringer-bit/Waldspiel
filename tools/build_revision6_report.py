#!/usr/bin/env python3
"""Erzeugt den selbst enthaltenen REVISION-6-Bericht (.md + .html).

Alle Bilder sind data-URI-embedded, es gibt keine externen Styles, Skripte
oder Fonts. Daher funktioniert der Bericht auch im sandboxed Viewer.
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHOTS = [
    ("drag", "Gezogenes Wachstum: Wurzel, Stamm und Ast"),
    ("canopy", "Dichte Krone nach Skilltree-Kette"),
    ("worms", "Rotierte Würmer, stabile Gänge, bodengebundene Ameisen"),
]

SNIPPETS = [
    ("Zentrale Pixelart-Registry", "src/render/PixelArt.gd", '''const WORM := DIR + "worm.png"
const ANT := DIR + "ant.png"
const PATHS := { "trunk": TRUNK, "branch": BRANCH, "root": ROOT,
                 "leaf": LEAF, "worm": WORM, "ant": ANT, ... }

static func draw_fibre(ci, p, a, b, width, modulate):
    ci.draw_set_transform(a, (b - a).angle(), Vector2(1.0, width / 16.0))
    ci.draw_texture_rect(tex(p), Rect2(0, 0, (b - a).length(), 16.0),
                         true, modulate, false)
    ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)'''),
    ("Stabile Gang-Mittellinie", "src/animals/Animal.gd", '''func _sync_worm_motion(dt: float) -> void:
    var prev := _burrow_center
    surface_y = generator.height_smooth_at(position.x)
    base_y = surface_y + burrow_depth
    _burrow_center = Vector2(position.x, base_y)
    position.y = base_y + sin(phase * 2.2) * 0.30   # nur Koerper wackelt
    var vel := _burrow_center - prev
    if vel.length() > 0.02:
        _body_angle = lerp_angle(_body_angle, atan2(vel.y, vel.x),
                                 clampf(dt * 10.0, 0.0, 1.0))'''),
    ("Ameisen bodengebunden", "src/animals/Animal.gd", '''func _follow_ground() -> void:
    surface_y = generator.height_smooth_at(position.x)
    base_y = surface_y - 1.0
    position.y = base_y + sin(phase * 5.0) * 0.30'''),
    ("Gezielt ziehbare Wurzel", "src/plants/Tree.gd", '''func grow_root_along(world_points, max_steps, from_segment = null) -> int:
    var sampled := _resample_path(locals, DRAG_STEP, max_steps + 2)
    var tip := tip_for(from_segment)
    for idx in range(1, sampled.size()):
        var p: Vector2 = sampled[idx]
        p.y = maxf(p.y, 8.0)
        # logisches 16px-Raster bleibt fuer Wasser/Save erhalten ...
        var seg := _add_root_segment(chosen_grid, chosen, tip, false, p)
        tip = seg
    _refresh_growth_visuals()'''),
    ("Verdickung aller verbundenen Fasern", "src/plants/RootSegment.gd", '''var age := (1.0 + 0.010 * float(tree_ref.root_count)) if tree_ref != null else 1.0
var net := 1.0 + 0.030 * float(descendant_count())
_width = (2.6 + 5.2 * float(BaseTree.STAGE_WIDTHS[stage])) * age * net * depth_fade'''),
    ("Drag-State-Machine", "src/systems/InteractionController.gd", '''func _end_drag(pos: Vector2) -> bool:
    if not _drag_active or _drag_tree == null:
        _left_click(_pending_click)   # kurzer Klick = alte Verhalten
        return false
    var ok := apply_drag_growth(_drag_tree, _drag_kind, pts, _drag_origin_segment)
    _drag_tree.clear_growth_preview()
    return ok'''),
    ("Skilltree: genug Blaetter", "tools/generate_skilltree.gd", '''d.nodes.append(_node("canopy_i", ..., {"max_leaves": 12.0, "grant_leaves": 12.0}))
d.nodes.append(_node("canopy_ii", ..., {"max_leaves": 12.0, "grant_leaves": 12.0,
                                          "leaf_density": 1.0}))
d.nodes.append(_node("canopy_iii", ..., {"max_leaves": 12.0, "grant_leaves": 12.0,
                                           "leaf_density": 1.0}))'''),
    ("Savegame v6: optionale Felder", "src/plants/Tree.gd", '''"free": s.has_free_target, "fx": s.free_target.x, "fy": s.free_target.y,
"trunk_guide": _vecs_to_data(trunk_guide),
"branch_paths": paths,
"skill_leaf_density": skill_leaf_density'''),
]

CHECKS = [
    ("Import", "0 Fehler / 0 Warnungen (Godot 4.7.2, --headless --import)"),
    ("Smokes", "12/12 gruen: 3+26+25+32+27+56+20+32+63+58+35+34 = 411 Checks, 0 FEHLER"),
    ("REVISION-6-Smoke", "34 Checks: Gang stabil, Rotation vertikal/horizontal, Ameisen am Boden, Drag, Verdickung, Pixelart, Skilltree, Save/Load, DE/EN"),
    ("F5-Lauf", "180 Frames, exit 0, 0 SCRIPT ERROR"),
    ("Renders", "3 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Regression", "AUTO aus, Save v6, GLUCOSE_PACE 0.2, 16px-Hitbox, alte Smokes unveraendert gruen"),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md() -> str:
    lines = [
        "# REVISION 6 — Ziehen, Verdickung, stabile Bodenfauna, Pixelart-Slots",
        "",
        "Vollstaendiger Stand auf GitHub, Nachfolger von `5854ac5` (REVISION 5).",
        "Enthaelt Quellen, Assets, Tests, drei Screenshots und `waldspiel-REVISION6.zip`.",
        "",
        "## Was sich geaendert hat",
        "",
        "1. **Wurm-Gang wackelt nicht mehr.** Der Tunnel liegt auf einer stabilen,",
        "   Catmull-Rom-geglaetteten Mittellinie; nur der Koerper hat noch ein",
        "   minimales visuelles Wackeln. Die Spur wird in Eltern-Koordinaten",
        "   gespeichert und wandert nicht mehr mit dem Animations-Offset mit.",
        "2. **Wurm rotiert mit der Grabrichtung.** `atan2(vel.y, vel.x)` steuert",
        "   ein 16x16-`Sprite2D`: oben/unten senkrecht, links/rechts waagerecht,",
        "   diagonal entsprechend dem Pfad.",
        "3. **Ameisen laufen nicht mehr in der Luft.** Nach jeder x-Bewegung wird",
        "   `height_smooth_at(position.x)` neu abgefragt; die Fuesse bleiben auf",
        "   der Geländekante.",
        "4. **Wurzeln, Stamm und Aeste sind gezielt ziehbar.** Linksklick auf eine",
        "   Wurzel / den Baum halten, in die gewuenschte Richtung ziehen, loslassen.",
        "   Das sichtbare Mycelarium-Netz folgt dem Mauspfad (`free_target`,",
        "   `trunk_guide`, `branch_paths`); das logische 16px-Raster bleibt fuer",
        "   Wasser, Reservoir, Klick-Hitboxen und Savegame erhalten.",
        "5. **Jede bereits verbundene Wurzel wird dicker**, analog alle Stamm-",
        "   segmente: Breite = Wuchsstufe x Netzalter x Anzahl Nachkommen.",
        "6. **Alle Texturen sind zentral ersetzbar.** `src/render/PixelArt.gd`",
        "   enthaelt 21 Slots, Palette und `draw_fibre()`; `PIXELART.md`",
        "   beschreibt Groessen und Austausch. Stamm/Ast/Wurzel-Hauptfasern",
        "   sind bereits gekachelte 16x16-Texturen.",
        "7. **Skilltree-Option fuer genug Blaetter.** Drei Stufen",
        "   `canopy_i/ii/iii` (+12 Obergrenze und +12 sofortige Blaetter pro",
        "   Stufe, dazu Kronendichte) heben das Cap von 12 auf 50; 50 Blaetter",
        "   verteilen sich per Goldener-Schnitt-Folge auf alle Ast-Anker.",
        "",
        "## Bedienung",
        "",
        "* MANUELL (Standard): Wurzel oder Baum **anklicken, ziehen, loslassen**.",
        "  Ein kurzer Klick ohne Bewegung verhaelt sich exakt wie vorher.",
        "* `T` oeffnet den Skilltree; Kette: Effizientere Blaetter →",
        "  Photosynthese plus → Kronenwuchs → Dichte Krone I/II/III.",
        "* `R` Regen, Rechtsklick Info, `Esc` Eichel zuruecklegen (unveraendert).",
        "",
        "## Technische Anker",
        "",
        "| Datei | Rolle |",
        "|---|---|",
        "| `src/render/PixelArt.gd`, `assets/placeholders/PIXELART.md` | 21 Slots, Palette, `draw_fibre()`, `draw_sprite()` |",
        "| `src/animals/Animal.gd` | stabile Mittellinie, Rotation, Bodenbindung, rotiertes `Sprite2D` |",
        "| `src/plants/Tree.gd` | Drag-Geometrie, Verdickung, Blattverteilung, optionale Save-Felder |",
        "| `src/plants/RootSegment.gd` | `free_target`, Nachkommen-Zaehlung, gekachelte Wurzelfaser |",
        "| `src/systems/InteractionController.gd` | Drag-State-Machine, Kosten pro ~16 px |",
        "| `src/systems/SkillTree.gd`, `tools/generate_skilltree.gd`, `data/skilltrees/oak.tres` | 18 Knoten / 17 Verbindungen |",
        "| `tests/Revision6Smoke.gd` | 34 neue Checks |",
        "| `screenshots/rev6_{drag,canopy,worms}.png` | 1920x1080 Renders |",
        "",
        "## Testprotokoll",
        "",
    ]
    for name, result in CHECKS:
        lines.append(f"* **{name}:** {result}")
    lines += [
        "",
        "## Screenshots",
        "",
    ]
    for slug, caption in SHOTS:
        lines.append(f"![{caption}](screenshots/rev6_{slug}.png)")
        lines.append("")
        lines.append(f"*{caption}*")
        lines.append("")
    lines += [
        "## Code-Auszuege",
        "",
    ]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += [
        "## Bekannte Grenze",
        "",
        "Der komplette Arbeitsbaum wurde als ein Commit auf `main` gepusht; der",
        "Remote-HEAD ist der Nachfolger von `5854ac5`. Zusaetzlich liegt ein",
        "Godot-importierbares Komplett-Paket `waldspiel-REVISION6.zip` bereit.",
        "Der PAT wurde nur temporaer prozess-lokal verwendet, nicht in Dateien",
        "oder in der Git-Historie abgelegt.",
        "",
    ]
    return "\n".join(lines)


def build_html(md_images: list[tuple[str, str]]) -> str:
    css = """
    body{margin:0;background:#111814;color:#dfe8dc;font:15px/1.65 system-ui,sans-serif}
    .wrap{max-width:1080px;margin:0 auto;padding:32px 28px 80px}
    h1{font-size:30px;color:#a8d89a;border-bottom:2px solid #3f6b3a;padding-bottom:12px}
    h2{font-size:22px;color:#c8e6b8;margin-top:38px;border-left:4px solid #568a46;padding-left:12px}
    h3{font-size:17px;color:#e2efd6;margin-top:26px}
    code,pre{font-family:ui-monospace,Menlo,Consolas,monospace}
    pre{background:#0b100d;border:1px solid #2c3b2c;border-radius:8px;padding:14px;overflow:auto;color:#b8d8ac;font-size:13px}
    table{border-collapse:collapse;width:100%;margin:18px 0}
    td,th{border:1px solid #2c3b2c;padding:8px 10px;text-align:left}
    th{background:#1b2a1d;color:#a8d89a}
    img{width:100%;height:auto;border:1px solid #2c3b2c;border-radius:8px;margin:12px 0 4px}
    .cap{color:#93a88f;font-size:13px;margin:0 0 26px}
    ul{padding-left:22px}
    li{margin:5px 0}
    .badge{display:inline-block;background:#24402a;color:#b8e8a8;border-radius:5px;padding:2px 8px;font-size:12px}
    .note{background:#1a241c;border-left:4px solid #d7a84a;padding:12px 16px;border-radius:6px}
    """
    parts = [
        "<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
        "<title>REVISION 6 — Waldspiel</title><style>", css, "</style></head><body><div class=\"wrap\">",
        "<h1>REVISION 6 — Ziehen, Verdickung, stabile Bodenfauna, Pixelart-Slots</h1>",
        "<p><span class=\"badge\">auf GitHub gepusht</span> Nachfolger von <code>5854ac5</code> · Komplett-Paket <code>waldspiel-REVISION6.zip</code></p>",
        "<h2>Die sieben Korrekturen</h2><ol>",
        "<li><b>Wurm-Gang wackelt nicht mehr:</b> stabile, Catmull-Rom-geglaettete Mittellinie; nur der Koerper animiert.</li>",
        "<li><b>Wurm rotiert mit der Grabrichtung:</b> <code>atan2(vel.y, vel.x)</code> auf ein 16x16-<code>Sprite2D</code>; senkrecht bei vertikalem Graben.</li>",
        "<li><b>Ameisen bodengebunden:</b> Geländehöhe wird nach jeder x-Bewegung neu abgefragt.</li>",
        "<li><b>Gezielt ziehbar:</b> Wurzel / Stamm / Ast per Drag; freie Geometrie, logisches 16px-Raster bleibt fuer Wasser/Save.</li>",
        "<li><b>Verdickung:</b> jede bereits verbundene Wurzel und alle Stammsegmente werden bei weiterem Wachstum dicker.</li>",
        "<li><b>Pixelart:</b> 21 zentrale Slots in <code>PixelArt.gd</code> + <code>PIXELART.md</code>; Hauptfasern sind gekachelte Texturen.</li>",
        "<li><b>Dichte Krone:</b> drei Skilltree-Stufen heben das Blatt-Cap auf 50 und verteilen Blaetter auf alle Ast-Anker.</li>",
        "</ol>",
        "<h2>Bedienung</h2><ul>",
        "<li>MANUELL (Standard): Wurzel oder Baum <b>anklicken, ziehen, loslassen</b>. Kurzer Klick = altes Verhalten.</li>",
        "<li><code>T</code> → Skilltree: Effizientere Blaetter → Photosynthese plus → Kronenwuchs → Dichte Krone I/II/III.</li>",
        "<li>Pixelart spaeter: PNG gleicher Groesse in <code>assets/placeholders/</code> ersetzen; <code>PixelArt.PATHS</code> nur bei neuen Slots ergaenzen.</li>",
        "</ul>",
        "<h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>",
    ]
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table>")
    parts.append("<h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        data = dict(md_images)[slug]
        parts.append(f"<img alt=\"{html.escape(caption)}\" src=\"data:image/png;base64,{data}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — <code>screenshots/rev6_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append(
        "<h2>Grenze dieser Lieferung</h2><p class=\"note\">Vollstaendig gepusht: "
        "alle Quellen, Assets, Tests, Berichte, drei Screenshots und das ZIP "
        "<code>waldspiel-REVISION6.zip</code>. Der Remote-HEAD ist der Nachfolger "
        "von REVISION 5 (<code>5854ac5</code>). Der PAT lag nur temporaer "
        "prozess-lokal vor, nicht in Dateien oder in der Git-Historie.</p>"
    )
    parts.append("</div></body></html>")
    return "".join(parts)


def main() -> None:
    images = []
    for slug, _ in SHOTS:
        path = ROOT / f"screenshots/rev6_{slug}.png"
        if not path.exists():
            raise SystemExit(f"Bild fehlt: {path}")
        images.append((slug, b64(path)))
    (ROOT / "REVISION6-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "REVISION6-ERGEBNIS.html").write_text(build_html(images), encoding="utf-8")
    print("[R6-REPORT] md + html geschrieben | Bilder:", len(images),
          "| Snippets:", len(SNIPPETS))


if __name__ == "__main__":
    main()
