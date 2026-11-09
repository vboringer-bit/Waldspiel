#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt PHASE1-ERGEBNIS.md und PHASE1-ERGEBNIS.html (offline Preview).
Code-Snippets kommen direkt aus den echten Projektdateien; Bilder werden als
data: URIs eingebettet, damit der Viewer ohne Netzwerk funktioniert.
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHOTS = [
    ("phase1_start.png", "Start: 2 Eicheln im Inventar, HUD, noch kein Baum", "Seed 20261105 · Zoom 1.00x"),
    ("phase1_bird.png", "Vogel-Event: „Die Natur ist hungrig. Versuche es erneut.“", "1. Eichel · Vogel im Anflug · Inventar ×1"),
    ("phase1_tree.png", "Keimling: 2 Stamm-Tiles, 2 Blätter, 1 Wurzel · Glucose 8.7", "2. Eichel · AUTO · Wasser 98%"),
    ("phase1_rain.png", "Regen-Event mit blauen Linien und 5x Wasser-Boost", "Toast + HUD „Es regnet“"),
]


def extract(rel: str, start: str, end: str | None = None) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8")
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"Start-Marker fehlt: {start!r} in {rel}")
    j = text.find(end, i) if end else len(text)
    if j < 0:
        raise RuntimeError(f"End-Marker fehlt: {end!r} in {rel}")
    return text[i:j].rstrip() + "\n"


SNIPPETS = [
    ("Global.gd — Seed wird bei jedem Neustart gewürfelt", "gdscript",
     extract("src/autoload/Global.gd", "## Zufalls-Seed pro Prozessstart", "func set_seed_from_save")),
    ("InteractionController.gd — Tutorial: Vogel-Event + Keimung", "gdscript",
     extract("src/systems/InteractionController.gd", "func plant_seed_at", "func spawn_tree_at")),
    ("Tree.gd — Fotosynthese & Wasseraufnahme", "gdscript",
     extract("src/plants/Tree.gd", "## Punkt 4.2:", "# --------------------------------------------------------------------------- #\n# Info / Save")),
    ("WaterSystem.gd — Bodenwasser 0.1/s, Regen 5x", "gdscript",
     extract("src/systems/WaterSystem.gd", "func tick(delta: float) -> void:", "func start_rain")),
    ("GrowthSystem.gd — AUTO-Verteilung", "gdscript",
     extract("src/systems/GrowthSystem.gd", "func tick(delta: float) -> void:", "## Deterministische")),
    ("SaveManager.gd — JSON in user://savegame.json", "gdscript",
     extract("src/systems/SaveManager.gd", "func save_game() -> bool:", "func load_game")),
    ("data/species/oak.tres — TreeSpeciesData als Resource", "ini",
     (ROOT / "data/species/oak.tres").read_text(encoding="utf-8")),
]

SMOKE_LOG = """[Global] seed=1497285583 (Zufall) | difficulty=NORMAL | auto=ON | Godot 4.7.2-stable (official)
[Main] PHASE 1 bereit: 2 Eicheln, Vogel-Event, Keimung, Glucose/Wasser, Regen, AUTO/MANUELL.
[SMOKE] === PHASE 1 ===
[SMOKE] Zufalls-Seed pro Neustart (seed=1497285583)    OK
[SMOKE] 2 Eicheln im Inventar                          OK
[SMOKE] Vogel-Event ausgeloest                         OK
[SMOKE] Inventar nach Vogel: 1                         OK
[SMOKE] Noch kein Baum                                 OK
[SMOKE] 1 Baum nach 2. Eichel                          OK
[SMOKE] Keimling: 2 Stamm-Tiles / 2 Blaetter / 1 Wurzel OK
[SMOKE] Baum ausgewaehlt (HUD)                         OK
[SMOKE] Glucose steigt / Wasser sinkt                  OK
[SMOKE] Glucose 0.00 -> 8.00 | Wasser 100.00 -> 98.25
[SMOKE] Regen aktiv                                    OK
[SMOKE] Regen-Partikel (blaue Linien) sichtbar         OK
[SMOKE] Regen-Boost ~5x (normal 0.20 / Regen 1.00)     OK
[SMOKE] AUTO: Blatt-Wachstum, -10 Glucose              OK
[SMOKE] MANUELL: Wurzel-Wachstum, -10 Glucose          OK
[SMOKE] Speichern nach user://savegame.json            OK
[SMOKE] Baeume vor Load entfernt                       OK
[SMOKE] Laden erfolgreich                              OK
[SMOKE] 1 Baum wiederhergestellt                       OK
[SMOKE] Seed aus Spielstand wiederhergestellt          OK
[SMOKE] Inventar aus Spielstand                        OK
[SMOKE] Glucose aus Spielstand                         OK
[SMOKE] 5 Chunks nach Pan auf x=4300                   OK
[SMOKE] DE/EN-Umschaltung (TranslationServer)          OK
[SMOKE] Nearest + Forward+ weiterhin aktiv             OK
[SMOKE] Ergebnis: OK"""

CHECKS = [
    "Seed wird bei jedem Neustart neu gewürfelt (3 Teststarts → 3 Seeds); `--seed=<int>` und Save/Load stellen ihn reproduzierbar wieder her",
    "2 Eicheln im Inventar, Linksklick auf Boden platziert sie",
    "1. Eichel: Vogel fliegt per Tween rein, frisst sie, Toast „Die Natur ist hungrig. Versuche es erneut.“, kein Baum",
    "2. Eichel: Keimung zu Mini-Baum mit 2 Stamm-Tiles, 2 Blättern, 1 Wurzel",
    "`Tree.gd` (BaseTree) + `Oak.gd` + `TreeSpeciesData` als `oak.tres`; Glucose/Water/Health pro Instanz",
    "Blätter produzieren Glucose (`leaves × 0.8 × 1.0 × dt`), Wasser sinkt um `0.35 × dt` – immer Tag",
    "Wurzeln sammeln Wasser langsam (`roots × 0.1/s`), bei Regen 5x (`roots × 0.5/s`)",
    "Regen-Event 120–300 s Intervall / 20–60 s Dauer, blaue Linien, Toast + HUD „Es regnet“",
    "AUTO/MANUELL-Toggle funktioniert: AUTO kauft Wurzel/Blatt (10 Glucose), MANUELL per Klick",
    "HUD: Glucose mit Icon, Wasserbalken, Inventar, Zeit-Platzhalter, Toggle, DE/EN, Speichern/Laden, Skilltree-Platzhalter, Toasts",
    "Rechtsklick = Info (Baumwerte bzw. Bodenmaterial / Tiefe / Seed)",
    "Speichern/Laden-Button: JSON in `user://savegame.json` inkl. Seed + Baumwerten (Roundtrip getestet)",
    "PHASE 0 unverändert: 5 infinite Chunks, Hügel, Schichten, Fels, Zoom/Pan, Nearest, Forward+",
    "Keine externen Addons, keine Tag/Nacht, keine 3D-Nodes, kein C#",
    "Import, F5-Ersatz, `--phase0-smoke`, `--phase1-smoke`: Exit 0 / 0 rote Fehler",
]

NOTES = [
    "**Historischer Bericht:** Diese Datei beschreibt den Stand bei Abschluss der genannten Phase. Inzwischen sind PHASE 1 und PHASE 2 fertig – aktueller Stand: `PHASE2-ERGEBNIS.html` / `DECISIONS.md`.",

    "**PHASE 2 wurde nicht begonnen.** Richtungsbasiertes Wurzelwachstum, Bodenhärte/Kosten, Ghost-Preview, endliche Wasserreservoirs, Höhlen, L-System, Jahreszeiten, Schwierigkeitsgrade, Skilltree-UI, Tiere, Pilze und Parasiten sind bewusst noch nicht drin.",
    "**MANUELL ist in PHASE 1 absichtlich minimal:** Klickhöhe entscheidet Wurzel (unter der Oberfläche) oder Blatt (darüber), Kosten 10 Glucose. PHASE 2 ersetzt das durch Wachstum in Erd-Richtung mit Boden-Kosten und Ghost-Preview.",
    "**Save/Load ist schon drin**, obwohl es keiner Phase explizit zugeordnet ist: wegen des Zufalls-Seeds wäre dieselbe Welt sonst nach einem Neustart nicht mehr erreichbar. Punkt 9 und die MVP-Akzeptanzkriterien verlangen es ohnehin.",
    "**404-Repos ignoriert** (vom Nutzer bestätigt, keine lokalen Kopien). Referenzen jetzt: `GDQuest/godot-procedural-generation` (Seed-/Sektor-Muster, weiter aktiv) und `Tdead1/GodotGeneration` (Godot 3, Nachbar-Smoothing → Notiz für PHASE 2/5). Chunk-/Height-Logik bleibt eigene `FastNoiseLite`-Implementierung wie in Punkt 3.1.",
    "Zeit-Anzeige „Jahr 1 · Frühling“ und der deaktivierte Skilltree-Button sind Platzhalter (PHASE 3 / PHASE 4). `R` löst Regen sofort aus (Dev-Hook); das echte 2–5-Minuten-Intervall bleibt unverändert.",
    "Screenshots: echtes Godot 4.7.2 unter Xvfb mit Software-Rendering, reproduzierbar via `--seed=20261105 --phase1-shot-{bird,tree,rain}`. `project.godot` steht weiterhin auf **Forward+ / Vulkan**.",
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md() -> str:
    out = [
        "# PHASE 1 — Ergebnis",
        "",
        "> **Status:** ✅ abgeschlossen · lauffähig · getestet  ",
        "> **Engine:** Godot `4.7.2.stable.official.ed1daf0bf` (Forward+ / Vulkan) · GDScript  ",
        "> **Datum:** 2026-11-05 · **Nächster Schritt:** PHASE 2 **erst nach deinem OK**",
        "",
        "**User-Entscheidungen umgesetzt:** ① Seed wird bei jedem Neustart neu gewürfelt (Save/Load hält ihn fest). ② Die zwei 404-Repos werden ignoriert; eigene `FastNoiseLite`-Logik + GDQuest / Tdead1 als Referenz, keine Addons.",
        "",
        "---",
        "",
        "## 1. Screenshots (echte Godot-Renders)",
        "",
    ]
    for fn, caption, meta in SHOTS:
        out += [f"![{caption}](screenshots/{fn})", "", f"*{caption} — {meta}*", ""]
    out += [
        "## 2. Was PHASE 1 liefert",
        "",
        "| Bereich | Datei |",
        "|---|---|",
        "| Zufalls-Seed / Settings / DE/EN | `src/autoload/Global.gd` |",
        "| Signals | `src/autoload/EventBus.gd` |",
        "| Baum-Basisklasse + Eiche | `src/plants/Tree.gd`, `src/plants/Oak.gd` |",
        "| Art-Daten als Resource | `src/data/TreeSpeciesData.gd`, `data/species/oak.tres` |",
        "| Fotosynthese / AUTO-Kauf | `src/systems/GrowthSystem.gd` |",
        "| Wasser / Regen (5x) | `src/systems/WaterSystem.gd` |",
        "| Zeit-Platzhalter | `src/systems/TimeManager.gd` |",
        "| JSON-Savegame | `src/systems/SaveManager.gd` |",
        "| Platzieren / Vogel / Auswahl / Info | `src/systems/InteractionController.gd` |",
        "| HUD, Regen-Linien, Vogel-Animation | `src/ui/HUD.gd`, `RainEffect.gd`, `BirdEvent.gd` |",
        "| Tests | `tests/Phase0Smoke.gd`, `tests/Phase1Smoke.gd` |",
        "",
        "## 3. Code-Snippets (direkt aus dem Projekt)",
        "",
    ]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += [
        "## 4. Testprotokoll",
        "",
        "```bash",
        "godot --headless --path . --import                  # 0 Fehler",
        "godot --headless --path . --quit-after 120          # F5-Ersatz: 0 Fehler",
        "godot --headless --path . -- --phase0-smoke         # Regression: Ergebnis OK",
        "godot --headless --path . -- --phase1-smoke         # 25 Checks: Ergebnis OK, Exit 0",
        "```",
        "",
        "```text",
        SMOKE_LOG,
        "```",
        "",
        "Zusätzlich: 3 Neustarts → 3 unterschiedliche Seeds; 4 Xvfb-Screenshots ohne Fehler; "
        "DE/EN-`tr()`-Check und Save/Load-Roundtrip im Smoke-Test.",
        "",
        "## 5. Abnahme PHASE 1",
        "",
    ]
    out += [f"- [x] {c}" for c in CHECKS]
    out += ["", "## 6. Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += [
        "",
        "---",
        "",
        "**Ich stoppe hier.** Sag mir „Weiter mit PHASE 2“, dann kommen manuelles Wurzelwachstum in Erd-Richtung, "
        "Boden-Typen mit unterschiedlichen Kosten, endliche/austrocknende Wasserreservoirs und Höhlen.",
        "",
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
<title>PHASE 1 — Ergebnis | Wald-Regeneration</title>
<style>
  :root {{ --bg:#15191b; --card:#1e2427; --line:#33403f; --txt:#e8e5d9; --dim:#a8b2ad; --accent:#a9c47c; --warm:#e7c98d; }}
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
  .badges {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:16px; }}
  .badge {{ background:#26302e; border:1px solid var(--line); border-radius:999px; padding:5px 12px; font-size:12.5px; }}
  .badge.ok {{ border-color:#5c7d4a; color:#cfe6ac; }}
  h2 {{ font-size:21px; margin:42px 0 16px; padding-left:12px; border-left:3px solid var(--accent); }}
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
    <h1>PHASE 1 — Ergebnis</h1>
    <div class="sub">Kern-Loop: 2 Eicheln, Vogel-Event, Keimung, Glucose/Wasser, Regen (5x), AUTO/MANUELL.</div>
    <div class="decision">① Seed wird bei <strong>jedem Neustart neu gewürfelt</strong> (Save/Load hält ihn fest) · ② 404-Repos <strong>ignoriert</strong>, eigene FastNoiseLite-Logik + GDQuest / Tdead1, keine Addons.</div>
    <div class="badges">
      <span class="badge ok">✓ abgeschlossen</span>
      <span class="badge ok">✓ 0 Fehler im Output</span>
      <span class="badge">Forward+ / Vulkan</span>
      <span class="badge">25 Smoke-Checks OK</span>
      <span class="badge">2026-11-05</span>
      <span class="badge">PHASE 2 nicht begonnen</span>
    </div>
  </header>

  <h2>1 · Screenshots (echte Godot-Renders)</h2>
  <div class="gallery">{shots_html}
  </div>

  <h2>2 · Code-Snippets</h2>
  {code_html}

  <h2>3 · Testprotokoll</h2>
  <pre class="codeblock"><code>godot --headless --path . --import                  # 0 Fehler
godot --headless --path . --quit-after 120          # F5-Ersatz: 0 Fehler
godot --headless --path . -- --phase0-smoke         # Regression: OK
godot --headless --path . -- --phase1-smoke         # 25 Checks: OK, Exit 0</code></pre>
  <pre class="codeblock"><code>{html.escape(SMOKE_LOG)}</code></pre>
  <p class="sub">3 Neustarts → 3 unterschiedliche Seeds · 4 Xvfb-Screenshots ohne Fehler · DE/EN- und Save/Load-Roundtrip im Smoke-Test.</p>

  <h2>4 · Abnahme PHASE 1</h2>
  <ul>{checks_html}</ul>

  <h2>5 · Hinweise / bewusste Grenzen</h2>
  <div class="note"><ul>{notes_html}</ul></div>

  <footer><strong>Ich stoppe hier.</strong> Sag „Weiter mit PHASE 2“, dann kommen richtungsbasiertes Wurzelwachstum, Boden-Kosten, endliche Wasserreservoirs und Höhlen.</footer>
</div>
</body>
</html>
"""


if __name__ == "__main__":
    (ROOT / "PHASE1-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "PHASE1-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: PHASE1-ERGEBNIS.md / .html")
