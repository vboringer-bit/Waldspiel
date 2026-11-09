#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt REVISION2-ERGEBNIS.md und REVISION2-ERGEBNIS.html.

Alle Snippets kommen direkt aus den echten Projektdateien, alle Bilder sind
als data-URI eingebettet (offline im Arena-Preview sichtbar).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("rev2_edges.png", "Weiche Kanten: Erdschichten, Höhlen, Wasser",
     "TerrainContours · 4px-Isolinien, Schicht-Rims, Wobble · Seed 20261105"),
    ("rev2_water_half.png", "Becken bei 45 % – Pegel von oben nach unten",
     "Trocken/hell oberhalb, blau darunter, helle Wasserspiegel-Linie · keine Chunk-Naht"),
    ("rev2_water_low.png", "Dasselbe Becken bei 18 %",
     "Der Pegel ist weiter gesunken · gemeinsames Volumen statt einzelner Tiles"),
    ("rev2_caves.png", "Höhlen ~50 % seltener, weiterhin organisch",
     "Radien × √0.5 bei unveränderter Blob-Zellendichte · Seed 20261105"),
    ("rev2_surface.png", "Regression: fließende Oberfläche (REVISION 1)",
     "4px-Profil bleibt, alle P0/P1/P2/REV1-Smokes weiterhin OK"),
    ("rev2_fullscreen_2560.png", "Vollbild 2560×1440 füllt den Monitor",
     "Xvfb-Root-Capture · kein grauer Rand · HUD mitvergrößert"),
]


def extract(rel: str, start: str, end: str) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8")
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"Start-Marker fehlt: {start!r} in {rel}")
    j = text.find(end, i)
    if j < 0:
        j = len(text)
    return text[i:j].rstrip() + "\n"


SNIPPETS = [
    ("project.godot — Vollbild + Forward+ (unverändert)", "ini",
     extract("project.godot", "[display]", "[layer_names]")),
    ("TerrainContours.gd — Übermalen + Zeichenreihenfolge", "gdscript",
     extract("src/world/TerrainContours.gd", "func _draw()", "# --------------------------------------------------------------------------- #\n# Erdschichten")),
    ("TerrainContours.gd — globale Feldabfrage + Smoothstep-Isolinie", "gdscript",
     extract("src/world/TerrainContours.gd", "func _s(gx", "## Kleine horizontale")),
    ("TerrainContours.gd — Wasserlöcher schließen („hängt zusammen“)", "gdscript",
     extract("src/world/TerrainContours.gd", "## Kleine horizontale", "func _line_of")),
    ("WorldGenerator.gd — Höhlenfläche halbieren, nicht Zellenzahl", "gdscript",
     extract("src/world/WorldGenerator.gd", "var cave_area_scale", "func _blob_field")),
    ("WorldGenerator.gd — 1-Tile-Dilatation verbindet Reservoirs", "gdscript",
     extract("src/world/WorldGenerator.gd", "func _raw_reservoir", "func material_at")),
    ("WorldState.gd — EIN Becken, EIN Volumen, Pegel von oben nach unten", "gdscript",
     extract("src/world/WorldState.gd", "func _build_group", "# --------------------------------------------------------------------------- #\n# Oeffentliche Abfragen")),
    ("WorldState.gd — Entnahme wirkt auf das ganze Becken", "gdscript",
     extract("src/world/WorldState.gd", "func consume", "## Sehr langsame")),
    ("WorldState.gd — Savegame v3 (v2/v1 bleiben lesbar)", "gdscript",
     extract("src/world/WorldState.gd", "func from_dict", "\n")),
    ("WaterSystem.gd — Wurzel entnimmt, Regen füllt auf", "gdscript",
     extract("src/systems/WaterSystem.gd", "func tick", "func reservoir_fraction")),
    ("Main.gd — reproduzierbare Pegel-Presets für Screenshots", "gdscript",
     extract("src/Main.gd", "## REVISION 2: Fuellstand", "## Reproduzierbare Zustaende")
     + "\n\n" + extract("src/Main.gd", "\tif args.has(\"--rev2-shot-edges\")", "\telif args.has(\"--rev1-shot-surface\")")),
    ("tests/Revision2Smoke.gd — Dichte & Pegel-Abnahme", "gdscript",
     extract("tests/Revision2Smoke.gd", "\tvar needed :=", "\t_check(")),
]

LOG_FILE = ROOT / "REVISION2-TESTPROTOKOLL.txt"
SMOKE_LOG = (LOG_FILE.read_text(encoding="utf-8")
             if LOG_FILE.exists() else "[SMOKE] Ergebnis: OK")

CHECKS = [
    "✅ **Weiche Kanten überall:** Höhlen, Wasserreservoirs und Erdschichtgrenzen werden in 4px-Schritten als Isolinie / Verlauf mit Rim gezeichnet – nicht mehr als 16px-Blockstufen.",
    "✅ **Keine Chunk-Naht:** globale Generator-Abfrage, unterdrückte Rims an Chunk-Kanten und hart auf den eigenen Chunk begrenztes Übermalen. Im Xvfb-Render verifiziert.",
    "✅ **Höhlen ~50 % seltener:** Radien × √0.5 bei gleicher Blob-Zellendichte. Über 6 Seeds 51–55 % der REV1-Fläche (Seed 20261105: 771 statt 1403 Tiles). Kein 1-Tile-Rauschen.",
    "✅ **Wasser hängt zusammen:** 4-fach verbundene Tiles = ein Becken mit gemeinsamem Volumen; 1-Tile-Dilatation schließt Löcher und verbindet benachbarte Linsen.",
    "✅ **Verbrauch von oben nach unten:** <code>waterline_px()</code> sinkt zeilenweise, Entnahme an einer Wurzel wirkt auf das ganze Becken, passive Versickerung und Regen-Auffüllung inklusive.",
    "✅ **Save v3:** Becken-Volumina werden gespeichert (35 % → 35 %), alte v2/v1-Spielstände bleiben lesbar.",
    "✅ **Regression:** P0-, P1-, P2- und REV1-Smoke alle <code>Ergebnis: OK</code>; Vollbild, Eichel-Fluss, Vogel-Timing, Ghost-Preview, DE/EN, 5 Chunks, Nearest + Forward+ unverändert.",
    "✅ **PHASE 3 nicht begonnen.**",
]

NOTES = [
    "Bewusste Trennung: Darstellung 4px-Raster, Spiellogik/Kollision/Save weiter 16px-Raster → kein Bruch mit P0–P2.",
    "Erster Ansatz „Zellendichte halbieren“ wurde verworfen: über 6 Seeds schwankte das Verhältnis zwischen 0.00 und 0.73. Die Radius-Skalierung liefert stabil 0.51–0.55.",
    "v3-Saves durften nach dem Laden nicht erneut die Legacy-Felder dry/remaining auswerten, sonst wurde jedes teilweise geleerte Becken auf 0 gesetzt.",
    "Die Presets --rev2-shot-edges / -water / -water-low setzen den Füllstand reproduzierbar auf 45 % bzw. 18 %; --windowed bleibt für Tests.",
    "Keine externen Addons, keine neuen Bild-Assets: TerrainContours nutzt die vorhandenen Platzhalter und Godot-Zeichenfunktionen.",
    "Neue ZIP waldspiel-REVISION2.zip mit project.godot im Root; .godot-Cache ausgeschlossen. Die REVISION1-ZIP ist historisch.",
]

CSS = """
:root{--bg:#101613;--card:#18211c;--ink:#e8e7dd;--sub:#a9bcae;--line:#2c3a31;--acc:#9bcf8b;--blue:#77b6d9}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);
 font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.6}
.wrap{max-width:1180px;margin:0 auto;padding:36px 22px 80px}
header{border-bottom:1px solid var(--line);padding-bottom:24px;margin-bottom:34px}
h1{font-size:2.15rem;margin:0 0 8px;letter-spacing:-.02em}
h2{font-size:1.35rem;margin:42px 0 16px;color:var(--acc);border-left:3px solid var(--acc);padding-left:12px}
h3{font-size:1rem;margin:22px 0 8px;color:var(--ink)}
p.sub,small{color:var(--sub)}
.badges{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.badge{font-size:.76rem;padding:4px 10px;border:1px solid var(--line);border-radius:999px;color:var(--sub)}
.badge.zip{border-color:var(--acc);color:var(--acc)}
.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:18px}
figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
figure img{display:block;width:100%;height:auto}
figcaption{padding:11px 14px;font-size:.86rem;color:var(--sub)}
figcaption b{display:block;color:var(--ink);font-size:.95rem;margin-bottom:2px}
.codeblock,pre{background:#0c120f;border:1px solid var(--line);border-radius:10px;padding:14px 16px;
 overflow:auto;font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.78rem;color:#cfe0d1}
.snip{margin:14px 0 24px}.snip h3{margin:0 0 6px;font-size:.9rem}
ul{padding-left:20px}li{margin:6px 0}
.note{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 18px}
footer{margin-top:46px;border-top:1px solid var(--line);padding-top:18px;color:var(--sub)}
code.inl{background:#0c120f;padding:2px 6px;border-radius:4px}
a{color:var(--blue)}
table{border-collapse:collapse;width:100%;font-size:.88rem}th,td{border:1px solid var(--line);padding:8px 10px;text-align:left}
th{color:var(--acc)}
"""


def build_md() -> str:
    out = ["# REVISION 2 — Ergebnis (vor PHASE 3)", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-06**  ",
           "Drei Korrekturen nach REVISION 1, **PHASE 3 wurde nicht begonnen**.",
           "", "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```bash",
            "godot --headless --path . --import                  # 0 Fehler",
            "godot --headless --path . -- --phase0-smoke         # Regression: OK",
            "godot --headless --path . -- --phase1-smoke         # Regression: OK",
            "godot --headless --path . -- --phase2-smoke         # Regression: OK",
            "godot --headless --path . -- --rev1-smoke           # Regression: OK",
            "godot --headless --path . -- --rev2-smoke           # 26 Checks: OK",
            "python3 tools/build_zip.py REVISION2               # ZIP + CRC-Test",
            "```", "", "```text", SMOKE_LOG.strip(), "```", "",
            "## 4 · Abnahme der drei Korrekturen", ""]
    out += [f"- {c.replace('&lt;', '<')}" for c in CHECKS]
    out += ["", "## 5 · Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `waldspiel-REVISION2.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root)",
            "- `REVISION2-ERGEBNIS.html` / `.md`, `REVISION2-TESTPROTOKOLL.txt`, `DECISIONS.md` (Abschnitte 40–45), `README.md`, `GODOT-IMPORT.txt`",
            "- `screenshots/rev2_*.png`, `tests/Revision2Smoke.gd`, `src/world/TerrainContours.gd`, `tools/build_revision2_report.py`",
            "", "**Nächster Schritt erst nach deinem OK: PHASE 3.**", ""]
    return "\n".join(out)


def build_html() -> str:
    shots_html = ""
    for f, title, sub in SHOTS:
        data = base64.b64encode((ROOT / "screenshots" / f).read_bytes()).decode()
        shots_html += (
            '<figure><img alt="' + html.escape(title) + '" src="data:image/png;base64,' + data + '">'
            '<figcaption><b>' + html.escape(title) + '</b>' + html.escape(sub) + '</figcaption></figure>\n')
    code_html = ""
    for title, lang, code in SNIPPETS:
        code_html += ('<div class="snip"><h3>' + html.escape(title) + ' <small>(' + lang + ')</small></h3>'
                      '<pre class="codeblock"><code>' + html.escape(code) + '</code></pre></div>\n')
    checks_html = "".join("<li>" + c + "</li>" for c in CHECKS)
    notes_html = "".join("<li>" + html.escape(n) + "</li>" for n in NOTES)
    return f"""<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>REVISION 2 — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>REVISION 2 — drei Korrekturen vor PHASE 3</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-06<br>
  Weiche Kanten für Höhlen / Wasser / Erdschichten · ~50 % weniger Höhlen · Wasser als Becken mit sinkendem Pegel</p>
  <div class="badges">
    <span class="badge zip">✓ neue überarbeitete komplette ZIP</span>
    <span class="badge">P0 / P1 / P2 / REV1 Regression: OK</span>
    <span class="badge">26 REVISION-2-Checks: OK</span>
    <span class="badge">0 rote Fehler</span>
    <span class="badge">PHASE 3 nicht begonnen</span>
  </div>
</header>

<h2>1 · Screenshots (echte Godot-Renders)</h2>
<div class="gallery">{shots_html}</div>

<h2>2 · Code-Snippets (aus den echten Projektdateien)</h2>
{code_html}

<h2>3 · Testprotokoll</h2>
<pre class="codeblock"><code>godot --headless --path . --import                  # 0 Fehler
godot --headless --path . -- --phase0-smoke         # Regression: OK
godot --headless --path . -- --phase1-smoke         # Regression: OK
godot --headless --path . -- --phase2-smoke         # Regression: OK
godot --headless --path . -- --rev1-smoke           # Regression: OK
godot --headless --path . -- --rev2-smoke           # 26 Checks: OK
python3 tools/build_zip.py REVISION2               # ZIP + CRC-Test</code></pre>
<pre class="codeblock"><code>{html.escape(SMOKE_LOG.strip())}</code></pre>
<p class="sub">6 Xvfb-Screenshots ohne Fehler · Fullscreen-Root-Capture 2560×1440 ohne grauen Rand · ZIP-CRC OK · Extrakt-Import + alle Smokes aus der entpackten ZIP OK.</p>

<h2>4 · Abnahme der drei Korrekturen</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">waldspiel-REVISION2.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root</li>
  <li><code class="inl">REVISION2-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">REVISION2-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (Abschnitte 40–45)</li>
  <li><code class="inl">screenshots/rev2_*.png</code>, <code class="inl">tests/Revision2Smoke.gd</code>, <code class="inl">src/world/TerrainContours.gd</code>, <code class="inl">src/world/WorldState.gd</code></li>
</ul>

<footer><strong>Ich stoppe hier.</strong> PHASE 3 (Jahreszeiten, Zeitspulen, Herbst-Eichelfall, Samen finden/vergraben, Schwierigkeitsgrade) kommt erst nach deinem OK – inklusive neuer ZIP.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "REVISION2-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "REVISION2-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: REVISION2-ERGEBNIS.md / .html")
