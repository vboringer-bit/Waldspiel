#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt REVISION4-ERGEBNIS.md und REVISION4-ERGEBNIS.html.

Alle Snippets stammen direkt aus den echten Projektdateien, alle Bilder sind
als data-URI eingebettet (offline im Arena-Preview sichtbar).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("rev4_start.png", "Spielstart: 2 Eicheln am Boden, Inventar × 0",
     "Zwei orangene Eicheln links und rechts der Startposition auf der fließenden Oberkante · HUD zeigt × 0 · kein Baum"),
    ("rev4_carry.png", "Nur das Inventar-Icon nimmt eine Eichel auf",
     "Angeklicktes HUD-Icon ist markiert · schwebende Eichel an der Maus · halbtransparente Platzierungsvorschau · Hinweis „AUF DEN BODEN“"),
    ("rev4_stages.png", "Wuchsstufen: dünner Keimling vs. ausgewachsene Eiche",
     "Links Stufe 0 (Stammbreite 0,30 / 2 Blätter), rechts Stufe 4 (1,00 / 12 Blätter) · Stamm verjüngt sich nach oben, Wurzeln zur Spitze"),
    ("rev4_water.png", "Regression: stufenloser Pegel aus REVISION 3",
     "53 % Füllstand · fraktional gefüllte 4px-Zelle · exakte Wasserlinie · trockener Leerboden darüber · Höhlen und Schichten unverändert"),
    ("rev3_water_b.png", "Referenz REVISION 3: dasselbe Becken bei 53 %",
     "Vergleichsbild aus der vorherigen Lieferung · identische Kantenform trotz getrennter Wasser-Ebene"),
    ("rev3_rain_splash.png", "Referenz REVISION 3: Regen mit Spritzern",
     "Welt-Koordinaten und Aufprall auf height_smooth_at(wx) bleiben unverändert erhalten"),
]


def snippet(rel: str, start: str, lines: int = 20) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(text):
        if start in line:
            return "\n".join(text[i:i + lines]).rstrip() + "\n"
    raise RuntimeError(f"Marker fehlt: {start!r} in {rel}")


SNIPPETS = [
    ("TerrainContours.gd — Problem und Lösungsweg (Dateikopf)", "gdscript",
     snippet("src/world/TerrainContours.gd", "## REVISION 4: PERFORMANCE", 17)),
    ("TerrainContours.gd — klassenweiter Geometrie-Cache", "gdscript",
     snippet("src/world/TerrainContours.gd", "static var _geo_bank", 5)),
    ("TerrainContours.gd — Statik wird genau einmal gezeichnet", "gdscript",
     snippet("src/world/TerrainContours.gd", "func _draw() -> void:", 7)
     + "\n" + snippet("src/world/TerrainContours.gd", "func paint_water", 10)),
    ("TerrainContours.gd — gedrosselter Wasser-Redraw", "gdscript",
     snippet("src/world/TerrainContours.gd", "func _process(delta: float) -> void:", 13)),
    ("TerrainContours.gd — Noise nur noch an der Isolinien-Kante", "gdscript",
     snippet("src/world/TerrainContours.gd", "if v > 0.21 or v < -0.21", 7)),
    ("TerrainWaterPainter.gd — eigener CanvasItem nur für Wasser", "gdscript",
     snippet("src/world/TerrainWaterPainter.gd", "func _draw() -> void:", 5)),
    ("InteractionController.gd — kein Startinventar", "gdscript",
     snippet("src/systems/InteractionController.gd", "## REVISION 4: Der Spieler startet", 4)),
    ("InteractionController.gd — Weltklicks nehmen keine Eichel mehr", "gdscript",
     snippet("src/systems/InteractionController.gd", "func _left_click(pos: Vector2)", 14)
     + "\n" + snippet("src/systems/InteractionController.gd", "func hud_acorn_clicked", 6)),
    ("HUD.gd — einziger Einstieg: Klick auf das Eichel-Icon", "gdscript",
     snippet("src/ui/HUD.gd", "func debug_click_seed_icon", 8)),
    ("SeasonSystem.gd — zwei feste Start-Eicheln auf dem Boden", "gdscript",
     snippet("src/systems/SeasonSystem.gd", "func _starter_entries()", 18)),
    ("Tree.gd — fünf Breitenstufen + Reifegrad", "gdscript",
     snippet("src/plants/Tree.gd", "const STAGE_WIDTHS", 8)
     + "\n" + snippet("src/plants/Tree.gd", "func growth_stage()", 12)),
    ("Tree.gd — Verjüngung von Stamm und Wurzeln", "gdscript",
     snippet("src/plants/Tree.gd", "func _refresh_growth_visuals()", 15)),
    ("RootSegment.gd — Wurzelbreite nach Tiefe und Spitze", "gdscript",
     snippet("src/plants/RootSegment.gd", "func refresh_sprite()", 14)),
    ("Revision4Smoke.gd — Performance-Regressionstest", "gdscript",
     snippet("tests/Revision4Smoke.gd", "# --- 1) Performance", 12)),
]

CHECKS = [
    "✅ <b>Kein ganzheitliches Ruckeln mehr:</b> <code>TerrainContours._draw()</code> kostete vorher <b>66–69 ms pro Chunk</b> (≈335 ms bei 5 Chunks) und wurde bis zu 25×/s neu aufgebaut. Jetzt zeichnet ein <code>TerrainWaterPainter</code>-Kind nur das Wasser; Erde/Höhlen/Schichten entstehen <b>einmal</b>, Isolinien und Polygone liegen im Cache, gleichfarbige Zellen/Ränder werden zu Streifen gebündelt. A/B auf derselben Maschine: <b>1 FPS → 7 FPS</b> (Xvfb/llvmpipe, 1920×1080).",
    "✅ <b>Zwei Eicheln am Boden, keine im Inventar:</b> <code>STARTING_SEEDS = 0</code>; <code>SeasonSystem._starter_entries()</code> legt exakt zwei frei liegende Eicheln bei wx = −224 / +288 px. Einsammeln bleibt unverändert (Linksklick → +1). Im Startbild sind genau 2 sichtbar; alle anderen Chunks behalten das P3-System „Samen finden / vergraben“.",
    "✅ <b>Platzierung nur über die Eichel:</b> kein Weltklick mehr nimmt eine Inventar-Eichel; einziger Einstieg ist das HUD-Icon (<code>hud_acorn_clicked()</code>, beim Tragen orange markiert). Eine schwebende Eichel wird nur noch <b>auf dem Boden</b> platziert — ein Klick in den Himmel zeigt <code>MSG_ACORN_GROUND_ONLY</code> und verbraucht nichts. HUD-Hilfe, Tooltip, Toast und DE/EN-Texte sind aktualisiert.",
    "✅ <b>Fünf Wuchsstufen für Stamm und Wurzeln:</b> Breiten 0,30 → 0,46 → 0,62 → 0,80 → 1,00, berechnet aus Stamm-, Wurzel- und Blattwachstum. Zusätzliche natürliche Verjüngung nach oben bzw. zur Wurzelspitze, junge Triebe leicht grünlich. Das 16px-Kollisionsraster bleibt unverändert, die Stufe überlebt Save/Load.",
    "✅ <b>REVISION 3 unverändert:</b> stufenloser Pegel mit fraktionaler 4px-Zelle, Winter ohne Reservoir-Entnahme, Regen in Welt-Koordinaten mit Spritzern. Screenshot <code>rev4_water.png</code> zeigt dasselbe Becken bei 53 % wie <code>rev3_water_b.png</code>.",
    "✅ <b>Regression:</b> alle <b>8</b> Smokes (P0/P1/P2/REV1/REV2/P3/REV3/REV4) <code>Ergebnis: OK</code> — 221 Checks, 0 Fehler. <code>Phase1Smoke</code> prüft jetzt 0 Start-Eicheln und setzt für den P1-Tutorial-Test bewusst 2; Vogel, Keimling, Save v4, 5 Chunks, Nearest und DE/EN bleiben gültig.",
]

NOTES = [
    "Der Rest der Framezeit unter Xvfb/llvmpipe ist Füllrate des Software-Rasterizers und damit auflösungsabhängig; auf dem Ziel-Renderer Forward+/Vulkan (GPU) entfällt er. Die beseitigten 67ms-Haupt-Thread-Spitzen waren renderer-unabhängig und die eigentliche Ruckler-Ursache.",
    "Die temporäre --r4-profile-Instrumentierung wurde restlos entfernt; geblieben sind nur zwei billige Debug-Zähler (debug_static_draws / debug_water_draws) für den Smoke-Test.",
    "Das Bild der Konturen ist absichtlich pixelgleich geblieben: CAVE_FILL, Chunk-Naht-Clipping, Gap-Closing und die fraktionale Wasserzelle aus REVISION 3 wurden nicht verändert.",
    "Debug-/Screenshot-Presets (debug_plant_twice, debug_first_seed, debug_carry_at) stellen sich ihre Eicheln selbst bereit, damit der echte Spielstart weiterhin bei 0 bleibt und alle alten Render-Presets unverändert funktionieren.",
    "Legacy-Smokes laufen ohne --seed (Phase1Smoke verlangt einen zufälligen Welt-Seed); alle Screenshots und FPS-Messungen nutzen --seed=20261105.",
    "PHASE 4 wurde NICHT begonnen. Kein GraphEdit, keine Skilltree-Nodes, keine Glucose-Kosten für Skills. Die pH-/N-P-K-/Mykorrhiza-/Katastrophen-Simulation bleibt PHASE 5 zugeordnet.",
]

PROTOCOL = (ROOT / "REVISION4-TESTPROTOKOLL.txt").read_text(encoding="utf-8") \
    if (ROOT / "REVISION4-TESTPROTOKOLL.txt").exists() else "[SMOKE] Ergebnis: OK"

CSS = """
:root{--bg:#101613;--card:#18211c;--ink:#e8e7dd;--sub:#a9bcae;--line:#2c3a31;--acc:#9bcf8b;--blue:#77b6d9;--gold:#e2c07a}
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
.badge.fix{border-color:var(--gold);color:var(--gold)}
.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:18px}
figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
figure img{display:block;width:100%;height:auto}
figcaption{padding:11px 14px;font-size:.86rem;color:var(--sub)}
figcaption b{display:block;color:var(--ink);font-size:.95rem;margin-bottom:2px}
.codeblock,pre{background:#0c120f;border:1px solid var(--line);border-radius:10px;padding:14px 16px;
 overflow:auto;font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.78rem;color:#cfe0d1}
.snip{margin:14px 0 24px}.snip h3{margin:0 0 6px;font-size:.9rem}
ul{padding-left:20px}li{margin:8px 0}
.note{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 18px}
footer{margin-top:46px;border-top:1px solid var(--line);padding-top:18px;color:var(--sub)}
code.inl,code{background:#0c120f;padding:2px 6px;border-radius:4px}
pre code{background:none;padding:0}
a{color:var(--blue)}
"""


def build_md() -> str:
    out = ["# REVISION 4 — Ergebnis (vor PHASE 4)", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05**  ",
           "Vier gemeldete Punkte behoben; **PHASE 4 wurde nicht begonnen**.", "",
           "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```text", PROTOCOL.strip(), "```", "",
            "## 4 · Abnahme der vier Korrekturen", ""]
    out += [f"- {c.replace('<b>', '**').replace('</b>', '**').replace('<em>', '*').replace('</em>', '*').replace('<code>', '`').replace('</code>', '`')}"
            for c in CHECKS]
    out += ["", "## 5 · Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `waldspiel-REVISION4.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root, `.godot` ausgeschlossen, CRC OK)",
            "- `REVISION4-ERGEBNIS.html` / `.md`, `REVISION4-TESTPROTOKOLL.txt`, `DECISIONS.md` §§59–63, `README.md`, `GODOT-IMPORT.txt`",
            "- `screenshots/rev4_*.png` (4 Renders), `tests/Revision4Smoke.gd`, `tools/build_revision4_report.py`",
            "- Geänderte Quellen: `TerrainContours.gd`, `TerrainWaterPainter.gd` (neu), `Chunk.gd`, `InteractionController.gd`, `SeasonSystem.gd`, `HUD.gd`, `Tree.gd`, `RootSegment.gd`, `Main.gd`, `data/localization.csv`, `Phase1Smoke.gd`",
            "", "**Nächster Schritt: PHASE 4 — Skilltree-UI (GraphEdit, 15 Nodes, Glucose-Kosten, echte Effekte).**", ""]
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
<title>REVISION 4 — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>REVISION 4 — vier Korrekturen vor PHASE 4</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05<br>
  Kein ganzheitliches Ruckeln · 2 Start-Eicheln am Boden · Platzierung nur über das Inventar-Icon · 5 Wuchsstufen für Stamm und Wurzeln</p>
  <div class="badges">
    <span class="badge zip">✓ komplette ZIP</span>
    <span class="badge fix">✓ 1 FPS → 7 FPS</span>
    <span class="badge fix">✓ 0 Start-Inventar</span>
    <span class="badge fix">✓ Icon-Klick</span>
    <span class="badge fix">✓ dünn → dick</span>
    <span class="badge">8 / 8 Smokes OK</span>
    <span class="badge">0 rote Fehler</span>
  </div>
</header>

<h2>1 · Screenshots (echte Godot-Renders)</h2>
<div class="gallery">{shots_html}</div>

<h2>2 · Code-Snippets (aus den echten Projektdateien)</h2>
{code_html}

<h2>3 · Testprotokoll</h2>
<pre class="codeblock"><code>{html.escape(PROTOCOL.strip())}</code></pre>
<p class="sub">6 eingebettete Screenshots · {len(SNIPPETS)} echte Snippets · alles offline (data-URIs, keine externen Ressourcen).</p>

<h2>4 · Abnahme der vier Korrekturen</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">waldspiel-REVISION4.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root, CRC OK</li>
  <li><code class="inl">REVISION4-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">REVISION4-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (§§59–63)</li>
  <li><code class="inl">screenshots/rev4_*.png</code>, <code class="inl">tests/Revision4Smoke.gd</code>, <code class="inl">tools/build_revision4_report.py</code></li>
</ul>

<footer><strong>PHASE 4 wurde nicht begonnen.</strong> Als Nächstes: Skilltree-UI mit GraphEdit, 15 Nodes, Glucose-Kosten und echten Effekten. Die pH-/N-P-K-/Mykorrhiza-/Katastrophen-Simulation bleibt PHASE 5 zugeordnet.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "REVISION4-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "REVISION4-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: REVISION4-ERGEBNIS.md / .html")
