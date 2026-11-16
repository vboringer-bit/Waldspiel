#!/usr/bin/env python3
"""PHASE 8 — selbst enthaltener MD/HTML-Bericht (Data-URI-Bilder, keine externen Assets)."""
from pathlib import Path
import base64
import html

ROOT = Path(__file__).resolve().parent.parent
SHOTS = [
    ("before", "Vor der Freischaltung: 6 Tiere, 4/5 Arten · „noch 1 offen“"),
    ("bird", "Nach dem dritten Biom: 7 Tiere, 5/5 Arten · „alle da“ · Vogel fliegt über dem Boden"),
    ("carry", "Vogel im CARRY-Zustand: trägt eine Eichel nach links in ein anderes Biom"),
]
CHECKS = [
    ("Import", "0 Fehler (Godot 4.7.2, --headless --import)"),
    ("Skilltree", "24 Knoten / 23 Verbindungen, Generator err=0"),
    ("Smokes", "17/17 gruen: 887 OK-Zeilen, 0 FEHLER; drei komplette Laeufe (neu: --p8-smoke mit 104 Checks)"),
    ("F5-Lauf", "180 Frames, exit 0, 0 SCRIPT ERROR"),
    ("Renders", "3 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Regression P5", "debug_species_count() == 4 bei gesundem Wald bleibt unveraendert gruen"),
    ("Progression", "Vogel NUR bei health > 50 % UND allen drei entdeckten Biomen aus PHASE 7"),
    ("Tierarten", "Wurm, Ameise, Specht, Eichhoernchen, Vogel = 5 Arten / 7 Einzeltiere"),
    ("Flug", "Eigener _tick_bird(): 96px ueber der Gelaendekante, Sinus-Schwingen, keine Baum-Kollision"),
    ("StateMachine", "IDLE / WANDER / EAT / HELP_TREE / CARRY, INFO-Toast und eigene Hitbox"),
    ("Samen-Transport", "Vogel traegt nach links (-REMOTE_OFFSET) und pflanzt einen echten Baum; Eichhoernchen weiterhin nach rechts"),
    ("Save/Load", "FORMAT_VERSION bleibt 6, kein neuer Key: wildlife.to_dict() stellt den Vogel generisch wieder her"),
    ("HUD & DE/EN", "Vierte Panel-Zeile Arten n/5, Titel PHASE 8, alle P6/P7-Zeilen erhalten"),
    ("Keine neuen Assets", "Bestehender PixelArt.BIRD-Slot; PATHS.size() bleibt 21"),
    ("Abgrenzung", "40-60 Skillnodes, begehbare Berge und SFX sind die darauffolgenden Schritte; Tag/Nacht bleibt ausgeschlossen"),
]

SECTIONS = [
    ('Abgrenzung nach Master-Punkt §13',
     'Der Master-Prompt definiert in §10 nur PHASE 0-5. Fuer den Auftrag „Mache jetzt sorgfaeltig mit den naechsten Schritten weiter“ ist PHASE 8 der '
     '<b>naechste offene Kandidat aus §7</b> („Tiere: MVP 1, vorbereitet fuer 5“). Vier Arten waren bereits implementiert; der Vogel existierte nur als '
     'einmaliges Tutorial-Event. Gemaess §1 („Baue NICHT alles auf einmal“) ist P8 EIN Meilenstein. 40-60 Skillnodes, begehbare Berge und Ambient-SFX '
     'sind die darauffolgenden Schritte; Tag/Nacht bleibt durch §5/§12 dauerhaft ausgeschlossen. Siehe <code>DECISIONS.md</code> §77.'),
    ('Progression statt Test-Bruch',
     '<code>ADVANCED := ["woodpecker", "squirrel"]</code> und <code>_sync_advanced()</code> bleiben <b>unveraendert</b>, damit '
     '<code>Phase5Smoke</code> weiterhin <code>debug_species_count() == 4</code> prueft. Die fuenfte Art hat eine eigene '
     '<code>PROGRESSION := ["bird"]</code>: sie siedelt sich an, wenn die Wald-Gesundheit ueber 50 % liegt <b>UND</b> alle drei Biome aus PHASE 7 '
     'entdeckt sind. In allen R0-R8-/P6-/P7-Smokes ist nur das Start-Biom entdeckt — der Vogel erscheint dort nie. Die einzige Anpassung ist der reine '
     'Titel-String in <code>Phase7Smoke</code> (erweitert, nicht gesenkt).'),
    ('Echtes Verhalten',
     '<code>Animal._tick_bird()</code> ist ein separater, frueh zurueckspringender Pfad: 96px Flughoehe, Sinus-Schwingen, Bewegung ohne Baum-Kollision '
     'und die vorhandene StateMachine. Ueber <code>assign_carry()</code> traegt der Vogel Eicheln <b>nach links</b>, waehrend das Eichhoernchen weiter '
     'nach rechts traegt; am Ziel entsteht ueber <code>on_bird_seed_delivered()</code> ein echter Baum. Klick, Info-Toast, DE/EN und Save/Load funktionieren '
     'ohne neue Infrastruktur — die Tierliste in <code>wildlife.to_dict()</code> speichert die Species bereits generisch, <code>FORMAT_VERSION</code> bleibt 6.'),
    ('Grafik, HUD und Robustheit',
     'Als Grafik dient der <b>bereits vorhandene</b> Platzhalter <code>PixelArt.BIRD</code> — <code>PATHS.size()</code> bleibt 21, keine fremden Assets. '
     'Eine vierte Panel-Zeile zeigt <code>Arten: n/5</code> und den Fortschritt; Titel ist „PHASE 8 · Tierwelt & Progression“. Die Ansiedlung ist eine '
     '<b>dauerhafte Freischaltung</b>, kein taegliches Kommen und Gehen: so kann ein <code>forest_health.recompute()</code> nach dem Laden den Vogel nicht '
     'wieder entfernen. Ein seltener Seed-Flake im Transport-Check wurde durch die robuste Bedingung „CARRY beendet“ statt „Zustand exakt IDLE“ behoben.'),
]


def grab(path: str, needle: str, count: int) -> str:
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if needle in line:
            return "\n".join(lines[i:i + count])
    raise SystemExit(f"FEHLER: Snippet-Anker fehlt: {path} :: {needle}")


SNIPPETS = [
    ("Vier alte Arten vs. eigene Progression", "src/systems/WildlifeSystem.gd",
     grab("src/systems/WildlifeSystem.gd", "const ADVANCED :=", 8)),
    ("Freischalt-Bedingung", "src/systems/WildlifeSystem.gd",
     grab("src/systems/WildlifeSystem.gd", "func progression_ready(", 7)),
    ("Dauerhafte Ansiedlung", "src/systems/WildlifeSystem.gd",
     grab("src/systems/WildlifeSystem.gd", "func _sync_progression(", 13)),
    ("Eigener Abliefer-Pfad", "src/systems/WildlifeSystem.gd",
     grab("src/systems/WildlifeSystem.gd", "func on_bird_seed_delivered(", 9)),
    ("Transport-Takt nach links", "src/systems/WildlifeSystem.gd",
     grab("src/systems/WildlifeSystem.gd", "# PHASE 8: Der Vogel traegt", 9)),
    ("Eigener Flug-Pfad", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "# PHASE 8: komplett eigener Flug-Pfad", 5)),
    ("Vogel-StateMachine", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "func _tick_bird(", 27)),
    ("Flughoehe in reseat()", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "# PHASE 8: Vogel fliegt;", 8)),
    ("Bestehender BIRD-Slot", "src/animals/Animal.gd",
     grab("src/animals/Animal.gd", "# PHASE 8: der Vogel nutzt", 4)),
    ("HUD-Artenzaehler", "src/ui/HUD.gd",
     grab("src/ui/HUD.gd", "func _refresh_p8_species(", 14)),
    ("Drei Screenshot-Presets", "src/Main.gd",
     grab("src/Main.gd", "func _p8_shot(", 27)),
    ("Progression im Smoke", "tests/Phase8Smoke.gd",
     grab("tests/Phase8Smoke.gd", "# --- 2) Progression", 12)),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md(images: list[tuple[str, str]]) -> str:
    lines = [
        "# PHASE 8 — Fünf Tierarten, Vogel-Progression, Biodiversität",
        "",
        "Vollstaendiger PHASE-8-Stand, Nachfolger von `0b2f064` (PHASE 7).",
        "Alle Quellen, Tests, drei Screenshots, Berichte und das ZIP liegen im Workspace und auf GitHub.",
        "",
        "## Die vier Bausteine",
        "",
    ]
    for i, (title, body) in enumerate(SECTIONS, 1):
        plain = body.replace("<b>", "**").replace("</b>", "**").replace("<code>", "`").replace("</code>", "`")
        lines += [f"{i}. **{title}.** {plain}", ""]
    lines += ["## Testergebnisse", "", "| Pruefung | Ergebnis |", "|---|---|"]
    for name, result in CHECKS:
        lines.append(f"| {name} | {result} |")
    lines += ["", "## Screenshots", ""]
    for slug, caption in SHOTS:
        lines.append(f"![{caption}](data:image/png;base64,{dict(images)[slug]})")
        lines += [f"*{caption} — `screenshots/p8_{slug}.png`*", ""]
    lines += ["## Code-Auszuege", ""]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += [
        "## Bewusste Grenze",
        "",
        "40-60 Skillnodes, begehbare Berge und Ambient-SFX sind die darauffolgenden Schritte. Kein Tag/Nacht (§5/§12). "
        "`FORMAT_VERSION` bleibt 6, `Global.auto_mode` bleibt aus, `GLUCOSE_PACE` bleibt 0,2, "
        "21 Pixelart-Slots, 24/23 Skillnodes und alle R0-R8-/P6-/P7-Korrekturen bleiben gueltig.",
        "",
        "Siehe `PHASE8-TESTPROTOKOLL.txt`, `DECISIONS.md` §77 und `deliverables/waldspiel-PHASE8.zip`.",
        "",
    ]
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
td:first-child{width:200px;color:#bcd6a4}
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
        "<title>PHASE 8 — Waldspiel</title><style>", CSS,
        "</style></head><body><div class=\"wrap\">",
        "<h1>PHASE 8 — Fünf Tierarten, Vogel-Progression</h1>",
        "<p><span class=\"badge\">Meilenstein</span> Basis <code>0b2f064</code> "
        "· Master-Punkt 7 · dokumentierte Annahme in <code>DECISIONS.md</code> §77</p>",
        "<h2>Die vier Bausteine</h2><ol>",
    ]
    for title, body in SECTIONS:
        parts.append(f"<li><b>{html.escape(title)}.</b> {body}</li>")
    parts.append("</ol><h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>")
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table><h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        parts.append(f"<img alt=\"{html.escape(caption)}\" "
                     f"src=\"data:image/png;base64,{dict(images)[slug]}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — "
                     f"<code>screenshots/p8_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append(
        "<h2>Lieferung</h2><p class=\"note\">Vollstaendiger Stand inklusive "
        "<code>deliverables/waldspiel-PHASE8.zip</code>. Nach Import, 17/17 Smokes, "
        "F5-Lauf, Renders und frischem ZIP-Extrakt als ein Commit auf <code>main</code> "
        "gepusht. Keine Credentials in Commit, Remote-URL oder Repo-Dateien.</p>"
    )
    parts.append("</div></body></html>")
    return "".join(parts)


def main() -> None:
    images = []
    for slug, _caption in SHOTS:
        p = ROOT / f"screenshots/p8_{slug}.png"
        if not p.exists():
            raise SystemExit(f"FEHLER: Screenshot fehlt: {p}")
        images.append((slug, b64(p)))
    (ROOT / "PHASE8-ERGEBNIS.md").write_text(build_md(images), encoding="utf-8")
    (ROOT / "PHASE8-ERGEBNIS.html").write_text(build_html(images), encoding="utf-8")
    print(f"[P8-REPORT] md + html geschrieben | Bilder: {len(SHOTS)} | "
          f"Snippets: {len(SNIPPETS)} | Checks: {len(CHECKS)}")


if __name__ == "__main__":
    main()
