#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt REVISION5-ERGEBNIS.md und REVISION5-ERGEBNIS.html.

Alle Snippets werden direkt aus den echten Projektdateien gelesen. Die sechs
Screenshots werden als data-URI eingebettet, damit der HTML-Bericht auch im
offline/sandboxed Arena-Preview vollstaendig sichtbar ist.
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

from build_phase5_report import CSS  # gemeinsames, offline-faehiges Stylesheet

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("rev5_f5.png", "F5-Start — REVISION 5 lauffähig",
     "Ohne Preset · AUTO aus (MANUELL) · Ökologie-Panel mit neuer Versorgungs-Zeile · kleine Bodenfauna"),
    ("rev5_mature.png", "Ausgewachsene Eiche: ~476px statt 192px",
     "28 freie Wuchsschritte · geschwungener Stamm · 7 Hauptäste mit Zwigen · Krone aus Astspitzen"),
    ("rev5_branches.png", "Stamm verzweigt sich, ohne Kachelraster",
     "Nahaufnahme: asymmetrische Kurven, Verjüngung nach oben, Blätter an freien Astspitzen"),
    ("rev5_roots.png", "Mycelarium-artiges Wurzelnetz",
     "Goldene Hauptfaser mit 3–5 feinen Hyphen pro Segment, Gabeln und Seitenfächern; logisches 16px-Raster nur noch für Wasser/Klick"),
    ("rev5_worms.png", "Würmer graben sich unter der Erde langsam durch",
     "Zwei deutlich kleinere Regenwürmer mit aufgelockerten Gang-Spuren · Ameisen nur noch 9px · Specht unverändert"),
    ("rev5_supply.png", "Versorgungs-Bilanz steuert Glucose und Wuchs",
     "Links ein schlecht versorgter Keimling (wenig Wurzeln/Wasser), rechts ein gut versorgter Baum; HUD zeigt den knappsten Faktor"),
]


def snippet(rel: str, start: str, lines: int = 14) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(text):
        if start in line:
            return "\n".join(text[i:i + lines]).rstrip() + "\n"
    raise RuntimeError(f"Marker fehlt: {start!r} in {rel}")


SNIPPETS = [
    ("Tree.gd — neue Wachstums-/Glucose-Konstanten", "gdscript",
     snippet("src/plants/Tree.gd", "const MAX_LEAVES := 12", 12)),
    ("Tree.gd — multiplikative Versorgungs-Bilanz", "gdscript",
     snippet("src/plants/Tree.gd", "func soil_fertility() -> float:", 12)
     + "\n" + snippet("src/plants/Tree.gd", "func environment_parts(", 14)),
    ("Tree.gd — langsamere, versorgungsabhängige Fotosynthese", "gdscript",
     snippet("src/plants/Tree.gd", "func photosynthesize(dt: float", 16)),
    ("Tree.gd — freies, deterministisches Ast-Skelett", "gdscript",
     snippet("src/plants/Tree.gd", "func _rebuild_skeleton() -> void:", 30)),
    ("Tree.gd — Stamm und Äste als Kurven gezeichnet", "gdscript",
     snippet("src/plants/Tree.gd", "func _draw() -> void:", 30)),
    ("RootSegment.gd — Mycelium-Faser mit Hyphen und Gabeln", "gdscript",
     snippet("src/plants/RootSegment.gd", "func _draw() -> void:", 44)),
    ("RootSegment.gd — logische 16px-Hitbox bleibt erhalten", "gdscript",
     snippet("src/plants/RootSegment.gd", "func hit_rect() -> Rect2:", 5)),
    ("Animal.gd — Würmer klein, langsam, 20–120px tief", "gdscript",
     snippet("src/animals/Animal.gd", "const WORM_DEPTH_MIN", 12)),
    ("Animal.gd — langsames Graben mit Gang-Spur", "gdscript",
     snippet("src/animals/Animal.gd", "func _tick_burrow(dt: float) -> void:", 16)),
    ("Animal.gd — Fels/Stein/Wasser sind undurchlässig", "gdscript",
     snippet("src/animals/Animal.gd", "func _worm_blocked(next_x: float) -> bool:", 12)),
    ("Animal.gd — Wurm klein, Tunnel sichtbar", "gdscript",
     snippet("src/animals/Animal.gd", "func _draw_worm(f: float, w: float) -> void:", 30)),
    ("GrowthSystem.gd — Wuchskraft statt Sofort-Kauf", "gdscript",
     snippet("src/systems/GrowthSystem.gd", "\t\t# REVISION 5: Wuchskraft", 10)),
    ("WildlifeSystem.gd — Wurmtiefe im Save v6", "gdscript",
     snippet("src/systems/WildlifeSystem.gd", '\t\t\taa.append({"species"', 4)
     + "\n" + snippet("src/systems/WildlifeSystem.gd", "\t\ta.reseat(x,", 5)),
    ("HUD.gd — Versorgung mit knappstem Faktor", "gdscript",
     snippet("src/ui/HUD.gd", "\t# REVISION 5: echte Versorgungs-Bilanz", 26)),
    ("Main.gd — sechs reproduzierbare Screenshot-Zustände", "gdscript",
     snippet("src/Main.gd", "\t# --- REVISION 5: organisches Wachstum", 20)),
    ("Revision5Smoke.gd — Abnahme der neuen Regeln", "gdscript",
     snippet("tests/Revision5Smoke.gd", "\t# --- 4) Glucose: Grundtempo", 24)),
]

CHECKS = [
    "Würmer liegen <b>unter der Erdoberfläche</b>, graben 20–120 px tief, bewegen sich langsam (8 px/s) und hinterlassen sichtbare Gang-Spuren; Fels/Stein/Wasser/Hohlräume blockieren sie.",
    "Wurm <b>12 px</b> und Ameise <b>9 px</b> statt 28/21 px; kleinere Klickflächen; Specht/Eichhörnchen unverändert groß.",
    "Ausgewachsene Eiche: <b>28 Wuchsschritte × 17 px = 476 px</b> statt 12 × 16 px = 192 px; bis zu 7 Hauptäste mit je 2 Zwigen; Blätter an freien Astspitzen.",
    "Wurzeln und Stamm sind <b>freie, gekrümmte, deterministische Geometrie</b> abseits des 16px-Rasters; Wurzeln tragen 3–5 feine Hyphen mit Gabeln (Mycelarium-Anmutung).",
    "Wasser/Reservoir, Ghost-Preview, Klick-Hitboxen (16×16) und Save v6 bleiben <b>logisch unverändert</b> — nur die Darstellung wurde entkoppelt.",
    "Glucose-Grundtempo <b>0,2</b> (≈5× langsamer) plus multiplikative Bilanz aus <b>Wasser, Sonne, Nährstoffen (echte Bodengüte) und Wurzelmasse</b>.",
    "Ein Keimling mit 1 Wurzel produziert ~<b>1/4</b> bis <b>1/80</b> der Glucose eines gut versorgten Baums; AUTO-Wuchskraft sammelt sich nur entsprechend der Versorgung an.",
    "HUD zeigt <code>Versorgung …%</code> mit dem jeweils knappsten Faktor; 9 neue DE/EN-Schlüssel; Wurmtiefe über Save/Load erhalten.",
    "<b>11/11 Smokes OK · 377 OK-Zeilen · 0 Fehler</b>; Import, F5 ohne Preset und 180-Frame-Dauerlauf fehlerfrei; sechs 1920×1080-Xvfb-Renders.",
    "Regression: AUTO standardmäßig aus, ausgewachsener Baum verbraucht keine Glucose, P0–P5/REV-Artefakte und alle alten ZIPs erhalten.",
]

NOTES = [
    "Der User wählte per Rückfrage „~5× langsamer, ~3× größer\" und „freie organische Geometrie, Tile-Logik bleibt\". Beides ist in DECISIONS.md §71 verbindlich dokumentiert.",
    "„Entkoppelt von den Feldern\" wird als Entkopplung der DARSTELLUNG umgesetzt: die Simulation braucht weiterhin Bodentiles für Reservoire, Wasseraufnahme, Bodenhärte und Speicherstände. Ein kompletter Umbau der Simulation wurde bewusst nicht gewählt.",
    "Die Freiform-Geometrie wird aus tree_id + Index gehasht, nicht pro Frame zufällig generiert: kein Flackern, kein zusätzlicher Savegame-State, identische Bäume nach Laden.",
    "pH-/N-P-K-/Mykorrhiza-/Katastrophen-Vollsimulation bleibt weiterhin einer späteren Ausbaustufe vorbehalten. Es wurde keine PHASE 6 begonnen.",
]


def _shots_html() -> str:
    out = ""
    for name, title, caption in SHOTS:
        raw = (ROOT / "screenshots" / name).read_bytes()
        uri = "data:image/png;base64," + base64.b64encode(raw).decode("ascii")
        out += (f'<figure><img src="{uri}" alt="{html.escape(title)}">'
                f'<figcaption><b>{html.escape(title)}</b><br>'
                f'<span>{html.escape(caption)}</span></figcaption></figure>\n')
    return out


def build_md() -> str:
    lines = [
        "# REVISION 5 — Organisches Wachstum & Bodenleben",
        "",
        "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05**",
        "",
        "Würmer graben unter der Erde · Würmer/Ameisen deutlich kleiner · Bäume ~5× langsamer und ~3× größer · Glucose hängt an Wasser, Sonne, Nährstoffen und Wurzelmasse · Stamm und Wurzeln verzweigen sich frei statt im Kachelraster. **11/11 Smokes · 377 OK-Zeilen · 0 Fehler.**",
        "",
        "## 1 · Screenshots (echte Godot-Renders)",
        "",
    ]
    for name, title, caption in SHOTS:
        lines += [f"### {title}", f"*{caption}*", "",
                  f"![{title}](screenshots/{name})", ""]
    lines += ["---", "", "## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        lines += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    lines += ["---", "", "## 3 · Testprotokoll", "", "```text",
              (ROOT / "REVISION5-TESTPROTOKOLL.txt").read_text(encoding="utf-8").rstrip(),
              "```", "", "---", "", "## 4 · Abnahme REVISION 5", ""]
    lines += [f"- {c}" for c in CHECKS]
    lines += ["", "---", "", "## 5 · Hinweise / bewusste Grenzen", ""]
    lines += [f"- {n}" for n in NOTES]
    lines += ["", "---", "", "## 6 · Lieferumfang", "",
              "- `deliverables/waldspiel-REVISION5.zip` — vollständiges Projekt, `project.godot` im ZIP-Root, CRC OK, frischer Extrakt geprüft",
              "- `REVISION5-ERGEBNIS.html` / `.md`, `REVISION5-TESTPROTOKOLL.txt`, `DECISIONS.md` (§71)",
              "- `screenshots/rev5_*.png` (6 Renders), `tests/Revision5Smoke.gd`, `tools/build_revision5_report.py`",
              "- geändert: `src/plants/Tree.gd`, `src/plants/RootSegment.gd`, `src/animals/Animal.gd`, `src/systems/GrowthSystem.gd`, `src/systems/WildlifeSystem.gd`, `src/ui/HUD.gd`, `src/Main.gd`, `data/species/oak.tres`, `data/localization.csv`",
              "", "**REVISION 5 ist abgeschlossen. Es wurde keine PHASE 6 begonnen.**", ""]
    return "\n".join(lines)


def build_html() -> str:
    shots_html = _shots_html()
    code_html = ""
    for title, lang, code in SNIPPETS:
        code_html += ('<div class="snip"><h3>' + html.escape(title)
                      + ' <small>(' + lang + ')</small></h3>'
                      '<pre class="codeblock"><code>' + html.escape(code)
                      + '</code></pre></div>\n')
    protocol = (ROOT / "REVISION5-TESTPROTOKOLL.txt").read_text(encoding="utf-8")
    checks_html = "".join("<li>" + c + "</li>" for c in CHECKS)
    notes_html = "".join("<li>" + html.escape(n) + "</li>" for n in NOTES)
    return f"""<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>REVISION 5 — Organisches Wachstum &amp; Bodenleben</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>REVISION 5 — Organisches Wachstum &amp; Bodenleben</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05<br>
  Würmer graben unter der Erde · kleinere Bodenfauna · langsamere &amp; größere Bäume · Versorgungs-Bilanz · freie Verzweigung</p>
  <div class="badges">
    <span class="badge zip">✓ komplette ZIP</span>
    <span class="badge p5">✓ 11 / 11 Smokes OK</span>
    <span class="badge p5">✓ 377 OK-Zeilen</span>
    <span class="badge">0 rote Fehler</span>
    <span class="badge">6 eingebettete Renders</span>
    <span class="badge">{len(SNIPPETS)} echte Snippets</span>
  </div>
</header>

<h2>1 · Screenshots (echte Godot-Renders)</h2>
<div class="gallery">{shots_html}</div>

<h2>2 · Code-Snippets (aus den echten Projektdateien)</h2>
{code_html}

<h2>3 · Testprotokoll</h2>
<pre class="codeblock"><code>{html.escape(protocol.strip())}</code></pre>
<p class="sub">6 eingebettete Screenshots · {len(SNIPPETS)} echte Snippets · alles offline (data-URIs, keine externen Ressourcen).</p>

<h2>4 · Abnahme REVISION 5</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">deliverables/waldspiel-REVISION5.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root, CRC OK, frischer Extrakt geprüft</li>
  <li><code class="inl">REVISION5-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">REVISION5-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (§71)</li>
  <li><code class="inl">screenshots/rev5_*.png</code> (6 Renders), <code class="inl">tests/Revision5Smoke.gd</code>, <code class="inl">tools/build_revision5_report.py</code></li>
  <li>Alle P0–P5/REV-Artefakte, historischen ZIPs und Berichte bleiben erhalten; PHASE-5-Berichte sind als vorheriger Stand markiert.</li>
</ul>

<footer><strong>REVISION 5 ist abgeschlossen.</strong> pH-/N-P-K-/Mykorrhiza-/Katastrophen-Vollsimulation bleibt einer späteren Ausbaustufe vorbehalten; es wurde <strong>keine PHASE 6</strong> begonnen.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "REVISION5-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "REVISION5-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print(f"Berichte geschrieben: REVISION5-ERGEBNIS.md / .html | {len(SHOTS)} Bilder | {len(SNIPPETS)} Snippets")
