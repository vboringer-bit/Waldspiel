#!/usr/bin/env python3
"""KORREKTURRUNDE P8.1 — selbst enthaltener MD/HTML-Bericht (Data-URIs)."""
from __future__ import annotations

from pathlib import Path
import base64
import html

ROOT = Path(__file__).resolve().parent.parent

SHOTS = [
    ("wildlife", "Eichhoernchen am Boden, Specht im Flug-Frame, vier gestapelte Nachrichten"),
    ("toasts", "Fuenf Nachrichten uebereinander, jede mit eigener Lebenszeit"),
    ("seam", "Kamera genau auf einer Chunkgrenze: durchgehende Oberkante und Bodenfaerbung"),
]

CHECKS = [
    ("Import", "0 Fehler (Godot 4.7.2, --headless --import)"),
    ("Skilltree", "24 Knoten / 23 Verbindungen"),
    ("Smokes", "18/18 gruen: 1005 OK-Zeilen, 0 FEHLER; drei komplette Final-Laeufe (neu: --fix-smoke, 118 Checks)"),
    ("F5-Lauf", "180 Frames, exit 0, 0 Fehler, zeitgescheitelte Chunks aktiv"),
    ("Renders", "3 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Eichhoernchen klein", "BODY_SPAN 40 -> 26px, Zeichnung 0.65x, Hitbox 26x22"),
    ("Nie in der Luft", "_follow_ground() nach jedem Tick; 7 Positionen + 50 Ticks geprueft"),
    ("Baumklettern", "Neuer State.CLIMB: auf und ab am Stamm, danach wieder bodengebunden"),
    ("Eicheln verstreut", "Richtung + 0.6..2.4x Entfernung + Jitter, >= 30 verschiedene Ziele"),
    ("Nur 20% Keimung", "GERMINATION_CHANCE = 0.20; 40 Transporte -> Keimungen im 20%-Bereich"),
    ("Seltener Transport", "CARRY_INTERVAL 22s -> 55s"),
    ("Specht fliegt", "Eigener _tick_woodpecker(): 90px Flughoehe, nie bodennah"),
    ("Frame-Animation", "4 eigene Flug-Frames + Perch-Frame; >= 3 Frames pro Flug nachgewiesen"),
    ("Sitzt / frisst", "State.PERCH am Stamm (tree.y - 64), Picken entfernt echte Parasiten"),
    ("Toast-Stack", "5 Zeilen, 6s Lesezeit, 1.5s Ausbleichen, danach entfernt"),
    ("Biom-Ruckler", "Blend-Signale gedrosselt (<= 5 statt 20), HUD-Refreshes koalesziert, Himmel interpoliert"),
    ("WASD-Ruckler", "Chunk-Bau 711ms -> 2-Spalten-Scheiben mit 4ms Frame-Budget; Cache 31ms"),
    ("Chunk-Naht", "32 Streifen in Weltkoordinaten; |letzter| - |erster| < 0.01"),
    ("Regression", "FORMAT_VERSION 6, AUTO aus, GLUCOSE_PACE 0.2, 21 PATHS, 24/23 Skills, 16px-Hitbox"),
]

SECTIONS = [
    (
        "Diagnose statt Raten",
        """Der User meldete neun konkrete Fehler. Fuer jeden wurde die Ursache im Code lokalisiert:
        <code>TerrainSurface</code> berechnete den Biom-Ton <b>einmal in der Chunk-Mitte</b> und erzeugte damit einen harten Farbsprung alle 2048px.
        <code>ChunkManager._refresh()</code> baute neue Chunks <b>synchron in einem Frame</b> — gemessen <b>711ms</b> pro Chunk.
        <code>BiomeSystem</code> emittierte mit 10Hz Blend-Signale, <code>HUD</code> verband 27 Signale direkt mit einem vollen <code>refresh()</code>.
        <code>Animal.tick()</code> hielt Eichhoernchen und Specht auf einer beim Spawn eingefrorenen <code>base_y</code>; das Eichhoernchen-Ziel war konstant <code>erster Baum + 2304px</code>.
        Alle Annahmen sind in <code>DECISIONS.md</code> §78 dokumentiert.""",
    ),
    (
        "Tierwelt",
        """Das Eichhoernchen ist jetzt <b>26px</b> statt 40px gross, steht nach <b>jeder</b> Bewegung per <code>_follow_ground()</code> auf der 4px-Gelaendekante
        und kann im neuen <code>State.CLIMB</code> an einem nahen Baum hoch- und wieder herunterklettern. Der Specht hat einen eigenen <code>_tick_woodpecker()</code>
        mit 90px Flughoehe und <b>vier selbst gezeichneten Flug-Frames</b> plus einem Sitz-Frame (9 fps). Nach <code>HELP_TREE</code> setzt er sich im
        <code>State.PERCH</code> 64px ueber den Stammfuss und frisst im 0,5s-Takt echte Parasiten. Der erste Pick bleibt bei der Ankunft erhalten,
        damit <code>Phase5Smoke</code> unveraendert gruen bleibt. Verschleppte Eicheln landen jetzt <b>verstreut in beide Richtungen</b>, nur <b>20%</b> keimen
        und der Transport wurde von 22s auf <b>55s</b> verlangsamt. Der garantierte Test-Hook <code>debug_force_remote_seed()</code> bleibt unberuehrt.""",
    ),
    (
        "Performance und Naht",
        """<code>TerrainChunk</code> baut optional in <b>2-Spalten-Scheiben</b>; <code>ChunkManager</code> arbeitet pro Frame nur ein <b>4ms-Budget</b> ab.
        Weil <code>load_radius = 2</code> ist, liegt der neu gebaute Chunk zwei Chunks neben der Kamera und damit ausserhalb des sichtbaren Ausschnitts —
        kein Pop-in. Die fuenf Start-Chunks bleiben synchron, die 18 Headless-Smokes ebenfalls. Zusaetzlich cachen
        <code>_raw_res_cache</code> und <code>_slot_cache</code> die doppelten Noise-Berechnungen (Wiederholbau <b>31ms</b> statt 711ms).
        <code>BiomeSystem</code> sendet Blend-Aenderungen hoechstens alle 0,35s, <code>HUD</code> sammelt 27 Signal-Refreshes in einem Dirty-Flag
        und <code>SkyBackground</code> interpoliert den Himmelston einmal pro Frame. Die Oberkante wird in <b>32 Streifen in Weltkoordinaten</b> getoent —
        der letzte Streifen von Chunk n und der erste von Chunk n+1 sind praktisch identisch.""",
    ),
    (
        "Nachrichten und Regression",
        """Statt eines ueberschriebenen Labels zeigt <code>HUD</code> jetzt einen <code>VBoxContainer</code> mit bis zu <b>5 Zeilen</b>:
        neue Meldungen stapeln sich darunter, bleiben <b>6s</b> voll lesbar, bleichen in den letzten <b>1,5s</b> aus und werden entfernt.
        Unveraendert bleiben <code>FORMAT_VERSION = 6</code>, <code>Global.auto_mode = false</code>, <code>GLUCOSE_PACE = 0.2</code>,
        <b>21</b> <code>PixelArt.PATHS</code>-Slots (die neuen Frames liegen bewusst ausserhalb), 24/23 Skillnodes, das 16px-Raster,
        alle P7-Biomfaktoren und die P8-Vogel-Progression. Die einzige angepasste alte Erwartung ist die Groesse des Eichhoernchens
        in <code>Revision5Smoke</code> — das ist die neue Anforderung, keine Aufweichung.""",
    ),
]


def grab(path: str, needle: str, count: int) -> str:
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if needle in line:
            return "\n".join(lines[i:i + count])
    raise SystemExit(f"FEHLER: Snippet-Anker fehlt: {path} :: {needle}")


SNIPPETS = [
    ("Nahtlose Oberkante in Weltkoordinaten", "src/world/TerrainSurface.gd",
     grab("src/world/TerrainSurface.gd", "var any_tint := false", 22)),
    ("Globale Deko-Dichte ohne Chunk-Sprung", "src/world/WorldGenerator.gd",
     grab("src/world/WorldGenerator.gd", "func decorations_for_chunk(", 14)),
    ("Chunk in Scheiben bauen", "src/world/Chunk.gd",
     grab("src/world/Chunk.gd", "func build_slice(cols: int) -> bool:", 26)),
    ("Frame-Budget im ChunkManager", "src/world/ChunkManager.gd",
     grab("src/world/ChunkManager.gd", "func _drain_jobs(budget_usec: int)", 16)),
    ("Gedrosselte Biom-Signale", "src/systems/BiomeSystem.gd",
     grab("src/systems/BiomeSystem.gd", "func _update_at(world_x: float", 20)),
    ("Koaleszierte HUD-Refreshes", "src/ui/HUD.gd",
     grab("src/ui/HUD.gd", "func _request_refresh() -> void:", 22)),
    ("Sanfter Himmelsuebergang", "src/background/SkyBackground.gd",
     grab("src/background/SkyBackground.gd", "func _on_biome_changed(", 24)),
    ("Eichhoernchen bodengebunden", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "func _tick_squirrel(dt: float)", 32)),
    ("Klettern am Stamm", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "func _tick_climb(dt: float)", 22)),
    ("Specht-Frame-Auswahl", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "func _woodpecker_frame_index()", 12)),
    ("Verstreute Eicheln, 20% Keimung", "src/systems/WildlifeSystem.gd",
     grab("src/systems/WildlifeSystem.gd", "func _scattered_carry_target(", 16)),
    ("Toast-Stack", "src/ui/HUD.gd",
     grab("src/ui/HUD.gd", "func _on_toast(text: String)", 22)),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def strip_tags(text: str) -> str:
    return (text.replace("<b>", "**").replace("</b>", "**")
            .replace("<code>", "`").replace("</code>", "`"))


def build_md(images: list[tuple[str, str]]) -> str:
    lines = ["# KORREKTURRUNDE P8.1 — neun gemeldete Fehler behoben", "",
             "Nachfolger von `a144657` (PHASE 8). Vollstaendiger Stand im Workspace und auf GitHub.", "",
             "## Vier Arbeitsblöcke", ""]
    for i, (title, body) in enumerate(SECTIONS, 1):
        lines += [f"{i}. **{title}.** {' '.join(strip_tags(body).split())}", ""]
    lines += ["## Testergebnisse", "", "| Pruefung | Ergebnis |", "|---|---|"]
    for name, result in CHECKS:
        lines.append(f"| {name} | {result} |")
    lines += ["", "## Screenshots", ""]
    for slug, caption in SHOTS:
        lines += [f"![{caption}](data:image/png;base64,{dict(images)[slug]})",
                  f"*{caption} — `screenshots/fix_{slug}.png`*", ""]
    lines += ["## Code-Auszuege", ""]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += ["## Bewusste Grenze", "",
              "Kein Tag/Nacht (§5/§12), keine begehbaren Berge, keine 40-60 Skillnodes, kein SFX. "
              "Die historischen P0-P8-Pakete bleiben unveraendert erhalten. Siehe "
              "`PHASE8-FIX-TESTPROTOKOLL.txt`, `DECISIONS.md` §78 und `deliverables/waldspiel-PHASE8-FIX.zip`.", ""]
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
td:first-child{width:210px;color:#bcd6a4}
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
        "<title>KORREKTURRUNDE P8.1 — Waldspiel</title><style>", CSS,
        "</style></head><body><div class=\"wrap\">",
        "<h1>KORREKTURRUNDE P8.1 — neun Fehler behoben</h1>",
        "<p><span class=\"badge\">Bugfix-Runde</span> Basis <code>a144657</code> "
        "· dokumentierte Annahmen in <code>DECISIONS.md</code> §78</p>",
        "<h2>Vier Arbeitsblöcke</h2><ol>",
    ]
    for title, body in SECTIONS:
        parts.append(f"<li><b>{html.escape(title)}.</b> {body}</li>")
    parts.append("</ol><h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>")
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table><h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        parts.append(f"<img alt=\"{html.escape(caption)}\" src=\"data:image/png;base64,{dict(images)[slug]}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — <code>screenshots/fix_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append("<h2>Lieferung</h2><p class=\"note\">Vollstaendiger Stand inklusive "
                 "<code>deliverables/waldspiel-PHASE8-FIX.zip</code>. Nach Import, 18/18 Smokes, "
                 "drei Final-Laeufen, F5-Lauf, Renders und frischem ZIP-Extrakt als ein Commit "
                 "auf <code>main</code> gepusht. Keine Credentials im Repo.</p></div></body></html>")
    return "".join(parts)


def main() -> None:
    images = []
    for slug, _caption in SHOTS:
        p = ROOT / f"screenshots/fix_{slug}.png"
        if not p.exists():
            raise SystemExit(f"FEHLER: Screenshot fehlt: {p}")
        images.append((slug, b64(p)))
    (ROOT / "PHASE8-FIX-ERGEBNIS.md").write_text(build_md(images), encoding="utf-8")
    (ROOT / "PHASE8-FIX-ERGEBNIS.html").write_text(build_html(images), encoding="utf-8")
    print(f"[FIX-REPORT] md + html geschrieben | Bilder: {len(SHOTS)} | "
          f"Snippets: {len(SNIPPETS)} | Checks: {len(CHECKS)}")


if __name__ == "__main__":
    main()
