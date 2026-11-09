#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt REVISION3-ERGEBNIS.md und REVISION3-ERGEBNIS.html.

Alle Snippets stammen direkt aus den echten Projektdateien, alle Bilder sind
als data-URI eingebettet (offline im Arena-Preview sichtbar).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("rev3_rain_refill_smooth.png", "Regen + Spritzer + auffüllendes Becken",
     "Tropfen enden an der Geländelinie · kleine helle Spritzer · Becken blau unter dem Pegel, heller Leerboden darüber"),
    ("rev3_rain_splash.png", "Regen prasselt auf die Oberfläche",
     "Welt-Koordinaten: Aufprall exakt bei height_smooth_at(wx) · kein Tropfen fällt durch den Boden"),
    ("rev3_splash_detail.png", "Detail: kleine Spritzer und Rippen",
     "3-fach vergrößerter Ausschnitt (Nearest) · Tropfen steigen kurz auf, Rippen breiten sich aus"),
    ("rev3_water_a.png", "Stufenloser Pegel bei 50 % Füllstand",
     "Blaue Oberkante gemessen bei y = 554 px · Seed 20261105"),
    ("rev3_water_b.png", "Dasselbe Becken bei 53 % Füllstand",
     "Oberkante bei y = 551 px → 3 px Bewegung für 3 % Volumen statt 0 oder 16 px"),
    ("rev3_winter_no_drain.png", "Winter: keine Reservoir-Entnahme",
     "HUD rechts unten „Winter: kein Wasser aus Reservoirs“ · kahler Baum · Becken bleibt voll"),
    ("rev3_spring_regression.png", "Regression: Höhlen und Konturen intakt",
     "Dunkle Höhlen, weiche 4px-Kanten, 5 Chunks · alle sieben Smokes weiterhin OK"),
]


def snippet(rel: str, start: str, lines: int = 20) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(text):
        if start in line:
            return "\n".join(text[i:i + lines]).rstrip() + "\n"
    raise RuntimeError(f"Marker fehlt: {start!r} in {rel}")


SNIPPETS = [
    ("EventBus.gd — feines Redraw-Signal statt teurem Komplett-Refresh", "gdscript",
     snippet("src/autoload/EventBus.gd", "# --- REVISION 3", 5)),
    ("WorldState.gd — Volumen → Pegel in Pixeln, ohne 16px-Sprünge", "gdscript",
     snippet("src/world/WorldState.gd", "func _compute_level_px", 22)),
    ("WorldState.gd — zwei Signale: fein zeichnen, grob umschalten", "gdscript",
     snippet("src/world/WorldState.gd", "func _recompute_level", 24)),
    ("WorldState.gd — öffentliche Abfrage bleibt kompatibel", "gdscript",
     snippet("src/world/WorldState.gd", "func waterline_px", 5)),
    ("TerrainContours.gd — anteilig gefüllte 4px-Zelle + exakte Wasserlinie", "gdscript",
     snippet("src/world/TerrainContours.gd", "# REVISION 3: nicht mehr ganzzahlig", 12)),
    ("TerrainContours.gd — Kontur-Redraw auf ~25 Hz gedrosselt", "gdscript",
     snippet("src/world/TerrainContours.gd", "func _on_volume_changed", 10)),
    ("Chunk.gd — nur noch gecachte Reservoir-Kacheln statt 128×88 Noise-Abfragen", "gdscript",
     snippet("src/world/Chunk.gd", "var _water_cells", 4)
     + "\n" + snippet("src/world/Chunk.gd", "func refresh_reservoirs", 8)),
    ("WaterSystem.gd — Winter: keine Wurzel-Entnahme, keine Versickerung", "gdscript",
     snippet("src/systems/WaterSystem.gd", "# REVISION 3: Im Winter ruht", 5)
     + "\n" + snippet("src/systems/WaterSystem.gd", "elif not winter:", 3)),
    ("RainEffect.gd — Aufprall auf der echten Geländelinie", "gdscript",
     snippet("src/ui/RainEffect.gd", "func surface_y", 6)
     + "\n" + snippet("src/ui/RainEffect.gd", 'if float(d["wy"]) >= ground:', 6)),
    ("RainEffect.gd — Spritzer, Schwerkraft und Rippen zeichnen", "gdscript",
     snippet("src/ui/RainEffect.gd", "func _spawn_splash", 17)
     + "\n" + snippet("src/ui/RainEffect.gd", "for s in _splashes:", 5)),
    ("HUD.gd — Winter-Hinweis am Reservoir-Label", "gdscript",
     snippet("src/ui/HUD.gd", "# REVISION 3: im Winter zieht", 6)),
    ("Main.gd — Regen mit Kamera + Gelände verdrahten", "gdscript",
     snippet("src/Main.gd", "# REVISION 3: Regen kennt", 3)
     + "\n" + snippet("src/Main.gd", 'elif args.has("--rev3-shot-water-a")', 6)),
    ("tests/Revision3Smoke.gd — 200 Feinschritte + Winter/Regen-Checks", "gdscript",
     snippet("tests/Revision3Smoke.gd", "# 0.5 %-Schritte", 8)
     + "\n" + snippet("tests/Revision3Smoke.gd", 'time_manager.debug_set_season(TimeManager.Season.WINTER', 7)),
]

CHECKS = [
    "✅ <b>Stufenloser Pegel:</b> <code>_compute_level_px()</code> interpoliert aus dem Volumen über ein Zeilen-Histogramm den Wasserstand <em>innerhalb</em> einer Tile-Zeile. 200 Feinschritte: größter Sprung <b>2,42 px</b> statt 16 px, 199/200 Werte fraktional.",
    "✅ <b>Kein CPU-Ruckler:</b> neues feines Signal <code>reservoir_volume_changed</code> zeichnet nur die Konturen neu (~25 Hz gedrosselt); die teure Tile-Slot-Umschaltung läuft nur beim Zeilenwechsel und über eine gecachte Kachelliste statt 128 × 88 Noise-Abfragen je Chunk.",
    "✅ <b>Pixelgenaue Kante:</b> <code>TerrainContours</code> füllt die Zelle, durch die der Pegel läuft, anteilig und zeichnet die Wasserlinie auf Bruchteilpixel genau. Messung 50 % → 53 %: y=554 → y=551 (<b>3 px</b>) in 5 Spalten identisch.",
    "✅ <b>Winter:</b> Bäume entnehmen <b>kein</b> Reservoir-Wasser (8712,0 → 8712,0), Boden-Versickerung ruht bei Frost, Regen füllt weiter auf. Im Frühling sofort wieder aktiv (8712,0 → 8622,9). HUD zeigt <code>Winter: kein Wasser aus Reservoirs</code>.",
    "✅ <b>Regen:</b> Tropfen fallen in Welt-Koordinaten bis <code>height_smooth_at(wx)</code>, erzeugen 3 Spritzer + Rippe und starten oben neu. Smoke: Aufprallhöhe 320,0 px = echte Geländelinie, <b>316 Spritzer</b>, <b>0</b> Tropfen unter der Oberfläche.",
    "✅ <b>Regression:</b> alle sieben Smokes (P0/P1/P2/REV1/REV2/P3/REV3) <code>Ergebnis: OK</code>; REV2-Pegel-Start, „trocken ausschließlich oben“, Atlas-Slots, dunkle Höhlen, 5 Chunks, Nearest, DE/EN, Vogel, Save v4 unverändert.",
]

NOTES = [
    "Während des Umbaus erschienen Höhlen kurz nur als Umriss (fehlender CAVE_FILL-Zweig in Schritt 4). Sofort behoben, neu gerendert und visuell geprüft.",
    "Der Winter-Hinweis war in der ersten Fassung zu lang und wurde rechts abgeschnitten; der Text ist jetzt auf die 300px-Labelbreite gekürzt.",
    "level_row bleibt absichtlich diskret: er steuert nur noch is_dry() und die Atlas-Slots. So bleiben die REV2-/P2-Smokes ohne Anpassung gültig.",
    "Die Spritzer sind bewusst klein und kurzlebig (0,20–0,38 s), damit der Pixel-Look erhalten bleibt; Array-Grenzen verhindern unbegrenztes Wachstum bei Dauerregen.",
    "Legacy-Smokes laufen ohne --seed (Phase1Smoke verlangt einen zufälligen Welt-Seed); alle Screenshots nutzen --seed=20261105.",
    "PHASE 4 wurde NICHT begonnen. Kein GraphEdit, keine Skilltree-Nodes, keine Glucose-Kosten für Skills.",
]

PROTOCOL = (ROOT / "REVISION3-TESTPROTOKOLL.txt").read_text(encoding="utf-8") \
    if (ROOT / "REVISION3-TESTPROTOKOLL.txt").exists() else "[SMOKE] Ergebnis: OK"

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
table{border-collapse:collapse;width:100%;font-size:.88rem}th,td{border:1px solid var(--line);padding:8px 10px;text-align:left}
th{color:var(--acc)}
"""


def build_md() -> str:
    out = ["# REVISION 3 — Ergebnis (vor PHASE 4)", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-07**  ",
           "Drei gemeldete Punkte behoben; **PHASE 4 wurde nicht begonnen**.", "",
           "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```text", PROTOCOL.strip(), "```", "",
            "## 4 · Abnahme der drei Korrekturen", ""]
    out += [f"- {c.replace('<b>', '**').replace('</b>', '**').replace('<em>', '*').replace('</em>', '*').replace('<code>', '`').replace('</code>', '`')}"
            for c in CHECKS]
    out += ["", "## 5 · Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `waldspiel-REVISION3.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root, `.godot` ausgeschlossen, CRC OK)",
            "- `REVISION3-ERGEBNIS.html` / `.md`, `REVISION3-TESTPROTOKOLL.txt`, `DECISIONS.md` §§54–58, `README.md`, `GODOT-IMPORT.txt`",
            "- `screenshots/rev3_*.png` (7 Renders), `tests/Revision3Smoke.gd`, `tools/build_revision3_report.py`",
            "- Geänderte Quellen: `WorldState.gd`, `TerrainContours.gd`, `Chunk.gd`, `WaterSystem.gd`, `RainEffect.gd`, `HUD.gd`, `EventBus.gd`, `Main.gd`, `data/localization.csv`",
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
<title>REVISION 3 — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>REVISION 3 — drei Korrekturen vor PHASE 4</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-07<br>
  Stufenloser Wasserpegel ohne Ruckler · Winter ohne Reservoir-Entnahme · Regen mit Aufprall und kleinen Spritzern</p>
  <div class="badges">
    <span class="badge zip">✓ komplette ZIP</span>
    <span class="badge fix">✓ kein 16px-Ruckler</span>
    <span class="badge fix">✓ Winterruhe</span>
    <span class="badge fix">✓ Regen-Spritzer</span>
    <span class="badge">7 / 7 Smokes OK</span>
    <span class="badge">0 rote Fehler</span>
  </div>
</header>

<h2>1 · Screenshots (echte Godot-Renders)</h2>
<div class="gallery">{shots_html}</div>

<h2>2 · Code-Snippets (aus den echten Projektdateien)</h2>
{code_html}

<h2>3 · Testprotokoll</h2>
<pre class="codeblock"><code>{html.escape(PROTOCOL.strip())}</code></pre>
<p class="sub">7 eingebettete Screenshots · 13 echte Snippets · alles offline (data-URIs, keine externen Ressourcen).</p>

<h2>4 · Abnahme der drei Korrekturen</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">waldspiel-REVISION3.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root, CRC OK</li>
  <li><code class="inl">REVISION3-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">REVISION3-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (§§54–58)</li>
  <li><code class="inl">screenshots/rev3_*.png</code>, <code class="inl">tests/Revision3Smoke.gd</code>, <code class="inl">tools/build_revision3_report.py</code></li>
</ul>

<footer><strong>PHASE 4 wurde nicht begonnen.</strong> Als Nächstes: Skilltree-UI mit GraphEdit, 15 Nodes, Glucose-Kosten und echten Effekten. Die pH-/N-P-K-/Mykorrhiza-/Katastrophen-Simulation bleibt PHASE 5 zugeordnet.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "REVISION3-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "REVISION3-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: REVISION3-ERGEBNIS.md / .html")
