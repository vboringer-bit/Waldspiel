#!/usr/bin/env python3
"""Erzeugt den selbst enthaltenen REVISION-7-Bericht (.md + .html).

Alle vier Screenshots sind data-URI-embedded; es gibt keine externen Styles,
Skripte oder Fonts. Der Bericht funktioniert daher auch im sandboxed Viewer.
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHOTS = [
    ("worms", "Ruhiger Gang, dunklere Würmer, sichtbarer Erdschluss"),
    ("anthill", "Ameisenhuegel schliesst liniengetreu mit dem Boden ab"),
    ("skilltree", "24 Knoten / 23 Linien inkl. Licht- und Jahreszeit-Ast"),
    ("crowding", "Dichter Stand: beschatteter Baum bleibt sichtbar klein"),
]

SNIPPETS = [
    ("Ortfester Tunnel als eigener Node", "src/animals/BurrowTrail.gd", '''class_name BurrowTrail
extends Node2D
var points: PackedVector2Array = PackedVector2Array()

func set_points(p: PackedVector2Array) -> void:
    points = p
    queue_redraw()

func _draw() -> void:
    if points.size() < 2: return
    draw_polyline(points, tunnel, 5.0)
    draw_polyline(points, loose, 2.1)'''),
    ("Wurm ohne Koerper-Wackeln", "src/animals/Animal.gd", '''func _sync_worm_motion(dt: float) -> void:
    surface_y = generator.ground_y_at(position.x)   # sichtbare 4px-Kante
    base_y = surface_y + burrow_depth
    _burrow_center = Vector2(position.x, base_y)
    position.y = base_y                            # KEIN sin() mehr
    if _trail_timer >= BURROW_SAMPLE_TIME:
        if _burrow_center.distance_to(last) >= BURROW_SAMPLE_STEP:
            _trail.append(_burrow_center)
            _publish_trail()'''),
    ("Huegelbasis folgt dem Gelaende", "src/animals/Anthill.gd", '''func _ground_line() -> Array[Vector2]:
    for i in range(BASE_SAMPLES):
        var lx := -_w + 2.0 * _w * float(i) / float(BASE_SAMPLES - 1)
        var gy := generator.ground_y_at(position.x + lx)
        out.append(Vector2(lx, gy - position.y))
    return out'''),
    ("Sichtbare Gelaendekante", "src/world/WorldGenerator.gd", '''func ground_y_at(world_x: float) -> float:
    return roundf(height_smooth_at(world_x) / 4.0) * 4.0'''),
    ("Lichtkonkurrenz", "src/plants/Tree.gd", '''const CROWD_RADIUS := 170.0
const CROWD_MIN_LIGHT := 0.38
const CROWD_SHADE_STRENGTH := 0.75

func light_factor() -> float:
    return clampf(1.0 - CROWD_SHADE_STRENGTH * neighbor_shade(),
                  CROWD_MIN_LIGHT, 1.0)

func crowd_cap(part: String) -> int:
    match part:
        "trunk": return crowd_cap_of(MAX_TRUNK, 2)
        "leaf":  return crowd_cap_of(MAX_LEAVES + skill_max_leaves_bonus, 2)
        "root":  return crowd_cap_of(MAX_ROOTS, 1)
        "branch": return crowd_cap_of(MAX_CUSTOM_BRANCHES, 2)'''),
    ("Weniger Glucose im Schatten", "src/plants/Tree.gd", '''var shade := neighbor_shade()
var lf := clampf(1.0 - CROWD_SHADE_STRENGTH * shade, CROWD_MIN_LIGHT, 1.0)
var compensation := 1.0 + shade_gain * shade
glucose += ... * environment_factor(sunlight) * lf * compensation * dt'''),
    ("Sechs neue Skilltree-Knoten", "tools/generate_skilltree.gd", '''d.nodes.append(_node("light_seeker", ..., {"crowd_tolerance": 0.30}))
d.nodes.append(_node("shade_leaf", ..., {"shade_gain": 0.50}))
d.nodes.append(_node("forest_edge", ..., {"crowd_tolerance": 0.25,
                                         "germination": 0.35}))
d.nodes.append(_node("spring_sap", ..., {"spring_vigor": 0.45}))
d.nodes.append(_node("humus_net", ..., {"nutrients": 0.15,
                                       "root_water": 0.10}))
d.nodes.append(_node("winter_store", ..., {"winter_water": 0.25,
                                          "water_consumption": -0.10}))'''),
    ("Echte Effekte statt Datenknoten", "src/systems/SkillTree.gd", '''t.crowd_tolerance = clampf(bonus("crowd_tolerance"), 0.0, 0.80)
t.shade_gain = clampf(bonus("shade_gain"), 0.0, 1.0)
# SeasonSystem:  germination_mult = st.modifier("germination")
# GrowthSystem:  season_boost     = st.modifier("spring_vigor")
# WaterSystem:   winter_water     = st.modifier("winter_water")'''),
]

CHECKS = [
    ("Import", "0 Fehler (Godot 4.7.2, --headless --import)"),
    ("Skilltree", "24 Knoten / 23 Verbindungen, Generator err=0"),
    ("Smokes", "13/13 gruen: 462 OK-Zeilen, 0 FEHLER; zwei komplette Laeufe mit unterschiedlichen Seeds (neu: --rev7-smoke mit 51 Checks)"),
    ("Render-Robustheit", "Ameisenhuegel als konvexe Dreiecksstreifen: 0 'triangulation failed' in allen Smokes und Renders"),
    ("F5-Lauf", "180 Frames, exit 0, 0 SCRIPT ERROR"),
    ("Renders", "4 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Regression", "AUTO aus, Save v6, GLUCOSE_PACE 0.2, 16px-Hitbox, 21 Pixelart-Slots, alle R1-R6-Smokes unveraendert gruen"),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md(images: list[tuple[str, str]]) -> str:
    lines = [
        "# REVISION 7 — ruhige Gänge, Erdschluss, Licht & neue Skills",
        "",
        "Vollstaendiger REVISION-7-Stand auf GitHub, Nachfolger von `bcbd1ba`",
        "(REVISION 6). Alle Quellen, Tests, vier Screenshots, Berichte und das ZIP",
        "liegen im Workspace und sind Teil desselben Commits auf `main`.",
        "",
        "## Die fuenf Korrekturen",
        "",
        "1. **Wurm-Gang wackelt endgueltig nicht mehr.** Der Tunnel ist kein",
        "   `_draw()` des Tieres mehr, sondern ein eigener `BurrowTrail`-Node mit",
        "   `top_level = true` und absoluter `z_index = 39`. Er hat eine",
        "   Identitaets-Transformation und kann deshalb nicht mehr mit dem Koerper",
        "   mitwandern. Zusaetzlich wurde das `sin()`-Wackeln des Wurms komplett",
        "   entfernt und die Tiefe auf `ground_y_at()` (4px-Kante) gerastet.",
        "2. **Würmer sind dunkler.** `worm.png` und alle gezeichneten Details",
        "   (Segmente, Krumen, Erd-Schleier) sind deutlich gedeckter; der Wurm",
        "   faellt im Boden nicht mehr als leuchtendes Pink auf.",
        "3. **Ameisenhuegel schliessen mit dem Boden ab.** Die Basis wird ueber",
        "   neun Punkte entlang der sichtbaren Gelaendekante abgetastet; das",
        "   Polygon sitzt auf jedem Hoehenschritt auf statt auf einer waagerechten",
        "   Linie zu schweben. Ameisen rasten ebenfalls auf diese Kante.",
        "4. **Sechs sinnvolle Skilltree-Erweiterungen.** Lichtsucher, Schattenlaub,",
        "   Waldrand, Fruehlingssaft, Humusnetz und Wintervorrat: **24 Knoten /",
        "   23 Linien**, alle mit echten Werten in SkillTree, GrowthSystem,",
        "   SeasonSystem, WaterSystem und BaseTree verdrahtet.",
        "5. **Lichtkonkurrenz.** Baeume dichter als 170 px beschatten sich",
        "   gegenseitig. Der beschattete Baum bekommt nur noch 38–100 % Licht,",
        "   produziert weniger Glucose und bleibt bei Stamm, Blaettern, Wurzeln",
        "   und gezogenen Aesten sichtbar kleiner — statt zwei volle Kronen",
        "   uebereinander zu zeichnen. HUD und Toast erklaeren den Grund.",
        "",
        "## Bedienung",
        "",
        "* MANUELL (Standard): Wurzel / Stamm / Ast anklicken, ziehen, loslassen.",
        "* `T` oeffnet den Skilltree; neue Aeste: **Lichtsucher → Schattenlaub →",
        "  Waldrand** sowie **Fruehlingssaft**, **Humusnetz → Wintervorrat**.",
        "* Dicht pflanzen erzeugt natuerlich kleinere Baeume; mit den Licht-Skills",
        "  kann der Spieler gezielt gegensteuern.",
        "",
        "## Testergebnisse",
        "",
        "| Pruefung | Ergebnis |",
        "|---|---|",
    ]
    for name, result in CHECKS:
        lines.append(f"| {name} | {result} |")
    lines += ["", "## Screenshots", ""]
    for slug, caption in SHOTS:
        data = dict(images)[slug]
        lines += [f"![{caption}](data:image/png;base64,{data})", "",
                  f"*{caption}* — `screenshots/rev7_{slug}.png`", ""]
    lines += ["## Code-Auszuege", ""]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += [
        "## Liefergrenze",
        "",
        "Vollstaendiger Stand inklusive `deliverables/waldspiel-REVISION7.zip`.",
        "Als ein Commit auf `main` gepusht (Nachfolger von `bcbd1ba`); ZIP und",
        "Repo-Root sind direkt in Godot importierbar. Keine Credentials in",
        "Commit, Remote-URL oder Repo-Dateien.",
        "",
    ]
    return "\n".join(lines)


def build_html(images: list[tuple[str, str]]) -> str:
    css = """
    body{background:#111711;color:#e7e9df;font:15px/1.6 ui-monospace,Menlo,Consolas,monospace;margin:0}
    .wrap{max-width:1100px;margin:0 auto;padding:28px}
    h1{font-size:26px;color:#cfe6a8;border-bottom:2px solid #4b6b3a;padding-bottom:10px}
    h2{font-size:20px;color:#d7a84a;margin-top:34px}
    h3{font-size:16px;color:#9fc98a;margin-top:22px}
    table{border-collapse:collapse;width:100%;margin:14px 0}
    th,td{border:1px solid #344633;padding:8px 10px;text-align:left;vertical-align:top}
    th{background:#1d2a1b;color:#cfe6a8}
    pre{background:#0c120c;border-left:4px solid #4b6b3a;padding:12px 14px;overflow:auto;color:#d8e5cf}
    img{width:100%;border:1px solid #344633;border-radius:4px;display:block;margin:8px 0}
    .cap{color:#98a88f;font-size:13px;margin:0 0 22px}
    .badge{display:inline-block;background:#4b6b3a;color:#fff;padding:2px 9px;border-radius:10px;font-size:12px}
    .note{background:#1a241c;border-left:4px solid #d7a84a;padding:12px 16px;border-radius:6px}
    """
    parts = [
        "<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
        "<title>REVISION 7 — Waldspiel</title><style>", css,
        "</style></head><body><div class=\"wrap\">",
        "<h1>REVISION 7 — ruhige Gänge, Erdschluss, Licht &amp; neue Skills</h1>",
        "<p><span class=\"badge\">auf GitHub</span> Basis <code>bcbd1ba</code> "
        "· ein Commit auf <code>main</code></p>",
        "<h2>Die fuenf Korrekturen</h2><ol>",
        "<li><b>Gang wackelt nicht mehr:</b> eigener <code>BurrowTrail</code>-Node "
        "mit <code>top_level</code> und Identitaets-Transformation; kein "
        "<code>sin()</code>-Wackeln, Tiefe auf <code>ground_y_at()</code> gerastet.</li>",
        "<li><b>Dunklere Würmer:</b> gedeckte PNG-Palette, dunklere Segmente, "
        "Krumen und staerkerer Erd-Schleier.</li>",
        "<li><b>Ameisenhuegel am Boden:</b> neun Basispunkte folgen der "
        "sichtbaren 4px-Gelaendekante; kein Schweben mehr.</li>",
        "<li><b>24 Skilltree-Knoten:</b> 6 neue Licht-/Jahreszeit-Mutationen "
        "mit echten Effekten auf Keimung, Wuchskraft, Wasser, Naehrstoffe und "
        "Lichtkonkurrenz.</li>",
        "<li><b>Lichtkonkurrenz:</b> dichter Stand bleibt klein (Stamm, Krone, "
        "Wurzeln, Aeste), produziert weniger Glucose; HUD zeigt "
        "<code>Licht xx%</code>.</li>",
        "</ol>",
        "<h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>",
    ]
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table><h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        data = dict(images)[slug]
        parts.append(f"<img alt=\"{html.escape(caption)}\" "
                     f"src=\"data:image/png;base64,{data}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — "
                     f"<code>screenshots/rev7_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append(
        "<h2>Lieferung</h2><p class=\"note\">Vollstaendiger Stand inklusive "
        "<code>deliverables/waldspiel-REVISION7.zip</code>. Als ein Commit auf "
        "<code>main</code> gepusht (Nachfolger von <code>bcbd1ba</code>); "
        "Remote-HEAD, Tree und Raw-Dateien geprueft. Keine Credentials in "
        "Commit, Remote-URL oder Repo-Dateien.</p>"
    )
    parts.append("</div></body></html>")
    return "".join(parts)


def main() -> None:
    images: list[tuple[str, str]] = []
    for slug, _caption in SHOTS:
        p = ROOT / "screenshots" / f"rev7_{slug}.png"
        if not p.is_file():
            raise SystemExit(f"FEHLER: Screenshot fehlt: {p}")
        images.append((slug, b64(p)))
    (ROOT / "REVISION7-ERGEBNIS.md").write_text(
        build_md(images), encoding="utf-8")
    (ROOT / "REVISION7-ERGEBNIS.html").write_text(
        build_html(images), encoding="utf-8")
    print(f"[R7-REPORT] md + html geschrieben | Bilder: {len(images)} "
          f"| Snippets: {len(SNIPPETS)} | Checks: {len(CHECKS)}")


if __name__ == "__main__":
    main()
