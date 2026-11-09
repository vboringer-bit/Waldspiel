#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt PHASE2-ERGEBNIS.md und PHASE2-ERGEBNIS.html (offline Preview).
Snippets kommen direkt aus den echten Projektdateien, Bilder als data-URIs.
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHOTS = [
    ("phase2_caves.png", "Höhlen (dunkle Blasen) + blaue Wasserreservoirs", "Seed 20261105 · Zoom 1.00x · Blick in die Tiefe"),
    ("phase2_roots.png", "Pfahlwurzel + Seitenwurzeln bis ins Reservoir", "HUD: Reservoir 100% · 22 RootSegmente"),
    ("phase2_manual.png", "MANUELL: Ghost-Preview mit Bodenmaterial und Preis", "„Mutterboden · −10 Glucose“ · Glucose 42.0"),
    ("phase2_dry.png", "Ausgetrocknetes Reservoir wird optisch heller", "Toast „Ein Wasserreservoir ist ausgetrocknet.“"),
]


def extract(rel: str, start: str, end: str) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8")
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"Start-Marker fehlt: {start!r} in {rel}")
    j = text.find(end, i)
    if j < 0:
        raise RuntimeError(f"End-Marker fehlt: {end!r} in {rel}")
    return text[i:j].rstrip() + "\n"


SNIPPETS = [
    ("WorldGenerator.gd — kohärente Höhlen-/Reservoir-Blasen", "gdscript",
     extract("src/world/WorldGenerator.gd", "func _blob_at", "## Start-Kapazitaet")),
    ("GrowthCost.gd — Wachstum kostet nach Bodenhärte", "gdscript",
     extract("src/systems/GrowthCost.gd", "static func multiplier", "static func for_root")),
    ("RootSegment.gd — Tree → Roots → RootSegment → RootTip", "gdscript",
     extract("src/plants/RootSegment.gd", "func setup", "func refresh_sprite")),
    ("Tree.gd — nächstes Erd-Tile + Seitenwurzeln", "gdscript",
     extract("src/plants/Tree.gd", "func propose_next_tile", "## Tiefster Tip")),
    ("Oak.gd — Pfahlwurzel + Herzwurzelsystem", "gdscript",
     (ROOT / "src/plants/Oak.gd").read_text(encoding="utf-8")),
    ("GhostPreview.gd — Vorschau + Kosten-Label", "gdscript",
     extract("src/ui/GhostPreview.gd", "func show_at", "func _draw")),
    ("WaterSystem.gd — 0.1/s Boden, 2.0/s Reservoir, 5x Regen", "gdscript",
     extract("src/systems/WaterSystem.gd", "func tick", "## Anteil des")),
    ("WorldState.gd — endliche Kapazität + Austrocknen", "gdscript",
     extract("src/world/WorldState.gd", "## Entnimmt Wasser", "func dry_count")),
]

SMOKE_LOG = """[Global] seed=1621027769 (Zufall) | difficulty=NORMAL | auto=ON | Godot 4.7.2-stable (official)
[Main] PHASE 2 bereit: 2 Eicheln, Kern-Loop, Wurzel-Segmente, Bodenhärte, Reservoirs, Höhlen.
[SMOKE] === PHASE 2 ===
[SMOKE] Hoehlen/Reservoirs deterministisch pro Seed          OK
[SMOKE] Hoehlen-Tiles in Chunk 0 vorhanden (82)              OK
[SMOKE] Starter-Reservoir unter dem Keimling (Tiefe 10)      OK
[SMOKE] Hoehlen-Tile ohne Kollision (Hohlraum)               OK
[SMOKE] Mutterboden = 10 Glucose (Akzeptanzkriterium)        OK
[SMOKE] Fels > Lehm > Mutterboden > Hoehle (Kosten)          OK
[SMOKE] Keimling: 1 RootSegment auf (0,0)                    OK
[SMOKE] Hierarchie Tree -> Roots -> RootSegment -> RootTip   OK
[SMOKE] Wurzelklick: laenger, −9 Glucose (Boden)             OK
[SMOKE] Wurzel waechst in Erd-Richtung (+y)                  OK
[SMOKE] Ghost-Preview sichtbar (MANUELL)                     OK
[SMOKE] Ghost zeigt naechstes freies Erd-Tile                OK
[SMOKE] Pfahlwurzel beruehrt Reservoir (22 Segmente)         OK
[SMOKE] Reservoir schneller als Boden (32.4 > 4.4 / 2s)      OK
[SMOKE] Kapazitaet nimmt ab (110 -> 106 von 110)             OK
[SMOKE] Reservoir ausgetrocknet                              OK
[SMOKE] Ausgetrocknet = heller Atlas-Slot 16                 OK
[SMOKE] Speichern (Format v2)                                OK
[SMOKE] Laden (Format v2)                                    OK
[SMOKE] Trockenzustand aus Savegame wiederhergestellt        OK
[SMOKE] Wurzel-Segmente + Tips aus Savegame                  OK
[SMOKE] 5 Chunks nach Pan auf x=4300                         OK
[SMOKE] Nearest + Forward+ weiterhin aktiv                   OK
[SMOKE] DE/EN: neue PHASE-2-Texte                            OK
[SMOKE] Ergebnis: OK"""

CHECKS = [
    "Klick auf ein Wurzel-Segment → Wurzel wird länger und wächst in Erd-Richtung",
    "Kosten = 10 Glucose für Mutterboden (Akzeptanzkriterium), abhängig von Bodenhärte: Asche 8 / Humus 9 / Lehm 13 / Fels 25 / Stein 30 / Höhle 4 / Reservoir 15",
    "Ghost-Preview zeigt Ziel-Tile, Bodenmaterial und Preis; rot bei zu wenig Glucose; Vorschau und Kauf nutzen dieselbe propose_next_tile()",
    "Echte Wurzel-Segmente mit RootTip-Hierarchie (Tree → Roots → RootSegment → RootTip), max. 32 Segmente",
    "Eiche: Pfahlwurzel strikt nach unten + Herzwurzelsystem (alle 4 Tiefen-Tiles eine Seitenwurzel als weiterer Tip)",
    "Wasserreservoirs: 2.0/s pro berührtem Tile statt 0.1/s aus Boden – endlich, Kapazität 60–120 Einheiten",
    "Ausgetrocknete Reservoirs werden optisch heller (Atlas-Slot 16) und bleiben über Chunk-Wechsel / Save/Load trocken",
    "Höhlen: dunkle, kollisionsfreie Hohlraum-Blasen; Wurzelwachstum dort am billigsten",
    "AUTO zahlt dieselben bodenabhängigen Kosten wie MANUELL; Blatt/Stamm kosten weiter 10",
    "HUD: Wurzel-Kosten + Reservoir-Füllstand in %; alle neuen Texte DE/EN in localization.csv",
    "Speichern v2: Wurzel-Segmente + Reservoir-Zustand; liest v1-Spielstände rückwärtskompatibel",
    "Regression: PHASE 0 und PHASE 1 Smoke-Tests weiterhin Exit 0 / Ergebnis OK",
    "5 infinite Chunks, Zoom/Pan, Nearest, Forward+/Vulkan, 1920x1080, keine externen Addons",
    "Import, F5-Ersatz und 3 Smoke-Tests: 0 rote Fehler; 4 Screenshots ohne Fehler",
]

NOTES = [
    "**PHASE 3 wurde nicht begonnen.** Jahreszeiten/Zeitspulen, Herbst-Eichelfall, Samen finden/vergraben, Schwierigkeitsgrade, Buche/Kiefer, Skilltree-UI, Tiere, Pilze und Parasiten sind bewusst noch nicht drin.",
    "**10 Glucose bleibt der Referenzwert**, aber nur für Mutterboden. Der erste Noise-Ansatz für Höhlen/Reservoirs erzeugte 1-Tile-Sprenkel („Fernseh-Rauschen“) → ersetzt durch deterministische Ellipsen-Blasen auf einem Zellraster, memoisisiert pro Tile.",
    "**Ein garantiertes Starter-Reservoir** (Chunk 0, Tiles x −6…6, Tiefe 10–12) macht das Feature in Tutorial, Screenshots und Tests zuverlässig sichtbar; alle weiteren Reservoirs und Höhlen kommen aus dem Seed. Das ist eine dokumentierte Annahme, da der Master keine Verteilung vorgibt.",
    "**WorldState ist kein Autoload**, sondern ein RefCounted im Besitz des ChunkManager: Wo Wasser liegt = Seed, wie voll es ist = Spielzustand im Savegame. Sonst würde ein neu geladener Chunk endliches Wasser nachfüllen.",
    "**Höhlen sind Hohlraum-Tiles ohne Kollision**, kein Grab-/Abbau-Modus und keine begehbaren Tunnel (MVP-Rahmen).",
    "**ZIP ist ab jetzt fester Phasen-Abschluss** (User-Anweisung): `tools/build_zip.py PHASE2` → `waldspiel-PHASE2.zip` mit project.godot im Root. Gilt für alle kommenden Phasen.",
    "Screenshots: echtes Godot 4.7.2 unter Xvfb mit Software-Rendering, reproduzierbar via `--seed=20261105 --phase2-shot-{caves,roots,manual,dry}`. project.godot bleibt Forward+ / Vulkan.",
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md() -> str:
    out = [
        "# PHASE 2 — Ergebnis", "",
        "> **Status:** ✅ abgeschlossen · lauffähig · getestet  ",
        "> **Engine:** Godot `4.7.2.stable.official.ed1daf0bf` (Forward+ / Vulkan) · GDScript  ",
        "> **Datum:** 2026-11-05 · **Nächster Schritt:** PHASE 3 **erst nach deinem OK**",
        "",
        "**Umgesetzt:** Manuelles Wurzelwachstum in Erd-Richtung, Boden-Typen mit unterschiedlichen Glucose-Kosten, endliche/austrocknende Wasserreservoirs, Höhlen – plus Ghost-Preview, echte RootTip-Hierarchie und Save-Format v2.",
        "",
        "**Zusätzlich wie gewünscht:** eine vollständige, in Godot importierbare ZIP (`waldspiel-PHASE2.zip`).",
        "", "---", "", "## 1. Screenshots (echte Godot-Renders)", "",
    ]
    for fn, caption, meta in SHOTS:
        out += [f"![{caption}](screenshots/{fn})", "", f"*{caption} — {meta}*", ""]
    out += [
        "## 2. Neue / geänderte Dateien", "",
        "| Datei | Aufgabe |", "|---|---|",
        "| `src/plants/RootSegment.gd` | ein Wurzel-Segment + `RootTip`-Marker auf dem 16px-Raster |",
        "| `src/plants/Tree.gd`, `Oak.gd` | Segmente, `propose_next_tile()`, `grow_root_from()`, Pfahlwurzel + Herzwurzelsystem |",
        "| `src/systems/GrowthCost.gd` | zentrale Boden-Kosten-Tabelle (Fels teurer) |",
        "| `src/ui/GhostPreview.gd` | Ziel-Tile, Preis, affordability |",
        "| `src/world/WorldGenerator.gd` | Höhlen/Reservoir-Blasen, `SLOT_CAVE/WATER/DRY_WATER`, Starter-Reservoir |",
        "| `src/world/WorldState.gd` | endliche Kapazität, Austrocknen, Save/Load |",
        "| `src/world/Chunk.gd`, `ChunkManager.gd` | Spezial-Slots, Trocken-Repaint, `get_chunk()` |",
        "| `src/world/TerrainAtlas.gd` | 17 Atlas-Slots, Höhlen ohne Kollision |",
        "| `src/systems/WaterSystem.gd` | 2.0/s Reservoir-Boost, Regen 5x bleibt |",
        "| `src/systems/GrowthSystem.gd`, `InteractionController.gd`, `SaveManager.gd` | bodenabhängige Kosten, Wurzelklick, v2-Save |",
        "| `src/ui/HUD.gd` | Wurzel-Kosten + Reservoir-Füllstand |",
        "| `data/localization.csv`, `data/species/oak.tres` | DE/EN-Texte, `root_side_every` |",
        "| `tests/Phase2Smoke.gd`, `tools/build_zip.py`, `GODOT-IMPORT.txt` | 24 Checks, ZIP, Import-Anleitung |",
        "", "## 3. Code-Snippets (direkt aus dem Projekt)", "",
    ]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += [
        "## 4. Testprotokoll", "",
        "```bash",
        "godot --headless --path . --import                  # 0 Fehler",
        "godot --headless --path . --quit-after 180          # F5-Ersatz: 0 Fehler",
        "godot --headless --path . -- --phase0-smoke         # Regression: OK",
        "godot --headless --path . -- --phase1-smoke         # Regression: OK (25 Checks)",
        "godot --headless --path . -- --phase2-smoke         # 24 Checks: OK, Exit 0",
        "python3 tools/build_zip.py PHASE2                   # ZIP + CRC-Test",
        "```", "", "```text", SMOKE_LOG, "```", "",
        "Zusätzlich: 4 Xvfb-Screenshots ohne Fehler, 18/18 PNGs mit `mipmaps/generate=false`, "
        "3 Neustarts → 3 Seeds, ZIP-CRC-Test OK.",
        "", "## 5. Abnahme PHASE 2", "",
    ]
    out += [f"- [x] {c}" for c in CHECKS]
    out += ["", "## 6. Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += [
        "", "---", "",
        "**Ich stoppe hier.** Sag „Weiter mit PHASE 3“, dann kommen Jahreszeiten, Zeitspulen, "
        "Herbst-Eichelfall, Samen finden/vergraben und Schwierigkeitsgrade.", "",
    ]
    return "\n".join(out)


def build_html() -> str:
    shots_html = ""
    for fn, caption, meta in SHOTS:
        uri = "data:image/png;base64," + b64(ROOT / "screenshots" / fn)
        shots_html += f"""
        <figure>
          <img src="{uri}" alt="{html.escape(caption)}">
          <figcaption><strong>{html.escape(caption)}</strong><span>{html.escape(meta)}</span></figcaption>
        </figure>"""

    code_html = ""
    for title, _lang, code in SNIPPETS:
        code_html += f"""
        <details>
          <summary>{html.escape(title)}</summary>
          <pre><code>{html.escape(code.rstrip())}</code></pre>
        </details>"""

    checks_html = "".join(f"<li><span class='tick'>✓</span>{html.escape(c)}</li>" for c in CHECKS)
    notes_html = "".join(f"<li>{html.escape(n.replace('**', ''))}</li>" for n in NOTES)

    return f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PHASE 2 — Ergebnis | Wald-Regeneration</title>
<style>
  :root {{ --bg:#15191b; --card:#1e2427; --line:#33403f; --txt:#e8e5d9; --dim:#a8b2ad; --accent:#a9c47c; --warm:#e7c98d; --blue:#79b9d8; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--txt);
         font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif; line-height:1.6; }}
  .wrap {{ max-width:1100px; margin:0 auto; padding:36px 24px 80px; }}
  header {{ border-bottom:1px solid var(--line); padding-bottom:22px; margin-bottom:28px; }}
  .kicker {{ color:var(--accent); font-size:12px; letter-spacing:.22em; text-transform:uppercase; font-weight:700; }}
  h1 {{ font-size:38px; margin:8px 0 6px; letter-spacing:-.02em; }}
  .sub {{ color:var(--dim); font-size:15px; }}
  .decision {{ margin-top:16px; background:#202b26; border-left:3px solid var(--accent);
               padding:12px 16px; border-radius:0 8px 8px 0; font-size:14px; color:#d6e3cd; }}
  .zip {{ margin-top:10px; background:#202a2e; border-left:3px solid var(--blue);
          padding:12px 16px; border-radius:0 8px 8px 0; font-size:14px; color:#cfe2ee; }}
  .badges {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:16px; }}
  .badge {{ background:#26302e; border:1px solid var(--line); border-radius:999px; padding:5px 12px; font-size:12.5px; }}
  .badge.ok {{ border-color:#5c7d4a; color:#cfe6ac; }}
  .badge.zip {{ border-color:#4a7d96; color:#bfe0f0; }}
  h2 {{ font-size:21px; margin:42px 0 16px; padding-left:12px; border-left:3px solid var(--accent); }}
  table {{ width:100%; border-collapse:collapse; font-size:14px; }}
  th, td {{ text-align:left; padding:8px 10px; border-bottom:1px solid var(--line); vertical-align:top; }}
  th {{ color:var(--warm); }}
  td:first-child {{ font-family:ui-monospace,Menlo,Consolas,monospace; font-size:12.5px; color:#cfe0cf; }}
  .gallery {{ display:grid; gap:20px; }}
  figure {{ margin:0; background:var(--card); border:1px solid var(--line); border-radius:12px; overflow:hidden; }}
  figure img {{ display:block; width:100%; height:auto; }}
  figcaption {{ display:flex; justify-content:space-between; flex-wrap:wrap; gap:8px; padding:12px 16px;
                font-size:13.5px; border-top:1px solid var(--line); }}
  figcaption span {{ color:var(--dim); }}
  details {{ background:var(--card); border:1px solid var(--line); border-radius:10px; margin-bottom:10px; overflow:hidden; }}
  summary {{ cursor:pointer; padding:12px 16px; font-weight:600; font-size:14px; color:var(--warm); }}
  pre {{ margin:0; padding:0 16px 16px; overflow-x:auto; }}
  code {{ font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:12.5px; line-height:1.55;
          color:#d6e0d4; white-space:pre; }}
  pre.codeblock {{ background:#0e1213; border:1px solid var(--line); border-radius:10px; padding:16px;
                   overflow-x:auto; margin:0 0 16px; }}
  ul {{ padding-left:22px; }} li {{ margin:8px 0; }}
  .tick {{ color:var(--accent); font-weight:800; margin-right:10px; }}
  .note {{ background:#202826; border-left:3px solid var(--warm); padding:14px 18px; border-radius:0 8px 8px 0; }}
  .note li {{ color:var(--dim); font-size:14px; }}
  footer {{ margin-top:44px; padding-top:22px; border-top:1px solid var(--line); color:var(--dim); font-size:14px; }}
  strong {{ color:var(--txt); }}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="kicker">Wald-Regeneration · Godot 4.7.2 · GDScript</div>
    <h1>PHASE 2 — Ergebnis</h1>
    <div class="sub">Wachstum &amp; Boden: Wurzel-Segmente, Bodenhärte, endliche Reservoirs, Höhlen, Ghost-Preview.</div>
    <div class="decision">Manueller Wurzelklick wächst in Erd-Richtung · 10 Glucose für Mutterboden, Fels 25 · Reservoirs 2.0/s und austrocknend · Höhlen als kollisionsfreie Blasen.</div>
    <div class="zip"><strong>Zusätzlich wie gewünscht:</strong> <code>waldspiel-PHASE2.zip</code> – vollständiges Projekt, <code>project.godot</code> im ZIP-Root, direkt in Godot importierbar. Ab jetzt am Ende <em>jeder</em> Phase.</div>
    <div class="badges">
      <span class="badge ok">✓ abgeschlossen</span>
      <span class="badge ok">✓ 0 Fehler im Output</span>
      <span class="badge ok">✓ 3 Smoke-Tests grün</span>
      <span class="badge">Forward+ / Vulkan</span>
      <span class="badge zip">✓ komplette ZIP</span>
      <span class="badge">2026-11-05</span>
      <span class="badge">PHASE 3 nicht begonnen</span>
    </div>
  </header>

  <h2>1 · Screenshots (echte Godot-Renders)</h2>
  <div class="gallery">{shots_html}
  </div>

  <h2>2 · Code-Snippets</h2>
  {code_html}

  <h2>3 · Testprotokoll</h2>
  <pre class="codeblock"><code>godot --headless --path . --import                  # 0 Fehler
godot --headless --path . --quit-after 180          # F5-Ersatz: 0 Fehler
godot --headless --path . -- --phase0-smoke         # Regression: OK
godot --headless --path . -- --phase1-smoke         # Regression: OK (25 Checks)
godot --headless --path . -- --phase2-smoke         # 24 Checks: OK, Exit 0
python3 tools/build_zip.py PHASE2                   # ZIP + CRC-Test</code></pre>
  <pre class="codeblock"><code>{html.escape(SMOKE_LOG)}</code></pre>
  <p class="sub">4 Xvfb-Screenshots ohne Fehler · 18/18 PNGs mit mipmaps=off · 3 Neustarts → 3 Seeds · ZIP-CRC-Test OK.</p>

  <h2>4 · Abnahme PHASE 2</h2>
  <ul>{checks_html}</ul>

  <h2>5 · Hinweise / bewusste Grenzen</h2>
  <div class="note"><ul>{notes_html}</ul></div>

  <footer><strong>Ich stoppe hier.</strong> Sag „Weiter mit PHASE 3“, dann kommen Jahreszeiten, Zeitspulen, Herbst-Eichelfall, Samen finden/vergraben und Schwierigkeitsgrade – inklusive neuer ZIP.</footer>
</div>
</body>
</html>
"""


if __name__ == "__main__":
    (ROOT / "PHASE2-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "PHASE2-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: PHASE2-ERGEBNIS.md / .html")
