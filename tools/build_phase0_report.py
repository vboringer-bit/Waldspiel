#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt PHASE0-ERGEBNIS.md und PHASE0-ERGEBNIS.html (= offline Preview).
Die Code-Snippets werden direkt aus den echten Projektdateien ausgeschnitten,
damit der Bericht nicht von der Realitaet abweicht. Bilder werden im HTML als
data: URIs eingebettet (funktioniert im sandboxed Viewer ohne Netzwerk).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHOTS = [
    ("phase0_start.png", "F5-Startansicht: Himmel, Berge, Hügel, Asche, Bodenquerschnitt", "Zoom 1.00x · Kamera x=0"),
    ("phase0_soil.png", "Bodenquerschnitt bis zum Fels-Basement", "Zoom 0.85x · Kamera y=790"),
    ("phase0_pan.png", "Infinite Chunks: nach dem Pan auf x=4300", "Zoom 0.75x · Kamera x=4300"),
]


def extract(rel: str, start: str, end: str | None = None) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8")
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"Start-Marker nicht gefunden: {start!r} in {rel}")
    j = text.find(end, i) if end else len(text)
    if j < 0:
        raise RuntimeError(f"End-Marker nicht gefunden: {end!r} in {rel}")
    return text[i:j].rstrip() + "\n"


SNIPPETS = [
    ("project.godot — Engine, Autoloads, Pixel-Perfekt", "ini",
     extract("project.godot", "config_version=5", "[layer_names]")),
    ("WorldGenerator.gd — seed-basierte Höhenlinie (height_at)", "gdscript",
     extract("src/world/WorldGenerator.gd", "func height_at(world_x: float) -> float:", "func biome_at")),
    ("WorldGenerator.gd — Boden-Schichtung (material_at)", "gdscript",
     extract("src/world/WorldGenerator.gd", "func material_at", "## Liefert den Atlas-Slot")),
    ("ChunkManager.gd — 5 Chunks laden/entladen + Pause", "gdscript",
     extract("src/world/ChunkManager.gd", "func _refresh() -> void:", "func loaded_chunk_count")),
    ("Chunk.gd — TileMapLayer pro Chunk", "gdscript",
     extract("src/world/Chunk.gd", "func _build_terrain", "func _build_decor")),
    ("CameraController.gd — Mausrad-Zoom & Pan", "gdscript",
     extract("src/camera/CameraController.gd", "func _unhandled_input", "func teleport_to")),
]

SMOKE_LOG = """[Global] PHASE 0 | seed=20261105 | difficulty=NORMAL | Godot 4.7.2-stable (official)
[Main] PHASE 0 bereit: Himmel + Bodenquerschnitt, Zoom/Pan, infinite Chunks.
[SMOKE] === PHASE 0 ===
[SMOKE] deterministische Hoehen/Materialien/Deko: OK
[SMOKE] Settings Nearest/Forward+/1920x1080/canvas_items: OK
[SMOKE] x=      0  chunks=5  idx=[-2, -1, 0, 1, 2]
[SMOKE] x=   2100  chunks=5  idx=[-1, 0, 1, 2, 3]
[SMOKE] x=   4300  chunks=5  idx=[0, 1, 2, 3, 4]
[SMOKE] x=   8600  chunks=5  idx=[2, 3, 4, 5, 6]
[SMOKE] x=  -2200  chunks=5  idx=[-4, -3, -2, -1, 0]
[SMOKE] x=  -6500  chunks=5  idx=[-6, -5, -4, -3, -2]
[SMOKE] x=      0  chunks=5  idx=[-2, -1, 0, 1, 2]
[SMOKE] Schichten (Tiefe 0/1/5/20/60 Tiles): ASH, HUMUS, TOPSOIL, CLAY, ROCK
[SMOKE] Ergebnis: OK"""

CHECKS = [
    "project.godot: Godot 4.7.2, Forward+ (Vulkan), 1920×1080, canvas_items, Nearest, Mipmaps aus",
    "Komplette Ordnerstruktur aus Punkt 9 (Autoload / World / Camera / UI / Plants / Systems / Data)",
    "15 selbst generierte Platzhalter-PNGs: Boden-Atlas, Stamm, Blatt, Wurzel, Eichel, Vogel, 3 Stümpfe, Ast, Himmel, Berge",
    "Kamera: Mausrad-Zoom 0.5x–2.0x mit weichem Lerp, WASD + Maus-am-Rand-Pan",
    "ChunkManager: 2048px-Chunks, unebener Boden per FastNoiseLite, seed-deterministisch",
    "1 Biom (temperiert), 4 Bodenschichten + Fels-Basement, Steinklumpen, Alternative Tiles gegen Rastermuster",
    "Infinite Chunks: 5 gleichzeitig, Nachladen/Entladen, process_mode=DISABLED für äußere Ringe",
    "Start-Zustand: 4 verkohlte Stümpfe + Äste, keine lebenden Bäume; Berge nur Silhouette ohne Kollision",
    "DE/EN-CSV am TranslationServer, Global/EventBus-Autoloads, Headless-Smoke-Test",
    "Kein roter Fehler im Output (Import, F5-Lauf, Smoke-Test, 3 Renders)",
]

NOTES = [
    "**Historischer Bericht:** Diese Datei beschreibt den Stand bei Abschluss der genannten Phase. Inzwischen sind PHASE 1 und PHASE 2 fertig – aktueller Stand: `PHASE2-ERGEBNIS.html` / `DECISIONS.md`.",

    "**PHASE 1 wurde nicht begonnen.** Inventar, Eicheln, Vogel-Event, Keimung, Glucose/Wasser, Regen, Auto/Manuell, Speichern, HUD, Zeit, Skilltree und Tiere sind bewusst noch nicht drin.",
    "Zwei Referenz-Repos (`godot-pixel-sculpt`, `godot-poly-sculpt`) sind 404 — vom Nutzer inzwischen bestätigt und ignoriert. Die eigene FastNoiseLite-Logik (`height_at(x)` + 2048px-Chunks) bleibt, wie in Master-Punkt 3.1 beschrieben. Details: DECISIONS.md Abschnitt 9.",
    "Die Screenshots wurden mit Xvfb + Software-Rendering aus dem echten Godot 4.7.2 Binary erzeugt; `project.godot` selbst steht auf **Forward+ / Vulkan**. Auf deiner GPU läuft F5 mit Vulkan.",
    "Der Screenshot der Startansicht zeigt bewusst viel Himmel; mit `WASD`/Mausrad (oder dem Preset `-- --phase0-shot-soil`) siehst du das Fels-Basement. Alle drei Bilder sind reproduzierbar.",
]

QUESTIONS = [
    "Start-Seed: **vom Nutzer entschieden** → wird seit PHASE 1 bei jedem Neustart neu gewürfelt (Save/Load hält ihn fest).",
    "404-Repos: **vom Nutzer entschieden** → ignorieren; stattdessen eigene FastNoiseLite-Logik plus GDQuest / Tdead1 als Referenz.",
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


# --------------------------------------------------------------------------- #
# Markdown
# --------------------------------------------------------------------------- #
def build_md() -> str:
    out = [
        "# PHASE 0 — Ergebnis",
        "",
        "> **Status:** ✅ abgeschlossen · lauffähig · getestet  ",
        "> **Engine:** Godot `4.7.2.stable.official.ed1daf0bf` (Forward+ / Vulkan) · GDScript  ",
        "> **Datum:** 2026-11-05 · **Nächster Schritt:** PHASE 1 **erst nach deinem OK**",
        "",
        "---",
        "",
        "## 1. Screenshots (echte Godot-Renders, keine Mockups)",
        "",
    ]
    for fn, caption, meta in SHOTS:
        out += [f"![{caption}](screenshots/{fn})", "", f"*{caption} — {meta}*", ""]
    out += [
        "## 2. Was PHASE 0 liefert",
        "",
        "| Bereich | Datei |",
        "|---|---|",
        "| Einstieg / Verdrahtung | `src/Main.gd`, `src/Main.tscn` |",
        "| Globals / Signals | `src/autoload/Global.gd`, `src/autoload/EventBus.gd` |",
        "| Weltberechnung | `src/world/WorldGenerator.gd` (`height_at`, `material_at`, `chunk_seed`) |",
        "| Chunks | `src/world/ChunkManager.gd`, `Chunk.gd`, `TerrainAtlas.gd` |",
        "| Kamera | `src/camera/CameraController.gd` |",
        "| Hintergrund | `src/background/SkyBackground.gd`, `MountainBackdrop.gd` |",
        "| Info-Overlay | `src/ui/Phase0Overlay.gd` |",
        "| Grafiken | `assets/placeholders/` (Generator: `tools/generate_placeholders.py`) |",
        "| Tests | `tests/Phase0Smoke.gd` |",
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
        "godot --headless --path . --import                 # 0 Fehler",
        "godot --headless --path . --quit-after 120         # F5-Ersatz: 0 Fehler",
        "godot --headless --path . -- --phase0-smoke        # Exit 0, 'Ergebnis: OK'",
        "```",
        "",
        "```text",
        SMOKE_LOG,
        "```",
        "",
        "Zusätzlich: 5 aufeinanderfolgende Smoke-Läufe → 5× Exit 0 / 0 Fehler. "
        "Alle 15 `.import`-Dateien haben `mipmaps/generate=false`.",
        "",
        "## 5. Abnahme PHASE 0",
        "",
    ]
    out += [f"- [x] {c}" for c in CHECKS]
    out += ["", "## 6. Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 7. Zwei Rückfragen (nicht blockierend)", ""]
    out += [f"{i}. {q}" for i, q in enumerate(QUESTIONS, 1)]
    out += [
        "",
        "---",
        "",
        "**Ich stoppe hier.** Sag mir „Weiter mit PHASE 1“ (und ggf. deine Antworten), "
        "dann baue ich den Kern-Loop: 2 Eicheln, Vogel-Event, Keimung, Glucose/Wasser, Regen, Auto/Manuell.",
        "",
    ]
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# HTML (self-contained, data URIs)
# --------------------------------------------------------------------------- #
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
        <details open>
          <summary>{html.escape(title)}</summary>
          <pre><code>{html.escape(code.rstrip())}</code></pre>
        </details>"""

    checks_html = "".join(f"<li><span class='tick'>✓</span>{html.escape(c)}</li>" for c in CHECKS)
    notes_html = "".join(f"<li>{n}</li>" for n in [
        x.replace("**", "") for x in NOTES
    ])
    questions_html = "".join(f"<li>{html.escape(q)}</li>" for q in QUESTIONS)

    return f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PHASE 0 — Ergebnis | Wald-Regeneration</title>
<style>
  :root {{ --bg:#15191b; --card:#1e2427; --line:#33403f; --txt:#e8e5d9; --dim:#a8b2ad; --accent:#a9c47c; --warm:#e7c98d; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--txt);
         font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;
         line-height:1.6; }}
  .wrap {{ max-width:1100px; margin:0 auto; padding:36px 24px 80px; }}
  header {{ border-bottom:1px solid var(--line); padding-bottom:22px; margin-bottom:30px; }}
  .kicker {{ color:var(--accent); font-size:12px; letter-spacing:.22em; text-transform:uppercase; font-weight:700; }}
  h1 {{ font-size:38px; margin:8px 0 6px; letter-spacing:-.02em; }}
  .sub {{ color:var(--dim); font-size:15px; }}
  .badges {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:16px; }}
  .badge {{ background:#26302e; border:1px solid var(--line); color:var(--txt);
            border-radius:999px; padding:5px 12px; font-size:12.5px; }}
  .badge.ok {{ border-color:#5c7d4a; color:#cfe6ac; }}
  h2 {{ font-size:21px; margin:42px 0 16px; padding-left:12px; border-left:3px solid var(--accent); }}
  .gallery {{ display:grid; gap:20px; }}
  figure {{ margin:0; background:var(--card); border:1px solid var(--line); border-radius:12px; overflow:hidden; }}
  figure img {{ display:block; width:100%; height:auto; image-rendering:pixelated; }}
  figcaption {{ display:flex; justify-content:space-between; flex-wrap:wrap; gap:8px;
                padding:12px 16px; font-size:13.5px; border-top:1px solid var(--line); }}
  figcaption span {{ color:var(--dim); font-variant-numeric:tabular-nums; }}
  details {{ background:var(--card); border:1px solid var(--line); border-radius:10px; margin-bottom:10px; overflow:hidden; }}
  summary {{ cursor:pointer; padding:12px 16px; font-weight:600; font-size:14px; color:var(--warm); }}
  pre {{ margin:0; padding:0 16px 16px; overflow-x:auto; }}
  code {{ font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:12.5px;
          line-height:1.55; color:#d6e0d4; white-space:pre; }}
  pre.codeblock {{ background:#0e1213; border:1px solid var(--line); border-radius:10px;
                   padding:16px; overflow-x:auto; margin:0 0 16px; }}
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
    <h1>PHASE 0 — Ergebnis</h1>
    <div class="sub">Setup: leeres Projekt, Platzhalter-Pixel, Kamera mit Zoom/Pan, ChunkManager mit Hügeln, 1 Biom und Fels unten.</div>
    <div class="badges">
      <span class="badge ok">✓ abgeschlossen</span>
      <span class="badge ok">✓ 0 Fehler im Output</span>
      <span class="badge">Forward+ / Vulkan</span>
      <span class="badge">1920×1080 · Nearest</span>
      <span class="badge">2026-11-05</span>
      <span class="badge">PHASE 1 nicht begonnen</span>
    </div>
  </header>

  <h2>1 · Screenshots (echte Godot-Renders)</h2>
  <div class="gallery">{shots_html}
  </div>

  <h2>2 · Code-Snippets</h2>
  {code_html}

  <h2>3 · Testprotokoll</h2>
  <pre class="codeblock"><code>godot --headless --path . --import                 # 0 Fehler
godot --headless --path . --quit-after 120         # F5-Ersatz: 0 Fehler
godot --headless --path . -- --phase0-smoke        # Exit 0 · Ergebnis: OK</code></pre>
  <pre class="codeblock"><code>{html.escape(SMOKE_LOG)}</code></pre>
  <p class="sub">5 aufeinanderfolgende Smoke-Läufe: 5× Exit 0 / 0 Fehler. Alle 15 <code>.import</code>-Dateien: <code>mipmaps/generate=false</code>.</p>

  <h2>4 · Abnahme PHASE 0</h2>
  <ul>{checks_html}</ul>

  <h2>5 · Hinweise / bewusste Grenzen</h2>
  <div class="note"><ul>{notes_html}</ul></div>

  <h2>6 · Zwei Rückfragen (nicht blockierend)</h2>
  <ol>{questions_html}</ol>

  <footer><strong>Ich stoppe hier.</strong> Sag „Weiter mit PHASE 1“, dann kommen 2 Eicheln, Vogel-Event, Keimung, Glucose/Wasser, Regen und der Auto/Manuell-Toggle.</footer>
</div>
</body>
</html>
"""


if __name__ == "__main__":
    (ROOT / "PHASE0-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "PHASE0-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: PHASE0-ERGEBNIS.md / .html")
