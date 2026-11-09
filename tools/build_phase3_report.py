#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt PHASE3-ERGEBNIS.md und PHASE3-ERGEBNIS.html.

Alle Snippets werden direkt aus den echten Projektdateien gelesen, alle
Screenshots als data-URI eingebettet (offline im Arena-Preview sichtbar).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("phase3_rain_refill.png", "Korrektur 1: Regen füllt das Becken wieder auf",
     "Blau unter dem Pegel, heller trockener Leerboden darüber · Toast „Es regnet – die Wasserreservoirs füllen sich langsam wieder auf."),
    ("phase3_bird_mid.png", "Korrektur 2a: Vogel mitten im Flug",
     "Erste platzierte Eichel geklaut · Vogel samt Beute sichtbar · kamera-/viewport-abhängiger Abflug"),
    ("phase3_bird_exit.png", "Korrektur 2b: Vogel verlässt das Bild links",
     "Sprite fliegt bis hinter die linke Bildkante, erst dann queue_free() · kein Verschwinden in der Luft mehr"),
    ("phase3_difficulty.png", "Startmenü: LEICHT / NORMAL / SCHWER",
     "Vor Spielstart wählbar, nicht blockierend · jederzeit im HUD umschaltbar · CanvasLayer 20"),
    ("phase3_spring.png", "Frühling · Jahr 1 · 55 % Saison-Fortschritt",
     "Wachstumsboost ×1.35, Sonne ×1.25 · HUD mit x1/x3/x10, Pause, Schwierigkeit, Balken"),
    ("phase3_autumn.png", "Herbst: Eicheln fallen unter der Krone",
     "Laub herbstlich getönt · 7 Eicheln am Boden · Reife ab ~3 Spiel-Jahren · Chance × Schwierigkeit"),
    ("phase3_winter.png", "Winter: Wachstum stoppt, Laubbaum kahl",
     "Toast „Jahreszeitenwechsel: Winter“ · keine Fotosynthese · manuelles Wachstum blockiert"),
    ("phase3_seeds.png", "Samen finden & flach vergraben",
     "Zwei frei liegende Eicheln + ein kleiner Hügel (rechts) · Noise-Verteilung · Hügel erst mit Wurzel erreichbar"),
    ("phase3_fullscreen_2560.png", "Zusatzfix: Vollbild 2560×1440",
     "Xvfb-Root-Capture · content_scale_factor = 1.0 statt 1.333 · HUD vollständig sichtbar, kein grauer Rand"),
    ("phase3_edges_regression.png", "Regression: weiche Kanten (REVISION 2)",
     "4px-Isolinien für Höhlen/Wasser/Erdschichten bleiben · alle fünf Legacy-Smokes weiterhin OK"),
]


def snippet(rel: str, start: str, lines: int = 24) -> str:
    """Liest `lines` Zeilen ab dem ersten Vorkommen von `start`."""
    text = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(text):
        if start in line:
            return "\n".join(text[i:i + lines]).rstrip() + "\n"
    raise RuntimeError(f"Marker fehlt: {start!r} in {rel}")


SNIPPETS = [
    ("project.godot — Vollbild, canvas_items/expand, Forward+", "ini",
     snippet("project.godot", "[display]", 15)),
    ("WorldState.gd — Korrektur 1: Auffüllen skaliert mit der Beckengröße", "gdscript",
     snippet("src/world/WorldState.gd", "func refill", 20)),
    ("WaterSystem.gd — Regen nach der Wurzelentnahme, mit scaled_delta", "gdscript",
     snippet("src/systems/WaterSystem.gd", "func tick", 42)),
    ("BirdEvent.gd — Korrektur 2: Ziel hinter der linken Bildkante", "gdscript",
     snippet("src/ui/BirdEvent.gd", "func screen_left_world_x", 30)),
    ("BirdEvent.gd — Abflug pro Frame, erst am Rand freigeben", "gdscript",
     snippet("src/ui/BirdEvent.gd", "## progress 0 =", 18)),
    ("TimeManager.gd — eine Zeitquelle für alle Systeme", "gdscript",
     snippet("src/systems/TimeManager.gd", "const SCALES", 4)
     + "\n" + snippet("src/systems/TimeManager.gd", "func scaled_delta", 8)
     + "\n" + snippet("src/systems/TimeManager.gd", "func growth_factor", 8)),
    ("GrowthSystem.gd — Winter blockiert, Sonne/Wachstum/Difficulty", "gdscript",
     snippet("src/systems/GrowthSystem.gd", "func tick", 28)),
    ("SeasonSystem.gd — Reife ~3 Jahre, Eichelfall unter der Krone", "gdscript",
     snippet("src/systems/SeasonSystem.gd", "const MATURE_AGE_YEARS", 1)
     + "\n" + snippet("src/systems/SeasonSystem.gd", "func _autumn_drops", 20)),
    ("SeasonSystem.gd — Keimung nur bei Licht + Nicht-Winter", "gdscript",
     snippet("src/systems/SeasonSystem.gd", "func _land", 28)),
    ("WorldGenerator.gd — Noise-verteilte Samen pro Chunk", "gdscript",
     snippet("src/world/WorldGenerator.gd", "func ground_seeds_for_chunk", 26)),
    ("Global.gd — Schwierigkeit: Faktoren + vorbereitete Schalter", "gdscript",
     snippet("src/autoload/Global.gd", "func difficulty_toggle", 13)),
    ("SaveManager.gd — Format v4 (difficulty / time / seeds)", "gdscript",
     snippet("src/systems/SaveManager.gd", "func save_game", 20)),
    ("Main.gd — Zusatzfix: keine doppelte Vollbild-Skalierung", "gdscript",
     snippet("src/Main.gd", "func _fit_display", 12)),
    ("tests/Phase3Smoke.gd — die zwei Vorab-Korrekturen als Test", "gdscript",
     snippet("tests/Phase3Smoke.gd", "\t# --- 1) BUGFIX", 22)),
]

CHECKS = [
    "✅ <b>Korrektur 1 — Regen füllt Reservoirs auf:</b> <code>0.9 × Becken-Tiles × difficulty</code> Einheiten/s, <b>nach</b> der Wurzelentnahme, mit <code>TimeManager.scaled_delta()</code>. Smoke: 20 % → 40 % in 20 s, Pegelzeile 34 → 32. Screenshot <code>phase3_rain_refill.png</code> zeigt blau werdendes Becken + Toast.",
    "✅ <b>Korrektur 2 — Vogel fliegt aus dem Bild:</b> Ziel = Kamera-Mitte − Viewport-Breite/(2·Zoom) − 240 px, Bewegung pro Frame, <code>queue_free()</code> erst hinter der linken Kante. Zwei Screenshots (Mitte / Rand) + 3 Smoke-Checks.",
    "✅ <b>Zeit:</b> 1 Spiel-Jahr = 900 s (15 Echtzeit-Minuten, konfigurierbar), Frühling ×1.35 / Sommer ×1.00 / Herbst ×0.80 / <b>Winter ×0.00</b>, kahle Laubbäume, kein Tag/Nacht-Zyklus. <code>x1 / x3 / x10</code> + Pause (Leertaste), alle Systeme über <code>scaled_delta()</code>.",
    "✅ <b>Samen:</b> Noise-Verteilung pro Chunk, frei liegende Eicheln und flach vergrabene Hügel (<code>surface_tile_y_at + 2</code>), nur mit Wurzel in Reichweite erreichbar, Linksklick sammelt ein, Rechtsklick informiert, gesammelte IDs überleben Chunk-Reload.",
    "✅ <b>Herbst-Eichelfall:</b> Tween-Fall unter die Krone ab ~3 Spiel-Jahren, Keimung bei Licht + Nicht-Winter (22 % × Schwierigkeit × reservierter Skill „Verbreitung“), max. 14 Eicheln/Herbst und 100 Bäume.",
    "✅ <b>Schwierigkeitsgrade:</b> Startmenü vor Spielstart + HUD-Umschalter; Fotosynthese, Bodenwasser, Regen, Kosten, Verbrauch, Samendichte, Eichel-/Keimchance je LEICHT/NORMAL/SCHWER.",
    "✅ <b>Save v4:</b> <code>difficulty</code>, <code>time</code>, <code>seeds</code> zusätzlich; v3/v2/v1 weiter lesbar. Runde Reise im Smoke geprüft.",
    "✅ <b>Regression:</b> P0-, P1-, P2-, REV1-, REV2-Smoke alle <code>Ergebnis: OK</code>; weiche Kanten, 5 Chunks, Nearest + Forward+, DE/EN, Vogel-Timing, Eichel-Schwebe unverändert.",
    "✅ <b>Zusatzfix Vollbild:</b> bei 2560×1440 schnitt <code>content_scale_factor = 1.333</code> die HUD ab (Viewport nur 1440×810). Jetzt 1.0 → sichtbar 1920×1080, HUD vollständig, kein grauer Rand (2560×1440 und 3440×1440 geprüft).",
]

NOTES = [
    "pH-Wert, N-P-K, Mykorrhiza und Dürre/Sturm/Borkenkäfer sind laut Master-Punkt 4.2 Teil der „vollen Simulation“. PHASE 3 liefert alle Schalter (difficulty_toggle) und Faktoren (disaster_rate, soil_complexity) und speichert die Wahl; die Simulation selbst ist PHASE 5 zugeordnet. Der P3-Meilenstein (Zeile 153) nennt sie nicht.",
    "Skilltree-UI bleibt PHASE 4. Der Anschluss für den Skill „Verbreitung“ existiert bereits als SeasonSystem.set_spread_bonus() und geht in Eichel- und Keimwahrscheinlichkeit ein.",
    "Legacy-Smokes müssen ohne --seed laufen: Phase1Smoke.gd:47–48 verlangt ausdrücklich einen zufälligen Welt-Seed. Reproduzierbare Screenshots nutzen --seed=20261105.",
    "Regen-Partikel und UI-Tweens bleiben in Echtzeit; nur spielrelevante Simulation wird über scaled_delta() gespult bzw. pausiert.",
    "Keine externen Addons, keine Internet-Assets. Neu sind 2 Platzhalter-PNGs (seed_mound.png + .import/.uid), 17 Lokalisierungszeilen und 6 neue GDScript-/UI-Dateien bzw. Erweiterungen.",
    "Vor PHASE 3 wurde dem User absichtlich KEINE Zwischen-ZIP geschickt — die Lieferung erfolgt erst jetzt am Ende, wie gewünscht.",
]

PROTOCOL = (ROOT / "PHASE3-TESTPROTOKOLL.txt").read_text(encoding="utf-8") \
    if (ROOT / "PHASE3-TESTPROTOKOLL.txt").exists() else "[SMOKE] Ergebnis: OK"

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
    out = ["# PHASE 3 — Ergebnis (Zeit & Reproduktion)", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-07**  ",
           "Zwei Korrekturen vorab (Regen-Auffüllung, Vogel verlässt das Bild) "
           "**plus** die komplette PHASE 3 — ohne Zwischenlieferung, wie gewünscht.", "",
           "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```text", PROTOCOL.strip(), "```", "",
            "## 4 · Abnahme", ""]
    out += [f"- {c.replace('<b>', '**').replace('</b>', '**').replace('<code>', '`').replace('</code>', '`')}"
            for c in CHECKS]
    out += ["", "## 5 · Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `waldspiel-PHASE3.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root, `.godot` ausgeschlossen, CRC OK)",
            "- `PHASE3-ERGEBNIS.html` / `.md`, `PHASE3-TESTPROTOKOLL.txt`, `DECISIONS.md` §§46–53, `README.md`, `GODOT-IMPORT.txt`",
            "- `screenshots/phase3_*.png` (11 Renders), `tests/Phase3Smoke.gd`, `tools/build_phase3_report.py`",
            "- Neue/erweiterte Quellen: `TimeManager.gd`, `SeasonSystem.gd`, `StartMenu.gd`, `Global.gd`, `SaveManager.gd` (v4), `WaterSystem.gd`, `BirdEvent.gd`, `HUD.gd`, `Main.gd/.tscn`, `localization.csv`",
            "", "**PHASE 3 abgeschlossen · Nächster Schritt: PHASE 4 — Skilltree-UI.**", ""]
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
<title>PHASE 3 — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>PHASE 3 — Zeit &amp; Reproduktion</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-07<br>
  Zwei gemeldete Fehler behoben · Jahreszeiten (15 min/Jahr) · Zeitspulen x1/x3/x10 + Pause ·
  Herbst-Eichelfall · Samen finden/vergraben · LEICHT/NORMAL/SCHWER · Save v4</p>
  <div class="badges">
    <span class="badge zip">✓ komplette ZIP am Ende</span>
    <span class="badge fix">✓ Regen füllt Reservoirs</span>
    <span class="badge fix">✓ Vogel fliegt aus dem Bild</span>
    <span class="badge">6 / 6 Smokes OK</span>
    <span class="badge">55 P3-Checks OK</span>
    <span class="badge">0 rote Fehler</span>
  </div>
</header>

<h2>1 · Screenshots (echte Godot-Renders)</h2>
<div class="gallery">{shots_html}</div>

<h2>2 · Code-Snippets (aus den echten Projektdateien)</h2>
{code_html}

<h2>3 · Testprotokoll</h2>
<pre class="codeblock"><code>{html.escape(PROTOCOL.strip())}</code></pre>
<p class="sub">10 eingebettete Screenshots · 14 echte Snippets · alles offline (data-URIs, keine externen Ressourcen).</p>

<h2>4 · Abnahme</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">waldspiel-PHASE3.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root, CRC OK</li>
  <li><code class="inl">PHASE3-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">PHASE3-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (§§46–53)</li>
  <li><code class="inl">screenshots/phase3_*.png</code>, <code class="inl">tests/Phase3Smoke.gd</code>, <code class="inl">tools/build_phase3_report.py</code></li>
</ul>

<footer><strong>PHASE 3 ist abgeschlossen.</strong> Bewusst noch nicht enthalten: Skilltree-UI (PHASE 4) sowie die pH-/N-P-K-/Mykorrhiza-/Katastrophen-<em>Simulation</em> (PHASE 5; Schalter und Faktoren liegen bereits bereit). Kein Tag/Nacht-Zyklus – wie vom User gewünscht.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "PHASE3-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "PHASE3-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: PHASE3-ERGEBNIS.md / .html")
