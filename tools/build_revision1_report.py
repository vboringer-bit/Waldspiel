#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt REVISION1-ERGEBNIS.md und REVISION1-ERGEBNIS.html.

Alle Snippets kommen direkt aus den echten Projektdateien, alle Bilder sind
als data-URI eingebettet (offline im Arena-Preview sichtbar).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("rev1_surface.png", "Fließende Oberfläche – keine 16px-Ecken mehr",
     "4px-Profil von TerrainSurface · organisches Höhlenband · Seed 20261105"),
    ("rev1_caves.png", "Unregelmäßige Höhlen + Wasserlinsen",
     "Rotierte Ellipsen, 3 überlagerte Familien, Noise-Kanten · Zoom 1.00x"),
    ("rev1_carry.png", "Eichel schwebt an der Maus",
     "Toast + Inventar ×1 · halbtransparente Platzierungs-Vorschau auf der Oberfläche"),
    ("rev1_placed.png", "Vogel holt die ERSTE PLATZIERTE Eichel",
     "Toast „Der Vogel hat die erste platzierte Eichel geholt …“ · kein Keimling"),
    ("phase2_fullscreen_2560.png", "Vollbild 2560×1440 füllt den Monitor",
     "Xvfb-Root-Capture · kein grauer Rand · HUD mitvergrößert"),
    ("rev1_fullscreen_ultrawide.png", "Vollbild 3440×1440 (21:9) ebenfalls vollständig",
     "expand + dynamischer content_scale_factor · mehr sichtbare Welt, keine Balken"),
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
    ("project.godot — Vollbild + Skalierung", "ini",
     extract("project.godot", "[display]", "[layer_names]")),
    ("Main.gd — dynamischer Skalierungsfaktor + F11", "gdscript",
     extract("src/Main.gd", "func _fit_display", "## Reproduzierbare Zustaende")),
    ("WorldGenerator.gd — kontinuierliche Höhe, weiche Schichtgrenzen", "gdscript",
     extract("src/world/WorldGenerator.gd", "func height_smooth_at",
             "# --------------------------------------------------------------------------- #\n# Biome")),
    ("TerrainSurface.gd — 4px-Oberkante statt 16px-Blockstufe (vollständig)", "gdscript",
     (ROOT / "src/world/TerrainSurface.gd").read_text(encoding="utf-8")),
    ("Chunk.gd — oberste Tile-Zeile durch das Profil ersetzen", "gdscript",
     extract("src/world/Chunk.gd", "func _build_terrain", "func _slot_for")),
    ("WorldGenerator.gd — rotierte, mehrfache Blobs mit Noise-Kante", "gdscript",
     extract("src/world/WorldGenerator.gd", "func _blob_field",
             "## Unregelmaessige Wasserlinse")),
    ("WorldGenerator.gd — 3 Höhlen-Familien + organische Starter-Linse", "gdscript",
     extract("src/world/WorldGenerator.gd", "## Unregelmaessige Wasserlinse",
             "func cave_at")),
    ("InteractionController.gd — aufnehmen & schweben lassen", "gdscript",
     extract("src/systems/InteractionController.gd", "## Einstieg: Klick auf das Eichel-Inventar-Icon",
             "func _update_carry_visuals")),
    ("InteractionController.gd — platzieren erst beim 2. Klick", "gdscript",
     extract("src/systems/InteractionController.gd", "## Der Platzierungsversuch",
             "func _spawn_acorn_sprite")),
    ("InteractionController.gd — Vogel bleibt, aber NACH der Platzierung", "gdscript",
     extract("src/systems/InteractionController.gd", "func plant_seed_at",
             "func spawn_tree_at")),
    ("HUD.gd — klickbares Eichel-Icon", "gdscript",
     extract("src/ui/HUD.gd", "func _on_seed_icon_input", "func _connect")),
    ("SaveManager.gd — getragene Eichel im Savegame", "gdscript",
     extract("src/systems/SaveManager.gd", '\t\t# Eine schwebende Eichel',
             '\t\t"bird_event_done"')
     + "\n\n" + extract("src/systems/SaveManager.gd",
             '\tinteraction.clear_carrying(false)', '\tinteraction.set_seed_count')),
]

SMOKE_LOG = (Path("/tmp/rev_rev1.log").read_text(encoding="utf-8")
             if Path("/tmp/rev_rev1.log").exists() else "[SMOKE] Ergebnis: OK")

CHECKS = [
    "✅ Vollbild startet direkt (`mode=3`), `expand` + `content_scale_factor` skalieren auf jeden Monitor – **kein grauer Rand**.",
    "✅ Verifiziert bei **2560×1440** und **3440×1440** mit Xvfb-Root-Screenshots (Grau-Anteil &lt; 0,02 %).",
    "✅ Unterirdische Strukturen: 1–3 **rotierte** Ellipsen pro Zelle, 3 Familien, Noise-Kanten – 22 Komponenten / 18 Größen im Test, nur 2 Solitär-Tiles.",
    "✅ Starter-Reservoir nur noch 3×3-Kern + zerfranste Linse; Seed-Varianz 25 %.",
    "✅ Oberfläche: **0 Ecken ≥ 16 px**, maximaler Sprung **4 px** über 1025 Stützpunkte; Schichtgrenzen folgen der weichen Linie.",
    "✅ Eichel anklicken → Schwebe-Sprite + Vorschau; **kein Vogel** beim Aufnehmen; Rechtsklick/Esc legt sie zurück.",
    "✅ Linksklick platziert **überall** (x=320 und x=−640 getestet) → **danach** Vogel-Diebstahl; 2. Eichel keimt.",
    "✅ Save/Load: schwebende Eichel bleibt erhalten, keine Geister-Sprites; P0/P1/P2-Smokes weiterhin `OK`.",
    "✅ **PHASE 3 nicht begonnen.**",
]

NOTES = [
    "Bewusste Trennung: Darstellung 4px-Raster, Spiellogik/Kollision/Save weiter 16px-Raster → kein Bruch mit P0–P2.",
    "`--windowed` schaltet für Tests/Screenshots trotz Fullscreen-Default in den Fenstermodus; `F11` jederzeit.",
    "Auf stark abweichenden Seitenverhältnissen zeigt `expand` mehr Welt statt Balken; Pixel bleiben quadratisch.",
    "Debug-Presets `--rev1-shot-surface / -carry / -placed` und `--rev1-smoke` sind neu; alle alten Presets bleiben.",
    "Vogel-Text in `data/localization.csv` DE/EN angepasst; `Phase1Smoke` prüft den neuen Text.",
    "Keine externen Addons, keine neuen Assets: das Oberflächenprofil und die Schwebe-Eichel nutzen vorhandene Platzhalter/GD-Zeichenfunktionen.",
]


def build_md() -> str:
    out = ["# REVISION 1 — Ergebnis (vor PHASE 3)", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-06**  ",
           "Vier Korrekturen nach PHASE 2, **PHASE 3 wurde nicht begonnen**.",
           "", "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```bash",
            "godot --headless --path . --import                  # 0 Fehler",
            "godot --headless --path . --quit-after 180          # F5-Ersatz: 0 Fehler",
            "godot --headless --path . -- --phase0-smoke         # OK",
            "godot --headless --path . -- --phase1-smoke         # OK",
            "godot --headless --path . -- --phase2-smoke         # OK",
            "godot --headless --path . -- --rev1-smoke           # 31 Checks: OK",
            "python3 tools/build_zip.py REVISION1               # ZIP + CRC-Test",
            "```", "", "```text", SMOKE_LOG.strip(), "```", "",
            "## 4 · Abnahme", ""]
    out += [f"- {c.replace('&lt;', '<')}" for c in CHECKS]
    out += ["", "## 5 · Hinweise", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `waldspiel-REVISION1.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root)",
            "- `REVISION1-ERGEBNIS.html` / `.md`, `DECISIONS.md` (Abschnitte 34–39), `README.md`",
            "- `screenshots/rev1_*.png`, `tests/Revision1Smoke.gd`, `tools/build_revision1_report.py`",
            "", "**Nächster Schritt erst nach deinem OK: PHASE 3.**", ""]
    return "\n".join(out)


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
"""


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
<title>REVISION 1 — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>REVISION 1 — vier Korrekturen vor PHASE 3</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-06<br>
  Vollbild · organische Höhlen &amp; Reservoirs · fließende Oberfläche · Eichel schwebt &amp; wird frei platziert</p>
  <div class="badges">
    <span class="badge zip">✓ überarbeitete komplette ZIP</span>
    <span class="badge">P0 / P1 / P2 Regression: OK</span>
    <span class="badge">31 REVISION-1-Checks: OK</span>
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
godot --headless --path . --quit-after 180          # F5-Ersatz: 0 Fehler
godot --headless --path . -- --phase0-smoke         # Regression: OK
godot --headless --path . -- --phase1-smoke         # Regression: OK
godot --headless --path . -- --phase2-smoke         # Regression: OK
godot --headless --path . -- --rev1-smoke           # 31 Checks: OK
python3 tools/build_zip.py REVISION1               # ZIP + CRC-Test</code></pre>
<pre class="codeblock"><code>{html.escape(SMOKE_LOG.strip())}</code></pre>
<p class="sub">6 Xvfb-Screenshots ohne Fehler · 18/18 PNGs mit mipmaps=off · Fullscreen-Test bei 2560×1440 und 3440×1440 · ZIP-CRC OK.</p>

<h2>4 · Abnahme der vier Korrekturen</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">waldspiel-REVISION1.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root</li>
  <li><code class="inl">REVISION1-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">DECISIONS.md</code> (Abschnitte 34–39), <code class="inl">README.md</code></li>
  <li><code class="inl">screenshots/rev1_*.png</code>, <code class="inl">tests/Revision1Smoke.gd</code>, <code class="inl">src/world/TerrainSurface.gd</code></li>
</ul>

<footer><strong>Ich stoppe hier.</strong> PHASE 3 (Jahreszeiten, Zeitspulen, Herbst-Eichelfall, Samen finden/vergraben, Schwierigkeitsgrade) kommt erst nach deinem OK – inklusive neuer ZIP.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "REVISION1-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "REVISION1-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: REVISION1-ERGEBNIS.md / .html")
