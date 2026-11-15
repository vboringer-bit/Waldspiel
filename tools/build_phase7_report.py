#!/usr/bin/env python3
"""PHASE 7 — selbst enthaltener MD/HTML-Bericht (Data-URI-Bilder, keine externen Assets)."""
from pathlib import Path
import base64
import html

ROOT = Path(__file__).resolve().parent.parent
SHOTS = [
    ("dry", " links: TROCKEN · sandig-heller Himmel und Boden · Feuchte 15 % · Kosten x1,30"),
    ("temperate", " Mitte: TEMPERIERT · ausgeglichener Startwald · Feuchte 50 % · Kosten x1,00"),
    ("wet", " rechts: FEUCHT · moosig-dunkler Himmel und Boden · Feuchte 85 % · Kosten x0,85"),
]
CHECKS = [
    ("Import", "0 Fehler (Godot 4.7.2, --headless --import)"),
    ("Skilltree", "24 Knoten / 23 Verbindungen, Generator err=0"),
    ("Smokes", "16/16 gruen: 783 OK-Zeilen, 0 FEHLER; drei komplette Laeufe (neu: --p7-smoke mit 130 Checks)"),
    ("F5-Lauf", "180 Frames, exit 0, 0 SCRIPT ERROR"),
    ("Renders", "3 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Zonen", "Kern 2048px exakt temperiert, 4096px Smoothstep-Blende, ab 6144px volles Biom"),
    ("Determinismus", "Gleicher Seed = identische Blende; Biom-Noise verformt nur den Uebergang, nie den Kern"),
    ("Bodenwasser", "WaterSystem: 0,65 trocken / 1,00 Kern / 1,35 feucht"),
    ("Reservoirs", "Blob-Dichte 18 / 34 / 52 und Startkapazitaet 0,70 / 1,00 / 1,40"),
    ("Wachstum", "GrowthCost.for_tile(): 1,30 / 1,00 / 0,85; Akzeptanzkriterium 10 Glucose im Kern bleibt"),
    ("Regeneration", "SoilChemistry regeneriert pro Region mit 0,70 / 1,00 / 1,40"),
    ("Visualisierung", "TerrainContours, TerrainSurface und SkyBackground.toenung; kein zusaetzlicher Draw im Kern"),
    ("BiomeSystem", "Kamera weltweit, biome_changed/biome_discovered, Entdeckungen, HUD, Toast, DE/EN"),
    ("Speichern & Regression", "Format bleibt v6; optionaler Key 'biomes'; alle 653 R0-R8/P6-Checks weiter gruen"),
    ("Abgrenzung", "Keine 5 Tierarten, keine 40-60 Skillnodes, keine begehbaren Berge, kein Tag/Nacht, keine SFX"),
]

SECTIONS = [
    ("Abgrenzung nach Master-Punkt §13",
     "Der Master-Prompt definiert in §10 nur PHASE 0-5. Fuer den Auftrag „Bearbeite jetzt gruendlich Phase 7\" ist PHASE 7 der "
     "<b>erste der in §75 vorbereiteten Kandidaten</b>: die drei Biome aus §3.1. Gemaess §1 („Baue NICHT alles auf einmal\") "
     "ist es EIN Meilenstein. Fuenf Tierarten, 40-60 Skillnodes, begehbare Berge und SFX bleiben aussen vor; Tag/Nacht ist "
     "zusaetzlich durch §5/§12 als expliziter User-Wunsch ausgeschlossen. Die Annahme steht in <code>DECISIONS.md</code> §76."),
    ("Drei Weltzonen mit weicher Blende",
     "<code>WorldGenerator</code> behaelt <code>BiomeKind { TROCKEN, TEMPERIERT, FEUCHT }</code> und den vorbereiteten "
     "<code>_biome_noise</code>. Neu: 1 Chunk (2048px) temperierter Kern, 2 Chunks (4096px) Smoothstep-Blende, ab 3 Chunks "
     "(6144px) volle Auspraegung — links trocken, rechts feucht. <b>Im Kern ist die Blende exakt 0.0</b> und jeder Faktor exakt "
     "1.0; der Noise verformt multiplikativ nur den Uebergang. Hoehenlinie, Hoehlen und das 16px-Raster bleiben unangetastet."),
    ("Echte Simulation statt nur Farbe",
     "Fuenf messbare, multiplikative Effekte: Bodenwasser-Aufnahme in <code>WaterSystem</code> (0,65/1,00/1,35), Wurzel-Kosten "
     "in <code>GrowthCost.for_tile()</code> (1,30/1,00/0,85), Reservoir-Blob-Dichte (18/34/52), Reservoir-Startkapazitaet "
     "(0,70/1,00/1,40) und N/P/K-Regeneration pro Region in <code>SoilChemistry</code> (0,70/1,00/1,40). "
     "<code>biome_moisture_at()</code> liefert 0,15 / 0,50 / 0,85. Die Biome sind Geografie, nicht Schwierigkeit: sie wirken "
     "in LEICHT, NORMAL und SCHWER identisch."),
    ("Visualisierung, HUD und Speichern",
     "<code>TerrainContours</code> zeichnet 32 halbtransparente Streifen pro Chunk (sandig-hell / moosig-dunkel), "
     "<code>TerrainSurface</code> toent die Oberkante und <code>SkyBackground.modulate</code> den Himmel. Im Kern entsteht "
     "<b>kein einziger zusaetzlicher Draw-Befehl</b>, damit <code>Revision4Smoke.debug_static_draws</code> unveraendert bleibt. "
     "<code>BiomeSystem.gd</code> verfolgt die Kamera weltweit, zaehlt Entdeckungen und liefert HUD-Zeile, Toast und DE/EN. "
     "<code>FORMAT_VERSION</code> bleibt 6; <code>biomes</code> ist ein optionaler JSON-Key, alte v1-v6-Saves bleiben lesbar."),
]


def grab(path: str, needle: str, count: int) -> str:
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if needle in line:
            return "\n".join(lines[i:i + count])
    raise SystemExit(f"FEHLER: Snippet-Anker fehlt: {path} :: {needle}")


SNIPPETS = [
    ("Blende: Kern exakt 0, volle Zone exakt 1", "src/world/WorldGenerator.gd",
     grab("src/world/WorldGenerator.gd", "func biome_blend_at(", 16)
     + "\n\n" + grab("src/world/WorldGenerator.gd", "func biome_at(", 6)),
    ("Feuchte- und Kosten-Faktoren", "src/world/WorldGenerator.gd",
     grab("src/world/WorldGenerator.gd", "func biome_moisture_factor_at(", 8)
     + "\n\n" + grab("src/world/WorldGenerator.gd", "func biome_cost_factor_at(", 8)),
    ("Reservoir-Dichte und Kapazitaet", "src/world/WorldGenerator.gd",
     grab("src/world/WorldGenerator.gd", "func biome_reservoir_density_at(", 11)
     + "\n\n" + grab("src/world/WorldGenerator.gd", "func reservoir_capacity_at(", 7)),
    ("Prozedurale Boden- und Himmelstönung", "src/world/WorldGenerator.gd",
     grab("src/world/WorldGenerator.gd", "func biome_tint_at(", 8)),
    ("Reservoir-Blobs lesen die Biom-Dichte", "src/world/WorldGenerator.gd",
     grab("src/world/WorldGenerator.gd", "# PHASE 7: im Kern exakt 34", 4)),
    ("Wurzelkauf bleibt im Kern bei 10 Glucose", "src/systems/GrowthCost.gd",
     grab("src/systems/GrowthCost.gd", "static func for_tile(", 9)),
    ("Bodenwasser-Aufnahme", "src/systems/WaterSystem.gd",
     grab("src/systems/WaterSystem.gd", "# PHASE 7: Geo-Feuchte", 4)),
    ("N/P/K-Regeneration pro Region", "src/systems/SoilChemistry.gd",
     grab("src/systems/SoilChemistry.gd", "for region in cells.keys():", 11)),
    ("BiomeSystem: Signale und Entdeckungen", "src/systems/BiomeSystem.gd",
     grab("src/systems/BiomeSystem.gd", "func _update_at(", 24)),
    ("HUD-Zeile und Save-Zustand", "src/systems/BiomeSystem.gd",
     grab("src/systems/BiomeSystem.gd", "func display_text(", 12)
     + "\n\n" + grab("src/systems/BiomeSystem.gd", "func to_dict(", 8)),
    ("Kein zusätzlicher Draw im Kern", "src/world/TerrainContours.gd",
     grab("src/world/TerrainContours.gd", "func _draw_biome_tint(", 14)),
    ("Optionaler Key in Save v6 + HUD", "src/systems/SaveManager.gd",
     grab("src/systems/SaveManager.gd", '"biomes": BiomeSystem.instance.to_dict()', 2)
     + "\n\n" + grab("src/ui/HUD.gd", "func _refresh_p7_biome(", 10)),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md(images: list[tuple[str, str]]) -> str:
    lines = [
        "# PHASE 7 — Drei Biome, Weltzonen, Biom-Faktoren",
        "",
        "Vollstaendiger PHASE-7-Stand, Nachfolger von `d0c719c` (PHASE 6).",
        "Alle Quellen, Tests, drei Screenshots, Berichte und das ZIP liegen im Workspace und auf GitHub.",
        "",
        "## Die vier Bausteine",
        "",
    ]
    for i, (title, body) in enumerate(SECTIONS, 1):
        plain = body.replace("<b>", "**").replace("</b>", "**").replace("<code>", "`").replace("</code>", "`")
        lines += [f"{i}. **{title}.** {plain}", ""]
    lines += ["## Testergebnisse", "", "| Pruefung | Ergebnis |", "|---|---|"]
    for name, result in CHECKS:
        lines.append(f"| {name} | {result} |")
    lines += ["", "## Screenshots", ""]
    for slug, caption in SHOTS:
        lines.append(f"![{caption}](data:image/png;base64,{dict(images)[slug]})")
        lines += [f"*{caption} — `screenshots/p7_{slug}.png`*", ""]
    lines += ["## Code-Auszuege", ""]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += [
        "## Bewusste Grenze",
        "",
        "Keine 5 Tierarten, keine 40-60 Skillnodes, keine begehbaren Berge, kein Tag/Nacht, keine SFX. "
        "`FORMAT_VERSION` bleibt 6, `Global.auto_mode` bleibt aus, `GLUCOSE_PACE` bleibt 0,2, "
        "24/23 Skillnodes und alle R0-R8-/P6-Korrekturen bleiben gueltig.",
        "",
        "Siehe `PHASE7-TESTPROTOKOLL.txt`, `DECISIONS.md` §76 und `deliverables/waldspiel-PHASE7.zip`.",
        "",
    ]
    return "\n".join(lines)


CSS = """
body{background:#111711;color:#e7e9df;font:15px/1.6 ui-monospace,Menlo,Consolas,monospace;margin:0}
.wrap{max-width:1100px;margin:0 auto;padding:38px 28px 80px}
h1{font-size:27px;color:#cfe6b6;margin:0 0 6px}
h2{font-size:20px;color:#a9d08a;margin:34px 0 12px;border-bottom:1px solid #33422d;padding-bottom:6px}
h3{font-size:15px;color:#d7e8c2;margin:24px 0 8px}
h3 small{color:#8ea37d;font-weight:normal}
.badge{display:inline-block;background:#2c4a2a;color:#c8e6b0;border-radius:4px;padding:3px 10px;font-size:12px}
table{width:100%;border-collapse:collapse;margin:10px 0 24px}
th,td{border:1px solid #33422d;padding:8px 10px;text-align:left;vertical-align:top}
th{background:#1d2a1b;color:#cfe6b6}
td:first-child{width:200px;color:#bcd6a4}
pre{background:#0c120b;border:1px solid #2b3a26;border-radius:5px;padding:14px;overflow-x:auto;color:#c8dcb4;font-size:12.5px;line-height:1.5}
img{width:100%;border:1px solid #33422d;border-radius:5px;margin:8px 0}
.cap{color:#8ea37d;font-size:12px;margin:0 0 26px}
.note{background:#1a2518;border-left:3px solid #6f9a55;padding:12px 16px;color:#c3d6ae}
ol{padding-left:22px}li{margin-bottom:14px}
code{background:#1b2719;padding:1px 4px;border-radius:3px;color:#d8eec0}
"""


def build_html(images: list[tuple[str, str]]) -> str:
    parts = [
        "<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
        "<title>PHASE 7 — Waldspiel</title><style>", CSS,
        "</style></head><body><div class=\"wrap\">",
        "<h1>PHASE 7 — Drei Biome, Weltzonen, Biom-Faktoren</h1>",
        "<p><span class=\"badge\">Meilenstein</span> Basis <code>d0c719c</code> "
        "· Master-Punkt 3.1 · dokumentierte Annahme in <code>DECISIONS.md</code> §76</p>",
        "<h2>Die vier Bausteine</h2><ol>",
    ]
    for title, body in SECTIONS:
        parts.append(f"<li><b>{html.escape(title)}.</b> {body}</li>")
    parts.append("</ol><h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>")
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table><h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        parts.append(f"<img alt=\"{html.escape(caption)}\" "
                     f"src=\"data:image/png;base64,{dict(images)[slug]}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — "
                     f"<code>screenshots/p7_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append(
        "<h2>Lieferung</h2><p class=\"note\">Vollstaendiger Stand inklusive "
        "<code>deliverables/waldspiel-PHASE7.zip</code>. Nach Import, 16/16 Smokes, "
        "F5-Lauf, Renders und frischem ZIP-Extrakt als ein Commit auf <code>main</code> "
        "gepusht. Keine Credentials in Commit, Remote-URL oder Repo-Dateien.</p>"
    )
    parts.append("</div></body></html>")
    return "".join(parts)


def main() -> None:
    images = []
    for slug, _caption in SHOTS:
        p = ROOT / f"screenshots/p7_{slug}.png"
        if not p.exists():
            raise SystemExit(f"FEHLER: Screenshot fehlt: {p}")
        images.append((slug, b64(p)))
    (ROOT / "PHASE7-ERGEBNIS.md").write_text(build_md(images), encoding="utf-8")
    (ROOT / "PHASE7-ERGEBNIS.html").write_text(build_html(images), encoding="utf-8")
    print(f"[P7-REPORT] md + html geschrieben | Bilder: {len(SHOTS)} | "
          f"Snippets: {len(SNIPPETS)} | Checks: {len(CHECKS)}")


if __name__ == "__main__":
    main()
